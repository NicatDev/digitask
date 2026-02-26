import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Select, Tag, List, Grid } from 'antd';
import { PlusOutlined, DeleteOutlined, AppstoreOutlined } from '@ant-design/icons';
import styles from '../ProductTab/style.module.scss';
import { getCategories, createCategory, updateCategory, deleteCategory, addCategoryField, removeCategoryField } from '../../../../axios/api/warehouse/index';
import { handleApiError } from '../../../../utils/errorHandler';
import { useAuth } from '../../../../context/AuthContext';
import { hasPermission, PERMISSIONS } from '../../../../utils/permissions';

const { Option } = Select;

const CategoryTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);
    const { user } = useAuth();
    const screens = Grid.useBreakpoint();

    // Category Modal
    const [isCatModalOpen, setIsCatModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [form] = Form.useForm();

    // Field Modal
    const [isFieldModalOpen, setIsFieldModalOpen] = useState(false);
    const [selectedCategory, setSelectedCategory] = useState(null);
    const [fieldForm] = Form.useForm();

    const [pagination, setPagination] = useState({
        current: 1,
        pageSize: 10,
        total: 0,
    });

    const fetchData = async (params = {}) => {
        setLoading(true);
        try {
            const queryParams = {
                page: params.current || pagination.current,
                page_size: params.pageSize || pagination.pageSize,
            };
            const res = await getCategories(queryParams);
            const result = res.data;
            setData(result.results || result || []);
            setPagination(prev => ({
                ...prev,
                current: params.current || pagination.current,
                pageSize: params.pageSize || pagination.pageSize,
                total: result.count || 0,
            }));
        } catch (error) {
            handleApiError(error, 'Kateqoriyalar yüklənmədi');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (isActive) fetchData();
    }, [isActive]);

    const handleTableChange = (newPagination) => {
        fetchData({ current: newPagination.current, pageSize: newPagination.pageSize });
    };

    const handleDelete = async (id) => {
        try {
            await deleteCategory(id);
            message.success('Kateqoriya silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    const onCatFinish = async (values) => {
        try {
            if (editingItem) {
                await updateCategory(editingItem.id, values);
                message.success('Kateqoriya yeniləndi');
            } else {
                await createCategory(values);
                message.success('Kateqoriya yaradıldı');
            }
            setIsCatModalOpen(false);
            form.resetFields();
            setEditingItem(null);
            fetchData();
        } catch (error) {
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        }
    };

    const onAddField = async (values) => {
        try {
            await addCategoryField(selectedCategory.id, values);
            message.success('Sahə əlavə edildi');
            fieldForm.resetFields();
            fetchData();
            // Refresh selected category
            const res = await getCategories({ page_size: 100 });
            const allCats = res.data.results || res.data || [];
            const updated = allCats.find(c => c.id === selectedCategory.id);
            if (updated) setSelectedCategory(updated);
        } catch (error) {
            handleApiError(error, 'Sahə əlavə edilmədi');
        }
    };

    const onRemoveField = async (fieldId) => {
        try {
            await removeCategoryField(selectedCategory.id, fieldId);
            message.success('Sahə silindi');
            fetchData();
            const res = await getCategories({ page_size: 100 });
            const allCats = res.data.results || res.data || [];
            const updated = allCats.find(c => c.id === selectedCategory.id);
            if (updated) setSelectedCategory(updated);
        } catch (error) {
            handleApiError(error, 'Sahə silinmədi');
        }
    };

    const fieldTypeLabels = {
        string: 'Mətn',
        number: 'Rəqəm',
        boolean: 'Bəli/Xeyr',
        date: 'Tarix',
    };

    const fieldTypeColors = {
        string: 'blue',
        number: 'green',
        boolean: 'orange',
        date: 'purple',
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        { title: 'Ad', dataIndex: 'name', key: 'name' },
        {
            title: 'Sahələr',
            key: 'fields',
            render: (_, record) => {
                const fields = record.fields_list || [];
                return (
                    <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                        {fields.map(f => (
                            <Tag key={f.id} color={fieldTypeColors[f.field_type]}>
                                {f.name} ({fieldTypeLabels[f.field_type]})
                            </Tag>
                        ))}
                        {fields.length === 0 && <span style={{ color: '#999' }}>Sahə yoxdur</span>}
                    </div>
                );
            }
        },
        {
            title: 'Əməliyyat',
            key: 'action',
            width: 280,
            render: (_, record) => (
                <>
                    <Button
                        type="link"
                        icon={<AppstoreOutlined />}
                        onClick={() => {
                            setSelectedCategory(record);
                            setIsFieldModalOpen(true);
                            fieldForm.resetFields();
                        }}
                    >
                        Sahələr
                    </Button>
                    <Button type="link" onClick={() => {
                        setEditingItem(record);
                        form.setFieldsValue(record);
                        setIsCatModalOpen(true);
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
            <div style={{ marginBottom: 16, background: '#fff', padding: '16px', borderRadius: '8px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <h3 style={{ margin: 0 }}>Məhsul Kateqoriyaları</h3>
                <Button
                    type="primary"
                    icon={<PlusOutlined />}
                    onClick={() => {
                        setEditingItem(null);
                        form.resetFields();
                        setIsCatModalOpen(true);
                    }}
                    disabled={!hasPermission(user, PERMISSIONS.WAREHOUSE_WRITER)}
                >
                    Yeni Kateqoriya
                </Button>
            </div>

            <Table
                columns={columns}
                dataSource={data}
                rowKey="id"
                loading={loading}
                pagination={pagination}
                onChange={handleTableChange}
            />

            {/* Category Create/Edit Modal */}
            <Modal
                title={editingItem ? 'Kateqoriyanı Düzəlt' : 'Yeni Kateqoriya'}
                open={isCatModalOpen}
                onCancel={() => setIsCatModalOpen(false)}
                footer={null}
                width={400}
            >
                <Form form={form} onFinish={onCatFinish} layout="vertical">
                    <Form.Item name="name" label="Ad" rules={[{ required: true }]}>
                        <Input />
                    </Form.Item>
                    <Button type="primary" htmlType="submit" block>Təsdiqlə</Button>
                </Form>
            </Modal>

            {/* Fields Management Modal */}
            <Modal
                title={`Sahələr: ${selectedCategory?.name || ''}`}
                open={isFieldModalOpen}
                onCancel={() => setIsFieldModalOpen(false)}
                footer={null}
                width={600}
            >
                {/* Add field form */}
                <Form form={fieldForm} onFinish={onAddField} layout="inline" style={{ marginBottom: 16 }}>
                    <Form.Item name="name" rules={[{ required: true, message: 'Ad tələb olunur' }]}>
                        <Input placeholder="Sahə adı" />
                    </Form.Item>
                    <Form.Item name="field_type" initialValue="string" rules={[{ required: true }]}>
                        <Select style={{ width: 120 }}>
                            <Option value="string">Mətn</Option>
                            <Option value="number">Rəqəm</Option>
                            <Option value="boolean">Bəli/Xeyr</Option>
                            <Option value="date">Tarix</Option>
                        </Select>
                    </Form.Item>
                    <Form.Item>
                        <Button type="primary" htmlType="submit" icon={<PlusOutlined />}>Əlavə et</Button>
                    </Form.Item>
                </Form>

                {/* Existing fields */}
                <div style={{ maxHeight: 400, overflowY: 'auto' }}>
                    <List
                        dataSource={selectedCategory?.fields_list || []}
                        locale={{ emptyText: 'Hələ sahə əlavə olunmayıb' }}
                        renderItem={item => (
                            <List.Item
                                actions={[
                                    <Popconfirm title="Bu sahəni silmək istəyirsiniz?" onConfirm={() => onRemoveField(item.id)}>
                                        <Button type="text" danger icon={<DeleteOutlined />} size="small" />
                                    </Popconfirm>
                                ]}
                            >
                                <List.Item.Meta
                                    title={item.name}
                                    description={
                                        <Tag color={fieldTypeColors[item.field_type]}>
                                            {fieldTypeLabels[item.field_type]}
                                        </Tag>
                                    }
                                />
                            </List.Item>
                        )}
                    />
                </div>
            </Modal>
        </div>
    );
};

export default CategoryTab;
