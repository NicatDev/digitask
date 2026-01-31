import React, { createContext, useState, useEffect, useContext, useRef } from 'react';
import axiosInstance from '../axios';

const NotificationContext = createContext();

export const NotificationProvider = ({ children }) => {
    const [unreadCount, setUnreadCount] = useState(0);
    const [notifications, setNotifications] = useState([]);
    const ws = useRef(null);

    useEffect(() => {
        const token = localStorage.getItem('access_token');
        if (token) {
            connectWebSocket();
            fetchUnreadCount();
        }

        return () => {
            if (ws.current) {
                ws.current.close();
            }
        };
    }, []);

    const connectWebSocket = () => {
        const token = localStorage.getItem('access_token');
        if (!token) return;

        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const host = window.location.hostname;
        const port = '8000';
        const url = `${protocol}//${host}:${port}/ws/chat/notifications/?token=${token}`;

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
        };

        ws.current.onclose = () => {
            console.log('Notification WebSocket disconnected');
            // Reconnect after 5 seconds
            setTimeout(() => {
                if (localStorage.getItem('access_token')) {
                    connectWebSocket();
                }
            }, 5000);
        };

        ws.current.onerror = (err) => {
            console.error('Notification WebSocket error', err);
        };
    };

    const fetchUnreadCount = async () => {
        try {
            const res = await axiosInstance.get('/tasks/notifications/unread_count/');
            setUnreadCount(res.data.unread_count || 0);
        } catch (e) {
            console.error('Failed to fetch unread count', e);
        }
    };

    const markAllRead = async () => {
        try {
            await axiosInstance.post('/tasks/notifications/mark_read/');
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
            notifications,
            markAllRead,
            refetchCount,
            setNotifications,
            setUnreadCount
        }}>
            {children}
        </NotificationContext.Provider>
    );
};

export const useNotifications = () => useContext(NotificationContext);
