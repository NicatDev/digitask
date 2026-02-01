import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Tag, Space, Grid } from 'antd';
import { PlusOutlined, EditOutlined, DeleteOutlined } from '@ant-design/icons';
import { getShelves, createShelf, updateShelf, deleteShelf } from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';
import styles from './style.module.scss';

const ShelvesTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);

    // Modal
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [submitting, setSubmitting] = useState(false);
    const [form] = Form.useForm();

    // Search
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');

    const screens = Grid.useBreakpoint();

    useEffect(() => {
        const timer = setTimeout(() => setDebouncedSearchText(searchText), 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    const fetchData = async () => {
        setLoading(true);
        try {
            const response = await getShelves({ search: debouncedSearchText });
            setData(response.data.results || response.data);
        } catch (error) {
            handleApiError(error, 'Rəfləri yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (isActive) {
            fetchData();
        }
    }, [isActive, debouncedSearchText]);

    const openModal = (item = null) => {
        setEditingItem(item);
        if (item) {
            form.setFieldsValue(item);
        } else {
            form.resetFields();
        }
        setIsModalOpen(true);
    };

    const handleSubmit = async (values) => {
        setSubmitting(true);
        try {
            if (editingItem) {
                await updateShelf(editingItem.id, values);
                message.success('Rəf yeniləndi');
            } else {
                await createShelf(values);
                message.success('Rəf yaradıldı');
            }
            setIsModalOpen(false);
            fetchData();
        } catch (error) {
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        } finally {
            setSubmitting(false);
        }
    };

    const handleDelete = async (id) => {
        try {
            await deleteShelf(id);
            message.success('Rəf silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Rəf silinmədi');
        }
    };

    const columns = [
        { title: 'Ad', dataIndex: 'name', key: 'name' },
        { title: 'Ünvan / Yer', dataIndex: 'location', key: 'location', render: (v) => v || '-' },
        { title: 'Təsvir', dataIndex: 'description', key: 'description', ellipsis: true, render: (v) => v || '-' },
        {
            title: 'Sənəd sayı',
            dataIndex: 'document_count',
            key: 'document_count',
            render: (count) => <Tag color={count > 0 ? 'blue' : 'default'}>{count || 0}</Tag>
        },
        {
            title: 'Yaradılma',
            dataIndex: 'created_at',
            key: 'created_at',
            render: (date) => new Date(date).toLocaleDateString('az-AZ')
        },
        {
            title: 'Əməliyyat',
            key: 'action',
            width: 150,
            render: (_, record) => (
                <Space>
                    <Button
                        type="link"
                        size="small"
                        icon={<EditOutlined />}
                        onClick={() => openModal(record)}
                    >
                        Düzəliş
                    </Button>
                    <Popconfirm
                        title="Silmək istədiyinizə əminsiniz?"
                        onConfirm={() => handleDelete(record.id)}
                    >
                        <Button type="link" size="small" danger icon={<DeleteOutlined />}>
                            Sil
                        </Button>
                    </Popconfirm>
                </Space>
            )
        }
    ];

    return (
        <div className={styles.shelvesTab}>
            <div className={styles.toolbar}>
                <Input.Search
                    placeholder="Rəf axtar..."
                    onChange={(e) => setSearchText(e.target.value)}
                    style={{ width: screens.md ? 300 : '100%' }}
                />
                <Button type="primary" icon={<PlusOutlined />} onClick={() => openModal()}>
                    Yeni Rəf
                </Button>
                <Button onClick={fetchData}>Yenilə</Button>
            </div>

            <Table
                columns={columns}
                dataSource={data}
                rowKey="id"
                loading={loading}
                scroll={{ x: 800 }}
                pagination={{ pageSize: 10 }}
            />

            <Modal
                title={editingItem ? 'Rəf Düzəliş' : 'Yeni Rəf'}
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                footer={null}
            >
                <Form form={form} layout="vertical" onFinish={handleSubmit}>
                    <Form.Item
                        name="name"
                        label="Rəf adı"
                        rules={[{ required: true, message: 'Ad daxil edin' }]}
                    >
                        <Input placeholder="Rəf adı" />
                    </Form.Item>
                    <Form.Item name="location" label="Ünvan / Yer">
                        <Input placeholder="Ünvan və ya yer" />
                    </Form.Item>
                    <Form.Item name="description" label="Təsvir">
                        <Input.TextArea rows={3} placeholder="Əlavə məlumat" />
                    </Form.Item>
                    <Form.Item>
                        <Space>
                            <Button type="primary" htmlType="submit" loading={submitting}>
                                {editingItem ? 'Yenilə' : 'Yarat'}
                            </Button>
                            <Button onClick={() => setIsModalOpen(false)}>İmtina</Button>
                        </Space>
                    </Form.Item>
                </Form>
            </Modal>
        </div>
    );
};

export default ShelvesTab;
