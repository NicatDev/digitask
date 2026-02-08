import React, { useEffect, useState } from 'react';
import { Table, Button, Input, message, Modal, Select, Tag, Space, Grid } from 'antd';
import { FilterOutlined, FileOutlined, InboxOutlined, PlusOutlined } from '@ant-design/icons';
import { getTaskDocuments, archiveDocument, getShelves } from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';
import { useAuth } from '../../../../context/AuthContext';
import { hasPermission, PERMISSIONS } from '../../../../utils/permissions';
import AddDocumentModal from '../AddDocumentModal';
import styles from './style.module.scss';

const { Option } = Select;

const DocumentsTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);
    const [shelves, setShelves] = useState([]);
    const { user } = useAuth();

    // Search
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');

    // Pagination
    const [pagination, setPagination] = useState({
        current: 1,
        pageSize: 5,
        total: 0
    });

    // Archive Modal
    const [isArchiveModalOpen, setIsArchiveModalOpen] = useState(false);
    const [selectedDoc, setSelectedDoc] = useState(null);
    const [selectedShelf, setSelectedShelf] = useState(null);
    const [archiving, setArchiving] = useState(false);

    // Add Document Modal
    const [isAddModalOpen, setIsAddModalOpen] = useState(false);

    const screens = Grid.useBreakpoint();

    useEffect(() => {
        const timer = setTimeout(() => setDebouncedSearchText(searchText), 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    const fetchData = async (params = {}) => {
        setLoading(true);
        try {
            const queryParams = {
                confirmed: 'false',
                search: debouncedSearchText,
                page: params.page || pagination.current
            };
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
            handleApiError(error, 'Sənədləri yükləmək mümkün olmadı');
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
            fetchData({ page: 1 });
            fetchShelves();
        }
    }, [isActive, debouncedSearchText]);

    const handleTableChange = (newPagination) => {
        fetchData({ page: newPagination.current });
    };

    const openArchiveModal = (record) => {
        setSelectedDoc(record);
        setSelectedShelf(null);
        setIsArchiveModalOpen(true);
    };

    const handleArchive = async () => {
        if (!selectedShelf) {
            message.error('Rəf seçin');
            return;
        }
        setArchiving(true);
        try {
            await archiveDocument(selectedDoc.id, selectedShelf);
            message.success('Sənəd arxivə keçirildi');
            setIsArchiveModalOpen(false);
            fetchData();
        } catch (error) {
            handleApiError(error, 'Arxivə keçirmək mümkün olmadı');
        } finally {
            setArchiving(false);
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
            title: 'Əməliyyat',
            dataIndex: 'action',
            key: 'action',
            render: (v, record) => v || '-'
        },
        {
            title: 'Tarix',
            dataIndex: 'created_at',
            key: 'created_at',
            render: (date) => new Date(date).toLocaleDateString('az-AZ')
        },

        {
            title: 'Əməliyyat',
            key: 'action',
            width: 150,
            render: (_, record) => (
                <Button
                    type="primary"
                    size="small"
                    icon={<InboxOutlined />}
                    onClick={() => openArchiveModal(record)}
                    disabled={!hasPermission(user, PERMISSIONS.DOCUMENT_WRITER)}
                >
                    Arxivə keçir
                </Button>
            )
        }
    ];

    return (
        <div className={styles.documentsTab}>
            <div className={styles.toolbar}>
                <Input.Search
                    placeholder="Sənəd axtar..."
                    onChange={(e) => setSearchText(e.target.value)}
                    style={{ width: screens.md ? 300 : '100%' }}
                />
                <div style={{ display: 'flex', gap: 8, marginLeft: 'auto' }}>
                    <Button onClick={fetchData}>Yenilə</Button>
                    {hasPermission(user, PERMISSIONS.DOCUMENT_WRITER) && (
                        <Button
                            type="primary"
                            icon={<PlusOutlined />}
                            onClick={() => setIsAddModalOpen(true)}
                        >
                            Sənəd əlavə et
                        </Button>
                    )}
                </div>
            </div>

            <Table
                columns={columns}
                dataSource={data}
                rowKey="id"
                loading={loading}
                scroll={{ x: 800 }}
                pagination={pagination}
                onChange={handleTableChange}
            />

            <Modal
                title="Arxivə Keçir"
                open={isArchiveModalOpen}
                onCancel={() => setIsArchiveModalOpen(false)}
                onOk={handleArchive}
                confirmLoading={archiving}
                okText="Arxivə keçir"
                cancelText="İmtina"
            >
                <p>Sənəd: <strong>{selectedDoc?.title}</strong></p>
                <p style={{ marginTop: 16 }}>Rəf seçin:</p>
                <Select
                    style={{ width: '100%' }}
                    placeholder="Rəf seçin"
                    value={selectedShelf}
                    onChange={setSelectedShelf}
                >
                    {shelves.map(s => (
                        <Option key={s.id} value={s.id}>{s.name} {s.location && `(${s.location})`}</Option>
                    ))}
                </Select>
            </Modal>

            <AddDocumentModal
                open={isAddModalOpen}
                onClose={() => setIsAddModalOpen(false)}
                onSuccess={fetchData}
            />
        </div>
    );
};

export default DocumentsTab;
