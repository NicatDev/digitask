import React, { useState } from 'react';
import { Modal, Button, Tag, message, Typography } from 'antd';
import { CalendarOutlined, ClockCircleOutlined, DeleteOutlined } from '@ant-design/icons';
import { deleteEvent } from '../../../../axios/api/dashboard';
import styles from './style.module.scss';
import dayjs from 'dayjs';

const { Text, Title } = Typography;

const EventDetailModal = ({ open, onCancel, event, onSuccess }) => {
    const [loading, setLoading] = useState(false);

    if (!event) return null;

    const handleDelete = async () => {
        try {
            setLoading(true);
            await deleteEvent(event.id);
            message.success('Tədbir uğurla ləğv edildi');
            onSuccess();
        } catch (error) {
            console.error(error);
            message.error('Xəta baş verdi');
        } finally {
            setLoading(false);
        }
    };

    const getTypeColor = (type) => {
        switch (type) {
            case 'meeting': return 'blue';
            case 'holiday': return 'green';
            case 'maintenance': return 'orange';
            case 'announcement': return 'gold';
            default: return 'default';
        }
    };

    const getTypeLabel = (type) => {
        switch (type) {
            case 'meeting': return 'İclas';
            case 'holiday': return 'Bayram';
            case 'maintenance': return 'Texniki';
            case 'announcement': return 'Elan';
            default: return 'Digər';
        }
    };

    return (
        <Modal
            open={open}
            onCancel={onCancel}
            title="Tədbir Məlumatları"
            className={styles.detailModal}
            width={500}
            footer={[
                <Button key="back" onClick={onCancel} disabled={loading}>
                    Bağla
                </Button>,
                <Button
                    key="delete"
                    type="primary"
                    danger
                    icon={<DeleteOutlined />}
                    loading={loading}
                    onClick={handleDelete}
                >
                    Tədbiri ləğv et
                </Button>
            ]}
        >
            <div className={styles.detailsContainer}>
                <div className={styles.detailRow}>
                    <Title level={4} style={{ margin: 0 }}>{event.title}</Title>
                    <div>
                        <Tag color={getTypeColor(event.event_type)}>
                            {event.event_type_display || getTypeLabel(event.event_type)}
                        </Tag>
                    </div>
                </div>

                <div className={styles.detailRow}>
                    <span className={styles.label}>Tarix:</span>
                    <span className={styles.value}>
                        <CalendarOutlined style={{ marginRight: 6 }} />
                        {dayjs(event.date).format('DD MMMM YYYY')}
                    </span>
                </div>

                {event.description && (
                    <div className={styles.detailRow}>
                        <span className={styles.label}>Təsvir:</span>
                        <div className={`${styles.value} ${styles.description}`}>
                            {event.description}
                        </div>
                    </div>
                )}
            </div>
        </Modal>
    );
};

export default EventDetailModal;
