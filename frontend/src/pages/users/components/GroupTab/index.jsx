import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Select, Switch, Grid } from 'antd';
import { FilterOutlined } from '@ant-design/icons';
import styles from './style.module.scss';
import { getGroups, createGroup, updateGroup, deleteGroup, getRegions, updateGroupStatus } from '../../../../axios/api/account';
import { handleApiError } from '../../../../utils/errorHandler';

const GroupTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [regions, setRegions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [form] = Form.useForm();

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [statusFilter, setStatusFilter] = useState('all');
    const [regionFilter, setRegionFilter] = useState(null);
    const [showFilters, setShowFilters] = useState(false);
    const screens = Grid.useBreakpoint();

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
            const response = await getGroups();
            setData(response.data);

            const regionsRes = await getRegions();
            setRegions(regionsRes.data);
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
            await deleteGroup(id);
            message.success('Qrup silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    const onFinish = async (values) => {
        try {
            if (editingItem) {
                await updateGroup(editingItem.id, values);
                message.success('Qrup yeniləndi');
            } else {
                await createGroup(values);
                message.success('Qrup yaradıldı');
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
            await updateGroupStatus(id, checked);
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
            // Region filter: assuming region_name is string or we use ID. 
            // In API response 'region_name' was used in columns. But Select value will rely on regions list.
            // regions list has objects with name.
            // Let's assume filter value is name.
            const matchesRegion = regionFilter ? item.region_name === regionFilter : true;
            const matchesStatus = statusFilter !== 'all' ? item.is_active === statusFilter : true;
            return matchesSearch && matchesRegion && matchesStatus;
        });
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id' },
        { title: 'Ad', dataIndex: 'name', key: 'name' },
        { title: 'Region', dataIndex: 'region_name', key: 'region_name' },
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
                                    placeholder="Region seçin"
                                    style={{ width: screens.md ? 150 : '100%' }}
                                    allowClear
                                    onChange={setRegionFilter}
                                >
                                    {regions.map(r => <Select.Option key={r.id} value={r.name}>{r.name}</Select.Option>)}
                                </Select>
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
                            Yeni Qrup
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
                title={editingItem ? "Qrupu Düzəlt" : "Yeni Qrup"}
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                footer={null}
                className={styles.responsiveModal}
            >
                <Form form={form} onFinish={onFinish} layout="vertical">
                    <Form.Item name="name" label="Ad" rules={[{ required: true }]}>
                        <Input />
                    </Form.Item>
                    <Form.Item name="region" label="Region" rules={[{ required: true }]}>
                        <Select>
                            {regions.map(r => (
                                <Select.Option key={r.id} value={r.id}>{r.name}</Select.Option>
                            ))}
                        </Select>
                    </Form.Item>
                    <Form.Item name="description" label="Təsvir">
                        <Input.TextArea />
                    </Form.Item>
                    {/* Removed is_active Switch from Modal as requested */}
                    <Button type="primary" htmlType="submit" block>
                        Təsdiqlə
                    </Button>
                </Form>
            </Modal>
        </div>
    );
};

export default GroupTab;
