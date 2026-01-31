import React, { useState } from 'react';
import { Tabs, Typography } from 'antd';
import TaskTab from './components/TaskTab';
import CustomerTab from './components/CustomerTab';

import styles from './style.module.scss';

const { Title } = Typography;

const Tasks = () => {
    const [activeTab, setActiveTab] = useState('1');

    const items = [
        {
            key: '1',
            label: 'Tapşırıqlar',
            children: <TaskTab isActive={activeTab === '1'} />,
        },
        {
            key: '2',
            label: 'Müştərilər',
            children: <CustomerTab isActive={activeTab === '2'} />,
        },
    ];

    const onChange = (key) => {
        setActiveTab(key);
    };

    return (
        <div className={styles.tasksPage}>
            <Title level={2}>Tapşırıq İdarəetməsi</Title>
            <Tabs defaultActiveKey="1" items={items} onChange={onChange} />
        </div>
    );
};

export default Tasks;
