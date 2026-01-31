import React, { useEffect } from 'react';
import { Modal } from 'antd';
import { MapContainer, TileLayer, Marker, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css'; // Leaflet CSS import within component if needed, or in main

// Simple Map Utilities for View Modal
const MapResizer = () => {
    const map = useMap();
    useEffect(() => {
        map.invalidateSize();
    }, [map]);
    return null;
};

const SetViewOnEdit = ({ lat, lng }) => {
    const map = useMap();
    useEffect(() => {
        if (lat && lng) {
            map.setView([lat, lng], 15);
        }
    }, [lat, lng, map]);
    return null;
};

const MapModal = ({
    open,
    onCancel,
    title,
    coords // { lat, lng }
}) => {
    return (
        <Modal
            title={`📍 Müştəri ünvanı: ${title}`}
            open={open}
            onCancel={onCancel}
            footer={null}
            width={800}
            bodyStyle={{ height: '500px', padding: 0 }}
            destroyOnClose
        >
            {coords && (
                <MapContainer
                    center={[coords.lat, coords.lng]}
                    zoom={15}
                    style={{ height: '100%', width: '100%' }}
                >
                    <TileLayer
                        attribution='&copy; OpenStreetMap contributors'
                        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                    />
                    <MapResizer />
                    <Marker position={[coords.lat, coords.lng]} />
                    <SetViewOnEdit lat={coords.lat} lng={coords.lng} />
                </MapContainer>
            )}
        </Modal>
    );
};

export default MapModal;
