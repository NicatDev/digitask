import React from 'react';
import { Table, Button, Switch, Tooltip, Popconfirm, message, Space, Tag } from 'antd';
import { EnvironmentOutlined, FileAddOutlined, UserAddOutlined, TeamOutlined } from '@ant-design/icons';
import { TASK_STATUSES } from '../../constants';
import { useAuth } from '../../../../../../context/AuthContext';
import styles from '../../style.module.scss';

// Helper to get status label
const getStatusLabel = (status) => {
    const found = TASK_STATUSES.find(s => s.value === status);
    return found ? found.label : status;
};

const getIconUrl = (iconPath) => {
    if (!iconPath) return null;
    if (iconPath.startsWith('http')) return iconPath;
    const cleanPath = iconPath.startsWith('/') ? iconPath.substring(1) : iconPath;
    const isProduction = window.location.hostname === 'new.digitask.store' ||
        window.location.hostname === 'digitask.store' ||
        window.location.hostname === 'app.digitask.store';
    const baseUrl = isProduction ? 'https://app.digitask.store' : 'http://127.0.0.1:8000';
    return `${baseUrl}/${cleanPath}`;
};

const TaskTable = ({
    data,
    loading,
    services,
    onEdit,
    onStatusChange,
    onToggleActive,
    onQuestionnaire,
    onDelete,
    onAccept,
    onViewLocation,
    onViewDetail,
    onProductSelect,
    onDocumentAdd,
    onAddAssignee,
    onJoinTask,
    pagination,
    onChange,
    disableActions = false
}) => {
    const { user } = useAuth();

    const tableColumns = [
        { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        {
            title: 'Başlıq',
            dataIndex: 'title',
            key: 'title',
            render: (text, record) => (
                <a onClick={() => onViewDetail(record)}>{text}</a>
            )
        },
        {
            title: 'Növ',
            dataIndex: 'task_type_details',
            key: 'task_type',
            width: 140,
            render: (type, record) => type ? (
                <span style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    backgroundColor: type.color,
                    padding: '4px 12px',
                    borderRadius: '6px',
                    color: '#fff',
                    boxShadow: `0 4px 10px ${type.color}66`,
                    fontWeight: 500,
                    textShadow: '0 1px 2px rgba(0,0,0,0.2)',
                    width: 'fit-content'
                }}>
                    {type.name}
                </span>
            ) : '-'
        },
        { title: 'Müştəri', dataIndex: 'customer_name', key: 'customer_name' },
        { title: 'Əlaqə No', dataIndex: 'customer_phone', key: 'customer_phone' },
        { title: 'Qeydiyyat No', dataIndex: 'customer_register_number', key: 'customer_register_number' },
        { title: 'Qrup', dataIndex: 'group_name', key: 'group_name' },
        {
            title: 'Servislər',
            dataIndex: 'services',
            key: 'services',
            render: (serviceIds, record) => {
                const colors = [
                    { bg: '#e6f7ff', text: '#0958d9' },
                    { bg: '#f6ffed', text: '#389e0d' },
                    { bg: '#fff7e6', text: '#d46b08' },
                    { bg: '#fff1f0', text: '#cf1322' },
                    { bg: '#f9f0ff', text: '#531dab' },
                    { bg: '#e6fffb', text: '#08979c' },
                    { bg: '#fff0f6', text: '#c41d7f' },
                ];

                const taskServices = serviceIds ? serviceIds.map(id =>
                    services.find(s => s.id === id)
                ).filter(Boolean) : [];

                return (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                        {taskServices.map((svc, idx) => (
                            <span
                                key={svc.id}
                                style={{
                                    background: colors[idx % colors.length].bg,
                                    color: colors[idx % colors.length].text,
                                    padding: '2px 8px',
                                    borderRadius: '4px',
                                    fontSize: '12px',
                                    whiteSpace: 'nowrap',
                                    fontWeight: 500
                                }}
                            >
                                {svc.name}
                            </span>
                        ))}
                    </div>
                );
            }
        },
        {
            title: 'İcraçılar',
            dataIndex: 'assigned_to_names',
            key: 'assigned_to_names',
            width: 200,
            render: (names, record) => {
                const assigneeIds = record.assigned_to || [];
                const assigneeNames = names || [];
                const isCurrentUserAssignee = user && assigneeIds.includes(user.id);

                return (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                        {assigneeNames.length > 0 ? (
                            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
                                {assigneeNames.map((name, idx) => (
                                    <Tag key={idx} color="blue" style={{ margin: 0 }}>{name}</Tag>
                                ))}
                            </div>
                        ) : null}
                        <div style={{ display: 'flex', gap: '4px', marginTop: assigneeNames.length > 0 ? 4 : 0 }}>
                            {isCurrentUserAssignee ? (
                                <Button
                                    type="primary"
                                    size="small"
                                    icon={<UserAddOutlined />}
                                    onClick={() => onAddAssignee(record)}
                                    ghost
                                >
                                    İcraçı əlavə et
                                </Button>
                            ) : (
                                <Button
                                    type="primary"
                                    size="small"
                                    icon={<TeamOutlined />}
                                    onClick={() => onJoinTask(record)}
                                >
                                    İcraya qoşul
                                </Button>
                            )}
                        </div>
                    </div>
                );
            }
        },
        {
            title: 'Ünvan',
            key: 'location',
            width: 80,
            align: 'center',
            render: (_, record) => {
                const coords = record.customer_coordinates;
                const hasLocation = coords && coords.lat && coords.lng;
                return (
                    <Tooltip title={hasLocation ? 'Google Maps-da aç' : 'Koordinat yoxdur'}>
                        <EnvironmentOutlined
                            style={{
                                fontSize: 18,
                                cursor: hasLocation ? 'pointer' : 'default',
                                color: hasLocation ? '#52c41a' : '#ccc'
                            }}
                            onClick={() => {
                                if (hasLocation) {
                                    window.open(`https://www.google.com/maps?q=${coords.lat},${coords.lng}`, '_blank');
                                } else {
                                    message.info('Bu müştəri üçün koordinat qeyd olunmayıb');
                                }
                            }}
                        />
                    </Tooltip>
                );
            }
        },
        {
            title: 'Status',
            dataIndex: 'status',
            width: 125,
            key: 'status',
            render: (status) => (
                <span className={`${styles.statusBadge} ${styles[status]}`}>
                    {getStatusLabel(status)}
                </span>
            )
        },
        {
            title: 'Aktiv',
            dataIndex: 'is_active',
            key: 'is_active',
            render: (active, record) => (
                <Switch
                    checked={active}
                    onChange={(checked) => onToggleActive(record.id, checked)}
                />
            )
        },
        {
            title: 'Əməliyyat',
            key: 'action',
            width: 420,
            render: (_, record) => (
                <Space size={[6, 6]} wrap>
                    <Button type="link" size="small" onClick={() => onEdit(record)} disabled={disableActions}>Düzəliş</Button>
                    <Button type="link" size="small" onClick={() => onStatusChange(record)}>Status</Button>
                    <Button type="link" size="small" onClick={() => onQuestionnaire(record)}>Anket</Button>
                    <Button type="link" size="small" onClick={() => onProductSelect(record)}>
                        Məhsul ({record.task_products?.length || 0})
                    </Button>
                    <Button type="link" size="small" onClick={() => onDocumentAdd(record)}>
                        <FileAddOutlined /> ({record.task_documents?.length || 0})
                    </Button>
                    {(user?.is_task_writer || user?.is_admin || user?.is_super_admin) && (
                        <Popconfirm title="Silmək istədiyinizə əminsiniz?" onConfirm={() => onDelete(record.id)} disabled={disableActions}>
                            <Button type="link" size="small" danger disabled={disableActions}>Sil</Button>
                        </Popconfirm>
                    )}
                </Space>
            ),
        },
    ];

    return (
        <Table
            columns={tableColumns}
            dataSource={data}
            rowKey="id"
            loading={loading}
            scroll={{ x: 1600 }}
            pagination={pagination}
            onChange={onChange}
        />
    );
};

export default TaskTable;
