import React, { useEffect, useMemo, useRef } from 'react';
import { Form, Input, Select, Button } from 'antd';
import { EnvironmentOutlined } from '@ant-design/icons';
import { MapContainer, TileLayer, Marker, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import MapClickHandler from '../MapClickHandler';
import styles from './style.module.scss';

// Fix leaflet default marker icon issue
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const DEFAULT_COORDS = { lat: 40.4093, lng: 49.8671 };

// Component to handle map ready and invalidate size
const MapReadyHandler = ({ shouldCenter, lat, lng }) => {
    const map = useMap();
    const hasInitialized = useRef(false);

    useEffect(() => {
        if (!hasInitialized.current) {
            // Invalidate size after container is ready
            setTimeout(() => {
                map.invalidateSize();
                if (shouldCenter && !isNaN(lat) && !isNaN(lng)) {
                    map.setView([lat, lng], 15);
                }
            }, 100);
            hasInitialized.current = true;
        }
    }, [map, shouldCenter, lat, lng]);

    return null;
};

// Marker that updates position without re-centering
const DraggableMarker = ({ lat, lng }) => {
    if (isNaN(lat) || isNaN(lng)) return null;
    return <Marker position={[lat, lng]} />;
};

const WarehouseForm = ({ form, onFinish, regions, selectedCoords, setSelectedCoords, editingItem }) => {
    // Ensure coordinates are always valid numbers
    const validCoords = useMemo(() => {
        const lat = parseFloat(selectedCoords?.lat);
        const lng = parseFloat(selectedCoords?.lng);
        return {
            lat: !isNaN(lat) ? lat : DEFAULT_COORDS.lat,
            lng: !isNaN(lng) ? lng : DEFAULT_COORDS.lng
        };
    }, [selectedCoords]);

    // Only center on initial load when editing an existing warehouse with coordinates
    const shouldCenter = !!editingItem && editingItem.coordinates?.lat && editingItem.coordinates?.lng;

    return (
        <Form form={form} onFinish={onFinish} layout="vertical">
            <Form.Item name="name" label="Ad" rules={[{ required: true }]}>
                <Input />
            </Form.Item>
            <Form.Item name="region" label="Region" rules={[{ required: true }]}>
                <Select showSearch optionFilterProp="children">
                    {regions.map(r => (
                        <Select.Option key={r.id} value={r.id}>{r.name}</Select.Option>
                    ))}
                </Select>
            </Form.Item>
            <Form.Item name="address" label="Ünvan">
                <Input />
            </Form.Item>

            <Form.Item label={<span><EnvironmentOutlined /> Xəritədən Seç (Lat: {validCoords.lat.toFixed(4)}, Lng: {validCoords.lng.toFixed(4)})</span>}>
                <div className={styles.mapContainer}>
                    <MapContainer
                        center={[validCoords.lat, validCoords.lng]}
                        zoom={12}
                        style={{ height: '100%', width: '100%' }}
                    >
                        <TileLayer
                            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                        />
                        <DraggableMarker lat={validCoords.lat} lng={validCoords.lng} />
                        <MapClickHandler onLocationSelect={setSelectedCoords} />
                        <MapReadyHandler
                            shouldCenter={shouldCenter}
                            lat={validCoords.lat}
                            lng={validCoords.lng}
                        />
                    </MapContainer>
                </div>
            </Form.Item>

            <Form.Item name="note" label="Qeyd">
                <Input.TextArea />
            </Form.Item>

            <Button type="primary" htmlType="submit" block>
                Təsdiqlə
            </Button>
        </Form>
    );
};

export default WarehouseForm;
