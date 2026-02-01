import React, { useState } from 'react';
import { Tabs } from 'antd';
import { FileTextOutlined, InboxOutlined, AppstoreOutlined } from '@ant-design/icons';
import DocumentsTab from './components/DocumentsTab';
import ArchiveTab from './components/ArchiveTab';
import ShelvesTab from './components/ShelvesTab';
import styles from './style.module.scss';

const { TabPane } = Tabs;

const Documents = () => {
    const [activeTab, setActiveTab] = useState('documents');

    return (
        <div className={styles.documents}>
            <h1>Sənədlər</h1>
            <Tabs activeKey={activeTab} onChange={setActiveTab}>
                <TabPane
                    tab={<span><FileTextOutlined /> Sənədlər</span>}
                    key="documents"
                >
                    <DocumentsTab isActive={activeTab === 'documents'} />
                </TabPane>
                <TabPane
                    tab={<span><InboxOutlined /> Arxiv</span>}
                    key="archive"
                >
                    <ArchiveTab isActive={activeTab === 'archive'} />
                </TabPane>
                <TabPane
                    tab={<span><AppstoreOutlined /> Rəflər</span>}
                    key="shelves"
                >
                    <ShelvesTab isActive={activeTab === 'shelves'} />
                </TabPane>
            </Tabs>
        </div>
    );
};

export default Documents;
