import React, { useEffect, useMemo, useRef } from 'react';
import { Modal } from 'antd';
import { MapContainer, TileLayer, Marker, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import styles from './style.module.scss';

// Fix leaflet default marker icon issue
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const DEFAULT_COORDS = { lat: 40.4093, lng: 49.8671 };

// Component to handle map ready - invalidate size and fly to location
const MapReadyHandler = ({ lat, lng }) => {
    const map = useMap();
    const hasInitialized = useRef(false);

    useEffect(() => {
        if (!hasInitialized.current && !isNaN(lat) && !isNaN(lng)) {
            setTimeout(() => {
                map.invalidateSize();
                map.setView([lat, lng], 15);
            }, 100);
            hasInitialized.current = true;
        }
    }, [lat, lng, map]);

    return null;
};

// Safe Marker component
const SafeMarker = ({ lat, lng }) => {
    if (typeof lat !== 'number' || typeof lng !== 'number' || isNaN(lat) || isNaN(lng)) {
        return null;
    }
    return <Marker position={[lat, lng]} />;
};

const LocationViewModal = ({ open, onClose, coordinates, warehouseName }) => {
    const validCoords = useMemo(() => {
        const lat = parseFloat(coordinates?.lat);
        const lng = parseFloat(coordinates?.lng);
        const hasValid = !isNaN(lat) && !isNaN(lng);
        return {
            lat: hasValid ? lat : DEFAULT_COORDS.lat,
            lng: hasValid ? lng : DEFAULT_COORDS.lng,
            hasValid
        };
    }, [coordinates]);

    if (!open) return null;

    return (
        <Modal
            title={`Xəritə: ${warehouseName || 'Anbar'}`}
            open={open}
            onCancel={onClose}
            footer={null}
            width={600}
            className={styles.locationModal}
            destroyOnClose
        >
            <div className={styles.mapContainer}>
                {validCoords.hasValid ? (
                    <MapContainer
                        center={[validCoords.lat, validCoords.lng]}
                        zoom={15}
                        style={{ height: '100%', width: '100%' }}
                    >
                        <TileLayer
                            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                        />
                        <SafeMarker lat={validCoords.lat} lng={validCoords.lng} />
                        <MapReadyHandler lat={validCoords.lat} lng={validCoords.lng} />
                    </MapContainer>
                ) : (
                    <div className={styles.noLocation}>
                        Koordinat təyin edilməyib
                    </div>
                )}
            </div>
        </Modal>
    );
};

export default LocationViewModal;
