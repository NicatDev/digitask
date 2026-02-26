import React, { useState, useEffect } from 'react';
import { Modal, Form, Select, InputNumber, Table, Button, message, Tag } from 'antd';
import { PlusOutlined, DeleteOutlined, BarcodeOutlined } from '@ant-design/icons';
import { getWarehouses, getInventory, getProducts, getSerialItems } from '../../../../../../axios/api/warehouse';
import { createTaskProducts, deleteTaskProduct } from '../../../../../../axios/api/tasks';
import { handleApiError } from '../../../../../../utils/errorHandler';

const { Option } = Select;

const ProductSelectionModal = ({ open, onCancel, task, onSuccess }) => {
    const [form] = Form.useForm();
    const [warehouses, setWarehouses] = useState([]);
    const [inventory, setInventory] = useState([]);
    const [products, setProducts] = useState([]);
    const [serialItems, setSerialItems] = useState([]);
    const [serialLoading, setSerialLoading] = useState(false);
    const [selectedProducts, setSelectedProducts] = useState([]);
    const [loading, setLoading] = useState(false);
    const [submitting, setSubmitting] = useState(false);

    useEffect(() => {
        if (open) {
            fetchData();
            if (task?.task_products) {
                setSelectedProducts(task.task_products.map(tp => ({
                    id: tp.id,
                    product_id: tp.product,
                    product_name: tp.product_name,
                    warehouse_id: tp.warehouse,
                    warehouse_name: tp.warehouse_name,
                    quantity: parseFloat(tp.quantity),
                    serial_number: tp.serial_number || null,
                    has_serial_number: tp.has_serial_number || false,
                    is_existing: true
                })));
            }
        }
    }, [open, task]);

    const fetchData = async () => {
        setLoading(true);
        try {
            const [warehousesRes, inventoryRes, productsRes] = await Promise.all([
                getWarehouses({ page_size: 100 }),
                getInventory({ page_size: 1000 }),
                getProducts({ page_size: 200, is_active: true })
            ]);
            setWarehouses(warehousesRes.data.results || warehousesRes.data);
            setInventory(inventoryRes.data.results || inventoryRes.data);
            setProducts(productsRes.data.results || productsRes.data);
        } catch (error) {
            handleApiError(error, 'Məlumatları yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    const selectedWarehouseId = Form.useWatch('warehouse_id', form);
    const selectedProductId = Form.useWatch('product_id', form);

    // Find product details
    const selectedProductObj = products.find(p => p.id === selectedProductId);
    const isSerialProduct = selectedProductObj?.has_serial_number;

    // Get warehouse products from inventory
    const getWarehouseProducts = (warehouseId) => {
        return inventory.filter(inv => inv.warehouse === warehouseId && parseFloat(inv.quantity) > 0);
    };

    // Load serial items when serial product + warehouse selected
    useEffect(() => {
        if (isSerialProduct && selectedWarehouseId && selectedProductId) {
            setSerialLoading(true);
            getSerialItems({ product: selectedProductId, warehouse: selectedWarehouseId, page_size: 200 })
                .then(res => setSerialItems(res.data.results || res.data || []))
                .catch(() => message.error('Serial nömrələr yüklənmədi'))
                .finally(() => setSerialLoading(false));
        } else {
            setSerialItems([]);
        }
    }, [isSerialProduct, selectedWarehouseId, selectedProductId]);

    const handleAddProduct = (values) => {
        const { warehouse_id, product_id, quantity, serial_number } = values;

        const warehouse = warehouses.find(w => w.id === warehouse_id);
        const productInv = inventory.find(inv => inv.warehouse === warehouse_id && inv.product === product_id);
        const productObj = products.find(p => p.id === product_id);

        if (!warehouse || !productInv || !productObj) {
            message.error('Anbar və ya məhsul tapılmadı');
            return;
        }

        if (productObj.has_serial_number) {
            // Serial product: add one item per serial number
            if (!serial_number) {
                message.error('Serial nömrə seçin');
                return;
            }

            // Check if already added
            const alreadyAdded = selectedProducts.find(
                p => p.serial_number === serial_number
            );
            if (alreadyAdded) {
                message.warning('Bu serial nömrə artıq siyahıda var');
                return;
            }

            const serialItem = serialItems.find(s => s.serial_number === serial_number);

            setSelectedProducts([...selectedProducts, {
                product_id,
                product_name: productObj.name,
                warehouse_id,
                warehouse_name: warehouse.name,
                quantity: 1,
                serial_number,
                has_serial_number: true,
                is_existing: false
            }]);

            // Reset only serial number field so same product can be added again with different serial
            form.setFieldValue('serial_number', undefined);
        } else {
            // Normal product: check duplicate
            const existing = selectedProducts.find(
                p => p.product_id === product_id && p.warehouse_id === warehouse_id && !p.is_existing
            );
            if (existing) {
                message.warning('Bu məhsul artıq siyahıda var');
                return;
            }

            if (quantity > parseFloat(productInv.quantity)) {
                message.error(`Anbarda kifayət qədər məhsul yoxdur. Mövcud: ${parseFloat(productInv.quantity).toFixed(2)}`);
                return;
            }

            setSelectedProducts([...selectedProducts, {
                product_id,
                product_name: productObj.name,
                warehouse_id,
                warehouse_name: warehouse.name,
                quantity,
                serial_number: null,
                has_serial_number: false,
                is_existing: false
            }]);

            form.resetFields();
        }
    };

    const handleRemoveProduct = async (index) => {
        const product = selectedProducts[index];

        if (product.is_existing && product.id) {
            try {
                await deleteTaskProduct(product.id);
                message.success('Məhsul silindi');
            } catch (error) {
                handleApiError(error, 'Məhsul silinmədi');
                return;
            }
        }

        setSelectedProducts(selectedProducts.filter((_, i) => i !== index));
    };

    const handleSubmit = async () => {
        const newProducts = selectedProducts.filter(p => !p.is_existing);

        if (newProducts.length === 0) {
            message.info('Yeni məhsul əlavə olunmayıb');
            onCancel();
            return;
        }

        setSubmitting(true);
        try {
            await createTaskProducts(task.id, newProducts.map(p => ({
                product_id: p.product_id,
                warehouse_id: p.warehouse_id,
                quantity: p.quantity,
                serial_number: p.serial_number || undefined
            })));
            message.success('Məhsullar əlavə olundu');
            onSuccess?.();
            onCancel();
        } catch (error) {
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        } finally {
            setSubmitting(false);
        }
    };

    const columns = [
        { title: 'Məhsul', dataIndex: 'product_name', key: 'product_name' },
        { title: 'Anbar', dataIndex: 'warehouse_name', key: 'warehouse_name' },
        {
            title: 'Miqdar / Serial', key: 'qty_serial',
            render: (_, record) => record.serial_number
                ? <Tag icon={<BarcodeOutlined />} color="blue">{record.serial_number}</Tag>
                : parseFloat(record.quantity).toFixed(2)
        },
        {
            title: 'Status', key: 'status',
            render: (_, record) => record.is_existing ?
                <span style={{ color: '#52c41a' }}>Saxlanılıb</span> :
                <span style={{ color: '#faad14' }}>Gözləyir</span>
        },
        {
            title: '', key: 'action',
            render: (_, record, index) => (
                <Button type="text" danger icon={<DeleteOutlined />} onClick={() => handleRemoveProduct(index)} />
            )
        }
    ];

    const handleSerialSearch = (value) => {
        if (selectedProductId && selectedWarehouseId) {
            setSerialLoading(true);
            getSerialItems({ product: selectedProductId, warehouse: selectedWarehouseId, page_size: 200, search: value })
                .then(res => setSerialItems(res.data.results || res.data || []))
                .finally(() => setSerialLoading(false));
        }
    };

    return (
        <Modal
            title={`Məhsul Seç: ${task?.title || ''}`}
            open={open}
            onCancel={onCancel}
            width={750}
            footer={[
                <Button key="cancel" onClick={onCancel}>Ləğv et</Button>,
                <Button key="submit" type="primary" loading={submitting} onClick={handleSubmit}>Təsdiqlə</Button>,
            ]}
        >
            <Form form={form} layout="vertical" onFinish={handleAddProduct} style={{ marginBottom: 16 }}>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                    <Form.Item name="warehouse_id" rules={[{ required: true, message: 'Anbar seçin' }]} style={{ minWidth: 140, flex: 1 }}>
                        <Select placeholder="Anbar" loading={loading}
                            onChange={() => { form.setFieldValue('product_id', undefined); form.setFieldValue('serial_number', undefined); }}>
                            {warehouses.map(w => <Option key={w.id} value={w.id}>{w.name}</Option>)}
                        </Select>
                    </Form.Item>

                    <Form.Item name="product_id" rules={[{ required: true, message: 'Məhsul seçin' }]} style={{ minWidth: 180, flex: 2 }}>
                        <Select placeholder="Məhsul" disabled={!selectedWarehouseId}
                            showSearch optionFilterProp="children"
                            onChange={() => form.setFieldValue('serial_number', undefined)}>
                            {selectedWarehouseId && getWarehouseProducts(selectedWarehouseId).map(inv => {
                                const prod = products.find(p => p.id === inv.product);
                                const label = prod?.has_serial_number
                                    ? `${inv.product_name} [SN] (${parseFloat(inv.quantity).toFixed(0)})`
                                    : `${inv.product_name} (${parseFloat(inv.quantity).toFixed(2)})`;
                                return <Option key={inv.product} value={inv.product}>{label}</Option>;
                            })}
                        </Select>
                    </Form.Item>

                    {isSerialProduct ? (
                        <Form.Item name="serial_number" rules={[{ required: true, message: 'Serial nömrə' }]} style={{ minWidth: 180, flex: 2 }}>
                            <Select placeholder="Serial nömrə seçin" showSearch filterOption={false}
                                onSearch={handleSerialSearch} loading={serialLoading}
                                notFoundContent={serialLoading ? 'Yüklənir...' : 'Tapılmadı'}>
                                {serialItems.map(item => (
                                    <Option key={item.id} value={item.serial_number}>{item.serial_number}</Option>
                                ))}
                            </Select>
                        </Form.Item>
                    ) : (
                        <Form.Item name="quantity" rules={[{ required: true, message: 'Miqdar' }]} style={{ minWidth: 100 }}>
                            <InputNumber placeholder="Miqdar" min={0.001} step={0.001} style={{ width: '100%' }} />
                        </Form.Item>
                    )}

                    <Form.Item style={{ minWidth: 'auto' }}>
                        <Button type="primary" htmlType="submit" icon={<PlusOutlined />}>Əlavə et</Button>
                    </Form.Item>
                </div>
            </Form>

            <Table
                columns={columns}
                dataSource={selectedProducts}
                rowKey={(record, index) => record.id || `new-${index}`}
                pagination={false}
                size="small"
                locale={{ emptyText: 'Məhsul seçilməyib' }}
                scroll={{ x: 500 }}
            />
        </Modal>
    );
};

export default ProductSelectionModal;
