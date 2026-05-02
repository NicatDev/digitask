import React from 'react';

/** Serverdə ordering; cədvəl mövcud səhifəni yenidən qarışdırmır */
const serverSideSorter = { compare: () => 0 };
import { Table, Button, Switch, Tooltip, Popconfirm, message, Space, Tag, Input } from 'antd';
import {
    EnvironmentOutlined,
    FileAddOutlined,
    UserAddOutlined,
    TeamOutlined,
    CheckCircleOutlined,
    EditOutlined,
    SyncOutlined,
    FormOutlined,
    ShoppingOutlined,
    DeleteOutlined,
} from '@ant-design/icons';
import dayjs from 'dayjs';
import { TASK_STATUSES } from '../../constants';
import { useAuth } from '../../../../../../context/AuthContext';
import { defaultColumnVisibility, sumVisibleTableWidth, TASK_TABLE_COLUMN_WIDTHS as W } from '../../taskTableColumnPrefs';
import styles from '../../style.module.scss';

// Helper to get status label
const getStatusLabel = (status) => {
    const found = TASK_STATUSES.find(s => s.value === status);
    return found ? found.label : status;
};

const AZ_MONTHS = [
    'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
    'iyul', 'avqust', 'sentyabr', 'oktyabr', 'noyabr', 'dekabr',
];

/** İl üçün sıra şəkilçisi: 2023-cü, 2025-ci il və s. */
const azYearSuffix = (year) => {
    const d = year % 10;
    const map = { 0: 'cu', 1: 'ci', 2: 'ci', 3: 'cü', 4: 'cü', 5: 'ci', 6: 'cı', 7: 'ci', 8: 'ci', 9: 'cu' };
    return map[d] ?? 'cü';
};

const formatAzDateTime = (v) => {
    const d = dayjs(v);
    if (!v || !d.isValid()) return '—';
    const day = d.date();
    const mon = AZ_MONTHS[d.month()];
    const y = d.year();
    return `${day} ${mon} ${y}-${azYearSuffix(y)} il, ${d.format('HH:mm')}`;
};

const formatAzDate = (v) => {
    const d = dayjs(v);
    if (!v || !d.isValid()) return '—';
    const day = d.date();
    const mon = AZ_MONTHS[d.month()];
    const y = d.year();
    return `${day} ${mon} ${y}-${azYearSuffix(y)} il`;
};

const ACTION_ROW_COLS = 3;

/** Əməliyyat düymələrini sətirlərə bölür (sətirdə ən çox ACTION_ROW_COLS). */
const chunkActionRows = (items, cols = ACTION_ROW_COLS) => {
    const rows = [];
    for (let i = 0; i < items.length; i += cols) {
        rows.push(items.slice(i, i + cols));
    }
    return rows;
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
    canForTask,
    columnVisibility = defaultColumnVisibility(),
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

    const isTaskColVisible = (key) => key === 'action' || columnVisibility[key] !== false;

    const tableColumns = [
        {
            title: 'ID',
            dataIndex: 'id',
            key: 'id',
            width: W.id,
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
            width: W.title,
            render: (text, record) => (
                <a onClick={() => onViewDetail(record)}>{text}</a>
            )
        },
        {
            title: 'Növ',
            dataIndex: 'task_type_details',
            key: 'task_type',
            width: W.task_type,
            render: (type, record) => type ? (
                <span style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '5px',
                    backgroundColor: type.color,
                    padding: '3px 10px',
                    borderRadius: '5px',
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
        { title: 'Müştəri', dataIndex: 'customer_name', key: 'customer_name', width: W.customer_name },
        { title: 'Əlaqə No', dataIndex: 'customer_phone', key: 'customer_phone', width: W.customer_phone },
        {
            title: 'Qeydiyyat No',
            dataIndex: 'customer_register_number',
            key: 'customer_register_number',
            width: W.customer_register_number,
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
        { title: 'Qrup', dataIndex: 'group_name', key: 'group_name', width: W.group_name },
        {
            title: 'Servislər',
            dataIndex: 'services',
            key: 'services',
            width: W.services,
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
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '3px' }}>
                        {taskServices.map((svc, idx) => (
                            <span
                                key={svc.id}
                                style={{
                                    background: colors[idx % colors.length].bg,
                                    color: colors[idx % colors.length].text,
                                    padding: '1px 7px',
                                    borderRadius: '3px',
                                    fontSize: '11px',
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
            width: W.assigned_to_names,
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
                                    disabled={isDone || disableAssigneeManage || !canForTask?.('manage_assignees', record)}
                                >
                                    İcraçı əlavə et
                                </Button>
                            ) : (
                                <Button
                                    type="primary"
                                    size="small"
                                    icon={<TeamOutlined />}
                                    onClick={() => onJoinTask(record)}
                                    disabled={isDone || disableJoinTask || !canForTask?.('join_task', record)}
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
            width: W.location,
            align: 'center',
            render: (_, record) => {
                const coords = record.customer_coordinates;
                const hasLocation = coords && coords.lat && coords.lng;
                return (
                    <Tooltip title={hasLocation ? 'Google Maps-da aç' : 'Koordinat yoxdur'}>
                        <EnvironmentOutlined
                            style={{
                                fontSize: 16,
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
            width: W.status,
            key: 'status',
            render: (status, record) => (
                <div>
                    <span className={`${styles.statusBadge} ${styles[status] || ''}`}>
                        {getStatusLabel(status)}
                    </span>
                    {status === 'pending' && record.rescheduled_date && (
                        <div style={{ marginTop: 3, fontSize: 10, color: '#cf1322', lineHeight: 1.35 }}>
                            {record.rescheduled_date} tarixinə qədər təxirə salınıb
                            {record.pending_note ? <div>Qeyd: {record.pending_note}</div> : null}
                        </div>
                    )}
                </div>
            )
        },
        {
            title: 'Yaradılıb',
            dataIndex: 'created_at',
            key: 'created_at',
            width: W.created_at,
            render: (v) => formatAzDateTime(v),
        },
        // {
        //     title: 'Yenilənib',
        //     dataIndex: 'updated_at',
        //     key: 'updated_at',
        //     width: 168,
        //     render: (v) => formatAzDateTime(v),
        // },
        {
            title: 'Təxirə tarixi',
            dataIndex: 'rescheduled_date',
            key: 'rescheduled_date',
            width: W.rescheduled_date,
            render: (v) => formatAzDate(v),
        },
        {
            title: 'Aktiv',
            dataIndex: 'is_active',
            key: 'is_active',
            width: W.is_active,
            render: (active, record) => (
                <Switch
                    checked={active}
                    onChange={(checked) => onToggleActive(record.id, checked)}
                    disabled={disableActiveToggle || !canForTask?.('toggle_active', record)}
                />
            )
        },
        {
            title: 'Əməliyyat',
            key: 'action',
            width: W.action,
            render: (_, record) => {
                const btnStyle = { height: 'auto', fontSize: 11, padding: '4px 7px', lineHeight: 1.3 };
                const cells = [
                    <Button
                        key="edit"
                        type="primary"
                        size="small"
                        block
                        icon={<EditOutlined />}
                        style={btnStyle}
                        onClick={() => onEdit(record)}
                        disabled={disableEdit || !canForTask?.('edit_general', record)}
                    >
                        Düzəliş
                    </Button>,
                    <Button
                        key="status"
                        type="primary"
                        size="small"
                        block
                        icon={<SyncOutlined />}
                        style={btnStyle}
                        onClick={() => onStatusChange(record)}
                        disabled={disableStatus || !canForTask?.('change_status', record)}
                    >
                        Status
                    </Button>,
                    <Button
                        key="q"
                        type="primary"
                        size="small"
                        block
                        icon={<FormOutlined />}
                        style={btnStyle}
                        onClick={() => onQuestionnaire(record)}
                        disabled={disableQuestionnaire || !canForTask?.('manage_surveys', record)}
                    >
                        Anket
                    </Button>,
                    <Button
                        key="prod"
                        type="primary"
                        size="small"
                        block
                        icon={<ShoppingOutlined />}
                        style={btnStyle}
                        onClick={() => onProductSelect(record)}
                        disabled={disableProducts || !canForTask?.('manage_products', record)}
                    >
                        Məhsul ({record.task_products?.length || 0})
                    </Button>,
                    <Button
                        key="doc"
                        type="primary"
                        size="small"
                        block
                        icon={<FileAddOutlined />}
                        style={btnStyle}
                        onClick={() => onDocumentAdd(record)}
                        disabled={disableDocuments || !canForTask?.('manage_documents', record)}
                    >
                        Sənəd ({record.task_documents?.length || 0})
                    </Button>,
                    record.is_externally_archived ? (
                        <Button
                            key="arch"
                            type="primary"
                            size="small"
                            block
                            icon={<CheckCircleOutlined />}
                            style={{ ...btnStyle, opacity: 0.85 }}
                            disabled
                        >
                            Arxivdədir
                        </Button>
                    ) : (
                        <Button
                            key="arch"
                            type="primary"
                            size="small"
                            block
                            icon={<CheckCircleOutlined />}
                            style={btnStyle}
                            onClick={() => onMarkExternalArchived?.(record)}
                            disabled={!canForTask?.('mark_external_archived', record)}
                        >
                            Arxivə köçür
                        </Button>
                    ),
                    ...(!disableDelete
                        ? [
                              <Popconfirm
                                  key="del"
                                  title="Silmək istədiyinizə əminsiniz?"
                                  onConfirm={() => onDelete(record.id)}
                              >
                                  <Button type="primary" danger size="small" block icon={<DeleteOutlined />} style={btnStyle}>
                                      Sil
                                  </Button>
                              </Popconfirm>,
                          ]
                        : []),
                ];
                const rows = chunkActionRows(cells);
                return (
                    <div
                        style={{
                            border: '1px solid #f0f0f0',
                            borderRadius: 8,
                            background: '#fff',
                            overflow: 'hidden',
                        }}
                    >
                        {rows.map((row, idx) => (
                            <div
                                key={idx}
                                style={{
                                    display: 'grid',
                                    gridTemplateColumns: `repeat(${ACTION_ROW_COLS}, minmax(0, 1fr))`,
                                    columnGap: 6,
                                    rowGap: 6,
                                    padding: '6px 8px',
                                    borderBottom: idx < rows.length - 1 ? '1px solid #e8e8e8' : 'none',
                                    alignItems: 'stretch',
                                }}
                            >
                                {row.map((cell, j) => (
                                    <div key={j} style={{ minWidth: 0 }}>
                                        {cell}
                                    </div>
                                ))}
                            </div>
                        ))}
                    </div>
                );
            },
        },
    ];

    const visibleColumns = tableColumns.filter((col) => isTaskColVisible(col.key));

    return (
        <Table
            className={styles.taskTableCompact}
            columns={visibleColumns}
            dataSource={data}
            rowKey="id"
            loading={loading}
            scroll={{ x: sumVisibleTableWidth(columnVisibility) }}
            pagination={pagination}
            onChange={(pag, filters, sorter, extra) => onChange?.(pag, filters, sorter, extra)}
        />
    );
};

export default TaskTable;
