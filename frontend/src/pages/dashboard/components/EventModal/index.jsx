import React, { useState } from 'react';
import { Modal, Form, Input, Button, Select, DatePicker, message, Upload } from 'antd';
import { PlusOutlined } from '@ant-design/icons';
import { createEvent } from '../../../../axios/api/dashboard';
import styles from './style.module.scss';

const EventModal = ({ open, onCancel, onSuccess }) => {
    const [form] = Form.useForm();
    const [loading, setLoading] = useState(false);

    const onFinish = async (values) => {
        setLoading(true);
        try {
            const submitData = new FormData();
            submitData.append('title', values.title);
            if (values.description) submitData.append('description', values.description);
            submitData.append('event_type', values.event_type);
            submitData.append('is_active', 'true');
            if (values.date) submitData.append('date', values.date.toISOString());

            if (values.image?.fileList?.length) {
                values.image.fileList.forEach((f) => {
                    if (f.originFileObj) submitData.append('images', f.originFileObj);
                });
            }

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
            className={styles.eventModal}
        >
            <Form
                form={form}
                onFinish={onFinish}
                layout="vertical"
                initialValues={{ event_type: 'announcement', is_active: true }}
                style={{ maxHeight: '60vh', overflowY: 'auto', overflowX: 'hidden', paddingRight: '8px' }}
            >
                <Form.Item name="title" label="Başlıq" rules={[{ required: true }]}>
                    <Input />
                </Form.Item>
                <Form.Item name="description" label="Təsvir">
                    <Input.TextArea rows={3} />
                </Form.Item>
                <Form.Item name="event_type" label="Növ" rules={[{ required: true }]}>
                    <Select>
                        <Select.Option value="meeting">İclas</Select.Option>
                        <Select.Option value="holiday">Bayram</Select.Option>
                        <Select.Option value="maintenance">Texniki işlər</Select.Option>
                        <Select.Option value="announcement">Elan</Select.Option>
                        <Select.Option value="other">Digər</Select.Option>
                    </Select>
                </Form.Item>
                <Form.Item name="date" label="Tarix" rules={[{ required: true }]}>
                    <DatePicker showTime />
                </Form.Item>
                <Form.Item name="image" label="Şəkillər (bir neçə)">
                    <Upload
                        beforeUpload={() => false}
                        maxCount={12}
                        multiple
                        listType="picture-card"
                    >
                        <div>
                            <PlusOutlined />
                            <div style={{ marginTop: 8 }}>Əlavə et</div>
                        </div>
                    </Upload>
                </Form.Item>
                <Button type="primary" htmlType="submit" loading={loading} block>
                    Təsdiqlə
                </Button>
            </Form>
        </Modal>
    );
};

export default EventModal;
