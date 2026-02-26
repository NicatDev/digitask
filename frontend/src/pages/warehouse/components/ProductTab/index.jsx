import React, { useEffect, useState, useMemo } from 'react';
import { Table, Button, Input, Select, Popconfirm, Switch, Grid, Popover, Badge, Tag, Dropdown, Checkbox, message } from 'antd';
import { FilterOutlined, SwapOutlined, BarcodeOutlined, SettingOutlined } from '@ant-design/icons';
import { getProducts, updateProduct, deleteProduct, getWarehouses, getInventory, getCategories } from '../../../../axios/api/warehouse/index';
import { handleApiError } from '../../../../utils/errorHandler';
import { useAuth } from '../../../../context/AuthContext';
import { hasPermission, PERMISSIONS } from '../../../../utils/permissions';
import ProductFormModal from '../ProductFormModal';
import StockModal from '../StockModal';
import SerialStockModal from '../SerialStockModal';
import SerialListModal from '../SerialListModal';

const { Option } = Select;

const ALL_BASE_COLUMNS = [
    { key: 'id', label: 'ID' },
    { key: 'name', label: 'Ad' },
    { key: 'brand', label: 'Brand' },
    { key: 'model', label: 'Model' },
    { key: 'serial_info', label: 'Serial' },
    { key: 'size', label: 'Ölçü' },
    { key: 'weight', label: 'Çəki' },
    { key: 'port_count', label: 'Port Sayı' },
    { key: 'category_name', label: 'Kateqoriya' },
    { key: 'price', label: 'Qiymət' },
    { key: 'unit_display', label: 'Vahid' },
    { key: 'min_quantity', label: 'Min' },
    { key: 'max_quantity', label: 'Max' },
    { key: 'total_stock', label: 'Say' },
    { key: 'stock_action', label: 'Hərəkət' },
    { key: 'is_active', label: 'Aktiv' },
    { key: 'action', label: 'Əməliyyat' },
];

const DEFAULT_VISIBLE = ALL_BASE_COLUMNS.map(c => c.key);

const ProductTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);
    const [warehouses, setWarehouses] = useState([]);
    const [inventory, setInventory] = useState([]);
    const [categories, setCategories] = useState([]);
    const { user } = useAuth();

    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [statusFilter, setStatusFilter] = useState(true);
    const [warehouseFilter, setWarehouseFilter] = useState(null);
    const [categoryFilter, setCategoryFilter] = useState(null);
    const [showFilters, setShowFilters] = useState(false);
    const [visibleColumns, setVisibleColumns] = useState(DEFAULT_VISIBLE);
    const screens = Grid.useBreakpoint();

    // Modal states
    const [productModalOpen, setProductModalOpen] = useState(false);
    const [editingProduct, setEditingProduct] = useState(null);
    const [stockModalOpen, setStockModalOpen] = useState(false);
    const [serialStockModalOpen, setSerialStockModalOpen] = useState(false);
    const [serialListModalOpen, setSerialListModalOpen] = useState(false);
    const [selectedProduct, setSelectedProduct] = useState(null);
    const [prefilledSerial, setPrefilledSerial] = useState(null);
    const [prefilledWarehouse, setPrefilledWarehouse] = useState(null);

    const [pagination, setPagination] = useState({ current: 1, pageSize: 5, total: 0 });

    useEffect(() => {
        const timer = setTimeout(() => {
            setDebouncedSearchText(searchText);
            setPagination(prev => ({ ...prev, current: 1 }));
        }, 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    const fetchData = async (params = {}) => {
        setLoading(true);
        try {
            const queryParams = {
                page: params.current || pagination.current,
                page_size: params.pageSize || pagination.pageSize,
                search: debouncedSearchText,
            };
            if (statusFilter !== 'all') queryParams.is_active = statusFilter;
            if (categoryFilter) queryParams.category = categoryFilter;

            const [productsRes, warehousesRes, inventoryRes, categoriesRes] = await Promise.all([
                getProducts(queryParams),
                getWarehouses(),
                getInventory(),
                getCategories({ page_size: 100 })
            ]);

            setData(productsRes.data.results || []);
            setPagination(prev => ({
                ...prev,
                current: params.current || pagination.current,
                pageSize: params.pageSize || pagination.pageSize,
                total: productsRes.data.count || 0,
            }));
            setWarehouses(warehousesRes.data.results || warehousesRes.data);
            setInventory(inventoryRes.data.results || inventoryRes.data);
            setCategories(categoriesRes.data.results || categoriesRes.data || []);
        } catch (error) {
            handleApiError(error, 'Məlumatları yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (isActive) fetchData();
    }, [isActive, debouncedSearchText, statusFilter, warehouseFilter, categoryFilter]);

    const handleTableChange = (p) => fetchData({ current: p.current, pageSize: p.pageSize });
    const handleDelete = async (id) => {
        try { await deleteProduct(id); message.success('Məhsul silindi'); fetchData(); } catch (e) { handleApiError(e); }
    };
    const handleStatusChange = async (id, checked) => {
        try { await updateProduct(id, { is_active: checked }); message.success('Status yeniləndi'); fetchData(); } catch (e) { handleApiError(e); }
    };

    const openStockModal = (record) => {
        setSelectedProduct(record);
        setPrefilledSerial(null);
        setPrefilledWarehouse(null);
        if (record.has_serial_number) {
            setSerialStockModalOpen(true);
        } else {
            setStockModalOpen(true);
        }
    };

    const handleSerialExport = (serialItem) => {
        // Called from SerialListModal when user clicks Export/Transfer
        setPrefilledSerial(serialItem.serial_number);
        setPrefilledWarehouse(serialItem.warehouse);
        setSerialStockModalOpen(true);
    };

    // ─── Count logic ───
    const getProductInventory = (productId) => inventory.filter(inv => inv.product === productId);

    const getStockForProduct = (record) => {
        if (warehouseFilter) {
            const inv = inventory.find(i => i.product === record.id && i.warehouse === warehouseFilter);
            return inv ? parseFloat(inv.quantity || 0) : 0;
        }
        return parseFloat(record.total_stock || 0);
    };

    const renderInventoryPopover = (productId) => {
        const productInv = getProductInventory(productId);
        if (productInv.length === 0) return <div style={{ padding: 8 }}>Anbarda yoxdur</div>;
        return (
            <div style={{ minWidth: 200 }}>
                {productInv.map(inv => (
                    <div key={inv.id} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0', borderBottom: '1px solid #f0f0f0' }}>
                        <span>{inv.warehouse_name}</span>
                        <strong>{parseFloat(inv.quantity).toFixed(0)} {inv.product_unit}</strong>
                    </div>
                ))}
            </div>
        );
    };

    // Dynamic category columns
    const getCategoryColumns = () => {
        if (!categoryFilter) return [];
        const cat = categories.find(c => c.id === categoryFilter);
        if (!cat?.fields_list) return [];
        return cat.fields_list.map(f => ({
            title: f.name, key: `cf_${f.id}`,
            render: (_, record) => {
                const val = record.category_data?.[f.name];
                if (val === undefined || val === null) return '-';
                if (f.field_type === 'boolean') return val ? '✓' : '✗';
                return String(val);
            }
        }));
    };

    // ─── Column definitions ───
    const allColumnDefs = {
        id: { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        name: { title: 'Ad', dataIndex: 'name', key: 'name', width: 150 },
        brand: { title: 'Brand', dataIndex: 'brand', key: 'brand' },
        model: { title: 'Model', dataIndex: 'model', key: 'model' },
        serial_info: {
            title: 'Serial', key: 'serial_info', width: 100,
            render: (_, record) => {
                if (!record.has_serial_number) return <Tag color="default">—</Tag>;
                return (
                    <Button size="small" type="link" icon={<BarcodeOutlined />} onClick={() => {
                        setSelectedProduct(record);
                        setSerialListModalOpen(true);
                    }}>{parseInt(record.serial_count) || 0}</Button>
                );
            }
        },
        size: { title: 'Ölçü', dataIndex: 'size', key: 'size' },
        weight: { title: 'Çəki', dataIndex: 'weight', key: 'weight' },
        port_count: { title: 'Port Sayı', dataIndex: 'port_count', key: 'port_count' },
        category_name: { title: 'Kateqoriya', dataIndex: 'category_name', key: 'category_name', render: v => v || '-' },
        price: { title: 'Qiymət', dataIndex: 'price', key: 'price', render: v => v ? `${parseFloat(v).toFixed(2)} ₼` : '-' },
        unit_display: { title: 'Vahid', dataIndex: 'unit_display', key: 'unit_display' },
        min_quantity: { title: 'Min', dataIndex: 'min_quantity', key: 'min_quantity', render: v => v ? parseFloat(v).toFixed(0) : '-' },
        max_quantity: { title: 'Max', dataIndex: 'max_quantity', key: 'max_quantity', render: v => v ? parseFloat(v).toFixed(0) : '-' },
        total_stock: {
            title: 'Say', key: 'total_stock', width: 120,
            render: (_, record) => {
                const total = getStockForProduct(record);
                const min = record.min_quantity ? parseFloat(record.min_quantity) : null;
                const max = record.max_quantity ? parseFloat(record.max_quantity) : null;
                let color = '#52c41a';
                if (min !== null && total < min) color = '#faad14';
                if (max !== null && total > max) color = '#faad14';
                const badge = <Badge count={total.toFixed(0)} style={{ backgroundColor: color }} overflowCount={99999} showZero />;
                if (warehouseFilter) return badge;
                return (
                    <Popover content={renderInventoryPopover(record.id)} title="Anbar Balansı">
                        <span style={{ cursor: 'pointer' }}>{badge}</span>
                    </Popover>
                );
            }
        },
        stock_action: {
            title: 'Hərəkət', key: 'stock_action',
            render: (_, record) => (
                <Button size="small" icon={<SwapOutlined />} onClick={() => openStockModal(record)}
                    disabled={!hasPermission(user, PERMISSIONS.WAREHOUSE_WRITER)}>Stock</Button>
            )
        },
        is_active: {
            title: 'Aktiv', dataIndex: 'is_active', key: 'is_active',
            render: (active, record) => <Switch checked={active} onChange={c => handleStatusChange(record.id, c)} />
        },
        action: {
            title: 'Əməliyyat', key: 'action',
            render: (_, record) => (
                <>
                    <Button type="link" onClick={() => { setEditingProduct(record); setProductModalOpen(true); }}>Düzəliş</Button>
                    <Popconfirm title="Silmək istədiyinizə əminsiniz?" onConfirm={() => handleDelete(record.id)}>
                        <Button type="link" danger>Sil</Button>
                    </Popconfirm>
                </>
            ),
        },
    };

    const columns = useMemo(() => {
        const baseCols = ALL_BASE_COLUMNS.filter(c => visibleColumns.includes(c.key)).map(c => allColumnDefs[c.key]);
        return [...baseCols, ...getCategoryColumns()];
    }, [visibleColumns, data, inventory, warehouseFilter, categoryFilter, categories]);

    const columnMenuItems = ALL_BASE_COLUMNS.map(c => ({
        key: c.key,
        label: (
            <Checkbox checked={visibleColumns.includes(c.key)} onChange={e => {
                setVisibleColumns(prev => e.target.checked ? [...prev, c.key] : prev.filter(k => k !== c.key));
            }}>{c.label}</Checkbox>
        ),
    }));

    return (
        <div>
            <div style={{ marginBottom: 16, background: '#fff', padding: '16px', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div style={{ display: 'flex', flexDirection: screens.md ? 'row' : 'column', justifyContent: 'space-between', alignItems: screens.md ? 'center' : 'stretch', gap: 8 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, width: screens.md ? 'auto' : '100%' }}>
                        <Input.Search placeholder="Axtar (Ad, Brand, Model, Serial)..." onChange={e => setSearchText(e.target.value)} style={{ width: screens.md ? 250 : '100%' }} />
                        {!screens.md && <Button icon={<FilterOutlined />} onClick={() => setShowFilters(!showFilters)} />}
                    </div>
                    <div style={{ display: 'flex', flexDirection: screens.md ? 'row' : 'column', gap: 8, flexWrap: 'wrap', alignItems: screens.md ? 'center' : 'stretch', width: screens.md ? 'auto' : '100%' }}>
                        {(screens.md || showFilters) && (
                            <>
                                <Select placeholder="Status" style={{ width: screens.md ? 120 : '100%' }} value={statusFilter} onChange={setStatusFilter}>
                                    <Option value="all">Hamısı</Option>
                                    <Option value={true}>Aktiv</Option>
                                    <Option value={false}>Deaktiv</Option>
                                </Select>
                                <Select placeholder="Anbar" style={{ width: screens.md ? 150 : '100%' }} allowClear value={warehouseFilter} onChange={setWarehouseFilter}>
                                    {warehouses.map(w => <Option key={w.id} value={w.id}>{w.name}</Option>)}
                                </Select>
                                <Select placeholder="Kateqoriya" style={{ width: screens.md ? 150 : '100%' }} allowClear value={categoryFilter} onChange={setCategoryFilter}>
                                    {categories.map(c => <Option key={c.id} value={c.id}>{c.name}</Option>)}
                                </Select>
                            </>
                        )}
                        <Dropdown menu={{ items: columnMenuItems }} trigger={['click']} dropdownRender={menu => (
                            <div style={{ maxHeight: 350, overflow: 'auto', background: '#fff', borderRadius: 8, boxShadow: '0 6px 16px rgba(0,0,0,0.12)' }}>{menu}</div>
                        )}>
                            <Button icon={<SettingOutlined />} />
                        </Dropdown>
                        <Button type="primary" block={!screens.md} onClick={() => { setEditingProduct(null); setProductModalOpen(true); }}
                            disabled={!hasPermission(user, PERMISSIONS.WAREHOUSE_WRITER)}>Yeni Məhsul</Button>
                    </div>
                </div>
            </div>

            <Table columns={columns} dataSource={data} rowKey="id" loading={loading} scroll={{ x: 1000 }} pagination={pagination} onChange={handleTableChange} />

            {/* Extracted Modals */}
            <ProductFormModal
                open={productModalOpen}
                onClose={() => { setProductModalOpen(false); setEditingProduct(null); }}
                editingItem={editingProduct}
                categories={categories}
                onSuccess={() => { message.success(editingProduct ? 'Məhsul yeniləndi' : 'Məhsul yaradıldı'); fetchData(); }}
            />

            <StockModal
                open={stockModalOpen}
                onClose={() => { setStockModalOpen(false); setSelectedProduct(null); }}
                product={selectedProduct}
                warehouses={warehouses}
                inventory={inventory}
                onSuccess={() => { message.success('Stock əməliyyatı uğurlu'); fetchData(); }}
            />

            <SerialStockModal
                open={serialStockModalOpen}
                onClose={() => { setSerialStockModalOpen(false); setSelectedProduct(null); setPrefilledSerial(null); setPrefilledWarehouse(null); }}
                product={selectedProduct}
                warehouses={warehouses}
                inventory={inventory}
                onSuccess={() => { message.success('Serial stock əməliyyatı uğurlu'); fetchData(); }}
                prefilledSerial={prefilledSerial}
                prefilledWarehouse={prefilledWarehouse}
            />

            <SerialListModal
                open={serialListModalOpen}
                onClose={() => setSerialListModalOpen(false)}
                product={selectedProduct}
                onExport={handleSerialExport}
            />
        </div>
    );
};

export default ProductTab;
