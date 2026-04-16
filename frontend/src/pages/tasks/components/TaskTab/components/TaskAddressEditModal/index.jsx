import React, { useCallback, useEffect, useState } from 'react';
import { Modal, Form, Input, AutoComplete, Button, Spin, message } from 'antd';
import { AimOutlined, SearchOutlined } from '@ant-design/icons';
import { MapContainer, TileLayer, Marker, useMap, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import { getCustomer, updateCustomer } from '../../../../../../../axios/api/tasks';

const MapClickHandler = ({ onLocationSelect }) => {
    useMapEvents({
        click(e) {
            onLocationSelect({ lat: e.latlng.lat, lng: e.latlng.lng });
        },
    });
    return null;
};

const SetViewOnCoords = ({ lat, lng }) => {
    const map = useMap();
    useEffect(() => {
        if (lat && lng) map.setView([lat, lng], 16);
    }, [lat, lng, map]);
    return null;
};

const MapResizer = () => {
    const map = useMap();
    useEffect(() => {
        const timer = setTimeout(() => map.invalidateSize(), 100);
        return () => clearTimeout(timer);
    }, [map]);
    return null;
};

const TaskAddressEditModal = ({ open, onCancel, customerId, customerName, onSaved }) => {
    const [form] = Form.useForm();
    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [selectedCoords, setSelectedCoords] = useState(null);
    const [addressSearchText, setAddressSearchText] = useState('');
    const [addressOptions, setAddressOptions] = useState([]);
    const [addressSearching, setAddressSearching] = useState(false);
    const [geoAllowed, setGeoAllowed] = useState(false);

    useEffect(() => {
        if (!open || !customerId) return;
        setLoading(true);
        getCustomer(customerId)
            .then((res) => {
                const c = res.data;
                form.setFieldsValue({ address: c.address || '' });
                if (c.address_coordinates?.lat && c.address_coordinates?.lng) {
                    setSelectedCoords({
                        lat: parseFloat(c.address_coordinates.lat),
                        lng: parseFloat(c.address_coordinates.lng),
                    });
                } else {
                    setSelectedCoords(null);
                }
            })
            .finally(() => setLoading(false));
    }, [open, customerId, form]);

    useEffect(() => {
        let mounted = true;
        (async () => {
            try {
                if (!navigator?.geolocation) return;
                if (!navigator?.permissions?.query) {
                    if (mounted) setGeoAllowed(true);
                    return;
                }
                const p = await navigator.permissions.query({ name: 'geolocation' });
                if (mounted) setGeoAllowed(p.state !== 'denied');
            } catch {
                if (mounted) setGeoAllowed(false);
            }
        })();
        return () => {
            mounted = false;
        };
    }, []);

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
            setAddressOptions(
                data.map((item) => ({
                    value: item.display_name,
                    label: item.display_name,
                    lat: parseFloat(item.lat),
                    lon: parseFloat(item.lon),
                }))
            );
        } finally {
            setAddressSearching(false);
        }
    }, []);

    useEffect(() => {
        const timer = setTimeout(() => {
            if (addressSearchText) searchAddress(addressSearchText);
        }, 450);
        return () => clearTimeout(timer);
    }, [addressSearchText, searchAddress]);

    const handleAddressSelect = (value, option) => {
        if (option.lat && option.lon) {
            setSelectedCoords({ lat: option.lat, lng: option.lon });
            form.setFieldValue('address', value);
        }
    };

    const handleUseMyLocation = () => {
        if (!navigator?.geolocation) return;
        navigator.geolocation.getCurrentPosition(
            (pos) => {
                const coords = { lat: pos.coords.latitude, lng: pos.coords.longitude };
                setSelectedCoords(coords);
            },
            () => message.error('Lokasiya əldə edilə bilmədi.')
        );
    };

    const handleSave = async () => {
        if (!customerId) return;
        const values = await form.validateFields();
        setSaving(true);
        try {
            await updateCustomer(customerId, {
                address: values.address || '',
                address_coordinates: selectedCoords || {},
            });
            message.success('Müştəri ünvanı yeniləndi');
            onSaved?.();
            onCancel?.();
        } finally {
            setSaving(false);
        }
    };

    return (
        <Modal
            title={`Müştəri ünvanı: ${customerName || ''}`}
            open={open}
            onCancel={onCancel}
            onOk={handleSave}
            okText="Yadda saxla"
            confirmLoading={saving}
            width={820}
            destroyOnClose
        >
            {loading ? (
                <div style={{ textAlign: 'center', padding: 24 }}>
                    <Spin />
                </div>
            ) : (
                <>
                    <Form form={form} layout="vertical">
                        <Form.Item name="address" label="Ünvan">
                            <Input />
                        </Form.Item>
                    </Form>

                    <Form.Item label="Ünvan axtarışı (OSM)">
                        <AutoComplete
                            style={{ width: '100%' }}
                            options={addressOptions}
                            onSearch={setAddressSearchText}
                            onSelect={handleAddressSelect}
                            placeholder="Ünvan yazın və seçin..."
                            notFoundContent={addressSearching ? <Spin size="small" /> : null}
                        >
                            <Input prefix={<SearchOutlined />} suffix={addressSearching ? <Spin size="small" /> : null} />
                        </AutoComplete>
                    </Form.Item>

                    <div style={{ marginBottom: 8 }}>
                        <Button icon={<AimOutlined />} onClick={handleUseMyLocation} disabled={!geoAllowed}>
                            Mənim lokasiyam
                        </Button>
                    </div>

                    <div style={{ height: 360, width: '100%', borderRadius: 8, overflow: 'hidden' }}>
                        <MapContainer
                            center={selectedCoords ? [selectedCoords.lat, selectedCoords.lng] : [40.4093, 49.8671]}
                            zoom={selectedCoords ? 16 : 12}
                            style={{ height: '100%', width: '100%' }}
                        >
                            <TileLayer
                                attribution="&copy; OpenStreetMap contributors"
                                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                            />
                            <MapResizer />
                            <MapClickHandler onLocationSelect={setSelectedCoords} />
                            {selectedCoords ? (
                                <>
                                    <Marker position={[selectedCoords.lat, selectedCoords.lng]} />
                                    <SetViewOnCoords lat={selectedCoords.lat} lng={selectedCoords.lng} />
                                </>
                            ) : null}
                        </MapContainer>
                    </div>
                </>
            )}
        </Modal>
    );
};

export default TaskAddressEditModal;

