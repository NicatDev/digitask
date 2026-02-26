import React from 'react';
import { Modal, Form, Input, Button, Select, InputNumber } from 'antd';
import { adjustStock } from '../../../../axios/api/warehouse/index';
import { handleApiError } from '../../../../utils/errorHandler';

const { Option } = Select;

const StockModal = ({ open, onClose, product, warehouses, inventory, onSuccess }) => {
    const [form] = Form.useForm();

    const onFinish = async (values) => {
        try {
            await adjustStock({ ...values, product_id: product?.id });
            onSuccess();
            onClose();
            form.resetFields();
        } catch (e) {
            handleApiError(e, 'Stock əməliyyatı uğursuz oldu');
        }
    };

    const getInvQty = (whId) => {
        if (!product) return '0';
        const inv = inventory.find(i => i.warehouse === whId && i.product === product.id);
        return inv ? parseFloat(inv.quantity).toFixed(0) : '0';
    };

    return (
        <Modal
            title={`Stock Əməliyyatı: ${product?.name || ''}`}
            open={open} onCancel={() => { onClose(); form.resetFields(); }}
            footer={null} width={500} destroyOnClose
        >
            <Form form={form} onFinish={onFinish} layout="vertical">
                <Form.Item name="movement_type" label="Əməliyyat Növü" rules={[{ required: true }]}>
                    <Select>
                        <Option value="in">Giriş (Import)</Option>
                        <Option value="out">Çıxış (Export)</Option>
                        <Option value="transfer">Transfer</Option>
                        <Option value="adjust">Korreksiya</Option>
                        <Option value="return">Qaytarma</Option>
                    </Select>
                </Form.Item>

                <Form.Item name="warehouse_id" label="Anbar" rules={[{ required: true }]}>
                    <Select placeholder="Anbar seçin">
                        {warehouses.map(w => (
                            <Option key={w.id} value={w.id}>{w.name} ({getInvQty(w.id)})</Option>
                        ))}
                    </Select>
                </Form.Item>

                <Form.Item noStyle shouldUpdate={(p, c) => p.movement_type !== c.movement_type}>
                    {({ getFieldValue }) => getFieldValue('movement_type') === 'transfer' ? (
                        <Form.Item name="to_warehouse_id" label="Hədəf Anbar" rules={[{ required: true }]}>
                            <Select placeholder="Hədəf anbar seçin">
                                {warehouses.map(w => (
                                    <Option key={w.id} value={w.id}>{w.name} ({getInvQty(w.id)})</Option>
                                ))}
                            </Select>
                        </Form.Item>
                    ) : null}
                </Form.Item>

                <Form.Item noStyle shouldUpdate={(p, c) => p.movement_type !== c.movement_type}>
                    {({ getFieldValue }) => getFieldValue('movement_type') === 'return' ? (
                        <Form.Item name="returned_by" label="Qaytaran haqqında"><Input /></Form.Item>
                    ) : null}
                </Form.Item>

                <Form.Item name="quantity" label="Miqdar" rules={[{ required: true }]}>
                    <InputNumber style={{ width: '100%' }} min={0.001} step={0.001} />
                </Form.Item>

                <Form.Item name="reference_no" label="Sənəd No / Referans"><Input /></Form.Item>
                <Form.Item name="reason" label="Səbəb / Qeyd"><Input.TextArea /></Form.Item>
                <Button type="primary" htmlType="submit" block>İcra Et</Button>
            </Form>
        </Modal>
    );
};

export default StockModal;
