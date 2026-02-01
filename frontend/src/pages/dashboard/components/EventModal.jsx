import React, { useState } from 'react';
import { Modal, Form, Input, Button, Select, DatePicker, message } from 'antd';
import { createEvent } from '../../../axios/api/dashboard';

const EventModal = ({ open, onCancel, onSuccess }) => {
    const [form] = Form.useForm();
    const [loading, setLoading] = useState(false);

    const onFinish = async (values) => {
        setLoading(true);
        try {
            // Format date to ISO string if it exists
            const submitData = {
                ...values,
                date: values.date ? values.date.toISOString() : null
            };
            await createEvent(submitData);
            message.success('Tədbir yaradıldı');
            form.resetFields();
            onSuccess();
        } catch (error) {
            console.error('Event create error', error);
            message.error('Xəta baş verdi');
        } finally {
            setLoading(false);
        }
    };

    return (
        <Modal
            title="Yeni Tədbir"
            open={open}
            onCancel={onCancel}
            footer={null}
            destroyOnClose
        >
            <Form form={form} onFinish={onFinish} layout="vertical" initialValues={{ event_type: 'announcement' }}>
                <Form.Item name="title" label="Başlıq" rules={[{ required: true }]}>
                    <Input />
                </Form.Item>
                <Form.Item name="description" label="Təsvir">
                    <Input.TextArea rows={3} />
                </Form.Item>
                <Form.Item name="event_type" label="Növ" rules={[{ required: true }]}>
                    <Select>
                        <Select.Option value="meeting">İclat</Select.Option>
                        <Select.Option value="holiday">Bayram</Select.Option>
                        <Select.Option value="maintenance">Texniki işlər</Select.Option>
                        <Select.Option value="announcement">Elan</Select.Option>
                        <Select.Option value="other">Digər</Select.Option>
                    </Select>
                </Form.Item>
                <Form.Item name="date" label="Tarix" rules={[{ required: true }]}>
                    <DatePicker showTime />
                </Form.Item>
                <Button type="primary" htmlType="submit" loading={loading} block>
                    Təsdiqlə
                </Button>
            </Form>
        </Modal>
    );
};

export default EventModal;
