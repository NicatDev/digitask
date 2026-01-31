import React from 'react';
import { useMapEvents } from 'react-leaflet';

const MapClickHandler = ({ onLocationSelect }) => {
    useMapEvents({
        click(e) {
            onLocationSelect({ lat: e.latlng.lat, lng: e.latlng.lng });
        },
    });
    return null;
};

export default MapClickHandler;
