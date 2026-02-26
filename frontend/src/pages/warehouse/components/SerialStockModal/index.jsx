import React, { useEffect, useState } from 'react';
import { Modal, Form, Input, Button, Select, message } from 'antd';
import { serialAdjustStock, getSerialItems } from '../../../../axios/api/warehouse/index';
import { handleApiError } from '../../../../utils/errorHandler';

const { Option } = Select;

const SerialStockModal = ({ open, onClose, product, warehouses, inventory, onSuccess, prefilledSerial, prefilledWarehouse }) => {
    const [form] = Form.useForm();
    const [serialOptions, setSerialOptions] = useState([]);
    const [serialLoading, setSerialLoading] = useState(false);
    const isLocked = !!prefilledSerial;

    useEffect(() => {
        if (open) {
            form.resetFields();
            if (prefilledSerial) {
                setTimeout(() => {
                    form.setFieldsValue({
                        serial_number: prefilledSerial,
                        movement_type: 'out',
                        warehouse_id: prefilledWarehouse,
                    });
                }, 50);
            }
        }
    }, [open, prefilledSerial, prefilledWarehouse]);

    const movementType = Form.useWatch('movement_type', form);
    const warehouseId = Form.useWatch('warehouse_id', form);
    const needsSelect = movementType === 'out' || movementType === 'transfer';

    // Load serial items for out/transfer select
    useEffect(() => {
        if (open && product && warehouseId && needsSelect && !isLocked) {
            setSerialLoading(true);
            getSerialItems({ product: product.id, warehouse: warehouseId, page_size: 200 })
                .then(res => setSerialOptions(res.data.results || res.data || []))
                .catch(() => message.error('Serial nömrələr yüklənmədi'))
                .finally(() => setSerialLoading(false));
        }
    }, [open, product?.id, warehouseId, needsSelect, isLocked]);

    const onFinish = async (values) => {
        try {
            await serialAdjustStock({ ...values, product_id: product?.id });
            onSuccess();
            onClose();
            form.resetFields();
        } catch (e) {
            handleApiError(e, 'Serial stock əməliyyatı uğursuz oldu');
        }
    };

    const getInvQty = (whId) => {
        if (!product) return '0';
        const inv = inventory.find(i => i.warehouse === whId && i.product === product.id);
        return inv ? parseFloat(inv.quantity).toFixed(0) : '0';
    };

    return (
        <Modal
            title={`Serial Stock: ${product?.name || ''}`}
            open={open} onCancel={() => { onClose(); form.resetFields(); }}
            footer={null} width={500} destroyOnClose
        >
            <Form form={form} onFinish={onFinish} layout="vertical">
                <Form.Item name="movement_type" label="Əməliyyat Növü" rules={[{ required: true }]}>
                    <Select disabled={isLocked}>
                        <Option value="in">Giriş (Import)</Option>
                        <Option value="out">Çıxış (Export)</Option>
                        <Option value="transfer">Transfer</Option>
                        <Option value="adjust">Korreksiya</Option>
                        <Option value="return">Qaytarma</Option>
                    </Select>
                </Form.Item>

                <Form.Item name="warehouse_id" label="Anbar" rules={[{ required: true }]}>
                    <Select placeholder="Anbar seçin" disabled={isLocked}>
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

                {/* Serial number: Select for out/transfer, Input for in/return/adjust */}
                <Form.Item name="serial_number" label="Serial Nömrə" rules={[{ required: true, message: 'Serial nömrə tələb olunur' }]}>
                    {isLocked ? (
                        <Input disabled />
                    ) : needsSelect ? (
                        <Select
                            placeholder="Serial nömrə seçin"
                            showSearch optionFilterProp="children"
                            loading={serialLoading}
                            notFoundContent={serialLoading ? 'Yüklənir...' : 'Tapılmadı'}
                        >
                            {serialOptions.map(item => (
                                <Option key={item.id} value={item.serial_number}>{item.serial_number}</Option>
                            ))}
                        </Select>
                    ) : (
                        <Input placeholder="Serial nömrəni daxil edin" />
                    )}
                </Form.Item>

                <Form.Item name="reference_no" label="Sənəd No / Referans"><Input /></Form.Item>
                <Form.Item name="reason" label="Səbəb / Qeyd"><Input.TextArea /></Form.Item>
                <Button type="primary" htmlType="submit" block>İcra Et</Button>
            </Form>
        </Modal>
    );
};

export default SerialStockModal;
