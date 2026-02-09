import React, { createContext, useState, useEffect, useContext, useRef } from 'react';
import axiosInstance from '../axios';

const NotificationContext = createContext();

export const NotificationProvider = ({ children }) => {
    const [unreadCount, setUnreadCount] = useState(0);
    const [chatUnreadCount, setChatUnreadCount] = useState(0);
    const [notifications, setNotifications] = useState([]);
    const [lastChatNotification, setLastChatNotification] = useState(null);
    const ws = useRef(null);
    const reconnectTimeout = useRef(null);

    useEffect(() => {
        const token = localStorage.getItem('access_token');
        if (token) {
            connectWebSocket();
            fetchUnreadCount();
        }

        return () => {
            if (ws.current) {
                // Prevent reconnect on unmount
                ws.current.onclose = null;
                ws.current.close();
            }
            if (reconnectTimeout.current) {
                clearTimeout(reconnectTimeout.current);
            }
        };
    }, []);

    const connectWebSocket = () => {
        const token = localStorage.getItem('access_token');
        if (!token) return;

        // Prevent multiple connections
        if (ws.current && (ws.current.readyState === WebSocket.OPEN || ws.current.readyState === WebSocket.CONNECTING)) {
            return;
        }

        // Use dynamic base URL based on environment
        const isProduction = window.location.hostname === 'new.digitask.store' ||
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
                // New notification received
                setUnreadCount(prev => prev + 1);
                setNotifications(prev => [data.notification, ...prev]);
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
