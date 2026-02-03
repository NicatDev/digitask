import React from 'react';
import EventSection from './components/EventSection';
import StatsCharts from './components/StatsCharts';
import styles from './style.module.scss';


const Dashboard = () => {
    return (
        <div className={styles.dashboardPage}>
            <EventSection />

            <StatsCharts />
        </div>
    );
};

export default Dashboard;
