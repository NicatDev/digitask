import React, { useEffect, useState, useCallback } from 'react';
import { Modal, Form, Input, Button, Select, message } from 'antd';
import { serialAdjustStock, getSerialItems } from '../../../../axios/api/warehouse/index';
import { handleApiError } from '../../../../utils/errorHandler';

const { Option } = Select;

const SerialStockModal = ({ open, onClose, product, warehouses, inventory, onSuccess, prefilledSerial, prefilledWarehouse }) => {
    const [form] = Form.useForm();
    const [serialOptions, setSerialOptions] = useState([]);
    const [serialLoading, setSerialLoading] = useState(false);
    const [allSerialItems, setAllSerialItems] = useState([]);
    const isFromList = !!prefilledSerial; // came from serial list, but allow changing movement_type

    // Fetch ALL serial items for this product (for warehouse count display)
    useEffect(() => {
        if (open && product) {
            getSerialItems({ product: product.id, page_size: 1000 })
                .then(res => setAllSerialItems(res.data.results || res.data || []))
                .catch(() => { });
        }
    }, [open, product?.id]);

    useEffect(() => {
        if (open) {
            form.resetFields();
            setSerialOptions([]);
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
    const needsSelect = movementType === 'out' || movementType === 'transfer' || movementType === 'adjust_decrease';
    const needsInput = movementType === 'in' || movementType === 'return' || movementType === 'adjust_increase';

    // Load serial items filtered by warehouse for out/transfer/adjust_decrease
    const loadSerialOptions = useCallback(async (whId, search = '') => {
        if (!product) return;
        setSerialLoading(true);
        try {
            const params = { product: product.id, page_size: 200 };
            if (whId) params.warehouse = whId;
            if (search) params.search = search;
            const res = await getSerialItems(params);
            setSerialOptions(res.data.results || res.data || []);
        } catch (e) { console.error(e); }
        finally { setSerialLoading(false); }
    }, [product?.id]);

    // When warehouse changes → reload serial options, clear serial selection (unless from list)
    useEffect(() => {
        if (open && product && needsSelect) {
            if (warehouseId) {
                loadSerialOptions(warehouseId);
            } else {
                loadSerialOptions(null);
            }
            if (!isFromList) {
                form.setFieldValue('serial_number', undefined);
            }
        }
    }, [warehouseId, needsSelect, open]);

    // When movement type changes → clear serial if switching modes
    const handleMovementTypeChange = () => {
        if (!isFromList) {
            form.setFieldValue('serial_number', undefined);
        }
        form.setFieldValue('to_warehouse_id', undefined);
        form.setFieldValue('returned_by', undefined);
    };

    // Backend search for serial numbers
    const handleSerialSearch = (value) => {
        if (product && needsSelect) {
            loadSerialOptions(warehouseId, value);
        }
    };

    // When serial is selected → auto-set warehouse
    const handleSerialSelect = (serialNumber) => {
        const item = serialOptions.find(s => s.serial_number === serialNumber)
            || allSerialItems.find(s => s.serial_number === serialNumber);
        if (item && item.warehouse) {
            form.setFieldValue('warehouse_id', item.warehouse);
        }
    };

    const getSerialCountForWarehouse = (whId) => {
        return allSerialItems.filter(s => s.warehouse === whId).length;
    };

    const onFinish = async (values) => {
        try {
            const payload = { ...values, product_id: product?.id };
            // Korreksiya direction mapping
            if (values.movement_type === 'adjust_increase') {
                payload.movement_type = 'adjust';
                payload.adjust_direction = 'increase';
            } else if (values.movement_type === 'adjust_decrease') {
                payload.movement_type = 'adjust';
                payload.adjust_direction = 'decrease';
            }
            await serialAdjustStock(payload);
            onSuccess();
            handleClose();
        } catch (e) {
            handleApiError(e, 'Serial stock əməliyyatı uğursuz oldu');
        }
    };

    const handleClose = () => {
        form.resetFields();
        setSerialOptions([]);
        setAllSerialItems([]);
        onClose();
    };

    return (
        <Modal
            title={`Serial Stock: ${product?.name || ''}`}
            open={open} onCancel={handleClose}
            footer={null} width={500} destroyOnClose
        >
            <Form form={form} onFinish={onFinish} layout="vertical">
                <Form.Item name="movement_type" label="Əməliyyat Növü" rules={[{ required: true }]}>
                    <Select onChange={handleMovementTypeChange}>
                        <Option value="in">Giriş (Import)</Option>
                        <Option value="out">Çıxış (Export)</Option>
                        <Option value="transfer">Transfer</Option>
                        <Option value="adjust_increase">Korreksiya (+)</Option>
                        <Option value="adjust_decrease">Korreksiya (−)</Option>
                        <Option value="return">Qaytarma</Option>
                    </Select>
                </Form.Item>

                <Form.Item name="warehouse_id" label="Anbar" rules={[{ required: true }]}>
                    <Select placeholder="Anbar seçin" disabled={isFromList && (movementType === 'out' || movementType === 'transfer')}>
                        {warehouses.map(w => {
                            const cnt = getSerialCountForWarehouse(w.id);
                            return <Option key={w.id} value={w.id}>{w.name} ({cnt})</Option>;
                        })}
                    </Select>
                </Form.Item>

                <Form.Item noStyle shouldUpdate={(p, c) => p.movement_type !== c.movement_type}>
                    {({ getFieldValue }) => getFieldValue('movement_type') === 'transfer' ? (
                        <Form.Item name="to_warehouse_id" label="Hədəf Anbar" rules={[{ required: true }]}>
                            <Select placeholder="Hədəf anbar seçin">
                                {warehouses.map(w => {
                                    const cnt = getSerialCountForWarehouse(w.id);
                                    return <Option key={w.id} value={w.id}>{w.name} ({cnt})</Option>;
                                })}
                            </Select>
                        </Form.Item>
                    ) : null}
                </Form.Item>

                <Form.Item noStyle shouldUpdate={(p, c) => p.movement_type !== c.movement_type}>
                    {({ getFieldValue }) => getFieldValue('movement_type') === 'return' ? (
                        <Form.Item name="returned_by" label="Qaytaran haqqında"><Input /></Form.Item>
                    ) : null}
                </Form.Item>

                {/* Serial Number Field */}
                {needsSelect && (
                    <Form.Item name="serial_number" label="Serial Nömrə" rules={[{ required: true, message: 'Serial nömrə seçin' }]}>
                        {isFromList ? (
                            <Input disabled />
                        ) : (
                            <Select
                                placeholder="Serial nömrə seçin"
                                showSearch filterOption={false}
                                onSearch={handleSerialSearch}
                                onSelect={handleSerialSelect}
                                loading={serialLoading}
                                notFoundContent={serialLoading ? 'Yüklənir...' : 'Tapılmadı'}
                            >
                                {serialOptions.map(item => (
                                    <Option key={item.id} value={item.serial_number}>
                                        {item.serial_number} — {item.warehouse_name}
                                    </Option>
                                ))}
                            </Select>
                        )}
                    </Form.Item>
                )}
                {needsInput && (
                    <Form.Item name="serial_number" label="Serial Nömrə" rules={[{ required: true, message: 'Serial nömrə daxil edin' }]}>
                        <Input placeholder="Serial nömrəni daxil edin" />
                    </Form.Item>
                )}

                <Form.Item name="reference_no" label="Sənəd No / Referans"><Input /></Form.Item>
                <Form.Item name="reason" label="Səbəb / Qeyd"><Input.TextArea /></Form.Item>
                <Button type="primary" htmlType="submit" block>İcra Et</Button>
            </Form>
        </Modal>
    );
};

export default SerialStockModal;
