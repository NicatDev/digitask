import React, { useEffect } from 'react';
import { Modal, Form, Select, Button } from 'antd';
import { TASK_STATUSES } from '../../constants';

const { Option } = Select;

const StatusModal = ({
    open,
    onCancel,
    onStatusUpdate,
    initialStatus
}) => {
    const [form] = Form.useForm();

    useEffect(() => {
        if (open) {
            form.setFieldsValue({ status: initialStatus });
        } else {
            form.resetFields();
        }
    }, [open, initialStatus, form]);

    return (
        <Modal
            title="Statusu Dəyiş"
            open={open}
            onCancel={onCancel}
            footer={null}
            width={400}
            destroyOnClose
        >
            <Form form={form} onFinish={onStatusUpdate} layout="vertical">
                <Form.Item name="status" label="Yeni Status" rules={[{ required: true }]}>
                    <Select>
                        {TASK_STATUSES.map(s => (
                            <Option key={s.value} value={s.value}>
                                <span style={{ color: s.color, marginRight: 8 }}>●</span>
                                {s.label}
                            </Option>
                        ))}
                    </Select>
                </Form.Item>
                <Button type="primary" htmlType="submit" block>
                    Yenilə
                </Button>
            </Form>
        </Modal>
    );
};

export default StatusModal;
