import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Switch, Row, Col, Select, Grid, Collapse } from 'antd';
import { FilterOutlined } from '@ant-design/icons';
import styles from './style.module.scss';
import { getRoles, createRole, updateRole, deleteRole, updateRoleStatus } from '../../../../axios/api/account';
import { handleApiError } from '../../../../utils/errorHandler';

const TASK_GLOBAL_PERMISSION_GROUPS = [
    {
        title: 'Giriş və görünüş',
        options: [
            { key: 'view_module', label: 'Task modulu görünüşü' },
            { key: 'create', label: 'Tapşırıq yarat' },
        ],
    },
];

const TASK_STATUS_PERMISSION_GROUPS = [
    {
        title: 'Yaratma və redaktə',
        options: [
            { key: 'edit_general', label: 'Ümumi düzəliş' },
            { key: 'delete', label: 'Tapşırıq sil' },
            { key: 'toggle_active', label: 'Aktiv/deaktiv dəyiş' },
            { key: 'edit_customer_address', label: 'Müştəri ünvanı redaktə et' },
        ],
    },
    {
        title: 'İcra və əməliyyatlar',
        options: [
            { key: 'change_status', label: 'Status dəyiş' },
            { key: 'manage_products', label: 'Məhsul idarə et' },
            { key: 'manage_documents', label: 'Sənəd idarə et' },
            { key: 'manage_surveys', label: 'Anket idarə et' },
            { key: 'manage_assignees', label: 'İcraçı idarə et' },
            { key: 'join_task', label: 'İcraya qoşul' },
            { key: 'comment_activity', label: 'Activity şərh yaz' },
            { key: 'mark_external_archived', label: 'Məlumatlar əlaqəli platformalara köçürüldü' },
        ],
    },
];
const TASK_PERMISSION_KEYS = [...TASK_GLOBAL_PERMISSION_GROUPS, ...TASK_STATUS_PERMISSION_GROUPS].flatMap((g) => g.options.map((o) => o.key));
const TASK_STATUS_ACTION_KEYS = TASK_STATUS_PERMISSION_GROUPS.flatMap((g) => g.options.map((o) => o.key));

const TASK_STATUS_OPTIONS = [
    { value: 'todo', label: 'Gözləyir' },
    { value: 'in_progress', label: 'İcrada' },
    { value: 'pending', label: 'Təxirə salınıb' },
    { value: 'done', label: 'Tamamlandı' },
    { value: 'rejected', label: 'Rədd edildi' },
];
const TASK_SCOPE_OPTIONS = [
    { value: 'mine', label: 'Yalnız öz task-ları' },
    { value: 'group', label: 'Yalnız eyni qrup' },
    { value: 'all', label: 'Hamısı' },
];

const ROLE_PERMISSION_GROUPS = [
    {
        title: 'Tapşırıq modulu',
        children: (
            <>
                {TASK_GLOBAL_PERMISSION_GROUPS.map((group) => (
                    <React.Fragment key={group.title}>
                        <Col span={24}>
                            <div style={{ fontWeight: 600, marginBottom: 6 }}>{group.title}</div>
                        </Col>
                        {group.options.map((opt) => (
                            <Col span={12} key={opt.key}>
                                <Form.Item name={['task_permissions', opt.key]} label={opt.label} valuePropName="checked">
                                    <Switch />
                                </Form.Item>
                            </Col>
                        ))}
                    </React.Fragment>
                ))}
                <Col span={24}>
                    <Form.Item noStyle shouldUpdate>
                        {({ getFieldValue }) => {
                            const enabledMap = getFieldValue(['task_status_enabled']) || {};
                            return (
                                <Collapse
                                    size="small"
                                    items={TASK_STATUS_OPTIONS.map((status) => ({
                                        key: status.value,
                                        label: (
                                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                                <span>{status.label} üçün icazələr</span>
                                                <Form.Item name={['task_status_enabled', status.value]} valuePropName="checked" noStyle>
                                                    <Switch onClick={(_, e) => e?.stopPropagation?.()} />
                                                </Form.Item>
                                            </div>
                                        ),
                                        children: (
                                            <Row gutter={12}>
                                                <Col span={24}>
                                                    <Form.Item name={['task_status_scope', status.value]} label="Kim görə bilər?">
                                                        <Select options={TASK_SCOPE_OPTIONS} disabled={enabledMap[status.value] !== true} />
                                                    </Form.Item>
                                                </Col>
                                                {TASK_STATUS_PERMISSION_GROUPS.map((permGroup) => (
                                                    <React.Fragment key={`${status.value}-${permGroup.title}`}>
                                                        <Col span={24}>
                                                            <div style={{ fontWeight: 600, marginBottom: 6 }}>{permGroup.title}</div>
                                                        </Col>
                                                        {permGroup.options.map((opt) => (
                                                            <Col span={12} key={`${status.value}-${opt.key}`}>
                                                                <Form.Item
                                                                    name={['task_status_permissions', status.value, opt.key]}
                                                                    label={opt.label}
                                                                    valuePropName="checked"
                                                                >
                                                                    <Switch disabled={enabledMap[status.value] !== true} />
                                                                </Form.Item>
                                                            </Col>
                                                        ))}
                                                    </React.Fragment>
                                                ))}
                                            </Row>
                                        ),
                                    }))}
                                />
                            );
                        }}
                    </Form.Item>
                </Col>
            </>
        ),
    },
    {
        title: 'Anbar modulu',
        children: (
            <>
                <Col span={12}>
                    <Form.Item name="is_warehouse_reader" label="Anbar (Oxumaq)" valuePropName="checked">
                        <Switch />
                    </Form.Item>
                </Col>
                <Col span={12}>
                    <Form.Item name="is_warehouse_writer" label="Anbar (Yazmaq)" valuePropName="checked">
                        <Switch />
                    </Form.Item>
                </Col>
            </>
        ),
    },
    {
        title: 'Sənəd modulu',
        children: (
            <>
                <Col span={12}>
                    <Form.Item name="is_document_reader" label="Sənəd (Oxumaq)" valuePropName="checked">
                        <Switch />
                    </Form.Item>
                </Col>
                <Col span={12}>
                    <Form.Item name="is_document_writer" label="Sənəd (Yazmaq)" valuePropName="checked">
                        <Switch />
                    </Form.Item>
                </Col>
            </>
        ),
    },
    {
        title: 'İdarəetmə',
        children: (
            <>
                <Col span={12}>
                    <Form.Item name="is_admin" label="Admin" valuePropName="checked">
                        <Switch />
                    </Form.Item>
                </Col>
                <Col span={12}>
                    <Form.Item name="is_super_admin" label="Super Admin" valuePropName="checked">
                        <Switch />
                    </Form.Item>
                </Col>
            </>
        ),
    },
];

const RoleTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [loading, setLoading] = useState(false);

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [statusFilter, setStatusFilter] = useState('all');
    const [showFilters, setShowFilters] = useState(false);
    const screens = Grid.useBreakpoint();

    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [form] = Form.useForm();

    // Debounce Search
    useEffect(() => {
        const timer = setTimeout(() => {
            setDebouncedSearchText(searchText);
        }, 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    const fetchData = async () => {
        setLoading(true);
        try {
            const response = await getRoles();
            setData(response.data);
        } catch (error) {
            console.error(error);
            handleApiError(error, 'Məlumatları yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        if (isActive) {
            fetchData();
        }
    }, [isActive]);

    const handleDelete = async (id) => {
        try {
            await deleteRole(id);
            message.success('Rol silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    const onFinish = async () => {
        try {
            const values = form.getFieldsValue(true);
            const rawTaskPermissions = values.task_permissions || {};
            const existingStatusScopes = editingItem?.task_status_visibility?.status_scopes || {};
            const existingStatusPermissions = editingItem?.task_status_permissions || {};
            const taskPermissions = Object.fromEntries(
                TASK_PERMISSION_KEYS.map((key) => [key, rawTaskPermissions[key] === true])
            );
            const payload = {
                ...values,
                task_permissions: taskPermissions,
                task_status_visibility: {
                    visible_statuses: TASK_STATUS_OPTIONS.filter((status) => values?.task_status_enabled?.[status.value] === true).map((status) => status.value),
                    status_scopes: Object.fromEntries(
                        TASK_STATUS_OPTIONS.map((status) => [
                            status.value,
                            values?.task_status_scope?.[status.value] ||
                                existingStatusScopes?.[status.value] ||
                                'mine',
                        ])
                    ),
                },
                task_status_permissions: Object.fromEntries(
                    TASK_STATUS_OPTIONS.map((status) => {
                        const row = values?.task_status_permissions?.[status.value] ||
                            existingStatusPermissions?.[status.value] ||
                            {};
                        return [
                            status.value,
                            Object.fromEntries(
                                TASK_STATUS_ACTION_KEYS.map((actionKey) => [actionKey, row[actionKey] === true])
                            ),
                        ];
                    })
                ),
                // Backward-compatible flags (derived from dynamic permissions)
                is_task_reader: Boolean(
                    taskPermissions.view_module ||
                    taskPermissions.change_status ||
                    taskPermissions.manage_products ||
                    taskPermissions.manage_documents ||
                    taskPermissions.manage_surveys ||
                    taskPermissions.join_task ||
                    taskPermissions.comment_activity
                ),
                is_task_writer: Boolean(
                    taskPermissions.create ||
                    taskPermissions.edit_general ||
                    taskPermissions.delete ||
                    taskPermissions.toggle_active ||
                    taskPermissions.manage_assignees ||
                    taskPermissions.edit_customer_address
                ),
                is_task_view_all: false,
            };

            if (editingItem) {
                await updateRole(editingItem.id, payload);
                message.success('Rol yeniləndi');
            } else {
                await createRole(payload);
                message.success('Rol yaradıldı');
            }
            await fetchData();
            setIsModalOpen(false);
            form.resetFields();
            setEditingItem(null);
        } catch (error) {
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        }
    };

    const handleStatusChange = async (id, checked) => {
        try {
            await updateRoleStatus(id, checked);
            message.success('Status yeniləndi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const getFilteredData = () => {
        return data.filter(item => {
            const lowerSearch = debouncedSearchText.toLowerCase();
            const matchesSearch = item.name.toLowerCase().includes(lowerSearch);
            const matchesStatus = statusFilter !== 'all' ? item.is_active === statusFilter : true;
            return matchesSearch && matchesStatus;
        });
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id' },
        { title: 'Ad', dataIndex: 'name', key: 'name' },
        { title: 'Təsvir', dataIndex: 'description', key: 'description' },
        {
            title: 'Aktiv',
            dataIndex: 'is_active',
            key: 'is_active',
            render: (active, record) => (
                <Switch
                    checked={active}
                    onChange={(checked) => handleStatusChange(record.id, checked)}
                />
            )
        },
        {
            title: 'Əməliyyat',
            key: 'action',
            render: (_, record) => (
                <>
                    <Button type="link" onClick={() => {
                        setEditingItem(record);
                        form.setFieldsValue({
                            ...record,
                            task_permissions: record.task_permissions || {},
                            task_status_visibility: record.task_status_visibility || {
                                visible_statuses: [],
                            },
                            task_status_enabled: Object.fromEntries(
                                TASK_STATUS_OPTIONS.map((status) => [
                                    status.value,
                                    (record.task_status_visibility?.visible_statuses || []).includes(status.value),
                                ])
                            ),
                            task_status_scope: Object.fromEntries(
                                TASK_STATUS_OPTIONS.map((status) => [
                                    status.value,
                                    record.task_status_visibility?.status_scopes?.[status.value] || 'mine',
                                ])
                            ),
                            task_status_permissions: record.task_status_permissions || {},
                        });
                        setIsModalOpen(true);
                    }}>Düzəliş</Button>
                    <Popconfirm title="Silmək istədiyinizə əminsiniz?" onConfirm={() => handleDelete(record.id)}>
                        <Button type="link" danger>Sil</Button>
                    </Popconfirm>
                </>
            ),
        },
    ];

    return (
        <div>
            <div style={{ marginBottom: 16, background: '#fff', padding: '16px', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div style={{
                    display: 'flex',
                    flexDirection: screens.md ? 'row' : 'column',
                    justifyContent: 'space-between',
                    alignItems: screens.md ? 'center' : 'stretch',
                    gap: '8px'
                }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', width: screens.md ? 'auto' : '100%' }}>
                        <Input.Search
                            placeholder="Axtar (Ad)..."
                            onChange={(e) => setSearchText(e.target.value)}
                            style={{ width: screens.md ? 250 : '100%' }}
                        />
                        {/* Mobile Filter Toggle */}
                        {!screens.md && (
                            <Button
                                icon={<FilterOutlined />}
                                onClick={() => setShowFilters(!showFilters)}
                            />
                        )}
                    </div>

                    <div style={{
                        display: 'flex',
                        flexDirection: screens.md ? 'row' : 'column',
                        gap: '8px',
                        flexWrap: 'wrap',
                        alignItems: screens.md ? 'center' : 'stretch',
                        width: screens.md ? 'auto' : '100%'
                    }}>
                        {/* Filters Conditionally Hidden on Mobile */}
                        {(screens.md || showFilters) && (
                            <>
                                <Select
                                    placeholder="Status"
                                    style={{ width: screens.md ? 150 : '100%' }}
                                    allowClear
                                    value={statusFilter}
                                    onChange={setStatusFilter}
                                >
                                    <Select.Option value="all">Hamısı</Select.Option>
                                    <Select.Option value={true}>Aktiv</Select.Option>
                                    <Select.Option value={false}>Deaktiv</Select.Option>
                                </Select>
                            </>
                        )}
                        <Button type="primary" block={!screens.md} onClick={() => {
                            setEditingItem(null);
                            form.resetFields();
                            form.setFieldsValue({
                                task_permissions: {
                                    view_module: false,
                                    create: false,
                                    edit_general: false,
                                    delete: false,
                                    change_status: false,
                                    manage_products: false,
                                    manage_documents: false,
                                    manage_surveys: false,
                                    manage_assignees: false,
                                    join_task: false,
                                    toggle_active: false,
                                    comment_activity: false,
                                    edit_customer_address: false,
                                    mark_external_archived: false,
                                },
                                task_status_visibility: {
                                    visible_statuses: [],
                                },
                                task_status_enabled: Object.fromEntries(
                                    TASK_STATUS_OPTIONS.map((status) => [status.value, false])
                                ),
                                task_status_scope: Object.fromEntries(
                                    TASK_STATUS_OPTIONS.map((status) => [status.value, 'mine'])
                                ),
                                task_status_permissions: {},
                            });
                            setIsModalOpen(true);
                        }}>
                            Yeni Rol
                        </Button>
                    </div>
                </div>
            </div>

            <Table
                columns={columns}
                dataSource={getFilteredData()}
                rowKey="id"
                loading={loading}
                scroll={{ x: 800 }}
                pagination={{ pageSize: 10 }}
            />

            <Modal
                title={editingItem ? "Rolu Düzəlt" : "Yeni Rol"}
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                footer={null}
                width={600}
                className={styles.responsiveModal}
            >
                <Form form={form} onFinish={onFinish} layout="vertical">
                    <Form.Item name="name" label="Ad" rules={[{ required: true }]}>
                        <Input />
                    </Form.Item>
                    <Form.Item name="description" label="Təsvir">
                        <Input.TextArea />
                    </Form.Item>
                    <Collapse
                        defaultActiveKey={['Tapşırıq modulu']}
                        items={ROLE_PERMISSION_GROUPS.map((group) => ({
                            key: group.title,
                            label: <span style={{ fontWeight: 700 }}>{group.title}</span>,
                            children: <Row gutter={16}>{group.children}</Row>,
                        }))}
                    />

                    <Button type="primary" htmlType="submit" block style={{ marginTop: 16 }}>
                        Təsdiqlə
                    </Button>
                </Form>
            </Modal>
        </div>
    );
};

export default RoleTab;
