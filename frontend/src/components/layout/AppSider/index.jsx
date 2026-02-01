import React from 'react';
import { Layout, Menu, Drawer } from 'antd';
import { TeamOutlined, ShopOutlined, SettingOutlined, FileTextOutlined, GlobalOutlined, BellOutlined, FolderOutlined, HomeOutlined, BarChartOutlined } from '@ant-design/icons';
import styles from './style.module.scss';
import logo from '../../../assets/logo.svg';
import { hasPermission } from '../../../utils/permissions';
import { useAuth } from '../../../context/AuthContext';

const { Sider } = Layout;

const AppSider = ({ collapsed, mobileOpen, setMobileOpen, location, navigate }) => {
    const menuItems = [
        {
            key: '/',
            icon: <HomeOutlined />,
            label: 'Ana səhifə',
            // permissions can be empty if accessible to all, or matching user capabilities. 
            // Since it's a dashboard, surely everyone should see it.
        },
        {
            key: '/performance',
            icon: <BarChartOutlined />,
            label: 'Performans',
        },
        {
            key: '/tasks',
            icon: <FileTextOutlined />,
            label: 'Tapşırıqlar',
            permission: ['is_task_reader', 'is_task_writer']
        },
        {
            key: '/map',
            icon: <GlobalOutlined />,
            label: 'Xəritə',
            permission: ['is_task_reader', 'is_task_writer'] // Assuming map requires task access
        },
        {
            key: '/users',
            icon: <TeamOutlined />,
            label: 'İstifadəçilər',
            permission: ['is_admin', 'is_super_admin'] // Assuming only admins manage users
        },
        {
            key: '/warehouse',
            icon: <ShopOutlined />,
            label: 'Anbar',
            permission: ['is_warehouse_reader', 'is_warehouse_writer']
        },
        {
            key: '/documents',
            icon: <FolderOutlined />,
            label: 'Sənədlər',
            permission: ['is_document_reader', 'is_document_writer']
        },
        {
            key: '/admin',
            icon: <SettingOutlined />,
            label: 'Admin',
            permission: ['is_admin', 'is_super_admin']
        },
    ];

    const { user } = useAuth();


    const filteredItems = menuItems.filter(item => {
        if (!item.permission) return true;
        return hasPermission(user, item.permission);
    });

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
                    items={filteredItems}
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
                    items={filteredItems}
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
