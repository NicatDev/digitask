import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Switch, Grid } from 'antd';
import {
    getEquipment,
    createEquipment,
    updateEquipment,
    deleteEquipment,
} from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';

const EquipmentTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [form] = Form.useForm();
    const screens = Grid.useBreakpoint();

    const fetchData = async () => {
        setLoading(true);
        try {
            const res = await getEquipment({ page_size: 100 });
            setData(res.data.results || res.data);
        } catch (error) {
            handleApiError(error, 'Məlumatları yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (isActive) {
            fetchData();
        }
    }, [isActive]);

    const handleDelete = async (id) => {
        try {
            await deleteEquipment(id);
            message.success('Avadanlıq silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    const onFinish = async (values) => {
        try {
            if (editingItem) {
                await updateEquipment(editingItem.id, values);
                message.success('Yeniləndi');
            } else {
                await createEquipment(values);
                message.success('Əlavə olundu');
            }
            setIsModalOpen(false);
            form.resetFields();
            setEditingItem(null);
            fetchData();
        } catch (error) {
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        }
    };

    const handleStatusChange = async (id, checked) => {
        try {
            await updateEquipment(id, { is_active: checked });
            message.success('Status yeniləndi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        { title: 'Ad', dataIndex: 'name', key: 'name' },
        { title: 'Təsvir', dataIndex: 'description', key: 'description' },
        {
            title: 'Aktiv',
            dataIndex: 'is_active',
            key: 'is_active',
            render: (active, record) => (
                <Switch
                    checked={active}
                    onChange={(checked) => handleStatusChange(record.id, checked)}
                />
            ),
        },
        {
            title: 'Əməliyyat',
            key: 'action',
            render: (_, record) => (
                <>
                    <Button
                        type="link"
                        onClick={() => {
                            setEditingItem(record);
                            form.setFieldsValue(record);
                            setIsModalOpen(true);
                        }}
                    >
                        Düzəliş
                    </Button>
                    <Popconfirm title="Silmək istədiyinizə əminsiniz?" onConfirm={() => handleDelete(record.id)}>
                        <Button type="link" danger>
                            Sil
                        </Button>
                    </Popconfirm>
                </>
            ),
        },
    ];

    return (
        <div>
            <div
                style={{
                    marginBottom: 16,
                    background: '#fff',
                    padding: '16px',
                    borderRadius: '8px',
                    display: 'flex',
                    justifyContent: 'flex-end',
                }}
            >
                <Button
                    type="primary"
                    onClick={() => {
                        setEditingItem(null);
                        form.resetFields();
                        setIsModalOpen(true);
                    }}
                >
                    Yeni avadanlıq
                </Button>
            </div>

            <Table
                columns={columns}
                dataSource={data}
                rowKey="id"
                loading={loading}
                scroll={{ x: screens.md ? undefined : 600 }}
                pagination={{ pageSize: 10 }}
            />

            <Modal
                title={editingItem ? 'Avadanlığı düzəlt' : 'Yeni avadanlıq'}
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                footer={null}
                width={500}
                destroyOnClose
            >
                <Form form={form} onFinish={onFinish} layout="vertical">
                    <Form.Item name="name" label="Ad" rules={[{ required: true }]}>
                        <Input />
                    </Form.Item>
                    <Form.Item name="description" label="Təsvir">
                        <Input.TextArea rows={3} />
                    </Form.Item>
                    <Button type="primary" htmlType="submit" block>
                        Təsdiqlə
                    </Button>
                </Form>
            </Modal>
        </div>
    );
};

export default EquipmentTab;
