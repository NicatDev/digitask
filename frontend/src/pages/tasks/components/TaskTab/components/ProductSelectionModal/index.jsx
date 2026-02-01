import React, { useState, useEffect } from 'react';
import { Modal, Form, Select, InputNumber, Table, Button, message, Space } from 'antd';
import { PlusOutlined, DeleteOutlined } from '@ant-design/icons';
import { getWarehouses, getInventory } from '../../../../../../axios/api/warehouse';
import { createTaskProducts, deleteTaskProduct } from '../../../../../../axios/api/tasks';
import { handleApiError } from '../../../../../../utils/errorHandler';

const { Option } = Select;

const ProductSelectionModal = ({ open, onCancel, task, onSuccess }) => {
    const [form] = Form.useForm();
    const [warehouses, setWarehouses] = useState([]);
    const [inventory, setInventory] = useState([]);
    const [selectedProducts, setSelectedProducts] = useState([]);
    const [loading, setLoading] = useState(false);
    const [submitting, setSubmitting] = useState(false);

    useEffect(() => {
        if (open) {
            fetchData();
            // Əvvəlcədən seçilmiş məhsulları yüklə
            if (task?.task_products) {
                setSelectedProducts(task.task_products.map(tp => ({
                    id: tp.id,
                    product_id: tp.product,
                    product_name: tp.product_name,
                    warehouse_id: tp.warehouse,
                    warehouse_name: tp.warehouse_name,
                    quantity: parseFloat(tp.quantity),
                    is_existing: true
                })));
            }
        }
    }, [open, task]);

    const fetchData = async () => {
        setLoading(true);
        try {
            const [warehousesRes, inventoryRes] = await Promise.all([
                getWarehouses(),
                getInventory()
            ]);
            setWarehouses(warehousesRes.data.results || warehousesRes.data);
            setInventory(inventoryRes.data.results || inventoryRes.data);
        } catch (error) {
            handleApiError(error, 'Məlumatları yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    const getWarehouseProducts = (warehouseId) => {
        return inventory.filter(inv => inv.warehouse === warehouseId && parseFloat(inv.quantity) > 0);
    };

    const handleAddProduct = (values) => {
        const { warehouse_id, product_id, quantity } = values;

        // Anbar və məhsul məlumatlarını tap
        const warehouse = warehouses.find(w => w.id === warehouse_id);
        const productInv = inventory.find(inv => inv.warehouse === warehouse_id && inv.product === product_id);

        if (!warehouse || !productInv) {
            message.error('Anbar və ya məhsul tapılmadı');
            return;
        }

        // Yoxla ki, artıq əlavə olunub
        const existing = selectedProducts.find(
            p => p.product_id === product_id && p.warehouse_id === warehouse_id && !p.is_existing
        );
        if (existing) {
            message.warning('Bu məhsul artıq siyahıda var');
            return;
        }

        // Stok yoxla
        if (quantity > parseFloat(productInv.quantity)) {
            message.error(`Anbarda kifayət qədər məhsul yoxdur. Mövcud: ${parseFloat(productInv.quantity).toFixed(2)}`);
            return;
        }

        setSelectedProducts([...selectedProducts, {
            product_id,
            product_name: productInv.product_name,
            warehouse_id,
            warehouse_name: warehouse.name,
            quantity,
            is_existing: false
        }]);

        form.resetFields();
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
                quantity: p.quantity
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
        { title: 'Miqdar', dataIndex: 'quantity', key: 'quantity', render: (val) => parseFloat(val).toFixed(2) },
        {
            title: 'Status',
            key: 'status',
            render: (_, record) => record.is_existing ?
                <span style={{ color: '#52c41a' }}>Saxlanılıb</span> :
                <span style={{ color: '#faad14' }}>Gözləyir</span>
        },
        {
            title: '',
            key: 'action',
            render: (_, record, index) => (
                <Button
                    type="text"
                    danger
                    icon={<DeleteOutlined />}
                    onClick={() => handleRemoveProduct(index)}
                />
            )
        }
    ];

    const selectedWarehouseId = Form.useWatch('warehouse_id', form);

    return (
        <Modal
            title={`Məhsul Seç: ${task?.title || ''}`}
            open={open}
            onCancel={onCancel}
            width={700}
            footer={[
                <Button key="cancel" onClick={onCancel}>Ləğv et</Button>,
                <Button key="submit" type="primary" loading={submitting} onClick={handleSubmit}>
                    Təsdiqlə
                </Button>
            ]}
        >
            <Form form={form} layout="inline" style={{ marginBottom: 16 }} onFinish={handleAddProduct}>
                <Form.Item name="warehouse_id" rules={[{ required: true, message: 'Anbar seçin' }]}>
                    <Select
                        placeholder="Anbar"
                        style={{ width: 150 }}
                        loading={loading}
                        onChange={() => form.setFieldValue('product_id', undefined)}
                    >
                        {warehouses.map(w => (
                            <Option key={w.id} value={w.id}>{w.name}</Option>
                        ))}
                    </Select>
                </Form.Item>

                <Form.Item name="product_id" rules={[{ required: true, message: 'Məhsul seçin' }]}>
                    <Select
                        placeholder="Məhsul"
                        style={{ width: 200 }}
                        disabled={!selectedWarehouseId}
                    >
                        {selectedWarehouseId && getWarehouseProducts(selectedWarehouseId).map(inv => (
                            <Option key={inv.product} value={inv.product}>
                                {inv.product_name} ({parseFloat(inv.quantity).toFixed(2)})
                            </Option>
                        ))}
                    </Select>
                </Form.Item>

                <Form.Item name="quantity" rules={[{ required: true, message: 'Miqdar' }]}>
                    <InputNumber placeholder="Miqdar" min={0.001} step={0.001} style={{ width: 100 }} />
                </Form.Item>

                <Form.Item>
                    <Button type="primary" htmlType="submit" icon={<PlusOutlined />}>
                        Əlavə et
                    </Button>
                </Form.Item>
            </Form>

            <Table
                columns={columns}
                dataSource={selectedProducts}
                rowKey={(record, index) => record.id || `new-${index}`}
                pagination={false}
                size="small"
                locale={{ emptyText: 'Məhsul seçilməyib' }}
            />
        </Modal>
    );
};

export default ProductSelectionModal;
