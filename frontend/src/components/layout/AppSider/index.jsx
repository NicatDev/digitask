import React from 'react';
import { Layout, Menu, Drawer } from 'antd';
import { TeamOutlined, ShopOutlined, SettingOutlined, FileTextOutlined, GlobalOutlined, BellOutlined } from '@ant-design/icons';
import styles from './style.module.scss';
import logo from '../../../assets/logo.svg';

const { Sider } = Layout;

const AppSider = ({ collapsed, mobileOpen, setMobileOpen, location, navigate }) => {
    const menuItems = [
        {
            key: '/tasks',
            icon: <FileTextOutlined />,
            label: 'Tapşırıqlar',
        },
        {
            key: '/map',
            icon: <GlobalOutlined />,
            label: 'Xəritə',
        },
        {
            key: '/users',
            icon: <TeamOutlined />,
            label: 'İstifadəçilər',
        },
        {
            key: '/warehouse',
            icon: <ShopOutlined />,
            label: 'Anbar',
        },
        {
            key: '/notifications',
            icon: <BellOutlined />,
            label: 'Bildirişlər',
        },
        {
            key: '/admin',
            icon: <SettingOutlined />,
            label: 'Admin',
        },
    ];

    return (
        <>
            <Sider
                trigger={null}
                collapsible
                collapsed={collapsed}
                className={styles.desktopSider}
                breakpoint="lg"
                collapsedWidth="80"
                width={260}
                theme="light"
            >
                <div className={styles.logoContainer}>
                    <img src={logo} alt="Logo" className={styles.logoImage} />
                    {!collapsed && <div className={styles.logoText}>Digitask</div>}
                </div>
                <Menu
                    theme="light"
                    mode="inline"
                    selectedKeys={[location.pathname]}
                    items={menuItems}
                    onClick={({ key }) => navigate(key)}
                />
            </Sider>

            <Drawer
                placement="left"
                onClose={() => setMobileOpen(false)}
                open={mobileOpen}
                className={styles.mobileDrawer}
                styles={{ body: { padding: 0 } }}
                width={260}
            >
                <div className={`${styles.logoContainer} ${styles.mobile}`}>
                    <img src={logo} alt="Logo" className={styles.logoImage} />
                    <div className={styles.logoText}>Digitask</div>
                </div>
                <Menu
                    theme="light"
                    mode="inline"
                    selectedKeys={[location.pathname]}
                    items={menuItems}
                    onClick={({ key }) => {
                        navigate(key);
                        setMobileOpen(false);
                    }}
                />
            </Drawer>
        </>
    );
};

export default AppSider;
