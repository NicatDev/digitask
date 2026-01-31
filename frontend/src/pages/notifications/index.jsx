import React, { useEffect, useState } from 'react';
import { List, Card, Empty, Spin, Typography, Button, message } from 'antd';
import { BellOutlined, CheckOutlined } from '@ant-design/icons';
import axiosInstance from '../../axios';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import { useNotifications } from '../../context/NotificationContext';
import styles from './style.module.scss';

dayjs.extend(relativeTime);

const { Title, Text } = Typography;

const NotificationsPage = () => {
    const [notifications, setNotifications] = useState([]);
    const [loading, setLoading] = useState(true);
    const { setUnreadCount, refetchCount } = useNotifications();

    useEffect(() => {
        fetchNotifications();
    }, []);

    const fetchNotifications = async () => {
        setLoading(true);
        try {
            const res = await axiosInstance.get('/tasks/notifications/');
            setNotifications(res.data);
        } catch (e) {
            console.error('Failed to fetch notifications', e);
        } finally {
            setLoading(false);
        }
    };

    const handleMarkAllRead = async () => {
        try {
            await axiosInstance.post('/tasks/notifications/mark_read/');
            setNotifications([]);
            setUnreadCount(0);
            message.success('Bütün bildirişlər oxundu!');
        } catch (e) {
            console.error('Failed to mark as read', e);
            message.error('Xəta baş verdi');
        }
    };

    const getNotificationIcon = (type) => {
        switch (type) {
            case 'task_created': return '📋';
            case 'task_assigned': return '👤';
            case 'task_completed': return '✅';
            default: return '🔔';
        }
    };

    return (
        <div className={styles.container}>
            <Card>
                <div className={styles.header}>
                    <Title level={4} style={{ margin: 0 }}>
                        <BellOutlined style={{ marginRight: 8 }} />
                        Bildirişlər
                    </Title>
                    {notifications.length > 0 && (
                        <Button
                            type="primary"
                            icon={<CheckOutlined />}
                            onClick={handleMarkAllRead}
                        >
                            Hamısını oxunmuş kimi işarələ
                        </Button>
                    )}
                </div>

                <Spin spinning={loading}>
                    {notifications.length === 0 ? (
                        <Empty
                            description="Yeni bildiriş yoxdur"
                            style={{ padding: '40px 0' }}
                        />
                    ) : (
                        <List
                            dataSource={notifications}
                            renderItem={(item) => (
                                <List.Item className={styles.notificationItem}>
                                    <List.Item.Meta
                                        avatar={
                                            <div className={styles.notificationIcon}>
                                                {getNotificationIcon(item.notification_type)}
                                            </div>
                                        }
                                        title={item.title}
                                        description={
                                            <div>
                                                <Text>{item.message}</Text>
                                                <br />
                                                <Text type="secondary" style={{ fontSize: 12 }}>
                                                    {dayjs(item.created_at).fromNow()}
                                                </Text>
                                            </div>
                                        }
                                    />
                                </List.Item>
                            )}
                        />
                    )}
                </Spin>
            </Card>
        </div>
    );
};

export default NotificationsPage;
