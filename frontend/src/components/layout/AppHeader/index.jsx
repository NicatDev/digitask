import React from 'react';
import { Layout, Button, Avatar, Dropdown, Space, Typography, Badge } from 'antd';
import {
    MenuFoldOutlined,
    MenuUnfoldOutlined,
    UserOutlined,
    LogoutOutlined,
    BellOutlined,
    MessageOutlined,
    DownOutlined,
    AndroidOutlined
} from '@ant-design/icons';
import { useAuth } from '../../../context/AuthContext';
import { hasPermission } from '../../../utils/permissions';
import styles from './style.module.scss';

import { useNavigate } from 'react-router-dom';
import { useEffect, useState, useRef } from 'react';
import { useNotifications } from '../../../context/NotificationContext';
const { Header } = Layout;
const { Text } = Typography;

const AppHeader = ({ collapsed, setCollapsed, mobileOpen, setMobileOpen }) => {
    const { user, logout } = useAuth();
    const { unreadCount, chatUnreadCount } = useNotifications();
    const navigate = useNavigate();


    const items = [
        {
            key: 'profile',
            label: 'Profil',
            icon: <UserOutlined />,
            onClick: () => navigate('/profile')
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
                    {/* Android APK Download */}
                    <Button
                        type="text"
                        icon={<AndroidOutlined style={{ color: '#3DDC84', fontSize: '18px' }} />}
                        onClick={() => window.open('/app-release.apk', '_blank')}
                        title="Android APK Yüklə"
                    />

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
