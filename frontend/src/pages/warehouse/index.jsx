import React, { useState } from 'react';
import { Tabs, Typography } from 'antd';
import WarehouseTab from './components/WarehouseTab';
import ProductTab from './components/ProductTab';
import HistoryTab from './components/HistoryTab';
import CategoryTab from './components/CategoryTab';
import styles from './style.module.scss';

const { Title } = Typography;

const WarehousePage = () => {
    const [activeTab, setActiveTab] = useState('1');

    const items = [
        {
            key: '1',
            label: 'Anbarlar',
            children: <WarehouseTab isActive={activeTab === '1'} />,
        },
        {
            key: '2',
            label: 'Məhsullar',
            children: <ProductTab isActive={activeTab === '2'} />,
        },
        {
            key: '3',
            label: 'Kateqoriyalar',
            children: <CategoryTab isActive={activeTab === '3'} />,
        },
        {
            key: '4',
            label: 'Tarixçə',
            children: <HistoryTab isActive={activeTab === '4'} />,
        },
    ];

    return (
        <div className={styles.container}>
            <Title level={2}>Anbar İdarəetməsi</Title>
            <Tabs defaultActiveKey="1" items={items} onChange={setActiveTab} />
        </div>
    );
};

export default WarehousePage;

