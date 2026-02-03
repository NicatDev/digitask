import React, { useEffect, useState } from 'react';
import { Table, Card, DatePicker, Button, Row, Col, Space, Tag, Progress } from 'antd';
import { DownloadOutlined, ReloadOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import styles from './style.module.scss';
import { getUserPerformance } from '../../axios/api/performance';
import { Column } from '@ant-design/plots';
import { Typography } from 'antd';

const { Title } = Typography;
const PerformancePage = () => {
    const [loading, setLoading] = useState(false);
    const [data, setData] = useState([]);
    const [month, setMonth] = useState(dayjs());

    useEffect(() => {
        fetchData();
    }, [month]);

    const fetchData = async () => {
        setLoading(true);
        try {
            const date = month || dayjs();
            const res = await getUserPerformance({
                month: date.month() + 1,
                year: date.year()
            });
            setData(res.data);
        } catch (error) {
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const columns = [
        {
            title: 'İstifadəçi',
            dataIndex: ['user', 'full_name'],
            key: 'user',
            render: (text, record) => (
                <div style={{ fontWeight: 500 }}>{text || record.user.username}</div>
            )
        },
        {
            title: 'Ümumi',
            dataIndex: ['stats', 'total'],
            key: 'total',
            sorter: (a, b) => a.stats.total - b.stats.total,
        },
        {
            title: 'Tamamlanmış',
            dataIndex: ['stats', 'completed'],
            key: 'completed',
            render: (val) => <Tag color="green">{val}</Tag>
        },
        {
            title: 'Aktiv',
            dataIndex: ['stats', 'active'],
            key: 'active',
            render: (val) => <Tag color="blue">{val}</Tag>
        },
        {
            title: 'Effektivlik',
            dataIndex: ['stats', 'efficiency'],
            key: 'efficiency',
            sorter: (a, b) => a.stats.efficiency - b.stats.efficiency,
            render: (val) => (
                <Progress percent={val} size="small" status={val === 100 ? "success" : "active"} />
            )
        },
        {
            title: 'Top Növlər',
            key: 'breakdown',
            width: 300,
            render: (_, record) => (
                <Space wrap>
                    {record.breakdown.types.slice(0, 3).map((t, index) => (
                        <Tag key={index} color="cyan">
                            {t.task_type__name || 'Təyin olunmayıb'}: <strong>{t.count}</strong>
                        </Tag>
                    ))}
                    {record.breakdown.types.length === 0 && <span style={{ color: '#999', fontSize: '12px' }}>-</span>}
                </Space>
            )
        }
    ];

    const expandedRowRender = (record) => {
        return (
            <div style={{ padding: '20px', background: '#fafafa', borderRadius: '8px' }}>
                <Row gutter={24}>
                    <Col span={12}>
                        <h4 style={{ marginBottom: 16 }}>Tapşırıq Növləri (Detallı)</h4>
                        <Space wrap>
                             {record.breakdown.types.length > 0 ? (
                                record.breakdown.types.map((t, index) => (
                                    <Tag key={index} color="cyan" style={{ marginBottom: 8, padding: '4px 10px' }}>
                                        {t.task_type__name || 'Təyin olunmayıb'}: <span style={{ fontWeight: 600 }}>{t.count}</span>
                                    </Tag>
                                ))
                            ) : (
                                <span style={{ color: '#999' }}>Məlumat yoxdur</span>
                            )}
                        </Space>
                    </Col>
                    <Col span={12}>
                        <h4 style={{ marginBottom: 16 }}>Servislər (Detallı)</h4>
                        <Space wrap>
                            {record.breakdown.services.length > 0 ? (
                                record.breakdown.services.map((s, index) => (
                                    <Tag key={index} color="purple" style={{ marginBottom: 8, padding: '4px 10px' }}>
                                        {s.services__name || 'Təyin olunmayıb'}: <span style={{ fontWeight: 600 }}>{s.count}</span>
                                    </Tag>
                                ))
                            ) : (
                                <span style={{ color: '#999' }}>Məlumat yoxdur</span>
                            )}
                        </Space>
                    </Col>
                </Row>
            </div>
        );
    };

    return (
        <div className={styles.performancePage}>
       
                    <Title level={2} >İşçi Performansı</Title>
                    
            

                <Table
                    loading={loading}
                    columns={columns}
                    dataSource={data}
                    rowKey={record => record.user.id}
                    expandable={{ expandedRowRender }}
                    pagination={false}
                />
         
        </div>
    );
};

export default PerformancePage;
