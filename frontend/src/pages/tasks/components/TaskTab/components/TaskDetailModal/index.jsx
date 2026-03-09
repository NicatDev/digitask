import React from 'react';
import { Modal, Descriptions, Tag, Divider, Button, Spin, Table } from 'antd';
import dayjs from 'dayjs';
import { TASK_STATUSES } from '../../constants';

const TaskDetailModal = ({ open, onCancel, task, services = [] }) => {
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
            {!task ? (
                <div style={{ display: 'flex', justifyContent: 'center', padding: '40px' }}>
                    <Spin size="large" />
                </div>
            ) : (
                <div style={{ maxHeight: '60vh', overflowY: 'auto', paddingRight: '10px' }}>
                    <Descriptions title="Tapşırıq" bordered column={{ xxl: 2, xl: 2, lg: 2, md: 1, sm: 1, xs: 1 }}>
                        <Descriptions.Item label="Başlıq" span={2}>{task.title}</Descriptions.Item>
                        <Descriptions.Item label="Status"><StatusBadge status={task.status} /></Descriptions.Item>
                        <Descriptions.Item label="Aktivlik">{task.is_active ? <Tag color="green">Aktiv</Tag> : <Tag color="red">Deaktiv</Tag>}</Descriptions.Item>
                        <Descriptions.Item label="Yaradılma tarixi">{dayjs(task.created_at).format('DD.MM.YYYY HH:mm')}</Descriptions.Item>
                        <Descriptions.Item label="Son yenilənmə">{dayjs(task.updated_at).format('DD.MM.YYYY HH:mm')}</Descriptions.Item>
                        <Descriptions.Item label="Qrup">{task.group_name || '-'}</Descriptions.Item>
                        <Descriptions.Item label="Region">{task.region_name || '-'}</Descriptions.Item>
                        <Descriptions.Item label="İcraçılar">
                            {task.assigned_to_names && task.assigned_to_names.length > 0
                                ? task.assigned_to_names.map((name, idx) => <Tag key={idx} color="blue">{name}</Tag>)
                                : <Tag>Təyin edilməyib</Tag>
                            }
                        </Descriptions.Item>
                        <Descriptions.Item label="Tapşırıq Tipi">{task.task_type_details?.name || '-'}</Descriptions.Item>
                        <Descriptions.Item label="Təsvir" span={2}>
                            <div style={{ whiteSpace: 'pre-wrap' }}>{task.note || '-'}</div>
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

                    {/* Xidmətlər (task_services) */}
                    {task.task_services && task.task_services.length > 0 && (
                        <>
                            <Divider />
                            <h4>Xidmətlər</h4>
                            {task.task_services.map((ts, idx) => (
                                <div key={ts.id || idx} style={{ 
                                    background: '#fafafa', padding: '12px', borderRadius: '8px', 
                                    marginBottom: '8px', border: '1px solid #f0f0f0' 
                                }}>
                                    <strong>{ts.service_name || 'Xidmət'}</strong>
                                    {ts.note && <p style={{ color: '#888', margin: '4px 0' }}>{ts.note}</p>}
                                    {ts.values && ts.values.map(v => (
                                        <div key={v.id} style={{ fontSize: '13px', color: '#555' }}>
                                            {v.column_name || v.column_key}: <strong>{v.value ?? '-'}</strong>
                                        </div>
                                    ))}
                                </div>
                            ))}
                        </>
                    )}

                    {/* Məhsullar (task_products) */}
                    {task.task_products && task.task_products.length > 0 && (
                        <>
                            <Divider />
                            <h4>Məhsullar</h4>
                            <Table
                                dataSource={task.task_products}
                                rowKey="id"
                                size="small"
                                pagination={false}
                                columns={[
                                    { title: 'Məhsul', dataIndex: 'product_name', key: 'product_name' },
                                    { title: 'Say', dataIndex: 'quantity', key: 'quantity' },
                                    { title: 'Anbar', dataIndex: 'warehouse_name', key: 'warehouse_name' },
                                ]}
                            />
                        </>
                    )}

                    {/* Sənədlər (task_documents) */}
                    {task.task_documents && task.task_documents.length > 0 && (
                        <>
                            <Divider />
                            <h4>Sənədlər</h4>
                            {task.task_documents.map((doc, idx) => (
                                <div key={doc.id || idx} style={{ marginBottom: '4px' }}>
                                    <a href={doc.file} target="_blank" rel="noopener noreferrer">
                                        📎 {doc.title || doc.name || 'Sənəd'}
                                    </a>
                                </div>
                            ))}
                        </>
                    )}
                </div>
            )}
        </Modal>
    );
};

export default TaskDetailModal;

