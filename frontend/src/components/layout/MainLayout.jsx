import { Layout, Grid } from 'antd';
import { useNavigate, useLocation, Outlet } from 'react-router-dom';
import AppSider from './AppSider';
import AppHeader from './AppHeader';
import styles from './style.module.scss';
import { useState } from 'react';
const { Content } = Layout;
const { useBreakpoint } = Grid;

const MainLayout = () => {
    const [collapsed, setCollapsed] = useState(false);
    const [mobileOpen, setMobileOpen] = useState(false);
    const navigate = useNavigate();
    const location = useLocation();
    const screens = useBreakpoint();

    const handleLogout = () => {
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        navigate('/login');
    };

    // If screen is small (xs/mobile), margin should be 0 because Sider is hidden/Drawer
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
