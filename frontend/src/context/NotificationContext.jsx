import React, { createContext, useState, useEffect, useContext, useRef } from 'react';
import axiosInstance from '../axios';
import { notification } from 'antd';
import { useAuth } from './AuthContext';
import { initWebFcm } from '../services/webFcm';

const NotificationContext = createContext();

export const NotificationProvider = ({ children }) => {
    const { user, loading: authLoading } = useAuth();
    const [unreadCount, setUnreadCount] = useState(0);
    const [chatUnreadCount, setChatUnreadCount] = useState(0);
    const [notifications, setNotifications] = useState([]);
    const [lastChatNotification, setLastChatNotification] = useState(null);
    const ws = useRef(null);
    const reconnectTimeout = useRef(null);

    useEffect(() => {
        if (authLoading) return;

        const token = localStorage.getItem('access_token');
        if (!token || !user) {
            if (ws.current) {
                ws.current.onclose = null;
                ws.current.close();
                ws.current = null;
            }
            if (reconnectTimeout.current) {
                clearTimeout(reconnectTimeout.current);
                reconnectTimeout.current = null;
            }
            return;
        }

        connectWebSocket();
        fetchUnreadCount();
        initWebFcm().catch((e) => console.warn('[FCM Web] init', e));

        return () => {
            if (ws.current) {
                ws.current.onclose = null;
                ws.current.close();
                ws.current = null;
            }
            if (reconnectTimeout.current) {
                clearTimeout(reconnectTimeout.current);
                reconnectTimeout.current = null;
            }
        };
    }, [authLoading, user?.id]);

    const connectWebSocket = () => {
        const token = localStorage.getItem('access_token');
        if (!token) return;

        // Prevent multiple connections
        if (ws.current && (ws.current.readyState === WebSocket.OPEN || ws.current.readyState === WebSocket.CONNECTING)) {
            return;
        }

        // Use dynamic base URL based on environment
        const isProduction = true || window.location.hostname === 'new.digitask.store' ||
            window.location.hostname === 'digitask.store' ||
            window.location.hostname === 'app.digitask.store';
        const wsBase = isProduction ? 'wss://app.digitask.store' : 'ws://127.0.0.1:8000';
        const url = `${wsBase}/ws/notifications/?token=${token}`;

        ws.current = new WebSocket(url);

        ws.current.onopen = () => {
            console.log('Notification WebSocket connected');
        };

        ws.current.onmessage = (event) => {
            const data = JSON.parse(event.data);

            if (data.notification) {
                const incoming = data.notification;
                const isChatNotification = incoming?.notification_type === 'chat_message';

                if (!isChatNotification) {
                    // Keep badge synced with server source of truth.
                    fetchUnreadCount();
                    setNotifications(prev => {
                        const exists = prev.some(item => item.id === incoming.id);
                        return exists ? prev : [incoming, ...prev];
                    });

                    // Persistent toast until user manually closes it.
                    notification.open({
                        key: `notif-${incoming.id}`,
                        message: incoming.title || 'Yeni bildiriş',
                        description: incoming.message || '',
                        placement: 'topRight',
                        duration: 0,
                    });
                }
            }

            if (data.chat_notification) {
                setLastChatNotification(data.chat_notification);
            }

            if (data.type === 'unread_count') {
                setChatUnreadCount(data.count);
            }
        };

        ws.current.onclose = () => {
            console.log('Notification WebSocket disconnected');
            // Reconnect after 5 seconds
            reconnectTimeout.current = setTimeout(() => {
                if (localStorage.getItem('access_token')) {
                    connectWebSocket();
                }
            }, 5000);
        };

        ws.current.onerror = (err) => {
            console.error('Notification WebSocket error', err);
            ws.current.close();
        };
    };

    const fetchUnreadCount = async () => {
        try {
            const res = await axiosInstance.get('/notifications/unread_count/');
            if (res && res.data) {
                setUnreadCount(res.data.unread_count || 0);
            }
        } catch (e) {
            console.error('Failed to fetch unread count', e);
        }
    };

    const markAllRead = async () => {
        try {
            await axiosInstance.post('/notifications/mark_read/');
            setUnreadCount(0);
            setNotifications([]);
            notification.destroy();
        } catch (e) {
            console.error('Failed to mark as read', e);
        }
    };

    const refetchCount = () => {
        fetchUnreadCount();
    };

    return (
        <NotificationContext.Provider value={{
            unreadCount,
            chatUnreadCount,
            notifications,
            markAllRead,
            refetchCount,
            setNotifications,
            setUnreadCount,
            lastChatNotification
        }}>
            {children}
        </NotificationContext.Provider>
    );
};

export const useNotifications = () => useContext(NotificationContext);
