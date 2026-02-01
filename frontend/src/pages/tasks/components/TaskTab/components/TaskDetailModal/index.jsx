import React from 'react';
import { Modal, Descriptions, Tag, Divider, Button } from 'antd';
import dayjs from 'dayjs';
import { TASK_STATUSES } from '../../constants';

const TaskDetailModal = ({ open, onCancel, task, services = [] }) => {
    if (!task) return null;

    const getStatusLabel = (status) => {
        const found = TASK_STATUSES.find(s => s.value === status);
        return found ? found.label : status;
    };

    const StatusBadge = ({ status }) => {
        const found = TASK_STATUSES.find(s => s.value === status);
        return (
            <Tag color={found?.color || 'default'}>
                {found?.label || status}
            </Tag>
        );
    };

    return (
        <Modal
            title="Tapşırıq Məlumatları"
            open={open}
            onCancel={onCancel}
            footer={[
                <Button key="close" onClick={onCancel}>Bağla</Button>
            ]}
            width={800}
        >
            <div style={{ maxHeight: '60vh', overflowY: 'auto', paddingRight: '10px' }}>
                <Descriptions title="Tapşırıq" bordered column={{ xxl: 2, xl: 2, lg: 2, md: 1, sm: 1, xs: 1 }}>
                    <Descriptions.Item label="Başlıq" span={2}>{task.title}</Descriptions.Item>
                    <Descriptions.Item label="Status"><StatusBadge status={task.status} /></Descriptions.Item>
                    <Descriptions.Item label="Aktivlik">{task.is_active ? <Tag color="green">Aktiv</Tag> : <Tag color="red">Deaktiv</Tag>}</Descriptions.Item>
                    <Descriptions.Item label="Yaradılma tarixi">{dayjs(task.created_at).format('DD.MM.YYYY HH:mm')}</Descriptions.Item>
                    <Descriptions.Item label="Son yenilənmə">{dayjs(task.updated_at).format('DD.MM.YYYY HH:mm')}</Descriptions.Item>
                    <Descriptions.Item label="Qrup">{task.group_name || '-'}</Descriptions.Item>
                    <Descriptions.Item label="İcraçı">{task.assigned_to_name || <Tag>Təyin edilməyib</Tag>}</Descriptions.Item>
                    <Descriptions.Item label="Təsvir" span={2}>
                        <div style={{ whiteSpace: 'pre-wrap' }}>{task.description || '-'}</div>
                    </Descriptions.Item>
                    <Descriptions.Item label="Servislər" span={2}>
                        {task.services && task.services.length > 0 ? (
                            task.services.map(sid => {
                                const service = services.find(s => s.id === sid);
                                return <Tag key={sid}>{service ? service.name : sid}</Tag>;
                            })
                        ) : 'Yoxdur'}
                    </Descriptions.Item>
                </Descriptions>

                <Divider />

                <Descriptions title="Müştəri Məlumatları" bordered column={{ xxl: 2, xl: 2, lg: 2, md: 1, sm: 1, xs: 1 }}>
                    <Descriptions.Item label="Ad Soyad" span={2}>{task.customer_name}</Descriptions.Item>
                    <Descriptions.Item label="Telefon">{task.customer_phone || '-'}</Descriptions.Item>
                    <Descriptions.Item label="Qeydiyyat No">{task.customer_register_number || '-'}</Descriptions.Item>
                    <Descriptions.Item label="Ünvan" span={2}>
                        {task.customer_address || '-'}
                    </Descriptions.Item>
                </Descriptions>
            </div>
        </Modal>
    );
};

export default TaskDetailModal;
