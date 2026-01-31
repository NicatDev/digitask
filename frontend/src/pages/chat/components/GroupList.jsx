import React from 'react';
import { List, Avatar, Badge, Button, Modal, Form, Input } from 'antd';
import { PlusOutlined, UsergroupAddOutlined } from '@ant-design/icons';
import styles from '../style.module.scss';
import dayjs from 'dayjs';

const GroupList = ({ groups, selectedGroupId, onSelectGroup, onAddGroup }) => {
    const [isModalOpen, setIsModalOpen] = React.useState(false);
    const [form] = Form.useForm();

    const handleCreate = async (values) => {
        await onAddGroup(values);
        setIsModalOpen(false);
        form.resetFields();
    };

    return (
        <div className={styles.sidebar}>
            <div className={styles.header}>
                <h3 style={{ margin: 0 }}>Mesajlar</h3>
                <Button
                    type="text"
                    icon={<PlusOutlined />}
                    onClick={() => setIsModalOpen(true)}
                />
            </div>
            <div className={styles.groupList}>
                <List
                    itemLayout="horizontal"
                    dataSource={groups}
                    renderItem={item => (
                        <div
                            className={`${styles.groupItem} ${item.id === selectedGroupId ? styles.active : ''}`}
                            onClick={() => onSelectGroup(item.id)}
                            style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12 }}
                        >
                            <Badge count={item.unread_count} size="small">
                                <Avatar shape="square" size={48} icon={<UsergroupAddOutlined />} src={item.image} />
                            </Badge>
                            <div style={{ flex: 1, overflow: 'hidden' }}>
                                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                    <span style={{ fontWeight: 600, fontSize: 15 }}>{item.name}</span>
                                    {item.last_message && (
                                        <span style={{ fontSize: 11, color: '#999' }}>
                                            {dayjs(item.last_message.created_at).format('HH:mm')}
                                        </span>
                                    )}
                                </div>
                                <div style={{ fontSize: 13, color: '#888', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                    {item.last_message ? (
                                        <>
                                            <strong>{item.last_message.sender}: </strong>
                                            {item.last_message.content}
                                        </>
                                    ) : (
                                        <span>Mesaj yoxdur</span>
                                    )}
                                </div>
                            </div>
                        </div>
                    )}
                />
            </div>

            <Modal
                title="Yeni Qrup Yaradın"
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                onOk={() => form.submit()}
            >
                <Form form={form} onFinish={handleCreate} layout="vertical">
                    <Form.Item name="name" label="Qrup Adı" rules={[{ required: true }]}>
                        <Input placeholder="Məsələn: IT Departament" />
                    </Form.Item>
                </Form>
            </Modal>
        </div>
    );
};

export default GroupList;
