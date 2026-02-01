import React from 'react';
import { Modal, Form, Input, Button, ColorPicker } from 'antd';


const TaskTypeModal = ({
    open,
    onCancel,
    onFinish,
    form,
    editingItem
}) => {
    return (
        <Modal
            title={editingItem ? "Növü Düzəlt" : "Yeni Növ"}
            open={open}
            onCancel={onCancel}
            footer={null}
            width={500}
            destroyOnClose
        >
            <Form form={form} onFinish={onFinish} layout="vertical">
                <Form.Item name="name" label="Ad" rules={[{ required: true }]}>
                    <Input />
                </Form.Item>

                <Form.Item name="color" label="Rəng" rules={[{ required: true }]}>
                    <ColorPicker showText format="hex" />
                </Form.Item>

                <Form.Item name="description" label="Təsvir">
                    <Input.TextArea rows={3} />
                </Form.Item>

                <Button type="primary" htmlType="submit" block>
                    Təsdiqlə
                </Button>
            </Form>
        </Modal>
    );
};

export default TaskTypeModal;
