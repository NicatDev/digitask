import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Switch, Grid, ColorPicker } from 'antd';
import { getTaskTypes, createTaskType, updateTaskType, deleteTaskType } from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';
import TaskTypeModal from './TaskTypeModal';

const TaskTypeTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [form] = Form.useForm();
    const screens = Grid.useBreakpoint();

    const fetchData = async () => {
        setLoading(true);
        try {
            const res = await getTaskTypes();
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
            await deleteTaskType(id);
            message.success('Növ silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    const onFinish = async (values) => {
        try {
            // ColorPicker returns object, need hex string
            const color = typeof values.color === 'string' ? values.color : values.color.toHexString();
            const submitData = { ...values, color };

            if (editingItem) {
                await updateTaskType(editingItem.id, submitData);
                message.success('Növ yeniləndi');
            } else {
                await createTaskType(submitData);
                message.success('Növ yaradıldı');
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
            await updateTaskType(id, { is_active: checked });
            message.success('Status yeniləndi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        {
            title: 'Rəng',
            dataIndex: 'color',
            key: 'color',
            width: 80,
            render: (color) => (
                <div style={{
                    width: 24,
                    height: 24,
                    backgroundColor: color,
                    borderRadius: '4px',
                    border: '1px solid #d9d9d9'
                }} />
            )
        },
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
            )
        },
        {
            title: 'Əməliyyat',
            key: 'action',
            render: (_, record) => (
                <>
                    <Button type="link" onClick={() => {
                        setEditingItem(record);
                        form.setFieldsValue(record);
                        setIsModalOpen(true);
                    }}>Düzəliş</Button>
                    <Popconfirm title="Silmək istədiyinizə əminsiniz?" onConfirm={() => handleDelete(record.id)}>
                        <Button type="link" danger>Sil</Button>
                    </Popconfirm>
                </>
            ),
        },
    ];

    return (
        <div>
            <div style={{ marginBottom: 16, background: '#fff', padding: '16px', borderRadius: '8px', display: 'flex', justifyContent: 'flex-end' }}>
                <Button type="primary" onClick={() => {
                    setEditingItem(null);
                    form.resetFields();
                    setIsModalOpen(true);
                }}>
                    Yeni Növ
                </Button>
            </div>

            <Table
                columns={columns}
                dataSource={data}
                rowKey="id"
                loading={loading}
                scroll={{ x: 600 }}
                pagination={{ pageSize: 10 }}
            />

            <TaskTypeModal
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                onFinish={onFinish}
                form={form}
                editingItem={editingItem}
            />
        </div>
    );
};

export default TaskTypeTab;
