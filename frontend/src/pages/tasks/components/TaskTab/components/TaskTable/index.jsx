import React from 'react';
import { Table, Button, Switch, Tooltip, Popconfirm, message } from 'antd';
import { EnvironmentOutlined } from '@ant-design/icons';
import { TASK_STATUSES } from '../../constants';
import styles from '../../style.module.scss'; // Assuming we keep style.module.scss in TaskTab root or move it

// Helper to get status label
const getStatusLabel = (status) => {
    const found = TASK_STATUSES.find(s => s.value === status);
    return found ? found.label : status;
};

const getIconUrl = (iconPath) => {
    if (!iconPath) return null;
    if (iconPath.startsWith('http')) return iconPath;
    const cleanPath = iconPath.startsWith('/') ? iconPath.substring(1) : iconPath;
    return `http://127.0.0.1:8000/${cleanPath}`;
};

const TaskTable = ({
    data,
    loading,
    services, // List of {id, name, icon}
    onEdit,
    onStatusChange, // (record) => open modal
    onToggleActive, // (id, checked)
    onQuestionnaire,
    onDelete,
    onAccept,
    onViewLocation
}) => {

    const tableColumns = [
        { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        { title: 'Başlıq', dataIndex: 'title', key: 'title' },
        { title: 'Müştəri', dataIndex: 'customer_name', key: 'customer_name' },
        { title: 'Qrup', dataIndex: 'group_name', key: 'group_name' },
        {
            title: 'Servislər',
            dataIndex: 'services',
            key: 'services',
            render: (serviceIds, record) => {
                // Soft pastel colors with dark text
                const colors = [
                    { bg: '#e6f7ff', text: '#0958d9' },  // Light blue
                    { bg: '#f6ffed', text: '#389e0d' },  // Light green
                    { bg: '#fff7e6', text: '#d46b08' },  // Light orange
                    { bg: '#fff1f0', text: '#cf1322' },  // Light red
                    { bg: '#f9f0ff', text: '#531dab' },  // Light purple
                    { bg: '#e6fffb', text: '#08979c' },  // Light cyan
                    { bg: '#fff0f6', text: '#c41d7f' },  // Light pink
                ];

                // Get service objects from IDs
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
            title: 'Təyin edilib',
            dataIndex: 'assigned_to_name',
            key: 'assigned_to_name',
            render: (name, record) => name || (
                <Button
                    type="link"
                    size="small"
                    onClick={() => onAccept(record)}
                >
                    Qəbul et
                </Button>
            )
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
            render: (_, record) => (
                <>
                    <Button type="link" onClick={() => onEdit(record)}>Düzəliş et</Button>
                    <Button type="link" onClick={() => onStatusChange(record)}>Statusu dəyiş</Button>
                    <Button type="link" onClick={() => onQuestionnaire(record)}>
                        {record.task_services && record.task_services.length > 0 ? "Anketə bax" : "Anket doldur"}
                    </Button>
                    <Popconfirm title="Silmək istədiyinizə əminsiniz?" onConfirm={() => onDelete(record.id)}>
                        <Button type="link" danger>Sil</Button>
                    </Popconfirm>
                </>
            ),
        },
    ];

    return (
        <Table
            columns={tableColumns}
            dataSource={data}
            rowKey="id"
            loading={loading}
            scroll={{ x: 1000 }}
            pagination={{ pageSize: 10 }}
        />
    );
};

export default TaskTable;
