import React, { useEffect, useState } from 'react';
import { Table, Button, Input, Select, Grid, Tag } from 'antd';
import { FileOutlined } from '@ant-design/icons';
import { getTaskDocuments, getShelves } from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';
import styles from './style.module.scss';

const { Option } = Select;

const ArchiveTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);
    const [shelves, setShelves] = useState([]);

    // Filters
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [shelfFilter, setShelfFilter] = useState(null);

    const screens = Grid.useBreakpoint();

    useEffect(() => {
        const timer = setTimeout(() => setDebouncedSearchText(searchText), 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    const fetchData = async () => {
        setLoading(true);
        try {
            const params = { confirmed: 'true', search: debouncedSearchText };
            if (shelfFilter) params.shelf = shelfFilter;
            const response = await getTaskDocuments(params);
            setData(response.data.results || response.data);
        } catch (error) {
            handleApiError(error, 'Arxivi yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    const fetchShelves = async () => {
        try {
            const res = await getShelves();
            setShelves(res.data.results || res.data);
        } catch (error) {
            console.error(error);
        }
    };

    useEffect(() => {
        if (isActive) {
            fetchData();
            fetchShelves();
        }
    }, [isActive, debouncedSearchText, shelfFilter]);

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
                <Button onClick={fetchData}>Yenilə</Button>
            </div>

            <Table
                columns={columns}
                dataSource={data}
                rowKey="id"
                loading={loading}
                scroll={{ x: 900 }}
                pagination={{ pageSize: 10 }}
            />
        </div>
    );
};

export default ArchiveTab;
