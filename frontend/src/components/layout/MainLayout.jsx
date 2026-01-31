import { Layout, Grid } from 'antd';
import { useNavigate, useLocation, Outlet } from 'react-router-dom';
import AppSider from './AppSider';
import AppHeader from './AppHeader';
import styles from './style.module.scss';
import { useState, useEffect, useRef } from 'react';
const { Content } = Layout;
const { useBreakpoint } = Grid;

const MainLayout = () => {
    const [collapsed, setCollapsed] = useState(false);
    const [mobileOpen, setMobileOpen] = useState(false);
    const navigate = useNavigate();
    const location = useLocation();
    const screens = useBreakpoint();
    const trackingWs = useRef(null);
    const watchId = useRef(null);

    // Connect to tracking WebSocket globally to maintain online status
    useEffect(() => {
        connectTrackingWebSocket();
        startLocationTracking();

        return () => {
            if (trackingWs.current) {
                trackingWs.current.close();
            }
            if (watchId.current) {
                navigator.geolocation.clearWatch(watchId.current);
            }
        };
    }, []);

    const connectTrackingWebSocket = () => {
        const token = localStorage.getItem('access_token');
        if (!token) return;

        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const host = window.location.hostname;
        const port = '8000';
        const url = `${protocol}//${host}:${port}/ws/tracking/?token=${token}`;

        trackingWs.current = new WebSocket(url);

        trackingWs.current.onopen = () => {
            console.log('Tracking WebSocket connected - user is now online');
        };

        trackingWs.current.onclose = () => {
            console.log('Tracking WebSocket disconnected');
            // Attempt to reconnect after 5 seconds
            setTimeout(() => {
                if (localStorage.getItem('access_token')) {
                    connectTrackingWebSocket();
                }
            }, 5000);
        };

        trackingWs.current.onerror = (err) => {
            console.error('Tracking WebSocket error', err);
        };
    };

    const startLocationTracking = () => {
        if (navigator.geolocation) {
            watchId.current = navigator.geolocation.watchPosition(
                (pos) => {
                    const { latitude, longitude } = pos.coords;

                    if (trackingWs.current && trackingWs.current.readyState === WebSocket.OPEN) {
                        trackingWs.current.send(JSON.stringify({
                            type: 'location_update',
                            latitude,
                            longitude
                        }));
                    }
                },
                (err) => console.error('Geolocation error:', err),
                { enableHighAccuracy: true, timeout: 20000, maximumAge: 5000 }
            );
        }
    };

    const handleLogout = () => {
        if (trackingWs.current) {
            trackingWs.current.close();
        }
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        navigate('/login');
    };

    const marginLeft = !screens.lg ? 0 : (collapsed ? 80 : 260);

    return (
        <Layout className={styles.mainLayout}>
            <AppSider
                collapsed={collapsed}
                mobileOpen={mobileOpen}
                setMobileOpen={setMobileOpen}
                location={location}
                navigate={navigate}
            />

            <Layout
                style={{
                    marginLeft: marginLeft,
                    transition: 'margin-left 0.2s',
                    background: '#f5f5f5'
                }}
                className={styles.contentLayout}
            >
                <AppHeader
                    collapsed={collapsed}
                    setCollapsed={setCollapsed}
                    mobileOpen={mobileOpen}
                    setMobileOpen={setMobileOpen}
                    handleLogout={handleLogout}
                />

                <Content className={styles.mainContent}>
                    <Outlet />
                </Content>
            </Layout>
        </Layout>
    );
};

export default MainLayout;
