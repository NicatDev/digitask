import React from 'react';
import EventSection from './components/EventSection';
import StatsCharts from './components/StatsCharts';
import styles from './style.module.scss';
import { Typography } from 'antd';

const { Title } = Typography;

const Dashboard = () => {
    return (
        <div className={styles.dashboardPage}>
            <Title level={2}>Ana Səhifə</Title>

            <EventSection />

            <StatsCharts />
        </div>
    );
};

export default Dashboard;
