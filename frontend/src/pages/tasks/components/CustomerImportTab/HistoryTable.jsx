import React from 'react';
import { Button, Space, Table, Tag, Tooltip, Typography } from 'antd';
import { EyeOutlined, RollbackOutlined } from '@ant-design/icons';
import { STATUS_META, fmtDate } from './utils';

const { Text } = Typography;

const HistoryTable = ({ data, loading, pagination, onChange, onOpen, onRollback }) => {
    const columns = [
        {
            title: 'Tarix',
            dataIndex: 'created_at',
            width: 150,
            render: (v, r) => (
                <div>
                    <div>{fmtDate(v)}</div>
                    <Text type="secondary" style={{ fontSize: 12 }}>{r.created_by_name || '—'}</Text>
                </div>
            ),
        },
        {
            title: 'Fayl',
            dataIndex: 'original_filename',
            ellipsis: true,
            render: (v, r) => (
                <Space size={4}>
                    <Tag>{r.source_type === 'excel' ? 'Excel' : 'JSON'}</Tag>
                    <span title={v}>{v}</span>
                </Space>
            ),
        },
        {
            title: 'Status',
            dataIndex: 'status',
            width: 140,
            render: (s) => {
                const m = STATUS_META[s] || { color: 'default', label: s };
                return <Tag color={m.color}>{m.label}</Tag>;
            },
        },
        { title: 'Sətir', dataIndex: 'total_rows', width: 70, align: 'right' },
        {
            title: 'Yeni',
            width: 80,
            align: 'right',
            render: (_, r) => (
                <Text style={{ color: '#389e0d' }}>{r.status === 'preview' ? r.new_count : r.created_count}</Text>
            ),
        },
        {
            title: 'Artıq var',
            width: 90,
            align: 'right',
            render: (_, r) => <Text style={{ color: '#1677ff' }}>{r.existing_count + r.duplicate_in_file_count}</Text>,
        },
        {
            title: 'Problemli',
            dataIndex: 'problem_count',
            width: 90,
            align: 'right',
            render: (v) => <Text type={v ? 'danger' : 'secondary'}>{v}</Text>,
        },
        {
            title: '',
            width: 190,
            render: (_, r) => (
                <Space>
                    <Button size="small" icon={<EyeOutlined />} onClick={() => onOpen(r)} disabled={!r.total_rows}>
                        Bax
                    </Button>
                    {r.can_rollback && (
                        <Tooltip title="Yalnız ən son importu geri qaytarmaq olar">
                            <Button size="small" danger icon={<RollbackOutlined />} onClick={() => onRollback(r)}>
                                Geri qaytar
                            </Button>
                        </Tooltip>
                    )}
                </Space>
            ),
        },
    ];

    return (
        <Table
            size="small"
            rowKey="id"
            loading={loading}
            columns={columns}
            dataSource={data}
            scroll={{ x: 900 }}
            pagination={{ ...pagination, showTotal: (t) => `Cəmi ${t} import` }}
            onChange={onChange}
        />
    );
};

export default HistoryTable;
