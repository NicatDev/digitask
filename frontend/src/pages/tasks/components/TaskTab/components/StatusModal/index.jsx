import React, { useEffect } from 'react';
import { Modal, Form, Select, Button, DatePicker, Grid } from 'antd';
import dayjs from 'dayjs';
import { TASK_STATUSES } from '../../constants';

const { Option } = Select;

const StatusModal = ({
    open,
    onCancel,
    onStatusUpdate,
    initialStatus,
    initialRescheduledDate
}) => {
    const [form] = Form.useForm();
    const status = Form.useWatch('status', form);
    const screens = Grid.useBreakpoint();
    const modalWidth = screens.md ? 420 : '100%';

    useEffect(() => {
        if (open) {
            const normalized =
                initialStatus === 'arrived' ? 'in_progress' : initialStatus;
            form.setFieldsValue({
                status: normalized,
                rescheduled_date:
                    initialRescheduledDate && normalized === 'pending'
                        ? dayjs(initialRescheduledDate)
                        : undefined
            });
        } else {
            form.resetFields();
        }
    }, [open, initialStatus, initialRescheduledDate, form]);

    return (
        <Modal
            title="Statusu Dəyiş"
            open={open}
            onCancel={onCancel}
            footer={null}
            width={modalWidth}
            style={!screens.md ? { top: 0, paddingBottom: 0 } : undefined}
            destroyOnClose
        >
            <Form form={form} onFinish={onStatusUpdate} layout="vertical">
                <Form.Item name="status" label="Yeni Status" rules={[{ required: true }]}>
                    <Select
                        onChange={(v) => {
                            if (v !== 'pending') {
                                form.setFieldValue('rescheduled_date', undefined);
                            }
                        }}
                    >
                        {TASK_STATUSES.map(s => (
                            <Option key={s.value} value={s.value}>
                                <span style={{ color: s.color, marginRight: 8 }}>●</span>
                                {s.label}
                            </Option>
                        ))}
                    </Select>
                </Form.Item>
                {status === 'pending' && (
                    <Form.Item
                        name="rescheduled_date"
                        label="Rescheduled date"
                        rules={[
                            {
                                required: true,
                                message: 'Təxirə salındı üçün tarix seçin'
                            }
                        ]}
                    >
                        <DatePicker
                            style={{ width: '100%' }}
                            format="YYYY-MM-DD"
                            placeholder="Tarix seçin"
                        />
                    </Form.Item>
                )}
                <Button type="primary" htmlType="submit" block>
                    Yenilə
                </Button>
            </Form>
        </Modal>
    );
};

export default StatusModal;
