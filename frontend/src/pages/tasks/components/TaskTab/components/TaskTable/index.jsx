import React from 'react';

/** Serverdə ordering; cədvəl mövcud səhifəni yenidən qarışdırmır */
const serverSideSorter = { compare: () => 0 };
import { Table, Button, Switch, Tooltip, Popconfirm, message, Space, Tag, Input } from 'antd';
import { EnvironmentOutlined, FileAddOutlined, UserAddOutlined, TeamOutlined, CheckCircleOutlined } from '@ant-design/icons';
import { TASK_STATUSES } from '../../constants';
import { useAuth } from '../../../../../../context/AuthContext';
import styles from '../../style.module.scss';

// Helper to get status label
const getStatusLabel = (status) => {
    const found = TASK_STATUSES.find(s => s.value === status);
    return found ? found.label : status;
};

/** Siz icraçısınız, təxirə salınıb və tarix qeyd olunub — cizgi + ID-də ! */
const isPendingRescheduledHighlight = (record, user) => {
    const assigneeIds = record.assigned_to || [];
    const isAssignee = user && assigneeIds.includes(user.id);
    const st = record.status;
    return Boolean(isAssignee && st === 'pending' && record.rescheduled_date);
};

const getIconUrl = (iconPath) => {
    if (!iconPath) return null;
    if (iconPath.startsWith('http')) return iconPath;
    const cleanPath = iconPath.startsWith('/') ? iconPath.substring(1) : iconPath;
    const isProduction = window.location.hostname === 'new.digitask.digigroup.az' ||
        window.location.hostname === 'digitask.digigroup.az' ||
        window.location.hostname === 'app.digitask.digigroup.az';
    const baseUrl = isProduction ? 'https://app.digitask.digigroup.az' : 'http://127.0.0.1:8000';
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
    onMarkExternalArchived,
    pagination,
    onChange,
    tableOrdering = null,
    columnIdSearch = '',
    columnRegisterSearch = '',
    onColumnIdInputChange,
    onColumnIdFilterClear,
    onColumnIdFilterFlush,
    onColumnRegisterInputChange,
    onColumnRegisterFilterClear,
    onColumnRegisterFilterFlush,
    disableEdit = false,
    disableDelete = false,
    disableStatus = false,
    disableQuestionnaire = false,
    disableProducts = false,
    disableDocuments = false,
    disableAssigneeManage = false,
    disableJoinTask = false,
    disableActiveToggle = false,
}) => {
    const { user } = useAuth();

    const idSortOrder =
        tableOrdering === 'id' ? 'ascend' : tableOrdering === '-id' ? 'descend' : null;
    const registerSortOrder =
        tableOrdering === 'register_number'
            ? 'ascend'
            : tableOrdering === '-register_number'
              ? 'descend'
              : null;

    const tableColumns = [
        {
            title: 'ID',
            dataIndex: 'id',
            key: 'id',
            width: 87,
            sorter: serverSideSorter,
            sortOrder: idSortOrder,
            sortDirections: ['ascend', 'descend'],
            showSorterTooltip: false,
            filteredValue: columnIdSearch ? [columnIdSearch] : null,
            filterDropdown: ({ setSelectedKeys, selectedKeys, confirm, clearFilters }) => (
                <div style={{ padding: 8 }} onKeyDown={(e) => e.stopPropagation()}>
                    <Input
                        placeholder="ID (məs. 140) — avtomatik sorğu"
                        value={selectedKeys[0] ?? ''}
                        allowClear
                        onChange={(e) => {
                            const v = e.target.value;
                            setSelectedKeys(v ? [v] : []);
                            onColumnIdInputChange?.(v);
                        }}
                        onPressEnter={(e) => {
                            const v = e.currentTarget.value;
                            setSelectedKeys(v ? [v] : []);
                            confirm();
                            onColumnIdFilterFlush?.(v);
                        }}
                        style={{ marginBottom: 8, display: 'block' }}
                    />
                    <Space>
                        <Button
                            type="primary"
                            onClick={() => {
                                confirm();
                                onColumnIdFilterFlush?.(selectedKeys[0] ?? '');
                            }}
                            size="small"
                        >
                            İndi axtar
                        </Button>
                        <Button
                            onClick={() => {
                                setSelectedKeys([]);
                                clearFilters?.();
                                confirm();
                                onColumnIdFilterClear?.('');
                            }}
                            size="small"
                        >
                            Sıfırla
                        </Button>
                    </Space>
                </div>
            ),
            render: (id, record) => {
                const mark = isPendingRescheduledHighlight(record, user);
                return (
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, whiteSpace: 'nowrap' }}>
                        {mark && (
                            <span
                                style={{ color: '#f5222d', fontWeight: 700, lineHeight: 1 }}
                                title="Təxirə salınıb"
                            >
                                !
                            </span>
                        )}
                        <span>{id}</span>
                    </span>
                );
            }
        },
        {
            title: 'Başlıq',
            dataIndex: 'title',
            key: 'title',
            width: 220,
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
        { title: 'Müştəri', dataIndex: 'customer_name', key: 'customer_name', width: 200 },
        { title: 'Əlaqə No', dataIndex: 'customer_phone', key: 'customer_phone', width: 150 },
        {
            title: 'Qeydiyyat No',
            dataIndex: 'customer_register_number',
            key: 'customer_register_number',
            width: 170,
            sorter: serverSideSorter,
            sortOrder: registerSortOrder,
            sortDirections: ['ascend', 'descend'],
            showSorterTooltip: false,
            filteredValue: columnRegisterSearch ? [columnRegisterSearch] : null,
            filterDropdown: ({ setSelectedKeys, selectedKeys, confirm, clearFilters }) => (
                <div style={{ padding: 8 }} onKeyDown={(e) => e.stopPropagation()}>
                    <Input
                        placeholder="Qeydiyyat № — avtomatik sorğu"
                        value={selectedKeys[0] ?? ''}
                        allowClear
                        onChange={(e) => {
                            const v = e.target.value;
                            setSelectedKeys(v ? [v] : []);
                            onColumnRegisterInputChange?.(v);
                        }}
                        onPressEnter={(e) => {
                            const v = e.currentTarget.value;
                            setSelectedKeys(v ? [v] : []);
                            confirm();
                            onColumnRegisterFilterFlush?.(v);
                        }}
                        style={{ marginBottom: 8, display: 'block' }}
                    />
                    <Space>
                        <Button
                            type="primary"
                            onClick={() => {
                                confirm();
                                onColumnRegisterFilterFlush?.(selectedKeys[0] ?? '');
                            }}
                            size="small"
                        >
                            İndi axtar
                        </Button>
                        <Button
                            onClick={() => {
                                setSelectedKeys([]);
                                clearFilters?.();
                                confirm();
                                onColumnRegisterFilterClear?.('');
                            }}
                            size="small"
                        >
                            Sıfırla
                        </Button>
                    </Space>
                </div>
            ),
        },
        { title: 'Qrup', dataIndex: 'group_name', key: 'group_name', width: 150 },
        {
            title: 'Servislər',
            dataIndex: 'services',
            key: 'services',
            width: 190,
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
                const isDone = record.status === 'done';

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
                                    disabled={isDone || disableAssigneeManage}
                                >
                                    İcraçı əlavə et
                                </Button>
                            ) : (
                                <Button
                                    type="primary"
                                    size="small"
                                    icon={<TeamOutlined />}
                                    onClick={() => onJoinTask(record)}
                                    disabled={isDone || disableJoinTask}
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
            render: (status, record) => (
                <div>
                    <span className={`${styles.statusBadge} ${styles[status] || ''}`}>
                        {getStatusLabel(status)}
                    </span>
                    {status === 'pending' && record.rescheduled_date && (
                        <div style={{ marginTop: 4, fontSize: 11, color: '#cf1322', lineHeight: 1.35 }}>
                            {record.rescheduled_date} tarixinə qədər təxirə salınıb
                            {record.pending_note ? <div>Qeyd: {record.pending_note}</div> : null}
                        </div>
                    )}
                </div>
            )
        },
        {
            title: 'Aktiv',
            dataIndex: 'is_active',
            key: 'is_active',
            width: 90,
            render: (active, record) => (
                <Switch
                    checked={active}
                    onChange={(checked) => onToggleActive(record.id, checked)}
                    disabled={disableActiveToggle}
                />
            )
        },
        {
            title: 'Əməliyyat',
            key: 'action',
            width: 420,
            render: (_, record) => (
                <Space size={[6, 6]} wrap>
                    <Button type="link" size="small" onClick={() => onEdit(record)} disabled={disableEdit}>Düzəliş</Button>
                    <Button type="link" size="small" onClick={() => onStatusChange(record)} disabled={disableStatus}>Status</Button>
                    <Button type="link" size="small" onClick={() => onQuestionnaire(record)} disabled={disableQuestionnaire}>Anket</Button>
                    <Button type="link" size="small" onClick={() => onProductSelect(record)} disabled={disableProducts}>
                        Məhsul ({record.task_products?.length || 0})
                    </Button>
                    <Button type="link" size="small" onClick={() => onDocumentAdd(record)} disabled={disableDocuments}>
                        <FileAddOutlined /> ({record.task_documents?.length || 0})
                    </Button>
                    <Button
                        type={record.is_externally_archived ? 'default' : 'link'}
                        size="small"
                        icon={<CheckCircleOutlined />}
                        onClick={() => onMarkExternalArchived?.(record)}
                        disabled={disableEdit || record.is_externally_archived}
                    >
                        {record.is_externally_archived ? 'Arxivləşdirmə tamamlanıb' : 'Arxivləşdirməni tamamla'}
                    </Button>
                    {!disableDelete && (
                        <Popconfirm title="Silmək istədiyinizə əminsiniz?" onConfirm={() => onDelete(record.id)}>
                            <Button type="link" size="small" danger>Sil</Button>
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
            scroll={{ x: 2115 }}
            pagination={pagination}
            onChange={(pag, filters, sorter, extra) => onChange?.(pag, filters, sorter, extra)}
        />
    );
};

export default TaskTable;
