import React, { useEffect, useState, useMemo } from 'react';
import dayjs from 'dayjs';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Switch, Select, Grid, InputNumber, Row, Col, Popover, Badge, List, Tag, DatePicker, Dropdown, Checkbox } from 'antd';
import { FilterOutlined, SwapOutlined, PlusOutlined, BarcodeOutlined, SettingOutlined } from '@ant-design/icons';
import styles from './style.module.scss';
import { getProducts, createProduct, updateProduct, deleteProduct, adjustStock, getWarehouses, getInventory, getCategories, getSerialItems } from '../../../../axios/api/warehouse/index';
import { handleApiError } from '../../../../utils/errorHandler';
import { useAuth } from '../../../../context/AuthContext';
import { hasPermission, PERMISSIONS } from '../../../../utils/permissions';

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

    // Product Modal
    const [isProductModalOpen, setIsProductModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [form] = Form.useForm();
    const [selectedCategory, setSelectedCategory] = useState(null);

    // Stock Modal
    const [isStockModalOpen, setIsStockModalOpen] = useState(false);
    const [stockForm] = Form.useForm();
    const [selectedProduct, setSelectedProduct] = useState(null);
    const [stockSerialItems, setStockSerialItems] = useState([]);
    const [stockSerialLoading, setStockSerialLoading] = useState(false);
    const [serialLocked, setSerialLocked] = useState(false); // true when serial pre-selected from list

    // Serial Number List Modal
    const [isSerialModalOpen, setIsSerialModalOpen] = useState(false);
    const [serialItems, setSerialItems] = useState([]);
    const [serialLoading, setSerialLoading] = useState(false);
    const [serialProduct, setSerialProduct] = useState(null);
    const [serialSearch, setSerialSearch] = useState('');
    const [serialPagination, setSerialPagination] = useState({ current: 1, pageSize: 50, total: 0 });

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
        try { await deleteProduct(id); message.success('Məhsul silindi'); fetchData(); } catch (e) { handleApiError(e, 'Silinmə uğursuz oldu'); }
    };

    const onProductFinish = async (values) => {
        try {
            const cat = categories.find(c => c.id === values.category);
            if (cat && cat.fields_list) {
                const categoryData = {};
                cat.fields_list.forEach(f => {
                    const key = `cf_${f.id}`;
                    if (values[key] !== undefined && values[key] !== null) {
                        categoryData[f.name] = f.field_type === 'date' && values[key]?.format ? values[key].format('YYYY-MM-DD') : values[key];
                    }
                    delete values[key];
                });
                values.category_data = categoryData;
            }
            if (editingItem) {
                await updateProduct(editingItem.id, values);
                message.success('Məhsul yeniləndi');
            } else {
                await createProduct(values);
                message.success('Məhsul yaradıldı');
            }
            setIsProductModalOpen(false);
            form.resetFields();
            setEditingItem(null);
            setSelectedCategory(null);
            fetchData();
        } catch (e) { handleApiError(e, 'Əməliyyat uğursuz oldu'); }
    };

    const handleStatusChange = async (id, checked) => {
        try { await updateProduct(id, { is_active: checked }); message.success('Status yeniləndi'); fetchData(); } catch (e) { handleApiError(e, 'Status yenilənmədi'); }
    };

    const onStockFinish = async (values) => {
        try {
            const payload = { ...values, product_id: selectedProduct?.id };
            await adjustStock(payload);
            message.success('Əməliyyat uğurla tamamlandı');
            setIsStockModalOpen(false);
            stockForm.resetFields();
            setSelectedProduct(null);
            setStockSerialItems([]);
            setSerialLocked(false);
            fetchData();
        } catch (e) { handleApiError(e, 'Stock əməliyyatı uğursuz oldu'); }
    };

    // Load serial items for stock modal select
    const loadStockSerialItems = async (productId, warehouseId) => {
        if (!productId) return;
        setStockSerialLoading(true);
        try {
            const params = { product: productId, page_size: 200 };
            if (warehouseId) params.warehouse = warehouseId;
            const res = await getSerialItems(params);
            setStockSerialItems(res.data.results || res.data || []);
        } catch (e) { console.error(e); }
        finally { setStockSerialLoading(false); }
    };

    // Serial list modal
    const openSerialModal = (product) => {
        setSerialProduct(product);
        setIsSerialModalOpen(true);
        setSerialSearch('');
        fetchSerialList(product.id, 1, '');
    };

    const fetchSerialList = async (productId, page = 1, search = '') => {
        setSerialLoading(true);
        try {
            const params = { product: productId, page, page_size: 50 };
            if (search) params.search = search;
            const res = await getSerialItems(params);
            const result = res.data;
            setSerialItems(result.results || result || []);
            setSerialPagination(p => ({ ...p, current: page, total: result.count || 0 }));
        } catch (e) { message.error('Serial nömrələr yüklənmədi'); }
        finally { setSerialLoading(false); }
    };

    useEffect(() => {
        if (serialProduct && isSerialModalOpen) {
            const timer = setTimeout(() => fetchSerialList(serialProduct.id, 1, serialSearch), 300);
            return () => clearTimeout(timer);
        }
    }, [serialSearch]);

    // --- Count logic ---
    const getProductInventory = (productId) => inventory.filter(inv => inv.product === productId);

    const getStockForProduct = (record) => {
        // For ALL products: use WarehouseInventory data (backend adjust_stock updates it for both serial and non-serial)
        const productInv = getProductInventory(record.id);
        if (warehouseFilter) {
            const inv = productInv.find(i => i.warehouse === warehouseFilter);
            return inv ? parseFloat(inv.quantity || 0) : 0;
        }
        // total_stock comes from backend annotation (Sum of inventory_items__quantity)
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
        if (!cat || !cat.fields_list) return [];
        return cat.fields_list.map(f => ({
            title: f.name,
            key: `cf_${f.id}`,
            render: (_, record) => {
                const val = record.category_data?.[f.name];
                if (val === undefined || val === null) return '-';
                if (f.field_type === 'boolean') return val ? '✓' : '✗';
                return String(val);
            }
        }));
    };

    // Column definitions
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
                    <Button size="small" type="link" icon={<BarcodeOutlined />} onClick={() => openSerialModal(record)}>
                        {parseInt(record.serial_count) || 0}
                    </Button>
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
                <Button size="small" icon={<SwapOutlined />} onClick={() => {
                    setSelectedProduct(record);
                    setIsStockModalOpen(true);
                    stockForm.resetFields();
                    setStockSerialItems([]);
                    setSerialLocked(false);
                }} disabled={!hasPermission(user, PERMISSIONS.WAREHOUSE_WRITER)}>Stock</Button>
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
                    <Button type="link" onClick={() => {
                        setEditingItem(record);
                        const cat = categories.find(c => c.id === record.category);
                        setSelectedCategory(cat || null);
                        const fv = { ...record };
                        if (cat?.fields_list && record.category_data) {
                            cat.fields_list.forEach(f => {
                                let val = record.category_data[f.name];
                                if (f.field_type === 'date' && val) val = dayjs(val);
                                fv[`cf_${f.id}`] = val;
                            });
                        }
                        form.setFieldsValue(fv);
                        setIsProductModalOpen(true);
                    }}>Düzəliş</Button>
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

    // Column selector
    const columnMenuItems = ALL_BASE_COLUMNS.map(c => ({
        key: c.key,
        label: (
            <Checkbox
                checked={visibleColumns.includes(c.key)}
                onChange={(e) => {
                    setVisibleColumns(prev => e.target.checked ? [...prev, c.key] : prev.filter(k => k !== c.key));
                }}
            >{c.label}</Checkbox>
        ),
    }));

    const formCategory = Form.useWatch('category', form);
    useEffect(() => {
        const cat = formCategory ? categories.find(c => c.id === formCategory) : null;
        setSelectedCategory(cat || null);
    }, [formCategory, categories]);

    const isSerialProduct = selectedProduct?.has_serial_number;
    const stockMovementType = Form.useWatch('movement_type', stockForm);
    const stockWarehouseId = Form.useWatch('warehouse_id', stockForm);

    // Load serial items when warehouse changes in stock modal (for out/transfer)
    useEffect(() => {
        if (isSerialProduct && stockWarehouseId && (stockMovementType === 'out' || stockMovementType === 'transfer')) {
            loadStockSerialItems(selectedProduct.id, stockWarehouseId);
        }
    }, [stockWarehouseId, stockMovementType, isSerialProduct]);

    // Needs serial select for out/transfer
    const needsSerialSelect = isSerialProduct && (stockMovementType === 'out' || stockMovementType === 'transfer');
    // Needs serial input for in/return/adjust
    const needsSerialInput = isSerialProduct && (stockMovementType === 'in' || stockMovementType === 'return' || stockMovementType === 'adjust');

    return (
        <div>
            <div style={{ marginBottom: 16, background: '#fff', padding: '16px', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
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
                        <Dropdown menu={{ items: columnMenuItems }} trigger={['click']} dropdownRender={(menu) => (
                            <div style={{ maxHeight: 350, overflow: 'auto', background: '#fff', borderRadius: 8, boxShadow: '0 6px 16px rgba(0,0,0,0.12)' }}>
                                {menu}
                            </div>
                        )}>
                            <Button icon={<SettingOutlined />} />
                        </Dropdown>
                        <Button type="primary" block={!screens.md} onClick={() => { setEditingItem(null); form.resetFields(); setSelectedCategory(null); setIsProductModalOpen(true); }} disabled={!hasPermission(user, PERMISSIONS.WAREHOUSE_WRITER)}>
                            Yeni Məhsul
                        </Button>
                    </div>
                </div>
            </div>

            <Table columns={columns} dataSource={data} rowKey="id" loading={loading} scroll={{ x: 1000 }} pagination={pagination} onChange={handleTableChange} />

            {/* Product Create/Edit Modal */}
            <Modal title={editingItem ? "Məhsulu Düzəlt" : "Yeni Məhsul"} open={isProductModalOpen} onCancel={() => { setIsProductModalOpen(false); setSelectedCategory(null); }} footer={null} width={800} className={styles.responsiveModal}>
                <div style={{ maxHeight: '70vh', overflowY: 'auto', paddingRight: 8 }}>
                    <Form form={form} onFinish={onProductFinish} layout="vertical">
                        <Row gutter={16}>
                            <Col span={12}><Form.Item name="name" label="Ad" rules={[{ required: true }]}><Input /></Form.Item></Col>
                            <Col span={12}>
                                <Form.Item name="unit" label="Ölçü Vahidi" rules={[{ required: true }]} initialValue="pcs">
                                    <Select>
                                        <Option value="pcs">Ədəd</Option><Option value="kg">Kq</Option><Option value="g">Qram</Option>
                                        <Option value="l">Litr</Option><Option value="m">Metr</Option><Option value="box">Qutu</Option><Option value="set">Dəst</Option>
                                    </Select>
                                </Form.Item>
                            </Col>
                        </Row>
                        <Row gutter={16}>
                            <Col span={8}><Form.Item name="brand" label="Brand"><Input /></Form.Item></Col>
                            <Col span={8}><Form.Item name="model" label="Model"><Input /></Form.Item></Col>
                            <Col span={8}><Form.Item name="has_serial_number" label="Serial Nömrəli" valuePropName="checked"><Switch /></Form.Item></Col>
                        </Row>
                        <Row gutter={16}>
                            <Col span={6}><Form.Item name="size" label="Ölçü"><Input /></Form.Item></Col>
                            <Col span={6}><Form.Item name="weight" label="Çəki"><Input /></Form.Item></Col>
                            <Col span={6}><Form.Item name="port_count" label="Port Sayı"><InputNumber style={{ width: '100%' }} /></Form.Item></Col>
                            <Col span={6}><Form.Item name="price" label="Qiymət"><InputNumber style={{ width: '100%' }} step="0.01" /></Form.Item></Col>
                        </Row>
                        <Row gutter={16}>
                            <Col span={8}><Form.Item name="min_quantity" label="Min Say"><InputNumber style={{ width: '100%' }} /></Form.Item></Col>
                            <Col span={8}><Form.Item name="max_quantity" label="Max Say"><InputNumber style={{ width: '100%' }} /></Form.Item></Col>
                            <Col span={8}>
                                <Form.Item name="category" label="Kateqoriya">
                                    <Select allowClear placeholder="Kateqoriya seçin">
                                        {categories.map(c => <Option key={c.id} value={c.id}>{c.name}</Option>)}
                                    </Select>
                                </Form.Item>
                            </Col>
                        </Row>

                        {selectedCategory?.fields_list?.length > 0 && (
                            <>
                                <div style={{ marginBottom: 8, fontWeight: 600, color: '#1890ff' }}>{selectedCategory.name} sahələri</div>
                                <Row gutter={16}>
                                    {selectedCategory.fields_list.map(f => (
                                        <Col span={8} key={f.id}>
                                            <Form.Item name={`cf_${f.id}`} label={f.name}
                                                rules={f.is_required ? [{ required: true, message: `${f.name} tələb olunur` }] : []}
                                                {...(f.field_type === 'boolean' ? { valuePropName: 'checked' } : {})}>
                                                {f.field_type === 'string' && <Input />}
                                                {f.field_type === 'number' && <InputNumber style={{ width: '100%' }} />}
                                                {f.field_type === 'boolean' && <Switch />}
                                                {f.field_type === 'date' && <DatePicker style={{ width: '100%' }} />}
                                            </Form.Item>
                                        </Col>
                                    ))}
                                </Row>
                            </>
                        )}

                        <Form.Item name="description" label="Təsvir"><Input.TextArea /></Form.Item>
                        <Button type="primary" htmlType="submit" block>Təsdiqlə</Button>
                    </Form>
                </div>
            </Modal>

            {/* Stock Movement Modal */}
            <Modal
                title={`Stock Əməliyyatı: ${selectedProduct?.name}`}
                open={isStockModalOpen}
                onCancel={() => { setIsStockModalOpen(false); setStockSerialItems([]); setSerialLocked(false); }}
                footer={null} width={500} className={styles.responsiveModal}
            >
                <Form form={stockForm} onFinish={onStockFinish} layout="vertical">
                    <Form.Item name="movement_type" label="Əməliyyat Növü" rules={[{ required: true }]}>
                        <Select onChange={() => {
                            stockForm.setFieldValue('to_warehouse_id', undefined);
                            stockForm.setFieldValue('returned_by', undefined);
                            if (!serialLocked) stockForm.setFieldValue('serial_number', undefined);
                        }}>
                            <Option value="in">Giriş (Import)</Option>
                            <Option value="out">Çıxış (Export)</Option>
                            <Option value="transfer">Transfer</Option>
                            <Option value="adjust">Korreksiya</Option>
                            <Option value="return">Qaytarma</Option>
                        </Select>
                    </Form.Item>

                    <Form.Item name="warehouse_id" label="Anbar" rules={[{ required: true }]}>
                        <Select placeholder="Anbar seçin">
                            {warehouses.map(w => {
                                const inv = selectedProduct ? inventory.find(i => i.warehouse === w.id && i.product === selectedProduct.id) : null;
                                const qty = inv ? parseFloat(inv.quantity).toFixed(0) : '0';
                                return <Option key={w.id} value={w.id}>{w.name} ({qty})</Option>;
                            })}
                        </Select>
                    </Form.Item>

                    <Form.Item noStyle shouldUpdate={(prev, cur) => prev.movement_type !== cur.movement_type}>
                        {({ getFieldValue }) => getFieldValue('movement_type') === 'transfer' ? (
                            <Form.Item name="to_warehouse_id" label="Hədəf Anbar" rules={[{ required: true }]}>
                                <Select placeholder="Hədəf anbar seçin">
                                    {warehouses.map(w => {
                                        const inv = selectedProduct ? inventory.find(i => i.warehouse === w.id && i.product === selectedProduct.id) : null;
                                        const qty = inv ? parseFloat(inv.quantity).toFixed(0) : '0';
                                        return <Option key={w.id} value={w.id}>{w.name} ({qty})</Option>;
                                    })}
                                </Select>
                            </Form.Item>
                        ) : null}
                    </Form.Item>

                    <Form.Item noStyle shouldUpdate={(prev, cur) => prev.movement_type !== cur.movement_type}>
                        {({ getFieldValue }) => getFieldValue('movement_type') === 'return' ? (
                            <Form.Item name="returned_by" label="Qaytaran haqqında məlumat">
                                <Input placeholder="Qaytaran şəxsin adı" />
                            </Form.Item>
                        ) : null}
                    </Form.Item>

                    {/* Serial product: select for out/transfer, input for in/return/adjust */}
                    {needsSerialSelect && (
                        <Form.Item name="serial_number" label="Serial Nömrə" rules={[{ required: true, message: 'Serial nömrə seçin' }]}>
                            <Select
                                placeholder="Serial nömrə seçin"
                                showSearch optionFilterProp="children"
                                loading={stockSerialLoading}
                                disabled={serialLocked}
                                notFoundContent={stockSerialLoading ? 'Yüklənir...' : 'Tapılmadı'}
                            >
                                {stockSerialItems.map(item => (
                                    <Option key={item.id} value={item.serial_number}>{item.serial_number}</Option>
                                ))}
                            </Select>
                        </Form.Item>
                    )}
                    {needsSerialInput && (
                        <Form.Item name="serial_number" label="Serial Nömrə" rules={[{ required: true, message: 'Serial nömrə daxil edin' }]}>
                            <Input placeholder="Serial nömrəni daxil edin" />
                        </Form.Item>
                    )}
                    {!isSerialProduct && (
                        <Form.Item name="quantity" label="Miqdar" rules={[{ required: true }]}>
                            <InputNumber style={{ width: '100%' }} min={0} step={0.001} />
                        </Form.Item>
                    )}

                    <Form.Item name="reference_no" label="Sənəd No / Referans"><Input /></Form.Item>
                    <Form.Item name="reason" label="Səbəb / Qeyd"><Input.TextArea /></Form.Item>
                    <Button type="primary" htmlType="submit" block>İcra Et</Button>
                </Form>
            </Modal>

            {/* Serial Number List Modal */}
            <Modal
                title={`Serial Nömrələr: ${serialProduct?.name || ''}`}
                open={isSerialModalOpen}
                onCancel={() => setIsSerialModalOpen(false)}
                footer={null} width={650}
            >
                <Input.Search
                    placeholder="Serial nömrə axtar..."
                    value={serialSearch}
                    onChange={e => setSerialSearch(e.target.value)}
                    style={{ marginBottom: 16 }}
                    allowClear
                />
                <div style={{ maxHeight: '60vh', overflowY: 'auto' }}>
                    <List
                        loading={serialLoading}
                        dataSource={serialItems}
                        locale={{ emptyText: 'Serial nömrə yoxdur' }}
                        pagination={{
                            current: serialPagination.current,
                            pageSize: serialPagination.pageSize,
                            total: serialPagination.total,
                            onChange: (page) => fetchSerialList(serialProduct.id, page, serialSearch),
                            size: 'small',
                        }}
                        renderItem={item => (
                            <List.Item actions={[
                                <Button size="small" icon={<SwapOutlined />} onClick={() => {
                                    const prod = serialProduct;
                                    setIsSerialModalOpen(false);
                                    setSelectedProduct(prod);
                                    setSerialLocked(true);
                                    stockForm.resetFields();
                                    setTimeout(() => {
                                        stockForm.setFieldsValue({
                                            serial_number: item.serial_number,
                                            movement_type: 'out',
                                            warehouse_id: item.warehouse,
                                        });
                                    }, 100);
                                    setIsStockModalOpen(true);
                                }}>Export/Transfer</Button>
                            ]}>
                                <List.Item.Meta
                                    avatar={<BarcodeOutlined style={{ fontSize: 20, color: '#1890ff' }} />}
                                    title={item.serial_number}
                                    description={`Anbar: ${item.warehouse_name} | ${new Date(item.created_at).toLocaleDateString('az-AZ')}`}
                                />
                            </List.Item>
                        )}
                    />
                </div>
            </Modal>
        </div>
    );
};

export default ProductTab;
