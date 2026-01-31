import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Switch, Select, Grid, InputNumber, Row, Col, Popover, Badge } from 'antd';
import { FilterOutlined, SwapOutlined, PlusOutlined, MinusOutlined, InfoCircleOutlined } from '@ant-design/icons';
import styles from './style.module.scss';
import { getProducts, createProduct, updateProduct, deleteProduct, adjustStock, getWarehouses, getInventory } from '../../../../axios/api/warehouse/index';
import { handleApiError } from '../../../../utils/errorHandler';

const { Option } = Select;

const ProductTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);
    const [warehouses, setWarehouses] = useState([]);
    const [inventory, setInventory] = useState([]);

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [statusFilter, setStatusFilter] = useState('all');
    const [showFilters, setShowFilters] = useState(false);
    const screens = Grid.useBreakpoint();

    // Product Modal
    const [isProductModalOpen, setIsProductModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [form] = Form.useForm();

    // Stock Modal
    const [isStockModalOpen, setIsStockModalOpen] = useState(false);
    const [stockForm] = Form.useForm();
    const [selectedProduct, setSelectedProduct] = useState(null);

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
            const [productsRes, warehousesRes, inventoryRes] = await Promise.all([
                getProducts(),
                getWarehouses(),
                getInventory()
            ]);
            setData(productsRes.data.results || productsRes.data);
            setWarehouses(warehousesRes.data.results || warehousesRes.data);
            setInventory(inventoryRes.data.results || inventoryRes.data);
        } catch (error) {
            console.error(error);
            handleApiError(error, 'Məlumatları yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (isActive) {
            fetchData();
        }
    }, [isActive]);

    const handleDelete = async (id) => {
        try {
            await deleteProduct(id);
            message.success('Məhsul silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    const onProductFinish = async (values) => {
        try {
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
            fetchData();
        } catch (error) {
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        }
    };

    const handleStatusChange = async (id, checked) => {
        try {
            await updateProduct(id, { is_active: checked });
            message.success('Status yeniləndi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const onStockFinish = async (values) => {
        try {
            const payload = {
                ...values,
                product_id: selectedProduct?.id
            };
            await adjustStock(payload);
            message.success('Əməliyyat uğurla tamamlandı');
            setIsStockModalOpen(false);
            stockForm.resetFields();
            setSelectedProduct(null);
            fetchData(); // Refresh data after stock adjustment
        } catch (error) {
            handleApiError(error, 'Stock əməliyyatı uğursuz oldu');
        }
    };

    const getFilteredData = () => {
        return data.filter(item => {
            const lowerSearch = debouncedSearchText.toLowerCase();
            const matchesSearch = item.name.toLowerCase().includes(lowerSearch) ||
                (item.brand && item.brand.toLowerCase().includes(lowerSearch)) ||
                (item.model && item.model.toLowerCase().includes(lowerSearch));
            const matchesStatus = statusFilter !== 'all' ? item.is_active === statusFilter : true;
            return matchesSearch && matchesStatus;
        });
    };

    const getProductInventory = (productId) => {
        return inventory.filter(inv => inv.product === productId);
    };

    const getTotalStock = (productId) => {
        const productInv = getProductInventory(productId);
        return productInv.reduce((sum, inv) => sum + parseFloat(inv.quantity || 0), 0);
    };

    const renderInventoryPopover = (productId) => {
        const productInv = getProductInventory(productId);
        if (productInv.length === 0) {
            return <div style={{ padding: '8px' }}>Anbarda yoxdur</div>;
        }
        return (
            <div style={{ minWidth: 200 }}>
                {productInv.map(inv => (
                    <div key={inv.id} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0', borderBottom: '1px solid #f0f0f0' }}>
                        <span>{inv.warehouse_name}</span>
                        <strong>{parseFloat(inv.quantity).toFixed(2)} {inv.product_unit}</strong>
                    </div>
                ))}
            </div>
        );
    };

    const columns = [
        {
            title: 'Şəkil',
            dataIndex: 'image',
            key: 'image',
            width: 80,
            render: (image) => image ? (
                <img
                    src={image}
                    alt="Product"
                    style={{ width: 40, height: 40, objectFit: 'cover', borderRadius: 4 }}
                />
            ) : '-'
        },
        { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        { title: 'Ad', dataIndex: 'name', key: 'name', width: 150 },
        { title: 'Brand', dataIndex: 'brand', key: 'brand' },
        { title: 'Model', dataIndex: 'model', key: 'model' },
        { title: 'Serial No', dataIndex: 'serial_number', key: 'serial_number' },
        { title: 'Ölçü', dataIndex: 'size', key: 'size' },
        { title: 'Çəki', dataIndex: 'weight', key: 'weight' },
        { title: 'Port Sayı', dataIndex: 'port_count', key: 'port_count' },
        { title: 'Qiymət', dataIndex: 'price', key: 'price', render: (val) => val ? `${parseFloat(val).toFixed(2)} ₼` : '-' },
        { title: 'Vahid', dataIndex: 'unit_display', key: 'unit_display' },
        { title: 'Min Say', dataIndex: 'min_quantity', key: 'min_quantity', render: (val) => val ? parseFloat(val).toFixed(2) : '-' },
        { title: 'Max Say', dataIndex: 'max_quantity', key: 'max_quantity', render: (val) => val ? parseFloat(val).toFixed(2) : '-' },
        {
            title: 'Say',
            key: 'total_stock',
            width: 120,
            render: (_, record) => {
                const total = getTotalStock(record.id);
                const min = record.min_quantity ? parseFloat(record.min_quantity) : null;
                const max = record.max_quantity ? parseFloat(record.max_quantity) : null;

                let color = '#52c41a'; // Green (OK)
                let tooltip = 'Normal';

                if (min !== null && total < min) {
                    color = '#faad14'; // Yellow (Low stock)
                    tooltip = 'Minimumdan az';
                }
                if (max !== null && total > max) {
                    color = '#f5222d'; // Red (Over stock) - using Red for critical/over
                    // Or keep Yellow for warning? Usually overstock is less critical than understock but still a warning.
                    // User said "sari rengde" (yellow) if less or more. Let's use flexible logic.
                    // Request: "eger az ve ya coxdusa sari rengde" -> Yellow for both.
                    color = '#faad14';
                    tooltip = total > max ? 'Maksimumdan çox' : 'Minimumdan az';
                }

                return (
                    <Popover content={renderInventoryPopover(record.id)} title="Anbar Balansı">
                        <span style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 6 }}>
                            <Badge
                                count={total.toFixed(2)}
                                style={{ backgroundColor: color }}
                                overflowCount={99999}
                            />
                            {/* <InfoCircleOutlined style={{ color: '#1890ff' }} /> */}
                        </span>
                    </Popover>
                );
            }
        },
        {
            title: 'Hərəkət',
            key: 'stock_action',
            render: (_, record) => (
                <Button
                    size="small"
                    icon={<SwapOutlined />}
                    onClick={() => {
                        setSelectedProduct(record);
                        setIsStockModalOpen(true);
                        stockForm.resetFields();
                    }}
                >
                    Stock
                </Button>
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
                    <Button type="link" onClick={() => {
                        setEditingItem(record);
                        form.setFieldsValue(record);
                        setIsProductModalOpen(true);
                    }}>Düzəliş</Button>
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
                            placeholder="Axtar (Ad, Brand, Model)..."
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
                        <Button type="primary" block={!screens.md} onClick={() => {
                            setEditingItem(null);
                            form.resetFields();
                            setIsProductModalOpen(true);
                        }}>
                            Yeni Məhsul
                        </Button>
                    </div>
                </div>
            </div>

            <Table
                columns={columns}
                dataSource={getFilteredData()}
                rowKey="id"
                loading={loading}
                scroll={{ x: 1000 }}
                pagination={{ pageSize: 10 }}
            />

            {/* Product Create/Edit Modal */}
            <Modal
                title={editingItem ? "Məhsulu Düzəlt" : "Yeni Məhsul"}
                open={isProductModalOpen}
                onCancel={() => setIsProductModalOpen(false)}
                footer={null}
                width={800}
                className={styles.responsiveModal}
            >
                <Form form={form} onFinish={onProductFinish} layout="vertical">
                    <Row gutter={16}>
                        <Col span={24}>
                            <Form.Item name="image" label="Link (URL)">
                                <Input placeholder="Şəkil URL" />
                            </Form.Item>
                            {/* Ideally this should be a File Upload, but for now assuming logic uses URL or File handling needs to be checked. 
                                Backend model has ImageField. React code creating needs Upload component to send valid file.
                                The current hook uses createProduct(values). 
                                If it just sends JSON, ImageField won't work with simple string unless it's base64 or backend handles url.
                                Let's check createProduct api. It likely expects FormData for file upload.
                                For now, I will NOT change the Form to Upload separately unless instructed, 
                                but I'll add the field columns first as requested. user said 'anbarda mehsullarin butun fieldlerin elave et table-da gorunsun' 
                                Table is priority.
                            */}
                        </Col>
                    </Row>
                    <Row gutter={16}>
                        <Col span={12}>
                            <Form.Item name="name" label="Ad" rules={[{ required: true }]}>
                                <Input />
                            </Form.Item>
                        </Col>
                        <Col span={12}>
                            <Form.Item name="unit" label="Ölçü Vahidi" rules={[{ required: true }]} initialValue="pcs">
                                <Select>
                                    <Option value="pcs">Ədəd (Piece)</Option>
                                    <Option value="kg">Kq (Kilogram)</Option>
                                    <Option value="g">Qram (Gram)</Option>
                                    <Option value="l">Litr (Liter)</Option>
                                    <Option value="m">Metr (Meter)</Option>
                                    <Option value="box">Qutu (Box)</Option>
                                    <Option value="set">Dəst (Set)</Option>
                                </Select>
                            </Form.Item>
                        </Col>
                    </Row>
                    <Row gutter={16}>
                        <Col span={8}>
                            <Form.Item name="brand" label="Brand">
                                <Input />
                            </Form.Item>
                        </Col>
                        <Col span={8}>
                            <Form.Item name="model" label="Model">
                                <Input />
                            </Form.Item>
                        </Col>
                        <Col span={8}>
                            <Form.Item name="serial_number" label="Serial Nömrə">
                                <Input />
                            </Form.Item>
                        </Col>
                    </Row>
                    <Row gutter={16}>
                        <Col span={6}>
                            <Form.Item name="size" label="Ölçü">
                                <Input />
                            </Form.Item>
                        </Col>
                        <Col span={6}>
                            <Form.Item name="weight" label="Çəki">
                                <Input />
                            </Form.Item>
                        </Col>
                        <Col span={6}>
                            <Form.Item name="port_count" label="Port Sayı">
                                <InputNumber style={{ width: '100%' }} />
                            </Form.Item>
                        </Col>
                        <Col span={6}>
                            <Form.Item name="price" label="Qiymət">
                                <InputNumber style={{ width: '100%' }} step="0.01" />
                            </Form.Item>
                        </Col>
                    </Row>
                    <Row gutter={16}>
                        <Col span={12}>
                            <Form.Item name="min_quantity" label="Min Say">
                                <InputNumber style={{ width: '100%' }} />
                            </Form.Item>
                        </Col>
                        <Col span={12}>
                            <Form.Item name="max_quantity" label="Max Say">
                                <InputNumber style={{ width: '100%' }} />
                            </Form.Item>
                        </Col>
                    </Row>
                    <Form.Item name="description" label="Təsvir">
                        <Input.TextArea />
                    </Form.Item>

                    <Button type="primary" htmlType="submit" block>
                        Təsdiqlə
                    </Button>
                </Form>
            </Modal>

            {/* Stock Movement Modal */}
            <Modal
                title={`Stock Əməliyyatı: ${selectedProduct?.name}`}
                open={isStockModalOpen}
                onCancel={() => setIsStockModalOpen(false)}
                footer={null}
                width={500}
                className={styles.responsiveModal}
            >
                <Form form={stockForm} onFinish={onStockFinish} layout="vertical">
                    <Form.Item name="movement_type" label="Əməliyyat Növü" rules={[{ required: true }]}>
                        <Select onChange={() => stockForm.setFieldValue('to_warehouse_id', undefined)}>
                            <Option value="in">Giriş (Import)</Option>
                            <Option value="out">Çıxış (Export)</Option>
                            <Option value="transfer">Transfer</Option>
                        </Select>
                    </Form.Item>

                    <Form.Item name="warehouse_id" label="Anbar" rules={[{ required: true }]}>
                        <Select placeholder="Anbar seçin">
                            {warehouses.map(w => {
                                const inv = selectedProduct ? inventory.find(i => i.warehouse === w.id && i.product === selectedProduct.id) : null;
                                const qty = inv ? parseFloat(inv.quantity).toFixed(2) : '0.00';
                                return <Option key={w.id} value={w.id}>{w.name} ({qty})</Option>;
                            })}
                        </Select>
                    </Form.Item>

                    <Form.Item
                        noStyle
                        shouldUpdate={(prev, current) => prev.movement_type !== current.movement_type}
                    >
                        {({ getFieldValue }) =>
                            getFieldValue('movement_type') === 'transfer' ? (
                                <Form.Item name="to_warehouse_id" label="Hədəf Anbar" rules={[{ required: true }]}>
                                    <Select placeholder="Hədəf anbar seçin">
                                        {warehouses.map(w => {
                                            const inv = selectedProduct ? inventory.find(i => i.warehouse === w.id && i.product === selectedProduct.id) : null;
                                            const qty = inv ? parseFloat(inv.quantity).toFixed(2) : '0.00';
                                            return <Option key={w.id} value={w.id}>{w.name} ({qty})</Option>;
                                        })}
                                    </Select>
                                </Form.Item>
                            ) : null
                        }
                    </Form.Item>

                    <Form.Item name="quantity" label="Miqdar" rules={[{ required: true }]}>
                        <InputNumber style={{ width: '100%' }} min={0} step={0.001} />
                    </Form.Item>

                    <Form.Item name="reference_no" label="Sənəd No / Referans">
                        <Input />
                    </Form.Item>

                    <Form.Item name="reason" label="Səbəb / Qeyd">
                        <Input.TextArea />
                    </Form.Item>

                    <Button type="primary" htmlType="submit" block>
                        İcra Et
                    </Button>
                </Form>
            </Modal>
        </div>
    );
};

export default ProductTab;
