import React, { useEffect, useState } from 'react';
import { Modal, Spin } from 'antd';
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from 'react-leaflet';
import L from 'leaflet';
import axiosInstance from '../../../../axios';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';

dayjs.extend(relativeTime);

// Fix Leaflet Default Icon
import iconUrl from 'leaflet/dist/images/marker-icon.png';
import iconShadow from 'leaflet/dist/images/marker-shadow.png';

let DefaultIcon = L.icon({
    iconUrl: iconUrl,
    shadowUrl: iconShadow,
    iconSize: [25, 41],
    iconAnchor: [12, 41]
});
L.Marker.prototype.options.icon = DefaultIcon;

// Route colors palette
const ROUTE_COLORS = ['#52c41a', '#1890ff', '#722ed1', '#eb2f96', '#fa8c16', '#13c2c2', '#f5222d'];

const MapResizer = () => {
    const map = useMap();
    useEffect(() => {
        setTimeout(() => map.invalidateSize(), 100);
    }, [map]);
    return null;
};

// Fly to user location component
const FlyToUser = ({ lat, lng }) => {
    const map = useMap();
    useEffect(() => {
        if (lat && lng && !isNaN(lat) && !isNaN(lng)) {
            setTimeout(() => {
                map.flyTo([lat, lng], 14, { duration: 1.5 });
            }, 200);
        }
    }, [lat, lng, map]);
    return null;
};

// Check if user was online in last 10 minutes
const isRecentlyOnline = (userData) => {
    if (userData?.is_online) return true;
    if (!userData?.last_seen) return false;
    const lastSeen = dayjs(userData.last_seen);
    const tenMinutesAgo = dayjs().subtract(10, 'minute');
    return lastSeen.isAfter(tenMinutesAgo);
};

// Custom SVG Icons with name label
const createUserIconWithName = (isActiveOrRecent, name) => {
    const firstName = name?.split(' ')[0] || 'User';
    return L.divIcon({
        className: 'custom-user-icon',
        html: `
            <div style="display: flex; flex-direction: column; align-items: center;">
                <div style="
                    width: 34px; 
                    height: 34px; 
                    display: flex; 
                    align-items: center; 
                    justify-content: center;
                    filter: drop-shadow(2px 2px 2px rgba(0,0,0,0.3));
                ">
                    <svg viewBox="0 0 22 22" width="34" height="34" fill="${isActiveOrRecent ? '#52c41a' : '#8c8c8c'}">
                        <circle cx="12" cy="8" r="4"/>
                        <path d="M12 14c-6 0-8 3-8 6v2h16v-2c0-3-2-6-8-6z"/>
                    </svg>
                </div>
                <div style="
                    background: white; 
                    padding: 2px 6px; 
                    border-radius: 4px; 
                    font-size: 11px; 
                    font-weight: bold;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.3);
                    white-space: nowrap;
                    margin-top: 5px;
                ">${firstName}</div>
            </div>
        `,
        iconSize: [50, 55],
        iconAnchor: [25, 40]
    });
};

// Customer/House Icon with custom color
const getCustomerIcon = (color = '#f5222d') => L.divIcon({
    className: 'custom-customer-icon',
    html: `
        <div style="
            width: 34px; 
            height: 34px; 
            display: flex; 
            align-items: center; 
            justify-content: center;
            filter: drop-shadow(2px 2px 2px rgba(0,0,0,0.3));
        ">
            <svg viewBox="0 0 22 22" width="34" height="34" fill="${color}">
                <path d="M12 3L2 12h3v9h6v-6h2v6h6v-9h3L12 3z"/>
            </svg>
        </div>
    `,
    iconSize: [34, 34],
    iconAnchor: [17, 34]
});

// Warehouse Icon
const getWarehouseIcon = () => L.divIcon({
    className: 'custom-warehouse-icon',
    html: `
        <div style="
            width: 32px; 
            height: 32px; 
            display: flex; 
            align-items: center; 
            justify-content: center;
            filter: drop-shadow(2px 2px 2px rgba(0,0,0,0.3));
        ">
            <svg viewBox="0 0 22 22" width="32" height="32" fill="#faad14">
                <path d="M22 21V7L12 3 2 7v14h6v-7h8v7h6zM12 12a2 2 0 110-4 2 2 0 010 4z"/>
            </svg>
        </div>
    `,
    iconSize: [32, 32],
    iconAnchor: [16, 32]
});

const UserLocationModal = ({ open, onCancel, userId }) => {
    const [userData, setUserData] = useState(null);
    const [historyPath, setHistoryPath] = useState([]);
    const [warehouses, setWarehouses] = useState([]);
    const [routesToCustomers, setRoutesToCustomers] = useState({});
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        if (open && userId) {
            fetchData();
        } else {
            setUserData(null);
            setHistoryPath([]);
            setRoutesToCustomers({});
        }
    }, [open, userId]);

    const fetchData = async () => {
        setLoading(true);
        try {
            const liveRes = await axiosInstance.get('/live-map/');

            const foundUser = liveRes.data.users.find(u => u.user_id === userId);
            setUserData(foundUser);
            setWarehouses(liveRes.data.warehouses || []);

            try {
                const histRes = await axiosInstance.get(`/live-map/${userId}/history/?hours=1`);
                const path = histRes.data.map(h => [parseFloat(h.latitude), parseFloat(h.longitude)]);
                setHistoryPath(path);
            } catch (e) {
                console.error("Could not fetch history", e);
            }

            // Fetch routes for all active tasks
            if (foundUser?.latitude && foundUser?.active_tasks && foundUser.active_tasks.length > 0) {
                const routes = {};
                for (const task of foundUser.active_tasks) {
                    if (task.customer_lat && task.customer_lng) {
                        const route = await fetchOSRMRoute(
                            parseFloat(foundUser.latitude),
                            parseFloat(foundUser.longitude),
                            parseFloat(task.customer_lat),
                            parseFloat(task.customer_lng)
                        );
                        routes[task.id] = route;
                    }
                }
                setRoutesToCustomers(routes);
            }

        } catch (e) {
            console.error("Error fetching user location data", e);
        } finally {
            setLoading(false);
        }
    };

    const fetchOSRMRoute = async (startLat, startLng, endLat, endLng) => {
        try {
            if (isNaN(startLat) || isNaN(startLng) || isNaN(endLat) || isNaN(endLng)) {
                return [[startLat, startLng], [endLat, endLng]];
            }
            const url = `https://router.project-osrm.org/route/v1/driving/${startLng},${startLat};${endLng},${endLat}?overview=full&geometries=geojson`;

            const response = await fetch(url);
            const data = await response.json();

            if (data.routes && data.routes.length > 0) {
                return data.routes[0].geometry.coordinates.map(coord => [coord[1], coord[0]]);
            }
            return [[startLat, startLng], [endLat, endLng]];
        } catch (e) {
            console.error("OSRM routing error", e);
            return [[startLat, startLng], [endLat, endLng]];
        }
    };

    const userIsActiveOrRecent = isRecentlyOnline(userData);

    return (
        <Modal
            title="İstifadəçi Xəritəsi"
            open={open}
            onCancel={onCancel}
            footer={null}
            width={900}
            destroyOnHidden
        >
            <Spin spinning={loading}>
                <div style={{ height: '550px', width: '100%' }}>
                    <MapContainer
                        center={[40.4093, 49.8671]}
                        zoom={13}
                        style={{ height: '100%', width: '100%' }}
                    >
                        <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
                        <MapResizer />

                        {/* Fly to user when data loads */}
                        {userData?.latitude && userData?.longitude && !isNaN(parseFloat(userData.latitude)) && !isNaN(parseFloat(userData.longitude)) &&
                            <FlyToUser lat={parseFloat(userData.latitude)} lng={parseFloat(userData.longitude)} />
                        }

                        {warehouses.map(w => {
                            const lat = parseFloat(w.lat);
                            const lng = parseFloat(w.lng);
                            if (isNaN(lat) || isNaN(lng)) return null;

                            return (
                                <Marker key={`w-${w.id}`} position={[lat, lng]} icon={getWarehouseIcon()}>
                                    <Popup><strong>Anbar:</strong> {w.name}</Popup>
                                </Marker>
                            );
                        })}

                        {userData && userData.latitude && userData.longitude && !isNaN(parseFloat(userData.latitude)) && !isNaN(parseFloat(userData.longitude)) && (
                            <Marker
                                position={[parseFloat(userData.latitude), parseFloat(userData.longitude)]}
                                icon={createUserIconWithName(userIsActiveOrRecent, userData.full_name)}
                                zIndexOffset={100}
                            >
                                <Popup>
                                    <strong>{userData.full_name}</strong><br />
                                    {userData.is_online
                                        ? "🟢 Online"
                                        : userIsActiveOrRecent
                                            ? `🟢 Son 10 dəqiqədə aktiv (${dayjs(userData.last_seen).fromNow()})`
                                            : `🔴 Offline (${dayjs(userData.last_seen).fromNow()})`
                                    }
                                </Popup>
                            </Marker>
                        )}

                        {historyPath.length > 0 && (
                            <Polyline
                                positions={historyPath}
                                pathOptions={{ color: '#1890ff', weight: 4, opacity: 0.7, dashArray: '5, 10' }}
                            />
                        )}

                        {/* Customer Markers & Routes for all active tasks */}
                        {userData?.active_tasks && userData.active_tasks.map((task, taskIdx) => {
                            const lat = parseFloat(task.customer_lat);
                            const lng = parseFloat(task.customer_lng);

                            if (isNaN(lat) || isNaN(lng)) return null;

                            const routeColor = ROUTE_COLORS[taskIdx % ROUTE_COLORS.length];
                            return (
                                <React.Fragment key={`task-${task.id}`}>
                                    <Marker
                                        position={[lat, lng]}
                                        icon={getCustomerIcon(routeColor)}
                                    >
                                        <Popup>
                                            <strong>🏠 Müştəri:</strong> {task.customer_name}<br />
                                            {task.customer_address}
                                        </Popup>
                                    </Marker>

                                    {routesToCustomers[task.id] && routesToCustomers[task.id].length > 0 && (
                                        <Polyline
                                            positions={routesToCustomers[task.id]}
                                            pathOptions={{ color: routeColor, weight: 5, opacity: 0.8 }}
                                        />
                                    )}
                                </React.Fragment>
                            );
                        })}

                    </MapContainer>
                </div>
            </Spin>
        </Modal>
    );
};

export default UserLocationModal;
