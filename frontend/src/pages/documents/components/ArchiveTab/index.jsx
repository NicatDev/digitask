import React, { useEffect, useState } from 'react';
import { Table, Button, Input, Select, Grid, Tag, Space, Popconfirm, message } from 'antd';
import { FileOutlined, DeleteOutlined } from '@ant-design/icons';
import { getTaskDocuments, getShelves, deleteTaskDocument } from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';
import { useAuth } from '../../../../context/AuthContext';
import { hasPermission, PERMISSIONS } from '../../../../utils/permissions';
import styles from './style.module.scss';

const { Option } = Select;

const ArchiveTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);
    const [shelves, setShelves] = useState([]);
    const { user } = useAuth();

    // Filters
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [shelfFilter, setShelfFilter] = useState(null);
    const [statusFilter, setStatusFilter] = useState('true'); // default: Aktiv

    // Pagination
    const [pagination, setPagination] = useState({
        current: 1,
        pageSize: 5,
        total: 0
    });

    const screens = Grid.useBreakpoint();

    useEffect(() => {
        const timer = setTimeout(() => setDebouncedSearchText(searchText), 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    const fetchData = async (params = {}) => {
        setLoading(true);
        try {
            const queryParams = {
                confirmed: 'true',
                search: debouncedSearchText,
                page: params.page || pagination.current
            };
            if (shelfFilter) queryParams.shelf = shelfFilter;
            if (statusFilter !== 'all') {
                queryParams.is_active = statusFilter;
            }
            const response = await getTaskDocuments(queryParams);
            const responseData = response.data;

            if (responseData.results) {
                setData(responseData.results);
                setPagination(prev => ({
                    ...prev,
                    current: queryParams.page,
                    total: responseData.count
                }));
            } else {
                setData(responseData);
            }
        } catch (error) {
            handleApiError(error, 'Arxivi yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    const fetchShelves = async () => {
        try {
            const res = await getShelves({ is_active: 'true' });
            setShelves(res.data.results || res.data);
        } catch (error) {
            console.error(error);
        }
    };

    useEffect(() => {
        if (isActive) {
            fetchData({ page: 1 });
            fetchShelves();
        }
    }, [isActive, debouncedSearchText, shelfFilter, statusFilter]);

    const handleTableChange = (newPagination) => {
        fetchData({ page: newPagination.current });
    };

    const handleDelete = async (id) => {
        try {
            await deleteTaskDocument(id);
            message.success('Sənəd silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Sənəd silinmədi');
        }
    };

    const columns = [
        {
            title: 'Fayl',
            dataIndex: 'file_url',
            key: 'file_url',
            width: 60,
            render: (url) => url ? (
                <a href={url} target="_blank" rel="noopener noreferrer">
                    <FileOutlined style={{ fontSize: 24, color: '#1890ff' }} />
                </a>
            ) : '-'
        },
        { title: 'Başlıq', dataIndex: 'title', key: 'title' },
        {
            title: 'Rəf',
            dataIndex: 'shelf_name',
            key: 'shelf_name',
            render: (name) => name ? <Tag color="blue">{name}</Tag> : '-'
        },
        { title: 'Təsdiqləyən', dataIndex: 'confirmed_by_name', key: 'confirmed_by_name', render: (v) => v || '-' },
        {
            title: 'Təsdiq tarixi',
            dataIndex: 'confirmed_at',
            key: 'confirmed_at',
            render: (date) => date ? new Date(date).toLocaleDateString('az-AZ') : '-'
        },
        {
            title: 'Yaradılma',
            dataIndex: 'created_at',
            key: 'created_at',
            render: (date) => new Date(date).toLocaleDateString('az-AZ')
        },
        {
            title: 'Əməliyyat',
            key: 'actions',
            width: 100,
            render: (_, record) => (
                <Popconfirm title="Silmək istədiyinizə əminsiniz?" onConfirm={() => handleDelete(record.id)} disabled={!hasPermission(user, PERMISSIONS.DOCUMENT_WRITER)}>
                    <Button type="link" size="small" danger icon={<DeleteOutlined />} disabled={!hasPermission(user, PERMISSIONS.DOCUMENT_WRITER)}>Sil</Button>
                </Popconfirm>
            )
        }
    ];

    return (
        <div className={styles.archiveTab}>
            <div className={styles.toolbar}>
                <Input.Search
                    placeholder="Sənəd axtar..."
                    onChange={(e) => setSearchText(e.target.value)}
                    style={{ width: screens.md ? 300 : '100%' }}
                />
                <Select
                    placeholder="Rəf filteri"
                    style={{ width: screens.md ? 200 : '100%' }}
                    allowClear
                    onChange={setShelfFilter}
                    value={shelfFilter}
                >
                    {shelves.map(s => (
                        <Option key={s.id} value={s.id}>{s.name}</Option>
                    ))}
                </Select>
                <Select
                    value={statusFilter}
                    onChange={(v) => setStatusFilter(v)}
                    style={{ width: 130 }}
                >
                    <Option value="true">Aktiv</Option>
                    <Option value="all">Hamısı</Option>
                    <Option value="false">Deaktiv</Option>
                </Select>
                <Button onClick={fetchData}>Yenilə</Button>
            </div>

            <Table
                columns={columns}
                dataSource={data}
                rowKey="id"
                loading={loading}
                scroll={{ x: 900 }}
                pagination={pagination}
                onChange={handleTableChange}
            />
        </div>
    );
};

export default ArchiveTab;
