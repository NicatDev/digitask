import React, { useEffect, useState, useCallback } from 'react';
import { Table, Button, Modal, Form, Input, message, Popconfirm, Switch, Select, Grid, Tooltip, AutoComplete, Spin } from 'antd';
import { FilterOutlined, EnvironmentOutlined, SearchOutlined } from '@ant-design/icons';
import { MapContainer, TileLayer, Marker, Popup, useMap, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import styles from './style.module.scss';
import {
    getCustomers,
    createCustomer,
    updateCustomer,
    deleteCustomer,
    getEquipment,
    getOpticBoxes,
} from '../../../../axios/api/tasks';
import CustomerHistoryModal from '../TaskTab/components/CustomerHistoryModal';
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

// Set view on coordinates change
const SetViewOnCoords = ({ lat, lng }) => {
    const map = useMap();
    useEffect(() => {
        const parsedLat = parseFloat(lat);
        const parsedLng = parseFloat(lng);
        if (!isNaN(parsedLat) && !isNaN(parsedLng)) {
            map.setView([parsedLat, parsedLng], 16);
        }
    }, [lat, lng, map]);
    return null;
};

// Fix map rendering in modal
const MapResizer = () => {
    const map = useMap();
    useEffect(() => {
        const timer = setTimeout(() => {
            map.invalidateSize();
        }, 100);
        return () => clearTimeout(timer);
    }, [map]);
    return null;
};

const CustomerTab = ({ isActive }) => {
    const [data, setData] = useState([]);
    const [regions, setRegions] = useState([]);
    const [equipmentOptions, setEquipmentOptions] = useState([]);
    const [opticBoxOptions, setOpticBoxOptions] = useState([]);
    const [loading, setLoading] = useState(false);
    const [pagination, setPagination] = useState({
        current: 1,
        pageSize: 10,
        total: 0
    });

    // Filter States
    const [searchText, setSearchText] = useState('');
    const [debouncedSearchText, setDebouncedSearchText] = useState('');
    const [regionFilter, setRegionFilter] = useState(null);
    const [equipmentFilter, setEquipmentFilter] = useState(null);
    const [opticBoxFilter, setOpticBoxFilter] = useState(null);
    const [statusFilter, setStatusFilter] = useState('all');
    const [showFilters, setShowFilters] = useState(false);
    const screens = Grid.useBreakpoint();

    const [isModalOpen, setIsModalOpen] = useState(false);
    const [editingItem, setEditingItem] = useState(null);
    const [selectedCoords, setSelectedCoords] = useState(null);
    const [form] = Form.useForm();

    // Location View Modal state
    const [locationModalOpen, setLocationModalOpen] = useState(false);
    const [viewingCustomer, setViewingCustomer] = useState(null);

    const [taskHistoryOpen, setTaskHistoryOpen] = useState(false);
    const [taskHistoryCustomer, setTaskHistoryCustomer] = useState(null);

    // OSM Address Search state
    const [addressSearchText, setAddressSearchText] = useState('');
    const [addressOptions, setAddressOptions] = useState([]);
    const [addressSearching, setAddressSearching] = useState(false);

    // Debounce Search
    useEffect(() => {
        const timer = setTimeout(() => {
            setDebouncedSearchText(searchText);
        }, 500);
        return () => clearTimeout(timer);
    }, [searchText]);

    // OSM Nominatim Address Search
    const searchAddress = useCallback(async (query) => {
        if (!query || query.length < 3) {
            setAddressOptions([]);
            return;
        }

        setAddressSearching(true);
        try {
            const response = await fetch(
                `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=5&countrycodes=az`
            );
            const data = await response.json();
            const options = data.map(item => ({
                value: item.display_name,
                label: item.display_name,
                lat: parseFloat(item.lat),
                lon: parseFloat(item.lon)
            }));
            setAddressOptions(options);
        } catch (error) {
            console.error('OSM search error:', error);
        } finally {
            setAddressSearching(false);
        }
    }, []);

    // Debounce address search
    useEffect(() => {
        const timer = setTimeout(() => {
            if (addressSearchText) {
                searchAddress(addressSearchText);
            }
        }, 500);
        return () => clearTimeout(timer);
    }, [addressSearchText, searchAddress]);

    const handleAddressSelect = (value, option) => {
        if (option.lat && option.lon) {
            setSelectedCoords({ lat: option.lat, lng: option.lon });
            // Ünvan field-ə yazılsın
            form.setFieldValue('address', value);
        }
    };

    const fetchData = React.useCallback(async (params = {}) => {
        setLoading(true);
        try {
            const page = params.current || pagination.current;
            const apiParams = {
                page: page,
                page_size: 10,
                search: debouncedSearchText,
            };

            if (regionFilter) apiParams.region = regionFilter;
            if (equipmentFilter) apiParams.equipment = equipmentFilter;
            if (opticBoxFilter) apiParams.optic_box = opticBoxFilter;
            if (statusFilter !== 'all') apiParams.is_active = statusFilter;

            const [customersRes, regionsRes] = await Promise.all([
                getCustomers(apiParams),
                getRegions(),
            ]);

            const results = customersRes.data.results || [];
            const count = customersRes.data.count || 0;

            setData(results);
            setPagination(prev => ({
                ...prev,
                current: page,
                total: count
            }));

            if (regions.length === 0) {
                setRegions(regionsRes.data.results || regionsRes.data);
            }
        } catch (error) {
            console.error(error);
            handleApiError(error, 'Məlumatları yükləmək mümkün olmadı');
        } finally {
            setLoading(false);
        }
    }, [debouncedSearchText, regionFilter, equipmentFilter, opticBoxFilter, statusFilter, pagination.current, regions.length]);

    const handleTableChange = (newPagination) => {
        fetchData({ current: newPagination.current });
    };

    useEffect(() => {
        if (isActive) {
            fetchData({ current: 1 });
        }
    }, [isActive, debouncedSearchText, regionFilter, equipmentFilter, opticBoxFilter, statusFilter]); // Trigger on filters change

    useEffect(() => {
        if (!isActive) return;
        (async () => {
            try {
                const [e, o] = await Promise.all([
                    getEquipment({ is_active: true, page_size: 100 }),
                    getOpticBoxes({ is_active: true, page_size: 100 }),
                ]);
                setEquipmentOptions(e.data.results || e.data || []);
                setOpticBoxOptions(o.data.results || o.data || []);
            } catch (err) {
                console.error(err);
            }
        })();
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
                address_coordinates: selectedCoords || {},
                equipment: values.equipment ?? null,
                optic_box: values.optic_box ?? null,
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
            setAddressSearchText('');
            setAddressOptions([]);
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



    const openEditModal = (record) => {
        setEditingItem(record);
        form.setFieldsValue(record);
        if (record.address_coordinates && record.address_coordinates.lat) {
            setSelectedCoords(record.address_coordinates);
        } else {
            setSelectedCoords(null);
        }
        setAddressSearchText('');
        setAddressOptions([]);
        setIsModalOpen(true);
    };

    const openNewModal = () => {
        setEditingItem(null);
        form.resetFields();
        setSelectedCoords(null);
        setAddressSearchText('');
        setAddressOptions([]);
        setIsModalOpen(true);
    };

    const openTaskHistoryModal = (record) => {
        setTaskHistoryCustomer({ id: record.id, full_name: record.full_name });
        setTaskHistoryOpen(true);
    };

    const columns = [
        { title: 'ID', dataIndex: 'id', key: 'id', width: 60 },
        { title: 'Ad Soyad', dataIndex: 'full_name', key: 'full_name' },
        { title: 'Telefon', dataIndex: 'phone_number', key: 'phone_number' },
        { title: 'Qeyd No', dataIndex: 'register_number', key: 'register_number' },
        { title: 'Region', dataIndex: 'region_name', key: 'region_name' },
        { title: 'Avadanlıq', dataIndex: 'equipment_name', key: 'equipment_name', ellipsis: true },
        { title: 'Optik qutu', dataIndex: 'optic_box_name', key: 'optic_box_name', ellipsis: true },
        { title: 'Ünvan', dataIndex: 'address', key: 'address', ellipsis: true },
        {
            title: 'Xəritə',
            key: 'map',
            width: 100,
            render: (_, record) => (
                <Tooltip title={record.address_coordinates?.lat ? 'Xəritədə göstər' : 'Koordinat yoxdur'}>
                    <EnvironmentOutlined
                        style={{
                            fontSize: 18,
                            color: record.address_coordinates?.lat ? '#1890ff' : '#ccc',
                            cursor: record.address_coordinates?.lat ? 'pointer' : 'default'
                        }}
                        onClick={() => {
                            if (record.address_coordinates?.lat) {
                                setViewingCustomer(record);
                                setLocationModalOpen(true);
                            }
                        }}
                    />
                </Tooltip>
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
            width: 280,
            render: (_, record) => (
                <>
                    <Button type="link" onClick={() => openTaskHistoryModal(record)}>
                        Tapşırıq tarixçəsi
                    </Button>
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
                                    placeholder="Avadanlıq"
                                    style={{ width: screens.md ? 160 : '100%' }}
                                    allowClear
                                    onChange={setEquipmentFilter}
                                >
                                    {equipmentOptions.map((item) => (
                                        <Option key={item.id} value={item.id}>{item.name}</Option>
                                    ))}
                                </Select>
                                <Select
                                    placeholder="Optik qutu"
                                    style={{ width: screens.md ? 160 : '100%' }}
                                    allowClear
                                    onChange={setOpticBoxFilter}
                                >
                                    {opticBoxOptions.map((item) => (
                                        <Option key={item.id} value={item.id}>{item.name}</Option>
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
                        <Button type="primary" block={!screens.md} onClick={openNewModal}>
                            Yeni Müştəri
                        </Button>
                    </div>
                </div>
            </div>

            <Table
                columns={columns}
                dataSource={data}
                rowKey="id"
                loading={loading}
                scroll={{ x: 1100 }}
                pagination={{ ...pagination, pageSize: 10, showSizeChanger: false }}
                onChange={handleTableChange}
            />

            <CustomerHistoryModal
                open={taskHistoryOpen}
                onCancel={() => {
                    setTaskHistoryOpen(false);
                    setTaskHistoryCustomer(null);
                }}
                customerId={taskHistoryCustomer?.id}
                customerName={taskHistoryCustomer?.full_name}
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
                    <Form.Item name="equipment" label="Avadanlıq">
                        <Select allowClear placeholder="Seçin" showSearch optionFilterProp="children">
                            {equipmentOptions.map((item) => (
                                <Option key={item.id} value={item.id}>{item.name}</Option>
                            ))}
                        </Select>
                    </Form.Item>
                    <Form.Item name="optic_box" label="Optik qutu">
                        <Select allowClear placeholder="Seçin" showSearch optionFilterProp="children">
                            {opticBoxOptions.map((item) => (
                                <Option key={item.id} value={item.id}>{item.name}</Option>
                            ))}
                        </Select>
                    </Form.Item>
                    <Form.Item name="address" label="Ünvan">
                        <Input />
                    </Form.Item>

                    {/* OSM Address Search */}
                    <Form.Item label="Ünvan Axtarışı (OSM)">
                        <AutoComplete
                            style={{ width: '100%' }}
                            options={addressOptions}
                            onSearch={setAddressSearchText}
                            onSelect={handleAddressSelect}
                            placeholder="Ünvan yazın və seçin..."
                            notFoundContent={addressSearching ? <Spin size="small" /> : null}
                        >
                            <Input
                                prefix={<SearchOutlined />}
                                suffix={addressSearching ? <Spin size="small" /> : null}
                            />
                        </AutoComplete>
                        <div style={{ fontSize: 12, color: '#888', marginTop: 4 }}>
                            Ünvan yazın, nəticələrdən seçin - xəritədə point avtomatik yerləşəcək
                        </div>
                    </Form.Item>

                    <Form.Item label="Xəritədə Ünvan (klik edin və ya yuxarıdan axtarın)">
                        <div className={styles.mapContainer}>
                            <MapContainer
                                center={selectedCoords ? [selectedCoords.lat, selectedCoords.lng] : [40.4093, 49.8671]}
                                zoom={selectedCoords ? 16 : 12}
                                style={{ height: '100%', width: '100%' }}
                            >
                                <TileLayer
                                    attribution='&copy; OpenStreetMap contributors'
                                    url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                                />
                                <MapResizer />
                                <MapClickHandler onLocationSelect={setSelectedCoords} />
                                {selectedCoords && (
                                    <>
                                        <Marker position={[selectedCoords.lat, selectedCoords.lng]} />
                                        <SetViewOnCoords lat={selectedCoords.lat} lng={selectedCoords.lng} />
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

            {/* Customer Location View Modal */}
            <Modal
                title={`📍 ${viewingCustomer?.full_name || 'Müştəri'} - Ünvan`}
                open={locationModalOpen}
                onCancel={() => {
                    setLocationModalOpen(false);
                    setViewingCustomer(null);
                }}
                footer={null}
                width={700}
                destroyOnHidden
            >
                {viewingCustomer?.address_coordinates?.lat && (
                    <div style={{ height: '450px', width: '100%' }}>
                        <MapContainer
                            center={[viewingCustomer.address_coordinates.lat, viewingCustomer.address_coordinates.lng]}
                            zoom={15}
                            style={{ height: '100%', width: '100%' }}
                        >
                            <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
                            <MapResizer />
                            <Marker position={[viewingCustomer.address_coordinates.lat, viewingCustomer.address_coordinates.lng]}>
                                <Popup>
                                    <strong>{viewingCustomer.full_name}</strong><br />
                                    {viewingCustomer.address || 'Ünvan qeyd olunmayıb'}<br />
                                    📞 {viewingCustomer.phone_number || '-'}
                                </Popup>
                            </Marker>
                        </MapContainer>
                        <div style={{ marginTop: 8, color: '#666' }}>
                            <strong>Ünvan:</strong> {viewingCustomer.address || 'Qeyd olunmayıb'}<br />
                            <strong>Koordinatlar:</strong> {viewingCustomer.address_coordinates.lat.toFixed(6)}, {viewingCustomer.address_coordinates.lng.toFixed(6)}
                        </div>
                    </div>
                )}
            </Modal>
        </div>
    );
};

export default CustomerTab;
