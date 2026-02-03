import React from 'react';
import EventSection from './components/EventSection';
import TopUsersList from './components/TopUsersList';
import styles from './style.module.scss';


const Dashboard = () => {
    return (
        <div className={styles.dashboardPage}>
            <EventSection />

            <TopUsersList />
        </div>
    );
};

export default Dashboard;
