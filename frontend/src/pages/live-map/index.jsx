import React, { useEffect, useState, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from 'react-leaflet';
import { Input, List, Card, Badge, message, Collapse, Tag } from 'antd';
import { UserOutlined, ShopOutlined, SearchOutlined } from '@ant-design/icons';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import styles from './style.module.scss';
import axiosInstance from '../../axios';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';

dayjs.extend(relativeTime);

// Fix Leaflet Default Icon
import icon from 'leaflet/dist/images/marker-icon.png';
import iconShadow from 'leaflet/dist/images/marker-shadow.png';

let DefaultIcon = L.icon({
    iconUrl: icon,
    shadowUrl: iconShadow,
    iconSize: [25, 41],
    iconAnchor: [12, 41]
});
L.Marker.prototype.options.icon = DefaultIcon;

const MapInvalidator = () => {
    const map = useMap();
    useEffect(() => {
        setTimeout(() => {
            map.invalidateSize();
        }, 100);
    }, []);
    return null;
};

// Fly to location component
const FlyToLocation = ({ coords, trigger }) => {
    const map = useMap();
    useEffect(() => {
        if (coords && trigger) {
            map.flyTo([coords.lat, coords.lng], 16, { duration: 1.2 });
        }
    }, [coords, trigger, map]);
    return null;
};

// Check if user was online in last 10 minutes
const isRecentlyOnline = (user) => {
    if (user?.is_online) return true;
    if (!user?.last_seen) return false;
    const lastSeen = dayjs(user.last_seen);
    const tenMinutesAgo = dayjs().subtract(10, 'minute');
    return lastSeen.isAfter(tenMinutesAgo);
};

// Custom User Icon with name label
const createUserIconWithName = (isOnline, name) => {
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
                    <svg viewBox="0 0 22 22" width="34" height="34" fill="${isOnline ? '#52c41a' : '#8c8c8c'}">
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
                    margin-top: -5px;
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

// Route colors palette
const ROUTE_COLORS = ['#52c41a', '#1890ff', '#722ed1', '#eb2f96', '#fa8c16', '#13c2c2', '#f5222d'];

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

const LiveMap = () => {
    const [users, setUsers] = useState([]);
    const [warehouses, setWarehouses] = useState([]);
    const [userRoutes, setUserRoutes] = useState({});
    const [searchText, setSearchText] = useState('');
    const [flyTarget, setFlyTarget] = useState(null);
    const [flyTrigger, setFlyTrigger] = useState(0);
    const ws = useRef(null);

    useEffect(() => {
        fetchInitialData();
        connectWebSocket();
        return () => {
            if (ws.current) ws.current.close();
        };
    }, []);

    const fetchInitialData = async () => {
        try {
            const res = await axiosInstance.get('/live-map/');
            const usersData = res.data.users || [];
            setUsers(usersData);
            setWarehouses(res.data.warehouses || []);

            // Fetch routes for all active tasks
            usersData.forEach(u => {
                if (u.latitude && u.active_tasks && u.active_tasks.length > 0) {
                    u.active_tasks.forEach((task, idx) => {
                        if (task.customer_lat && task.customer_lng) {
                            fetchOSRMRoute(
                                `${u.user_id}_${task.id}`,
                                parseFloat(u.latitude),
                                parseFloat(u.longitude),
                                parseFloat(task.customer_lat),
                                parseFloat(task.customer_lng)
                            );
                        }
                    });
                }
            });
        } catch (e) {
            console.error("Failed to fetch map data", e);
        }
    };

    const fetchOSRMRoute = async (routeKey, startLat, startLng, endLat, endLng) => {
        try {
            // Ensure all values are valid numbers
            if (isNaN(startLat) || isNaN(startLng) || isNaN(endLat) || isNaN(endLng)) {
                console.error("Invalid coordinates for route", routeKey);
                return;
            }
            const url = `https://router.project-osrm.org/route/v1/driving/${startLng},${startLat};${endLng},${endLat}?overview=full&geometries=geojson`;
            const response = await fetch(url);
            const data = await response.json();

            if (data.routes && data.routes.length > 0) {
                const coordinates = data.routes[0].geometry.coordinates.map(coord => [coord[1], coord[0]]);
                setUserRoutes(prev => ({ ...prev, [routeKey]: coordinates }));
            }
        } catch (e) {
            console.error("OSRM routing error for", routeKey, e);
            setUserRoutes(prev => ({ ...prev, [routeKey]: [[startLat, startLng], [endLat, endLng]] }));
        }
    };

    const connectWebSocket = () => {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const host = window.location.hostname;
        const port = '8000';
        const token = localStorage.getItem('access_token');
        const url = `${protocol}//${host}:${port}/ws/tracking/?token=${token}`;

        ws.current = new WebSocket(url);

        ws.current.onmessage = (event) => {
            const data = JSON.parse(event.data);
            if (data.type === 'location_message') {
                handleUserUpdate(data);
            }
        };
    };

    const handleUserUpdate = (data) => {
        setUsers(prev => {
            const idx = prev.findIndex(u => u.user_id === data.user_id);
            if (idx > -1) {
                const updated = [...prev];
                const oldUser = updated[idx];
                updated[idx] = {
                    ...oldUser,
                    latitude: data.latitude,
                    longitude: data.longitude,
                    is_online: data.is_online,
                    last_seen: new Date().toISOString()
                };

                // Update routes for all active tasks
                if (oldUser.active_tasks && oldUser.active_tasks.length > 0) {
                    oldUser.active_tasks.forEach(task => {
                        if (task.customer_lat && task.customer_lng) {
                            fetchOSRMRoute(
                                `${data.user_id}_${task.id}`,
                                parseFloat(data.latitude),
                                parseFloat(data.longitude),
                                parseFloat(task.customer_lat),
                                parseFloat(task.customer_lng)
                            );
                        }
                    });
                }

                return updated;
            }
            return prev;
        });
    };

    const handleUserClick = (user) => {
        if (user.latitude && user.longitude) {
            setFlyTarget({ lat: user.latitude, lng: user.longitude });
            setFlyTrigger(prev => prev + 1);
        } else {
            message.info(`${user.full_name} üçün ünvan məlumatı yoxdur`);
        }
    };

    const handleWarehouseClick = (warehouse) => {
        if (warehouse.lat && warehouse.lng) {
            setFlyTarget({ lat: warehouse.lat, lng: warehouse.lng });
            setFlyTrigger(prev => prev + 1);
        }
    };

    const filteredUsers = users.filter(u =>
        u.full_name?.toLowerCase().includes(searchText.toLowerCase())
    );

    const collapseItems = [
        {
            key: 'users',
            label: (
                <span>
                    <UserOutlined style={{ marginRight: 8 }} />
                    İstifadəçilər ({users.length})
                </span>
            ),
            children: (
                <List
                    size="small"
                    dataSource={filteredUsers}
                    renderItem={user => {
                        const hasLocation = user.latitude && user.longitude;
                        return (
                            <List.Item
                                onClick={() => handleUserClick(user)}
                                style={{
                                    cursor: 'pointer',
                                    padding: '8px 12px',
                                    borderRadius: '4px',
                                    marginBottom: '4px',
                                    background: '#fafafa'
                                }}
                                className={styles.listItem}
                            >
                                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', width: '100%' }}>
                                    <Badge status={user.is_online ? 'success' : 'default'} />
                                    <span style={{
                                        color: hasLocation ? '#333' : '#bfbfbf',
                                        fontWeight: hasLocation ? 500 : 400
                                    }}>
                                        {user.full_name}
                                    </span>
                                    {!hasLocation && (
                                        <Tag color="default" style={{ fontSize: 10, marginLeft: 'auto' }}>GPS yoxdur</Tag>
                                    )}
                                </div>
                            </List.Item>
                        );
                    }}
                />
            )
        },
        {
            key: 'warehouses',
            label: (
                <span>
                    <ShopOutlined style={{ marginRight: 8 }} />
                    Anbarlar ({warehouses.length})
                </span>
            ),
            children: (
                <List
                    size="small"
                    dataSource={warehouses}
                    renderItem={warehouse => (
                        <List.Item
                            onClick={() => handleWarehouseClick(warehouse)}
                            style={{
                                cursor: 'pointer',
                                padding: '8px 12px',
                                borderRadius: '4px',
                                marginBottom: '4px',
                                background: '#fffbe6'
                            }}
                            className={styles.listItem}
                        >
                            <span style={{ fontWeight: 500 }}>📦 {warehouse.name}</span>
                        </List.Item>
                    )}
                />
            )
        }
    ];

    return (
        <div className={styles.container}>
            {/* Sidebar */}
            <div className={styles.sidebar}>
                <Card size="small" title="Xəritə Paneli" style={{ marginBottom: 16 }}>
                    <Input
                        prefix={<SearchOutlined />}
                        placeholder="İstifadəçi axtar..."
                        value={searchText}
                        onChange={e => setSearchText(e.target.value)}
                        allowClear
                    />
                </Card>
                <Collapse items={collapseItems} defaultActiveKey={['users', 'warehouses']} />
            </div>

            {/* Map */}
            <div className={styles.mapWrapper}>
                <MapContainer center={[40.4093, 49.8671]} zoom={12} style={{ height: '100%', width: '100%' }}>
                    <TileLayer
                        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                    />
                    <MapInvalidator />
                    <FlyToLocation coords={flyTarget} trigger={flyTrigger} />

                    {/* Warehouses */}
                    {warehouses.map(w => (
                        <Marker key={`w-${w.id}`} position={[w.lat, w.lng]} icon={getWarehouseIcon()}>
                            <Popup><strong>Anbar:</strong> {w.name}</Popup>
                        </Marker>
                    ))}

                    {/* Users */}
                    {users.map(u => {
                        if (!u.latitude || !u.longitude) return null;
                        const userIsActiveOrRecent = isRecentlyOnline(u);
                        return (
                            <React.Fragment key={`u-${u.user_id}`}>
                                <Marker
                                    position={[parseFloat(u.latitude), parseFloat(u.longitude)]}
                                    icon={createUserIconWithName(userIsActiveOrRecent, u.full_name)}
                                >
                                    <Popup>
                                        <strong>{u.full_name}</strong><br />
                                        {u.role}<br />
                                        {u.is_online
                                            ? <span style={{ color: 'green' }}>🟢 Online</span>
                                            : userIsActiveOrRecent
                                                ? <span style={{ color: 'green' }}>🟢 Son 10 dəq aktiv ({dayjs(u.last_seen).fromNow()})</span>
                                                : <span style={{ color: 'red' }}>🔴 Offline {dayjs(u.last_seen).fromNow()}</span>
                                        }
                                    </Popup>
                                </Marker>

                                {/* Customer Markers & Routes for all active tasks */}
                                {u.active_tasks && u.active_tasks.map((task, taskIdx) => {
                                    const routeColor = ROUTE_COLORS[taskIdx % ROUTE_COLORS.length];
                                    const routeKey = `${u.user_id}_${task.id}`;
                                    return (
                                        <React.Fragment key={`task-${task.id}`}>
                                            <Marker
                                                position={[parseFloat(task.customer_lat), parseFloat(task.customer_lng)]}
                                                icon={getCustomerIcon(routeColor)}
                                            >
                                                <Popup>
                                                    <strong>🏠 Müştəri:</strong> {task.customer_name}<br />
                                                    {task.customer_address}
                                                </Popup>
                                            </Marker>

                                            {userRoutes[routeKey] && userRoutes[routeKey].length > 0 && (
                                                <Polyline
                                                    positions={userRoutes[routeKey]}
                                                    pathOptions={{ color: routeColor, weight: 5, opacity: 0.8 }}
                                                />
                                            )}
                                        </React.Fragment>
                                    );
                                })}
                            </React.Fragment>
                        );
                    })}
                </MapContainer>
            </div>
        </div >
    );
};

export default LiveMap;
