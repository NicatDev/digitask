import React, { useEffect, useState } from 'react';
import { Tag, Button, Tooltip } from 'antd';
import { CalendarOutlined, PlusOutlined, InfoCircleOutlined } from '@ant-design/icons';
import styles from '../style.module.scss';
import { getEvents } from '../../../axios/api/dashboard';
import EventModal from './EventModal';

const EventSection = () => {
    const [events, setEvents] = useState([]);
    const [isModalOpen, setIsModalOpen] = useState(false);

    useEffect(() => {
        fetchEvents();
    }, []);

    const fetchEvents = async () => {
        try {
            const res = await getEvents({ active_only: 'true' });
            setEvents(res.data || []);
        } catch (error) {
            console.error('Events fetch error', error);
        }
    };

    const getTypeColor = (type) => {
        switch (type) {
            case 'meeting': return '#1890ff'; // blue
            case 'holiday': return '#52c41a'; // green
            case 'maintenance': return '#fa8c16'; // orange
            case 'announcement': return '#faad14'; // gold
            default: return '#d9d9d9'; // default
        }
    };

    return (
        <div className={styles.eventSection}>
            <div style={{
                display: 'flex',
                gap: '24px',
                paddingBottom: '20px',
                overflowX: 'auto',
                flexWrap: 'nowrap',
                alignItems: 'stretch',
                paddingRight: '16px' // Prevent cut-off matching shadow
            }}>
                {/* Add Event Card */}
                <div
                    className={styles.eventCard}
                    style={{
                        minWidth: '220px',
                        flexShrink: 0,
                        display: 'flex',
                        flexDirection: 'column',
                        alignItems: 'center',
                        justifyContent: 'center',
                        cursor: 'pointer',
                        border: '2px dashed #d9d9d9',
                        background: '#fafafa',
                        borderRadius: '16px',
                        transition: 'all 0.3s ease'
                    }}
                    onClick={() => setIsModalOpen(true)}
                    onMouseEnter={(e) => {
                        e.currentTarget.style.borderColor = '#1890ff';
                        e.currentTarget.style.color = '#1890ff';
                    }}
                    onMouseLeave={(e) => {
                        e.currentTarget.style.borderColor = '#d9d9d9';
                        e.currentTarget.style.color = '#8c8c8c';
                    }}
                >
                    <PlusOutlined style={{ fontSize: '32px', marginBottom: '12px', color: 'inherit' }} />
                    <div style={{ fontSize: '16px', fontWeight: 600, color: 'inherit' }}>Yeni Tədbir</div>
                </div>

                {/* Event Cards */}
                {events.map((event) => {
                    const color = getTypeColor(event.event_type);
                    return (
                        <div
                            key={event.id}
                            className={styles.eventCard}
                            style={{
                                minWidth: '350px',
                                maxWidth: '350px',
                                flexShrink: 0,
                                background: '#fff',
                                borderRadius: '16px',
                                boxShadow: `0 8px 24px -6px ${color}40`, // Colored shadow with opacity
                                borderLeft: `6px solid ${color}`,
                                position: 'relative',
                                overflow: 'visible', // For shadow
                                transition: 'transform 0.3s ease, box-shadow 0.3s ease'
                            }}
                            onMouseEnter={(e) => {
                                e.currentTarget.style.transform = 'translateY(-4px)';
                                e.currentTarget.style.boxShadow = `0 12px 32px -8px ${color}60`;
                            }}
                            onMouseLeave={(e) => {
                                e.currentTarget.style.transform = 'translateY(0)';
                                e.currentTarget.style.boxShadow = `0 8px 24px -6px ${color}40`;
                            }}
                        >
                            <div className={styles.eventContent} style={{ padding: '24px' }}>
                                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '16px' }}>
                                    <Tag color={color} style={{
                                        fontSize: '14px',
                                        padding: '4px 10px',
                                        borderRadius: '6px',
                                        fontWeight: 600,
                                        border: 'none',
                                        lineHeight: '20px'
                                    }}>
                                        {event.event_type_display}
                                    </Tag>
                                    <span style={{
                                        color: '#8c8c8c',
                                        fontSize: '14px',
                                        fontWeight: 500,
                                        display: 'flex',
                                        alignItems: 'center',
                                        background: '#f5f5f5',
                                        padding: '4px 10px',
                                        borderRadius: '20px'
                                    }}>
                                        <CalendarOutlined style={{ marginRight: 6 }} />
                                        {new Date(event.date).toLocaleDateString()}
                                    </span>
                                </div>
                                <h3 style={{
                                    fontSize: '16px',
                                    marginBottom: '12px',
                                    color: '#1f1f1f',
                                    fontWeight: 700,
                                    lineHeight: 1.3
                                }}>{event?.title?.slice(0, 80)}</h3>
                                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '8px' }}>
                                    <p style={{
                                        display: '-webkit-box',
                                        WebkitLineClamp: 2,
                                        WebkitBoxOrient: 'vertical',
                                        overflow: 'hidden',
                                        margin: 0,
                                        color: '#595959',
                                        fontSize: '15px',
                                        lineHeight: '1.6',
                                        flex: 1
                                    }}>{event.description}</p>
                                    <Tooltip title={event.description} placement="bottomRight" overlayInnerStyle={{ maxWidth: '300px' }}>
                                        <InfoCircleOutlined style={{ fontSize: '18px', color: color, cursor: 'help', marginTop: '4px' }} />
                                    </Tooltip>
                                </div>
                            </div>
                        </div>
                    );
                })}
            </div>

            <EventModal
                open={isModalOpen}
                onCancel={() => setIsModalOpen(false)}
                onSuccess={() => {
                    setIsModalOpen(false);
                    fetchEvents();
                }}
            />
        </div>
    );
};

export default EventSection;
