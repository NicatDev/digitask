import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, Form, Input, InputNumber, message, Popconfirm, Switch, Select, Grid } from 'antd';
import { FilterOutlined } from '@ant-design/icons';
import styles from './style.module.scss';
import { getColumns, createColumn, updateColumn, deleteColumn, getServices } from '../../../../axios/api/tasks';
import { handleApiError } from '../../../../utils/errorHandler';

const { Option } = Select;

const FIELD_TYPES = [
    { value: 'string', label: 'Mətn (Qısa)' },
    { value: 'text', label: 'Mətn (Uzun)' },
    { value: 'integer', label: 'Tam Ədəd' },
    { value: 'decimal', label: 'Onluq Ədəd' },
    { value: 'boolean', label: 'Bəli/Xeyr' },
    { value: 'date', label: 'Tarix' },
    { value: 'datetime', label: 'Tarix və Saat' },
    { value: 'image', label: 'Şəkil' },
    { value: 'file', label: 'Fayl' },
];

// Character replacement map for Azerbaijani characters
const CHAR_MAP = {
    'ə': 'e', 'Ə': 'E',
    'ı': 'i', 'İ': 'I',
    'ö': 'o', 'Ö': 'O',
    'ü': 'u', 'Ü': 'U',
    'ş': 's', 'Ş': 'S',
    'ç': 'c', 'Ç': 'C',
    'ğ': 'g', 'Ğ': 'G',
};

// Generate slug from name
const generateSlug = (name) => {
    if (!name) return '';
    let slug = name.toLowerCase();
    // Replace Azerbaijani characters
    Object.keys(CHAR_MAP).forEach(char => {
        slug = slug.replace(new RegExp(char, 'g'), CHAR_MAP[char]);
    });
    // Replace spaces and special chars with underscore, remove invalid chars
    slug = slug
        .replace(/\s+/g, '_')
        .replace(/[^a-z0-9_-]/g, '')
        .replace(/_+/g, '_')
        .replace(/^_|_$/g, '');
    return slug;
};

const ColumnTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [services, setServices] = useState([]);
    const [loading, setLoading] = useState(false);

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [serviceFilter, setServiceFilter] = useState(null);
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
            const params = {};
            if (serviceFilter) params.service = serviceFilter;

            const [columnsRes, servicesRes] = await Promise.all([
                getColumns(params),
                getServices()
            ]);
            setData(columnsRes.data.results || columnsRes.data);
            setServices(servicesRes.data.results || servicesRes.data);
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
    }, [isActive, serviceFilter]);

    const handleDelete = async (id) => {
        try {
            await deleteColumn(id);
            message.success('Sütun silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    // Generate unique key for service
    const generateUniqueKey = (name, serviceId) => {
        let baseKey = generateSlug(name);
        if (!baseKey) return '';

        // Get existing keys for this service
        const existingKeys = data
            .filter(col => col.service === serviceId && (!editingItem || col.id !== editingItem.id))
            .map(col => col.key);

        if (!existingKeys.includes(baseKey)) {
            return baseKey;
        }

        // Key exists, add number suffix
        let counter = 2;
        while (existingKeys.includes(`${baseKey}_${counter}`)) {
            counter++;
        }
        return `${baseKey}_${counter}`;
    };

    // Handle name change to auto-generate key
    const handleNameChange = (e) => {
        const name = e.target.value;
        const serviceId = form.getFieldValue('service');
        if (serviceId && !editingItem) {
            const uniqueKey = generateUniqueKey(name, serviceId);
            form.setFieldsValue({ key: uniqueKey });
        }
    };

    // Handle service change to regenerate key
    const handleServiceChange = (serviceId) => {
        const name = form.getFieldValue('name');
        if (name && !editingItem) {
            const uniqueKey = generateUniqueKey(name, serviceId);
            form.setFieldsValue({ key: uniqueKey });
        }
    };

    const onFinish = async (values) => {
        try {
            if (editingItem) {
                await updateColumn(editingItem.id, values);
                message.success('Sütun yeniləndi');
            } else {
                await createColumn(values);
                message.success('Sütun yaradıldı');
            }
            setIsModalOpen(false);
            form.resetFields();
            setEditingItem(null);
            fetchData();
        } catch (error) {
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        }
    };

    const handleStatusChange = async (id, checked) => {
        try {
            await updateColumn(id, { is_active: checked });
            message.success('Status yeniləndi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const getFilteredData = () => {
        return data.filter(item => {
            const lowerSearch = debouncedSearchText.toLowerCase();
            const matchesSearch = item.name.toLowerCase().includes(lowerSearch) ||
                item.key.toLowerCase().includes(lowerSearch);
            const matchesStatus = statusFilter !== 'all' ? item.is_active === statusFilter : true;
            return matchesSearch && matchesStatus;
        });
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        { title: 'Servis', dataIndex: 'service_name', key: 'service_name' },
        { title: 'Ad', dataIndex: 'name', key: 'name' },
        { title: 'Açar', dataIndex: 'key', key: 'key' },
        { title: 'Tip', dataIndex: 'field_type_display', key: 'field_type_display' },
        {
            title: 'Məcburi',
            dataIndex: 'required',
            key: 'required',
            render: (val) => val ? 'Bəli' : 'Xeyr'
        },
        { title: 'Sıra', dataIndex: 'order', key: 'order', width: 60 },
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
                        form.setFieldsValue(record);
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
                            placeholder="Axtar..."
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
                                    placeholder="Servis seçin"
                                    style={{ width: screens.md ? 150 : '100%' }}
                                    allowClear
                                    value={serviceFilter}
                                    onChange={setServiceFilter}
                                >
                                    {services.map(s => (
                                        <Option key={s.id} value={s.id}>{s.name}</Option>
                                    ))}
                                </Select>
                                <Select
                                    placeholder="Status"
                                    style={{ width: screens.md ? 120 : '100%' }}
                                    value={statusFilter}
                                    onChange={setStatusFilter}
                                >
                                    <Option value="all">Hamısı</Option>
                                    <Option value={true}>Aktiv</Option>
                                    <Option value={false}>Deaktiv</Option>
                                </Select>
                            </>
                        )}
                        <Button type="primary" block={!screens.md} onClick={() => {
                            setEditingItem(null);
                            form.resetFields();
                            setIsModalOpen(true);
                        }}>
                            Yeni Sütun
                        </Button>
                    </div>
                </div>
            </div>

            <Table
                columns={columns}
                dataSource={getFilteredData()}
                rowKey="id"
                loading={loading}
                scroll={{ x: 900 }}
                pagination={{ pageSize: 10 }}
            />

            <Modal
                title={editingItem ? "Sütunu Düzəlt" : "Yeni Sütun"}
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                footer={null}
                width={600}
                className={styles.responsiveModal}
            >
                <Form form={form} onFinish={onFinish} layout="vertical">
                    <Form.Item name="service" label="Servis" rules={[{ required: true }]}>
                        <Select showSearch optionFilterProp="children" onChange={handleServiceChange}>
                            {services.map(s => (
                                <Option key={s.id} value={s.id}>{s.name}</Option>
                            ))}
                        </Select>
                    </Form.Item>
                    <Form.Item name="name" label="Ad" rules={[{ required: true }]}>
                        <Input onChange={handleNameChange} />
                    </Form.Item>
                    <Form.Item name="key" label="Açar (slug)" rules={[{ required: true }]}
                        extra="Ad daxil edildikdə avtomatik yaradılır. Eyni servis üçün unikal olmalıdır.">
                        <Input disabled={!editingItem} />
                    </Form.Item>
                    <Form.Item name="field_type" label="Tip" rules={[{ required: true }]}>
                        <Select>
                            {FIELD_TYPES.map(t => (
                                <Option key={t.value} value={t.value}>{t.label}</Option>
                            ))}
                        </Select>
                    </Form.Item>
                    <Form.Item name="required" label="Məcburi" valuePropName="checked">
                        <Switch />
                    </Form.Item>
                    <Form.Item name="order" label="Sıra">
                        <InputNumber min={0} style={{ width: '100%' }} />
                    </Form.Item>
                    <Form.Item name="min_value" label="Minimum Dəyər">
                        <InputNumber style={{ width: '100%' }} />
                    </Form.Item>
                    <Form.Item name="max_value" label="Maksimum Dəyər">
                        <InputNumber style={{ width: '100%' }} />
                    </Form.Item>

                    <Button type="primary" htmlType="submit" block>
                        Təsdiqlə
                    </Button>
                </Form>
            </Modal>
        </div>
    );
};

export default ColumnTab;
