import React, { useState, useEffect } from 'react';
import { Table, Card, DatePicker, Typography, Tag, Space, message } from 'antd';
import { getAuditLogs } from '../../axios/api/audit';
import styles from './style.module.scss';
import dayjs from 'dayjs';

const { Title } = Typography;

const ReportsPage = () => {
    const [loading, setLoading] = useState(false);
    const [data, setData] = useState([]);
    const [total, setTotal] = useState(0);
    const [currentPage, setCurrentPage] = useState(1);
    const [selectedDate, setSelectedDate] = useState(dayjs());

    const fetchData = async (page = 1, date = dayjs()) => {
        setLoading(true);
        try {
            const params = {
                page: page,
                created_at__date: date ? date.format('YYYY-MM-DD') : undefined,
                ordering: '-created_at'
            };
            const response = await getAuditLogs(params);
            setData(response.data.results);
            setTotal(response.data.count);
            setCurrentPage(page);
        } catch (error) {
            console.error(error);
            message.error('Logları yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchData(1, selectedDate);
    }, [selectedDate]);

    const handleTableChange = (pagination) => {
        fetchData(pagination.current, selectedDate);
    };

    const handleDateChange = (date) => {
        setSelectedDate(date);
    };

    const formatAction = (action) => {
        const map = {
            'POST': { text: 'Yaratdı (HTTP)', color: 'green' },
            'CREATE': { text: 'Yaratdı', color: 'green' },
            'PUT': { text: 'Yenilədi (HTTP)', color: 'orange' },
            'PATCH': { text: 'Yenilədi (HTTP)', color: 'orange' },
            'UPDATE': { text: 'Yenilədi', color: 'orange' },
            'DELETE': { text: 'Sildi', color: 'red' },
        };
        return map[action] || { text: action, color: 'default' };
    };

    const columns = [
        {
            title: 'Tarix/Saat',
            dataIndex: 'created_at',
            key: 'created_at',
            render: (text) => dayjs(text).format('DD.MM.YYYY HH:mm:ss'),
            width: 180,
        },
        {
            title: 'İstifadəçi',
            key: 'user',
            render: (_, record) => (
                <div className={styles.userInfo}>
                    <span className={styles.userName}>{record.user_name || 'Naməlum'}</span>
                    <span className={styles.userEmail}>{record.user_email}</span>
                </div>
            ),
        },
        {
            title: 'Əməliyyat',
            key: 'action',
            render: (_, record) => {
                const { text, color } = formatAction(record.action || record.method);
                return <Tag color={color}>{text}</Tag>;
            },
            width: 150,
        },
        {
            title: 'Model / Resurs',
            key: 'resource',
            render: (_, record) => {
                if (record.resource_type) {
                    return (
                        <div style={{ display: 'flex', flexDirection: 'column' }}>
                            <Tag color="geekblue">{record.resource_type}</Tag>
                            {record.resource_id && <span style={{ fontSize: 10, color: '#999' }}>ID: {record.resource_id}</span>}
                        </div>
                    );
                }
                const path = record.path || '';
                const parts = path.split('/').filter(Boolean);
                const resource = parts.length > 1 ? parts[1] : path;
                return <span className={styles.resourcePath}>{(resource || '').toUpperCase()}</span>;
            }
        },
        {
            title: 'IP',
            dataIndex: 'ip_address',
            key: 'ip_address',
            width: 130,
        },
    ];

    const renderChanges = (changes, action) => {
        if (!changes) return <span style={{ color: '#999' }}>Heç bir məlumat yoxdur</span>;

        if (action === 'UPDATE') {
            return (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                    {Object.entries(changes).map(([field, diff]) => (
                        <div key={field} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 13 }}>
                            <strong style={{ minWidth: 100 }}>{field}:</strong>
                            <span style={{ background: '#ffeef0', padding: '2px 6px', borderRadius: 4, textDecoration: 'line-through', color: '#cf1322' }}>
                                {String(diff.old)}
                            </span>
                            <span>→</span>
                            <span style={{ background: '#f6ffed', padding: '2px 6px', borderRadius: 4, color: '#389e0d' }}>
                                {String(diff.new)}
                            </span>
                        </div>
                    ))}
                </div>
            );
        }

        // For Create / Delete, show as JSON or Key-Value list
        return (
            <pre className={styles.jsonPayload}>
                {JSON.stringify(changes, null, 2)}
            </pre>
        );
    };

    const expandedRowRender = (record) => {
        return (
            <div className={styles.expandedRow}>
                {record.path && <p><strong>Tam Yol:</strong> {record.path}</p>}

                <div style={{ marginTop: 10 }}>
                    <h4 style={{ marginBottom: 8, color: '#1890ff' }}>
                        {record.action === 'UPDATE' ? 'Dəyişikliklər (Əvvəlki → Yeni)' : 'Məlumat Detalları'}
                    </h4>
                    {renderChanges(record.changes || record.payload, record.action)}
                </div>
            </div>
        );
    };

    return (
        <div className={styles.reportsPage}>
            <Card title={<Title level={4}>Sistem Hesabatları</Title>} extra={
                <DatePicker
                    onChange={handleDateChange}
                    value={selectedDate}
                    allowClear={false}
                    className={styles.datePicker}
                />
            }>
                <Table
                    columns={columns}
                    dataSource={data}
                    rowKey="id"
                    pagination={{
                        current: currentPage,
                        total: total,
                        pageSize: 20,
                        showSizeChanger: false
                    }}
                    loading={loading}
                    onChange={handleTableChange}
                    expandable={{
                        expandedRowRender,
                        rowExpandable: (record) => true,
                    }}
                    scroll={{ x: 800 }}
                />
            </Card>
        </div>
    );
};

export default ReportsPage;
