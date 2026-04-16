import React, { useState } from 'react';
import { Tabs, Typography } from 'antd';
import TaskTab from './components/TaskTab';
import CustomerTab from './components/CustomerTab';
import CustomerImportTab from './components/CustomerImportTab';
import { useAuth } from '../../context/AuthContext';

import styles from './style.module.scss';

const { Title } = Typography;

const Tasks = () => {
    const [activeTab, setActiveTab] = useState('1');
    const { user } = useAuth();
    const canSeeBulkImport = Boolean(user?.is_admin || user?.is_super_admin);

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
        ...(canSeeBulkImport
            ? [
                {
                    key: '3',
                    label: 'Bulk Import',
                    children: <CustomerImportTab />,
                },
            ]
            : []),
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
