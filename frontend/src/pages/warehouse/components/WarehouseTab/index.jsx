import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, message, Popconfirm, Switch, Select, Grid, Input } from 'antd';
import { FilterOutlined, EnvironmentOutlined } from '@ant-design/icons';
import { Form } from 'antd';
import styles from './style.module.scss';
import { getWarehouses, createWarehouse, updateWarehouse, deleteWarehouse } from '../../../../axios/api/warehouse/index';
import { getRegions } from '../../../../axios/api/account';
import { handleApiError } from '../../../../utils/errorHandler';
import WarehouseForm from './components/WarehouseForm';
import LocationViewModal from './components/LocationViewModal';

const WarehouseTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [regions, setRegions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [selectedCoords, setSelectedCoords] = useState(null);

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [statusFilter, setStatusFilter] = useState('all');
    const [showFilters, setShowFilters] = useState(false);
    const screens = Grid.useBreakpoint();

    // Pagination
    const [pagination, setPagination] = useState({
        current: 1,
        pageSize: 5,
        total: 0
    });

    // Form Modal
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [form] = Form.useForm();

    // Location View Modal
    const [isLocationModalOpen, setIsLocationModalOpen] = useState(false);
    const [viewingWarehouse, setViewingWarehouse] = useState(null);

    // Debounce Search
    useEffect(() => {
        const timer = setTimeout(() => {
            setDebouncedSearchText(searchText);
        }, 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    const fetchData = async (params = {}) => {
        setLoading(true);
        try {
            const queryParams = {
                page: params.page || pagination.current,
                search: debouncedSearchText
            };
            if (statusFilter !== 'all') {
                queryParams.is_active = statusFilter;
            }

            const [warehouseRes, regionRes] = await Promise.all([
                getWarehouses(queryParams),
                getRegions()
            ]);

            const responseData = warehouseRes.data;
            if (responseData.results) {
                setData(responseData.results);
                setPagination(prev => ({
                    ...prev,
                    current: queryParams.page,
                    total: responseData.count
                }));
            } else {
                setData(responseData);
            }
            setRegions(regionRes.data);
        } catch (error) {
            console.error(error);
            handleApiError(error, 'Məlumatları yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    const handleTableChange = (newPagination) => {
        fetchData({ page: newPagination.current });
    };

    useEffect(() => {
        if (isActive) {
            fetchData({ page: 1 });
        }
    }, [isActive, debouncedSearchText, statusFilter]);

    const handleDelete = async (id) => {
        try {
            await deleteWarehouse(id);
            message.success('Anbar silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    const onFinish = async (values) => {
        try {
            const payload = {
                ...values,
            };
            // Only include coordinates if user selected a location
            if (selectedCoords && selectedCoords.lat && selectedCoords.lng) {
                payload.coordinates = selectedCoords;
            }
            if (editingItem) {
                await updateWarehouse(editingItem.id, payload);
                message.success('Anbar yeniləndi');
            } else {
                await createWarehouse(payload);
                message.success('Anbar yaradıldı');
            }
            setIsModalOpen(false);
            form.resetFields();
            setEditingItem(null);
            setSelectedCoords(null);
            fetchData();
        } catch (error) {
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        }
    };

    const handleStatusChange = async (id, checked) => {
        try {
            await updateWarehouse(id, { is_active: checked });
            message.success('Status yeniləndi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    // Client-side filtering removed - now using server-side

    const openEditModal = (record) => {
        setEditingItem(record);
        form.setFieldsValue(record);
        if (record.coordinates && record.coordinates.lat && record.coordinates.lng) {
            setSelectedCoords(record.coordinates);
        } else {
            setSelectedCoords(null);
        }
        setIsModalOpen(true);
    };

    const openNewModal = () => {
        setEditingItem(null);
        form.resetFields();
        setSelectedCoords(null);
        setIsModalOpen(true);
    };

    const openLocationModal = (record) => {
        setViewingWarehouse(record);
        setIsLocationModalOpen(true);
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id' },
        { title: 'Ad', dataIndex: 'name', key: 'name' },
        { title: 'Region', dataIndex: 'region_name', key: 'region_name' },
        { title: 'Ünvan', dataIndex: 'address', key: 'address' },
        {
            title: 'Xəritə',
            key: 'location',
            render: (_, record) => (
                <Button
                    type="text"
                    icon={<EnvironmentOutlined />}
                    onClick={() => openLocationModal(record)}
                    style={{ color: record.coordinates?.lat ? '#1890ff' : '#ccc' }}
                />
            )
        },
        {
            title: 'Aktiv',
            dataIndex: 'is_active',
            key: 'is_active',
            render: (active, record) => (
                <Switch
                    checked={active}
                    onChange={(checked) => handleStatusChange(record.id, checked)}
                />
            )
        },
        {
            title: 'Əməliyyat',
            key: 'action',
            render: (_, record) => (
                <>
                    <Button type="link" onClick={() => openEditModal(record)}>Düzəliş</Button>
                    <Popconfirm title="Silmək istədiyinizə əminsiniz?" onConfirm={() => handleDelete(record.id)}>
                        <Button type="link" danger>Sil</Button>
                    </Popconfirm>
                </>
            ),
        },
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
                            placeholder="Axtar (Ad, Ünvan)..."
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
                                    placeholder="Status"
                                    style={{ width: screens.md ? 150 : '100%' }}
                                    allowClear
                                    value={statusFilter}
                                    onChange={setStatusFilter}
                                >
                                    <Select.Option value="all">Hamısı</Select.Option>
                                    <Select.Option value={true}>Aktiv</Select.Option>
                                    <Select.Option value={false}>Deaktiv</Select.Option>
                                </Select>
                            </>
                        )}
                        <Button type="primary" block={!screens.md} onClick={openNewModal}>
                            Yeni Anbar
                        </Button>
                    </div>
                </div>
            </div>

            <Table
                columns={columns}
                dataSource={data}
                rowKey="id"
                loading={loading}
                scroll={{ x: 800 }}
                pagination={pagination}
                onChange={handleTableChange}
            />

            <Modal
                title={editingItem ? "Anbarı Düzəlt" : "Yeni Anbar"}
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                footer={null}
                width={600}
                className={styles.responsiveModal}
            >
                <WarehouseForm
                    form={form}
                    onFinish={onFinish}
                    regions={regions}
                    selectedCoords={selectedCoords}
                    setSelectedCoords={setSelectedCoords}
                    editingItem={editingItem}
                />
            </Modal>

            <LocationViewModal
                open={isLocationModalOpen}
                onClose={() => setIsLocationModalOpen(false)}
                coordinates={viewingWarehouse?.coordinates}
                warehouseName={viewingWarehouse?.name}
            />
        </div>
    );
};

export default WarehouseTab;
