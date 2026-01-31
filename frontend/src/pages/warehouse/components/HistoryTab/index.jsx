import React, { useEffect, useState } from 'react';
import { Table, Button, Input, Select, Grid, Tag, DatePicker } from 'antd';
import { FilterOutlined } from '@ant-design/icons';
import styles from './style.module.scss';
import { getStockMovements, getWarehouses } from '../../../../axios/api/warehouse/index';
import { handleApiError } from '../../../../utils/errorHandler';
// import moment from 'moment'; // If needed for date formatting

const { Option } = Select;
const { RangePicker } = DatePicker;

const HistoryTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);
    const [warehouses, setWarehouses] = useState([]);

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [typeFilter, setTypeFilter] = useState(null);
    const [warehouseFilter, setWarehouseFilter] = useState(null);
    const [showFilters, setShowFilters] = useState(false);

    const screens = Grid.useBreakpoint();

    // Debounce Search
    useEffect(() => {
        const timer = setTimeout(() => {
            setDebouncedSearchText(searchText);
        }, 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    const fetchData = async () => {
        setLoading(true);
        try {
            // Build query params
            const params = {
                search: debouncedSearchText,
            };
            if (typeFilter) params.movement_type = typeFilter;
            if (warehouseFilter) params.warehouse = warehouseFilter;

            // Note: Backend doesn't support date range filtering explicitly yet via 'created_at__gte' unless we added django-filter DateFromToRangeFilter
            // For now we will rely on client side or basic exact match, but let's stick to supported filters.

            const response = await getStockMovements(params);
            setData(response.data.results || []); // Pagination result
        } catch (error) {
            console.error(error);
            handleApiError(error, 'Tarixçəni yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    const fetchWarehouses = async () => {
        try {
            const res = await getWarehouses();
            setWarehouses(res.data.results || res.data);
        } catch (error) {
            console.error("Failed to load warehouses");
        }
    }

    useEffect(() => {
        if (isActive) {
            fetchData();
            fetchWarehouses();
        }
    }, [isActive, debouncedSearchText, typeFilter, warehouseFilter]);

    const getTypeTag = (type) => {
        const map = {
            'in': { color: 'green', text: 'Giriş' },
            'out': { color: 'red', text: 'Çıxış' },
            'transfer': { color: 'blue', text: 'Transfer' },
            'adjust': { color: 'orange', text: 'Korreksiya' },
            'return': { color: 'purple', text: 'Qaytarma' },
        };
        const t = map[type.toLowerCase()] || { color: 'default', text: type };
        return <Tag color={t.color}>{t.text}</Tag>;
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        {
            title: 'Tarix',
            dataIndex: 'created_at',
            key: 'created_at',
            render: (date) => new Date(date).toLocaleString('az-AZ')
        },
        { title: 'Növ', dataIndex: 'movement_type', key: 'movement_type', render: (type) => getTypeTag(type) },
        { title: 'Anbar', dataIndex: 'warehouse_name', key: 'warehouse_name' },
        { title: 'Məhsul', dataIndex: 'product_name', key: 'product_name' },
        {
            title: 'Dəyişim',
            key: 'delta',
            render: (_, record) => {
                const delta = record.quantity_new - record.quantity_old;
                const color = delta > 0 ? 'green' : (delta < 0 ? 'red' : 'black');
                return <span style={{ color, fontWeight: 'bold' }}>{delta > 0 ? '+' : ''}{parseFloat(delta).toFixed(3)}</span>
            }
        },
        { title: 'Köhnə', dataIndex: 'quantity_old', key: 'quantity_old', render: (val) => parseFloat(val).toFixed(3) },
        { title: 'Yeni', dataIndex: 'quantity_new', key: 'quantity_new', render: (val) => parseFloat(val).toFixed(3) },
        { title: 'İcraçı', dataIndex: 'created_by_name', key: 'created_by_name' },
        { title: 'Referans', dataIndex: 'reference_no', key: 'reference_no' },
        { title: 'Səbəb', dataIndex: 'reason', key: 'reason', ellipsis: true },
    ];

    return (
        <div>
            <div style={{ marginBottom: 16, background: '#fff', padding: '16px', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div style={{
                    display: 'flex',
                    flexDirection: screens.md ? 'row' : 'column',
                    justifyContent: 'space-between',
                    alignItems: screens.md ? 'center' : 'stretch',
                    gap: '8px'
                }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', width: screens.md ? 'auto' : '100%' }}>
                        <Input.Search
                            placeholder="Axtar..."
                            onChange={(e) => setSearchText(e.target.value)}
                            style={{ width: screens.md ? 250 : '100%' }}
                        />
                        {!screens.md && (
                            <Button
                                icon={<FilterOutlined />}
                                onClick={() => setShowFilters(!showFilters)}
                            />
                        )}
                    </div>

                    <div style={{
                        display: 'flex',
                        flexDirection: screens.md ? 'row' : 'column',
                        gap: '8px',
                        flexWrap: 'wrap',
                        alignItems: screens.md ? 'center' : 'stretch',
                        width: screens.md ? 'auto' : '100%'
                    }}>
                        {(screens.md || showFilters) && (
                            <>
                                <Select
                                    placeholder="Əməliyyat Növü"
                                    style={{ width: screens.md ? 150 : '100%' }}
                                    allowClear
                                    onChange={setTypeFilter}
                                >
                                    <Option value="in">Giriş</Option>
                                    <Option value="out">Çıxış</Option>
                                    <Option value="transfer">Transfer</Option>
                                    <Option value="adjust">Korreksiya</Option>
                                    <Option value="return">Qaytarma</Option>
                                </Select>
                                <Select
                                    placeholder="Anbar"
                                    style={{ width: screens.md ? 150 : '100%' }}
                                    allowClear
                                    onChange={setWarehouseFilter}
                                >
                                    {warehouses.map(w => <Option key={w.id} value={w.id}>{w.name}</Option>)}
                                </Select>
                            </>
                        )}
                        <Button type="default" onClick={fetchData}>
                            Yenilə
                        </Button>
                    </div>
                </div>
            </div>

            <Table
                columns={columns}
                dataSource={data}
                rowKey="id"
                loading={loading}
                scroll={{ x: 1200 }}
                pagination={{ pageSize: 10 }}
            />
        </div>
    );
};

export default HistoryTab;
