import React, { useEffect, useState } from 'react';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Switch, Select, Grid } from 'antd';
import { FilterOutlined, EnvironmentOutlined } from '@ant-design/icons';
import { MapContainer, TileLayer, Marker, useMap, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import styles from './style.module.scss';
import { getCustomers, createCustomer, updateCustomer, deleteCustomer } from '../../../../axios/api/tasks';
import { getRegions } from '../../../../axios/api/account';
import { handleApiError } from '../../../../utils/errorHandler';

// Fix leaflet default marker icon
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const { Option } = Select;

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

const CustomerTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [regions, setRegions] = useState([]);
    const [loading, setLoading] = useState(false);

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [regionFilter, setRegionFilter] = useState(null);
    const [statusFilter, setStatusFilter] = useState('all');
    const [showFilters, setShowFilters] = useState(false);
    const screens = Grid.useBreakpoint();

    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [selectedCoords, setSelectedCoords] = useState(null);
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
            const [customersRes, regionsRes] = await Promise.all([
                getCustomers(),
                getRegions()
            ]);
            setData(customersRes.data.results || customersRes.data);
            setRegions(regionsRes.data.results || regionsRes.data);
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
            await deleteCustomer(id);
            message.success('Müştəri silindi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Silinmə uğursuz oldu');
        }
    };

    const onFinish = async (values) => {
        try {
            const submitData = {
                ...values,
                address_coordinates: selectedCoords || {}
            };

            if (editingItem) {
                await updateCustomer(editingItem.id, submitData);
                message.success('Müştəri yeniləndi');
            } else {
                await createCustomer(submitData);
                message.success('Müştəri yaradıldı');
            }
            setIsModalOpen(false);
            form.resetFields();
            setEditingItem(null);
            setSelectedCoords(null);
            fetchData();
        } catch (error) {
            handleApiError(error, 'Əməliyyat uğursuz oldu');
        }
    };

    const handleStatusChange = async (id, checked) => {
        try {
            await updateCustomer(id, { is_active: checked });
            message.success('Status yeniləndi');
            fetchData();
        } catch (error) {
            handleApiError(error, 'Status yenilənmədi');
        }
    };

    const getFilteredData = () => {
        return data.filter(item => {
            const lowerSearch = debouncedSearchText.toLowerCase();
            const matchesSearch = item.full_name.toLowerCase().includes(lowerSearch) ||
                (item.phone_number && item.phone_number.includes(lowerSearch)) ||
                (item.register_number && item.register_number.includes(lowerSearch));
            const matchesRegion = regionFilter ? item.region === regionFilter : true;
            const matchesStatus = statusFilter !== 'all' ? item.is_active === statusFilter : true;
            return matchesSearch && matchesRegion && matchesStatus;
        });
    };

    const openEditModal = (record) => {
        setEditingItem(record);
        form.setFieldsValue(record);
        if (record.address_coordinates && record.address_coordinates.lat) {
            setSelectedCoords(record.address_coordinates);
        } else {
            setSelectedCoords(null);
        }
        setIsModalOpen(true);
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        { title: 'Ad Soyad', dataIndex: 'full_name', key: 'full_name' },
        { title: 'Telefon', dataIndex: 'phone_number', key: 'phone_number' },
        { title: 'Qeyd No', dataIndex: 'register_number', key: 'register_number' },
        { title: 'Region', dataIndex: 'region_name', key: 'region_name' },
        { title: 'Ünvan', dataIndex: 'address', key: 'address', ellipsis: true },
        {
            title: 'Xəritə',
            key: 'map',
            width: 60,
            render: (_, record) => (
                <EnvironmentOutlined
                    style={{
                        fontSize: 18,
                        color: record.address_coordinates?.lat ? '#1890ff' : '#ccc'
                    }}
                />
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
                                    placeholder="Region seçin"
                                    style={{ width: screens.md ? 150 : '100%' }}
                                    allowClear
                                    onChange={setRegionFilter}
                                >
                                    {regions.map(r => (
                                        <Option key={r.id} value={r.id}>{r.name}</Option>
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
                            setSelectedCoords(null);
                            setIsModalOpen(true);
                        }}>
                            Yeni Müştəri
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
                title={editingItem ? "Müştərini Düzəlt" : "Yeni Müştəri"}
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                footer={null}
                width={700}
                className={styles.responsiveModal}
                destroyOnClose
            >
                <Form form={form} onFinish={onFinish} layout="vertical">
                    <Form.Item name="full_name" label="Ad Soyad" rules={[{ required: true }]}>
                        <Input />
                    </Form.Item>
                    <Form.Item name="phone_number" label="Telefon">
                        <Input />
                    </Form.Item>
                    <Form.Item name="register_number" label="Qeydiyyat Nömrəsi">
                        <Input />
                    </Form.Item>
                    <Form.Item name="region" label="Region" rules={[{ required: true }]}>
                        <Select showSearch optionFilterProp="children">
                            {regions.map(r => (
                                <Option key={r.id} value={r.id}>{r.name}</Option>
                            ))}
                        </Select>
                    </Form.Item>
                    <Form.Item name="address" label="Ünvan">
                        <Input />
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

                    <Button type="primary" htmlType="submit" block>
                        Təsdiqlə
                    </Button>
                </Form>
            </Modal>
        </div>
    );
};

export default CustomerTab;
