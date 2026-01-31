import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Switch, Row, Col, Select, Grid } from 'antd';
import { FilterOutlined } from '@ant-design/icons';
import styles from './style.module.scss';
import { getRoles, createRole, updateRole, deleteRole, updateRoleStatus } from '../../../../axios/api/account';
import { handleApiError } from '../../../../utils/errorHandler';

const RoleTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [statusFilter, setStatusFilter] = useState('all');
    const [showFilters, setShowFilters] = useState(false);
    const screens = Grid.useBreakpoint();

    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [form] = Form.useForm();

    // Debounce Search
    useEffect(() => {
        const timer = setTimeout(() => {
            setDebouncedSearchText(searchText);
        }, 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    const fetchData = async () => {
        setLoading(true);
        try {
            const response = await getRoles();
            setData(response.data);
        } catch (error) {
            console.error(error);
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
            await deleteRole(id);
            message.success('Rol silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    const onFinish = async (values) => {
        try {
            if (editingItem) {
                await updateRole(editingItem.id, values);
                message.success('Rol yeniləndi');
            } else {
                await createRole(values);
                message.success('Rol yaradıldı');
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
            await updateRoleStatus(id, checked);
            message.success('Status yeniləndi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const getFilteredData = () => {
        return data.filter(item => {
            const lowerSearch = debouncedSearchText.toLowerCase();
            const matchesSearch = item.name.toLowerCase().includes(lowerSearch);
            const matchesStatus = statusFilter !== 'all' ? item.is_active === statusFilter : true;
            return matchesSearch && matchesStatus;
        });
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id' },
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
            <div style={{ marginBottom: 16, background: '#fff', padding: '16px', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div style={{
                    display: 'flex',
                    flexDirection: screens.md ? 'row' : 'column',
                    justifyContent: 'space-between',
                    alignItems: screens.md ? 'center' : 'stretch',
                    gap: '8px'
                }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', width: screens.md ? 'auto' : '100%' }}>
                        <Input.Search
                            placeholder="Axtar (Ad)..."
                            onChange={(e) => setSearchText(e.target.value)}
                            style={{ width: screens.md ? 250 : '100%' }}
                        />
                        {/* Mobile Filter Toggle */}
                        {!screens.md && (
                            <Button
                                icon={<FilterOutlined />}
                                onClick={() => setShowFilters(!showFilters)}
                            />
                        )}
                    </div>

                    <div style={{
                        display: 'flex',
                        flexDirection: screens.md ? 'row' : 'column',
                        gap: '8px',
                        flexWrap: 'wrap',
                        alignItems: screens.md ? 'center' : 'stretch',
                        width: screens.md ? 'auto' : '100%'
                    }}>
                        {/* Filters Conditionally Hidden on Mobile */}
                        {(screens.md || showFilters) && (
                            <>
                                <Select
                                    placeholder="Status"
                                    style={{ width: screens.md ? 150 : '100%' }}
                                    allowClear
                                    value={statusFilter}
                                    onChange={setStatusFilter}
                                >
                                    <Select.Option value="all">Hamısı</Select.Option>
                                    <Select.Option value={true}>Aktiv</Select.Option>
                                    <Select.Option value={false}>Deaktiv</Select.Option>
                                </Select>
                            </>
                        )}
                        <Button type="primary" block={!screens.md} onClick={() => {
                            setEditingItem(null);
                            form.resetFields();
                            setIsModalOpen(true);
                        }}>
                            Yeni Rol
                        </Button>
                    </div>
                </div>
            </div>

            <Table
                columns={columns}
                dataSource={getFilteredData()}
                rowKey="id"
                loading={loading}
                scroll={{ x: 800 }}
                pagination={{ pageSize: 10 }}
            />

            <Modal
                title={editingItem ? "Rolu Düzəlt" : "Yeni Rol"}
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                footer={null}
                width={600}
                className={styles.responsiveModal}
            >
                <Form form={form} onFinish={onFinish} layout="vertical">
                    <Form.Item name="name" label="Ad" rules={[{ required: true }]}>
                        <Input />
                    </Form.Item>
                    <Form.Item name="description" label="Təsvir">
                        <Input.TextArea />
                    </Form.Item>
                    <Row gutter={16}>

                        {/* Add detail permission toggles if needed here via logic, e.g. is_task_reader */}
                        <Col span={12}>
                            <Form.Item name="is_task_writer" label="Tapşırıq (Yazmaq)" valuePropName="checked">
                                <Switch />
                            </Form.Item>
                        </Col>
                        <Col span={12}>
                            <Form.Item name="is_task_reader" label="Tapşırıq (Oxumaq)" valuePropName="checked">
                                <Switch />
                            </Form.Item>
                        </Col>
                        <Col span={12}>
                            <Form.Item name="is_warehouse_writer" label="Anbar (Yazmaq)" valuePropName="checked">
                                <Switch />
                            </Form.Item>
                        </Col>
                        <Col span={12}>
                            <Form.Item name="is_warehouse_reader" label="Anbar (Oxumaq)" valuePropName="checked">
                                <Switch />
                            </Form.Item>
                        </Col>
                        <Col span={12}>
                            <Form.Item name="is_admin" label="Admin" valuePropName="checked">
                                <Switch />
                            </Form.Item>
                        </Col>
                        <Col span={12}>
                            <Form.Item name="is_super_admin" label="Super Admin" valuePropName="checked">
                                <Switch />
                            </Form.Item>
                        </Col>
                    </Row>

                    <Button type="primary" htmlType="submit" block>
                        Təsdiqlə
                    </Button>
                </Form>
            </Modal>
        </div>
    );
};

export default RoleTab;
