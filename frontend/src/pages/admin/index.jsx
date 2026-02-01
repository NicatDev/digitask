import React, { useState } from 'react';
import { Tabs, Typography } from 'antd';
import ServiceTab from './components/ServiceTab';
import ColumnTab from './components/ColumnTab';

import styles from './style.module.scss';
import TaskTypeTab from './components/TaskTypeTab';

const { Title } = Typography;

const Admin = () => {
    const [activeTab, setActiveTab] = useState('1');

    const items = [
        {
            key: '1',
            label: 'Servislər',
            children: <ServiceTab isActive={activeTab === '1'} />,
        },
        {
            key: '2',
            label: 'Sütunlar',
            children: <ColumnTab isActive={activeTab === '2'} />,
        },
        {
            key: '3',
            label: 'Tapşırıq Növləri',
            children: <TaskTypeTab isActive={activeTab === '3'} />,
        },
    ];

    const onChange = (key) => {
        setActiveTab(key);
    };

    return (
        <div className={styles.adminPage}>
            <Title level={2}>Admin Panel</Title>
            <Tabs defaultActiveKey="1" items={items} onChange={onChange} />
        </div>
    );
};

export default Admin;
