import React, { useEffect, useState } from 'react';
import { List, Avatar, Spin, Tooltip, Badge } from 'antd';
import { UserOutlined, CheckCircleOutlined, ClockCircleOutlined, FolderOutlined } from '@ant-design/icons';
import { getDashboardStats } from '../../../../axios/api/dashboard';
import styles from './style.module.scss';

const TopUsersList = () => {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchStats();
    }, []);

    const fetchStats = async () => {
        try {
            const res = await getDashboardStats();
            // The backend returns user stats in res.data.tasks.by_user
            setUsers(res.data.tasks.by_user || []);
        } catch (error) {
            console.error('Stats fetch error', error);
        } finally {
            setLoading(false);
        }
    };

    if (loading) {
        return (
            <div className={styles.topUsersCard} style={{ display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
                <Spin />
            </div>
        );
    }

    return (
        <div className={styles.topUsersCard}>
            <h3>Ayın Top 5 İstifadəçisi</h3>
            <List
                itemLayout="horizontal"
                dataSource={users}
                renderItem={(item, index) => (
                    <List.Item className={styles.userItem}>
                        <List.Item.Meta
                            avatar={
                                <Badge count={index + 1} color="#faad14" offset={[0, 5]}>
                                    {item['assigned_to__avatar'] ? (
                                        <Avatar
                                            size={48}
                                            src={`${(window.location.hostname === 'new.digitask.store' || window.location.hostname === 'digitask.store' || window.location.hostname === 'app.digitask.store') ? 'https://app.digitask.store' : 'http://127.0.0.1:8000'}/media/${item['assigned_to__avatar']}`}
                                        />
                                    ) : (
                                        <Avatar size={48} icon={<UserOutlined />} style={{ backgroundColor: '#fde3cf', color: '#f56a00' }} />
                                    )}
                                </Badge>
                            }
                            title={
                                <div className={styles.userInfo}>
                                    <span className={styles.userName}>
                                        {item['assigned_to__first_name']} {item['assigned_to__last_name']}
                                    </span>
                                    <span className={styles.userGroup}>
                                        {item['assigned_to__group__name'] || 'Qrup yoxdur'}
                                    </span>
                                </div>
                            }
                        />
                        <div className={styles.statsRow}>
                            <Tooltip title="Aktiv Tapşırıqlar">
                                <div className={`${styles.statItem} ${styles.active}`}>
                                    <ClockCircleOutlined /> {item.active_tasks}
                                </div>
                            </Tooltip>

                            <Tooltip title="Tamamlanmış Tapşırıqlar">
                                <div className={`${styles.statItem} ${styles.done}`}>
                                    <CheckCircleOutlined /> {item.done_tasks}
                                </div>
                            </Tooltip>

                            <Tooltip title="Ümumi Tapşırıqlar">
                                <div className={`${styles.statItem} ${styles.total}`}>
                                    <FolderOutlined /> {item.total_tasks}
                                </div>
                            </Tooltip>
                        </div>
                    </List.Item>
                )}
            />
        </div>
    );
};

export default TopUsersList;
