import React from 'react';
import { Modal, Form, Input, Button, Select, Row, Col } from 'antd';
import styles from './style.module.scss';

const { Option } = Select;
const { TextArea } = Input;

const TaskModal = ({
    open,
    onCancel,
    onFinish,
    form,
    editingItem,
    customers,
    groups,
    users,
    services,
    taskTypes = []
}) => {
    return (
        <Modal
            title={editingItem ? "Tapşırığı Düzəlt" : "Yeni Tapşırıq"}
            open={open}
            onCancel={onCancel}
            footer={null}
            width={700}
            className={styles.responsiveModal}
            destroyOnClose
        >
            <Form form={form} onFinish={onFinish} layout="vertical">
                <Row gutter={16}>
                    <Col span={8}>
                        <Form.Item name="title" label="Başlıq" rules={[{ required: true }]}>
                            <Input />
                        </Form.Item>
                    </Col>
                    <Col span={8}>
                        <Form.Item name="task_type" label="Növ">
                            <Select allowClear>
                                {taskTypes.map(t => (
                                    <Option key={t.id} value={t.id}>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                            <div style={{ width: 12, height: 12, borderRadius: '50%', backgroundColor: t.color }} />
                                            {t.name}
                                        </div>
                                    </Option>
                                ))}
                            </Select>
                        </Form.Item>
                    </Col>
                    <Col span={8}>
                        <Form.Item name="customer" label="Müştəri" rules={[{ required: true }]}>
                            <Select showSearch optionFilterProp="children">
                                {customers.filter(c => c.is_active).map(c => (
                                    <Option key={c.id} value={c.id}>{c.full_name}</Option>
                                ))}
                            </Select>
                        </Form.Item>
                    </Col>
                </Row>

                <Row gutter={16}>
                    <Col span={12}>
                        <Form.Item name="group" label="Qrup" rules={[{ required: true }]}>
                            <Select showSearch optionFilterProp="children">
                                {groups.map(g => (
                                    <Option key={g.id} value={g.id}>{g.region_name} - {g.name}</Option>
                                ))}
                            </Select>
                        </Form.Item>
                    </Col>
                    <Col span={12}>
                        <Form.Item name="assigned_to" label="Təyin et">
                            <Select allowClear showSearch optionFilterProp="children">
                                {users.filter(u => u.is_active).map(u => (
                                    <Option key={u.id} value={u.id}>{u.username}</Option>
                                ))}
                            </Select>
                        </Form.Item>
                    </Col>
                </Row>

                <Row gutter={16}>
                    <Col span={24}>
                        <Form.Item name="services" label="Servislər">
                            <Select
                                mode="multiple"
                                placeholder="Servisləri seçin"
                                optionFilterProp="children"
                            >
                                {services.filter(s => s.is_active).map(s => (
                                    <Option key={s.id} value={s.id}>{s.name}</Option>
                                ))}
                            </Select>
                        </Form.Item>
                    </Col>
                </Row>

                <Form.Item name="note" label="Qeyd">
                    <TextArea rows={3} />
                </Form.Item>

                <Button type="primary" htmlType="submit" block>
                    Təsdiqlə
                </Button>
            </Form>
        </Modal >
    );
};

export default TaskModal;
