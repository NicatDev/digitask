import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Switch, Select, Grid, Card, DatePicker, InputNumber, Upload, Checkbox, Divider } from 'antd';
import { FilterOutlined, PlusOutlined, DeleteOutlined, UploadOutlined } from '@ant-design/icons';
import { MapContainer, TileLayer, Marker, useMap, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import styles from './style.module.scss';
import { getTasks, createTask, updateTask, deleteTask, updateTaskStatus, getServices, getColumns, getCustomers } from '../../../../axios/api/tasks';
import { getGroups, getUsers } from '../../../../axios/api/account';
import { handleApiError } from '../../../../utils/errorHandler';

// Fix leaflet default marker icon
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const { Option } = Select;
const { TextArea } = Input;

const TASK_STATUSES = [
    { value: 'todo', label: 'Gözləyir', color: '#1890ff' },
    { value: 'in_progress', label: 'İcrada', color: '#fa8c16' },
    { value: 'arrived', label: 'Çatdı', color: '#13c2c2' },
    { value: 'done', label: 'Tamamlandı', color: '#52c41a' },
    { value: 'pending', label: 'Təxirə salındı', color: '#ff4d4f' },
    { value: 'rejected', label: 'Rədd edildi', color: '#595959' },
];

// Map click handler
const MapClickHandler = ({ onLocationSelect }) => {
    useMapEvents({
        click(e) {
            onLocationSelect({ lat: e.latlng.lat, lng: e.latlng.lng });
        },
    });
    return null;
};

// Set view on edit
const SetViewOnEdit = ({ lat, lng }) => {
    const map = useMap();
    useEffect(() => {
        const parsedLat = parseFloat(lat);
        const parsedLng = parseFloat(lng);
        if (!isNaN(parsedLat) && !isNaN(parsedLng)) {
            map.setView([parsedLat, parsedLng], 15);
        }
    }, [lat, lng, map]);
    return null;
};

const TaskTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [customers, setCustomers] = useState([]);
    const [groups, setGroups] = useState([]);
    const [users, setUsers] = useState([]);
    const [services, setServices] = useState([]);
    const [columns, setColumns] = useState([]);
    const [loading, setLoading] = useState(false);

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [statusFilter, setStatusFilter] = useState(null);
    const [customerFilter, setCustomerFilter] = useState(null);
    const [showFilters, setShowFilters] = useState(false);
    const screens = Grid.useBreakpoint();

    const [isModalOpen, setIsModalOpen] = useState(false);
    const [isStatusModalOpen, setIsStatusModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [selectedCoords, setSelectedCoords] = useState(null);
    const [selectedServices, setSelectedServices] = useState([]);
    const [serviceValues, setServiceValues] = useState({});
    const [form] = Form.useForm();
    const [statusForm] = Form.useForm();

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
            const [tasksRes, customersRes, groupsRes, usersRes, servicesRes, columnsRes] = await Promise.all([
                getTasks(),
                getCustomers(),
                getGroups(),
                getUsers(),
                getServices(),
                getColumns()
            ]);
            setData(tasksRes.data.results || tasksRes.data);
            setCustomers(customersRes.data.results || customersRes.data);
            setGroups(groupsRes.data.results || groupsRes.data);
            setUsers(usersRes.data.results || usersRes.data);
            setServices(servicesRes.data.results || servicesRes.data);
            setColumns(columnsRes.data.results || columnsRes.data);
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
            await deleteTask(id);
            message.success('Tapşırıq silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    const getServiceColumns = (serviceId) => {
        return columns.filter(col => col.service === serviceId && col.is_active);
    };

    const handleServiceChange = (serviceId, add) => {
        if (add) {
            setSelectedServices([...selectedServices, serviceId]);
            setServiceValues({ ...serviceValues, [serviceId]: { values: [] } });
        } else {
            setSelectedServices(selectedServices.filter(id => id !== serviceId));
            const newValues = { ...serviceValues };
            delete newValues[serviceId];
            setServiceValues(newValues);
        }
    };

    const handleColumnValueChange = (serviceId, columnId, fieldType, value) => {
        const current = serviceValues[serviceId] || { values: [] };
        const existingIndex = current.values.findIndex(v => v.column === columnId);

        const valueField = getValueFieldName(fieldType);
        const newValue = { column: columnId, [valueField]: value };

        if (existingIndex >= 0) {
            current.values[existingIndex] = newValue;
        } else {
            current.values.push(newValue);
        }

        setServiceValues({ ...serviceValues, [serviceId]: current });
    };

    const getValueFieldName = (fieldType) => {
        const map = {
            'string': 'charfield_value',
            'text': 'text_value',
            'integer': 'number_value',
            'decimal': 'decimal_value',
            'boolean': 'boolean_value',
            'date': 'date_value',
            'datetime': 'datetime_value',
            'image': 'image_value',
            'file': 'file_value',
        };
        return map[fieldType] || 'charfield_value';
    };

    const renderColumnInput = (column, serviceId) => {
        const currentValue = serviceValues[serviceId]?.values?.find(v => v.column === column.id);

        switch (column.field_type) {
            case 'string':
                return (
                    <Input
                        placeholder={column.name}
                        value={currentValue?.charfield_value}
                        onChange={(e) => handleColumnValueChange(serviceId, column.id, 'string', e.target.value)}
                    />
                );
            case 'text':
                return (
                    <TextArea
                        rows={3}
                        placeholder={column.name}
                        value={currentValue?.text_value}
                        onChange={(e) => handleColumnValueChange(serviceId, column.id, 'text', e.target.value)}
                    />
                );
            case 'integer':
                return (
                    <InputNumber
                        style={{ width: '100%' }}
                        min={column.min_value}
                        max={column.max_value}
                        value={currentValue?.number_value}
                        onChange={(val) => handleColumnValueChange(serviceId, column.id, 'integer', val)}
                    />
                );
            case 'decimal':
                return (
                    <InputNumber
                        style={{ width: '100%' }}
                        step={0.01}
                        min={column.min_value}
                        max={column.max_value}
                        value={currentValue?.decimal_value}
                        onChange={(val) => handleColumnValueChange(serviceId, column.id, 'decimal', val)}
                    />
                );
            case 'boolean':
                return (
                    <Checkbox
                        checked={currentValue?.boolean_value}
                        onChange={(e) => handleColumnValueChange(serviceId, column.id, 'boolean', e.target.checked)}
                    >
                        {column.name}
                    </Checkbox>
                );
            case 'date':
                return (
                    <DatePicker
                        style={{ width: '100%' }}
                        onChange={(date, dateString) => handleColumnValueChange(serviceId, column.id, 'date', dateString)}
                    />
                );
            case 'datetime':
                return (
                    <DatePicker
                        showTime
                        style={{ width: '100%' }}
                        onChange={(date, dateString) => handleColumnValueChange(serviceId, column.id, 'datetime', dateString)}
                    />
                );
            default:
                return <Input placeholder={column.name} />;
        }
    };

    const onFinish = async (values) => {
        try {
            const servicesData = selectedServices.map(serviceId => ({
                service: serviceId,
                note: serviceValues[serviceId]?.note || '',
                values: serviceValues[serviceId]?.values || []
            }));

            const submitData = {
                ...values,
                latitude: selectedCoords?.lat,
                longitude: selectedCoords?.lng,
                services_data: servicesData
            };

            if (editingItem) {
                await updateTask(editingItem.id, submitData);
                message.success('Tapşırıq yeniləndi');
            } else {
                await createTask(submitData);
                message.success('Tapşırıq yaradıldı');
            }
            setIsModalOpen(false);
            form.resetFields();
            setEditingItem(null);
            setSelectedCoords(null);
            setSelectedServices([]);
            setServiceValues({});
            fetchData();
        } catch (error) {
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        }
    };

    const handleStatusChange = async (id, checked) => {
        try {
            await updateTask(id, { is_active: checked });
            message.success('Status yeniləndi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const openStatusModal = (record) => {
        setEditingItem(record);
        statusForm.setFieldsValue({ status: record.status });
        setIsStatusModalOpen(true);
    };

    const handleStatusUpdate = async (values) => {
        try {
            await updateTaskStatus(editingItem.id, values.status);
            message.success('Status yeniləndi');
            setIsStatusModalOpen(false);
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const openEditModal = (record) => {
        setEditingItem(record);
        form.setFieldsValue(record);

        if (record.latitude && record.longitude) {
            setSelectedCoords({ lat: parseFloat(record.latitude), lng: parseFloat(record.longitude) });
        } else {
            setSelectedCoords(null);
        }

        // Load existing services
        if (record.task_services) {
            const serviceIds = record.task_services.map(ts => ts.service);
            setSelectedServices(serviceIds);

            const vals = {};
            record.task_services.forEach(ts => {
                vals[ts.service] = {
                    note: ts.note,
                    values: ts.values || []
                };
            });
            setServiceValues(vals);
        }

        setIsModalOpen(true);
    };

    const getFilteredData = () => {
        return data.filter(item => {
            const lowerSearch = debouncedSearchText.toLowerCase();
            const matchesSearch = item.title.toLowerCase().includes(lowerSearch) ||
                (item.customer_name && item.customer_name.toLowerCase().includes(lowerSearch));
            const matchesStatus = statusFilter ? item.status === statusFilter : true;
            const matchesCustomer = customerFilter ? item.customer === customerFilter : true;
            return matchesSearch && matchesStatus && matchesCustomer;
        });
    };

    const getStatusLabel = (status) => {
        const found = TASK_STATUSES.find(s => s.value === status);
        return found ? found.label : status;
    };

    const tableColumns = [
        { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        { title: 'Başlıq', dataIndex: 'title', key: 'title' },
        { title: 'Müştəri', dataIndex: 'customer_name', key: 'customer_name' },
        { title: 'Qrup', dataIndex: 'group_name', key: 'group_name' },
        { title: 'Təyin edilib', dataIndex: 'assigned_to_name', key: 'assigned_to_name' },
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
                    onChange={(checked) => handleStatusChange(record.id, checked)}
                />
            )
        },
        {
            title: 'Əməliyyat',
            key: 'action',
            render: (_, record) => (
                <>
                    <Button type="link" onClick={() => openEditModal(record)}>Düzəliş</Button>
                    <Button type="link" onClick={() => openStatusModal(record)}>Status</Button>
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
                        {(screens.md || showFilters) && (
                            <>
                                <Select
                                    placeholder="Status"
                                    style={{ width: screens.md ? 140 : '100%' }}
                                    allowClear
                                    onChange={setStatusFilter}
                                >
                                    {TASK_STATUSES.map(s => (
                                        <Option key={s.value} value={s.value}>{s.label}</Option>
                                    ))}
                                </Select>
                                <Select
                                    placeholder="Müştəri"
                                    style={{ width: screens.md ? 150 : '100%' }}
                                    allowClear
                                    showSearch
                                    optionFilterProp="children"
                                    onChange={setCustomerFilter}
                                >
                                    {customers.map(c => (
                                        <Option key={c.id} value={c.id}>{c.full_name}</Option>
                                    ))}
                                </Select>
                            </>
                        )}
                        <Button type="primary" block={!screens.md} onClick={() => {
                            setEditingItem(null);
                            form.resetFields();
                            setSelectedCoords(null);
                            setSelectedServices([]);
                            setServiceValues({});
                            setIsModalOpen(true);
                        }}>
                            Yeni Tapşırıq
                        </Button>
                    </div>
                </div>
            </div>

            <Table
                columns={tableColumns}
                dataSource={getFilteredData()}
                rowKey="id"
                loading={loading}
                scroll={{ x: 1000 }}
                pagination={{ pageSize: 10 }}
            />

            {/* Task Form Modal */}
            <Modal
                title={editingItem ? "Tapşırığı Düzəlt" : "Yeni Tapşırıq"}
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                footer={null}
                width={800}
                className={styles.responsiveModal}
                destroyOnClose
            >
                <Form form={form} onFinish={onFinish} layout="vertical">
                    <Form.Item name="title" label="Başlıq" rules={[{ required: true }]}>
                        <Input />
                    </Form.Item>

                    <Form.Item name="customer" label="Müştəri" rules={[{ required: true }]}>
                        <Select showSearch optionFilterProp="children">
                            {customers.filter(c => c.is_active).map(c => (
                                <Option key={c.id} value={c.id}>{c.full_name}</Option>
                            ))}
                        </Select>
                    </Form.Item>

                    <Form.Item name="group" label="Qrup" rules={[{ required: true }]}>
                        <Select showSearch optionFilterProp="children">
                            {groups.map(g => (
                                <Option key={g.id} value={g.id}>{g.region_name} - {g.name}</Option>
                            ))}
                        </Select>
                    </Form.Item>

                    <Form.Item name="assigned_to" label="Təyin et">
                        <Select allowClear showSearch optionFilterProp="children">
                            {users.filter(u => u.is_active).map(u => (
                                <Option key={u.id} value={u.id}>{u.username}</Option>
                            ))}
                        </Select>
                    </Form.Item>

                    <Form.Item name="note" label="Qeyd">
                        <TextArea rows={3} />
                    </Form.Item>

                    <Form.Item label="Xəritədə Ünvan (klik edin)">
                        <div className={styles.mapContainer}>
                            <MapContainer
                                center={selectedCoords ? [selectedCoords.lat, selectedCoords.lng] : [40.4093, 49.8671]}
                                zoom={selectedCoords ? 15 : 10}
                                style={{ height: '100%', width: '100%' }}
                            >
                                <TileLayer
                                    attribution='&copy; OpenStreetMap contributors'
                                    url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                                />
                                <MapClickHandler onLocationSelect={setSelectedCoords} />
                                {selectedCoords && (
                                    <>
                                        <Marker position={[selectedCoords.lat, selectedCoords.lng]} />
                                        <SetViewOnEdit lat={selectedCoords.lat} lng={selectedCoords.lng} />
                                    </>
                                )}
                            </MapContainer>
                        </div>
                        {selectedCoords && (
                            <div style={{ marginTop: 8, color: '#888' }}>
                                Lat: {selectedCoords.lat.toFixed(6)}, Lng: {selectedCoords.lng.toFixed(6)}
                            </div>
                        )}
                    </Form.Item>

                    <Divider>Servislər</Divider>

                    <Form.Item label="Servis əlavə et">
                        <Select
                            placeholder="Servis seçin"
                            onChange={(val) => handleServiceChange(val, true)}
                            value={null}
                        >
                            {services
                                .filter(s => s.is_active && !selectedServices.includes(s.id))
                                .map(s => (
                                    <Option key={s.id} value={s.id}>{s.name}</Option>
                                ))}
                        </Select>
                    </Form.Item>

                    {selectedServices.map(serviceId => {
                        const service = services.find(s => s.id === serviceId);
                        const serviceCols = getServiceColumns(serviceId);

                        return (
                            <div key={serviceId} className={styles.serviceCard}>
                                <div className={styles.serviceHeader}>
                                    <strong>{service?.name}</strong>
                                    <Button
                                        type="text"
                                        danger
                                        icon={<DeleteOutlined />}
                                        onClick={() => handleServiceChange(serviceId, false)}
                                    />
                                </div>

                                {serviceCols.map(col => (
                                    <Form.Item key={col.id} label={col.name} required={col.required}>
                                        {renderColumnInput(col, serviceId)}
                                    </Form.Item>
                                ))}
                            </div>
                        );
                    })}

                    <Button type="primary" htmlType="submit" block>
                        Təsdiqlə
                    </Button>
                </Form>
            </Modal>

            {/* Status Change Modal */}
            <Modal
                title="Statusu Dəyiş"
                open={isStatusModalOpen}
                onCancel={() => setIsStatusModalOpen(false)}
                footer={null}
                width={400}
            >
                <Form form={statusForm} onFinish={handleStatusUpdate} layout="vertical">
                    <Form.Item name="status" label="Yeni Status" rules={[{ required: true }]}>
                        <Select>
                            {TASK_STATUSES.map(s => (
                                <Option key={s.value} value={s.value}>{s.label}</Option>
                            ))}
                        </Select>
                    </Form.Item>
                    <Button type="primary" htmlType="submit" block>
                        Yenilə
                    </Button>
                </Form>
            </Modal>
        </div>
    );
};

export default TaskTab;
