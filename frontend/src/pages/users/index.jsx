import React, { useState } from 'react';
import { Tabs, Layout, Typography } from 'antd';
import UserTab from './components/UserTab';
import RoleTab from './components/RoleTab';
import RegionTab from './components/RegionTab';
import GroupTab from './components/GroupTab';

import styles from './style.module.scss';

const { Content } = Layout;
const { Title } = Typography;

const Users = () => {
    const [activeTab, setActiveTab] = useState('1');

    const items = [
        {
            key: '1',
            label: 'İstifadəçilər',
            children: <UserTab isActive={activeTab === '1'} />,
        },
        {
            key: '2',
            label: 'Rollar',
            children: <RoleTab isActive={activeTab === '2'} />,
        },
        {
            key: '3',
            label: 'Regionlar',
            children: <RegionTab isActive={activeTab === '3'} />,
        },
        {
            key: '4',
            label: 'Qruplar',
            children: <GroupTab isActive={activeTab === '4'} />,
        },
    ];

    const onChange = (key) => {
        setActiveTab(key);
    };

    return (
        <div className={styles.usersPage}>
            <Title level={2}>İstifadəçi İdarəetməsi</Title>
            <Tabs defaultActiveKey="1" items={items} onChange={onChange} />
        </div>
    );
};

export default Users;
