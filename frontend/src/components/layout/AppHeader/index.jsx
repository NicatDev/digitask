import React from 'react';
import { Layout, Button, Avatar, Dropdown, Space, Typography } from 'antd';
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
import styles from './style.module.scss';

const { Header } = Layout;
const { Text } = Typography;

const AppHeader = ({ collapsed, setCollapsed, mobileOpen, setMobileOpen }) => {
    const { user, logout } = useAuth();

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
                    <Button type="text" icon={<MessageOutlined />} />
                    <Button type="text" icon={<BellOutlined />} />
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
