import React, { useEffect, useState, useRef } from 'react';
import { Card, Tag, Tooltip } from 'antd';
import { CalendarOutlined, PlusOutlined, InfoCircleOutlined } from '@ant-design/icons';
import styles from './style.module.scss';
import { getEvents } from '../../../../axios/api/dashboard';
import EventDetailModal from '../EventDetailModal';
import EventModal from '../EventModal';

const EventSection = () => {
    const [events, setEvents] = useState([]);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const [selectedEvent, setSelectedEvent] = useState(null);
    const [isDetailModalOpen, setIsDetailModalOpen] = useState(false);

    // Drag to scroll refs
    const scrollRef = useRef(null);
    const isDown = useRef(false);
    const startX = useRef(0);
    const scrollLeft = useRef(0);
    const isDragging = useRef(false); // To distinguish click vs drag

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
            case 'meeting': return 'blue';
            case 'holiday': return 'green';
            case 'maintenance': return 'orange';
            case 'announcement': return 'gold';
            default: return 'default';
        }
    };

    const getTypeLabel = (type) => { // Adding simple mapping fallback if display missing
        switch (type) {
            case 'meeting': return 'İclas';
            case 'holiday': return 'Bayram';
            case 'maintenance': return 'Texniki';
            case 'announcement': return 'Elan';
            default: return 'Digər';
        }
    };

    // Drag handlers
    const onMouseDown = (e) => {
        isDown.current = true;
        isDragging.current = false;
        startX.current = e.pageX - scrollRef.current.offsetLeft;
        scrollLeft.current = scrollRef.current.scrollLeft;
        scrollRef.current.style.cursor = 'grabbing';
    };

    const onMouseLeave = () => {
        isDown.current = false;
        if (scrollRef.current) scrollRef.current.style.cursor = 'grab';
    };

    const onMouseUp = () => {
        isDown.current = false;
        if (scrollRef.current) scrollRef.current.style.cursor = 'grab';
        // setTimeout to clear dragging flag after click event propagation
        setTimeout(() => { isDragging.current = false; }, 0);
    };

    const onMouseMove = (e) => {
        if (!isDown.current) return;
        e.preventDefault();
        const x = e.pageX - scrollRef.current.offsetLeft;
        const walk = (x - startX.current) * 2; // Scroll-fast
        scrollRef.current.scrollLeft = scrollLeft.current - walk;
        if (Math.abs(walk) > 5) {
            isDragging.current = true;
        }
    };

    const handleAddClick = (e) => {
        if (isDragging.current) {
            e.preventDefault();
            e.stopPropagation();
            return;
        }
        setIsModalOpen(true);
    };

    const handleEventClick = (e, event) => {
        if (isDragging.current) {
            e.preventDefault();
            e.stopPropagation();
            return;
        }
        setSelectedEvent(event);
        setIsDetailModalOpen(true);
    }

    return (
        <div className={styles.eventSection}>
            <div
                className={styles.sectionScrollContainer}
                ref={scrollRef}
                onMouseDown={onMouseDown}
                onMouseLeave={onMouseLeave}
                onMouseUp={onMouseUp}
                onMouseMove={onMouseMove}
            >
                {/* Add Event Card */}
                <Card
                    hoverable
                    className={styles.addEventCard}
                    onClick={handleAddClick}
                >
                    <PlusOutlined className={styles.plusIcon} />
                    <div className={styles.addText}>Yeni Tədbir</div>
                </Card>

                {/* Event Cards */}
                {events.map((event) => {
                    const colorType = getTypeColor(event.event_type);

                    return (
                        <Card
                            key={event.id}
                            className={styles.eventCard}
                            hoverable
                            onClick={(e) => handleEventClick(e, event)}
                            title={
                                <Tooltip title={event.title} placement="topLeft">
                                    <span style={{ cursor: 'default' }}>
                                        {event.title?.length > 25 ? `${event.title.slice(0, 25)}...` : event.title}
                                    </span>
                                </Tooltip>
                            }
                            extra={
                                <div className={styles.cardHeaderRight}>
                                    <Tag color={colorType}>
                                        {event.event_type_display || getTypeLabel(event.event_type)}
                                    </Tag>
                                </div>
                            }
                        >
                            <p className={styles.description}>{event.description}</p>

                            <div style={{ marginTop: 'auto', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', paddingTop: 10 }}>
                                <div className={styles.dateText}>
                                    <CalendarOutlined />
                                    {new Date(event.date).toLocaleDateString()}
                                </div>

                                <Tooltip title={event.description} overlayInnerStyle={{ maxWidth: '300px' }}>
                                    <InfoCircleOutlined style={{ color: '#1890ff', fontSize: '18px' }} />
                                </Tooltip>
                            </div>
                        </Card>
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

            <EventDetailModal
                open={isDetailModalOpen}
                event={selectedEvent}
                onCancel={() => setIsDetailModalOpen(false)}
                onSuccess={() => {
                    setIsDetailModalOpen(false);
                    fetchEvents();
                }}
            />
        </div>
    );
};

export default EventSection;
