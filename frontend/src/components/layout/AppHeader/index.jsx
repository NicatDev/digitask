import React from 'react';
import { Layout, Button, Avatar, Dropdown, Space, Typography, Badge } from 'antd';
import {
    MenuFoldOutlined,
    MenuUnfoldOutlined,
    UserOutlined,
    LogoutOutlined,
    BellOutlined,
    MessageOutlined,
    DownOutlined
} from '@ant-design/icons';
import { useAuth } from '../../../context/AuthContext';
import { useNotifications } from '../../../context/NotificationContext';
import styles from './style.module.scss';

import { useNavigate } from 'react-router-dom';
import { useEffect, useState, useRef } from 'react';

const { Header } = Layout;
const { Text } = Typography;

const AppHeader = ({ collapsed, setCollapsed, mobileOpen, setMobileOpen }) => {
    const { user, logout } = useAuth();
    const { unreadCount } = useNotifications();
    const navigate = useNavigate();
    const [chatUnreadCount, setChatUnreadCount] = useState(0);
    const ws = useRef(null);

    useEffect(() => {
        if (user) {
            connectNotificationWS();
        }
        return () => {
            if (ws.current) ws.current.close();
        };
    }, [user]);

    const connectNotificationWS = () => {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const host = window.location.hostname;
        const port = '8000';
        const token = localStorage.getItem('access_token');
        const url = `${protocol}//${host}:${port}/ws/chat/notifications/?token=${token}`;

        ws.current = new WebSocket(url);

        ws.current.onopen = () => {
            console.log("Connected to Notification WS");
        };

        ws.current.onmessage = (event) => {
            const data = JSON.parse(event.data);
            if (data.type === 'unread_count') {
                setChatUnreadCount(data.count);
            }
        };
    };


    const items = [
        {
            key: 'profile',
            label: 'Profil',
            icon: <UserOutlined />,
        },
        {
            key: 'logout',
            label: 'Çıxış',
            icon: <LogoutOutlined />,
            onClick: logout,
            danger: true
        },
    ];

    return (
        <Header className={styles.siteHeader}>
            <div className={styles.headerLeft}>
                <Button
                    type="text"
                    icon={mobileOpen ? <MenuFoldOutlined /> : <MenuUnfoldOutlined />}
                    onClick={() => setMobileOpen(!mobileOpen)}
                    className={styles.mobileTrigger}
                />

                <Button
                    type="text"
                    icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
                    onClick={() => setCollapsed(!collapsed)}
                    className={styles.desktopTrigger}
                />
            </div>

            <div className={styles.headerRight}>
                <Space size="large">
                    {/* Chat Messages */}
                    <div style={{ position: 'relative', cursor: 'pointer' }} onClick={() => navigate('/chat')}>
                        <Button type="text" icon={<MessageOutlined />} />
                        {chatUnreadCount > 0 && (
                            <div style={{
                                position: 'absolute',
                                top: 4,
                                right: 6,
                                background: '#ff4d4f',
                                color: '#fff',
                                borderRadius: '10px',
                                padding: '0 5px',
                                fontSize: '10px',
                                lineHeight: '16px',
                                minWidth: '16px',
                                textAlign: 'center'
                            }}>
                                {chatUnreadCount}
                            </div>
                        )}
                    </div>

                    {/* Notifications */}
                    <Badge count={unreadCount} size="small">
                        <Button
                            type="text"
                            icon={<BellOutlined />}
                            onClick={() => navigate('/notifications')}
                        />
                    </Badge>

                    <Dropdown menu={{ items }} trigger={['click']}>
                        <Space className={styles.userDropdownTrigger} style={{ cursor: 'pointer' }}>
                            <Avatar src={user?.avatar} icon={<UserOutlined />} />
                            <span className={styles.username}>{user?.first_name || user?.username}</span>
                            <DownOutlined />
                        </Space>
                    </Dropdown>
                </Space>
            </div>
        </Header>
    );
};

export default AppHeader;
