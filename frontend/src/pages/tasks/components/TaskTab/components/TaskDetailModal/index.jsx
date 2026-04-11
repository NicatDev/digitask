import React, { useEffect, useState, useCallback } from 'react';
import { Modal, Button, Input, Spin, Tag, Row, Col, Divider, message } from 'antd';
import dayjs from 'dayjs';
import { TASK_STATUSES } from '../../constants';
import {
    getTaskActivity,
    postTaskActivityComment,
} from '../../../../../../axios/api/tasks';
import { handleApiError } from '../../../../../../utils/errorHandler';
import CustomerHistoryModal from '../CustomerHistoryModal';
import styles from './TaskDetailModal.module.scss';

const { TextArea } = Input;

const Field = ({ label, children }) => (
    <div className={styles.field}>
        <div className={styles.fieldLabel}>{label}</div>
        <div className={styles.fieldValue}>{children}</div>
    </div>
);

const StatusBadge = ({ status }) => {
    const normalized = status === 'arrived' ? 'in_progress' : status;
    const found = TASK_STATUSES.find((s) => s.value === normalized);
    const label =
        status === 'arrived' ? 'İcrada' : found?.label || status;
    return <Tag color={found?.color || 'default'}>{label}</Tag>;
};

const TaskDetailModal = ({ open, onCancel, task, services = [], onRefresh }) => {
    const [activities, setActivities] = useState([]);
    const [actLoading, setActLoading] = useState(false);
    const [comment, setComment] = useState('');
    const [submitting, setSubmitting] = useState(false);
    const [historyOpen, setHistoryOpen] = useState(false);

    const loadActivity = useCallback(async () => {
        if (!task?.id) return;
        setActLoading(true);
        try {
            const res = await getTaskActivity(task.id);
            setActivities(Array.isArray(res.data) ? res.data : []);
        } catch (e) {
            handleApiError(e, 'Aktivlik yüklənmədi');
            setActivities([]);
        } finally {
            setActLoading(false);
        }
    }, [task?.id]);

    useEffect(() => {
        if (open && task?.id) {
            loadActivity();
            setComment('');
        }
    }, [open, task?.id, loadActivity]);

    const handleComment = async () => {
        const t = comment.trim();
        if (!t || !task?.id) return;
        setSubmitting(true);
        try {
            await postTaskActivityComment(task.id, t);
            message.success('Şərh əlavə olundu');
            setComment('');
            await loadActivity();
            onRefresh?.();
        } catch (e) {
            handleApiError(e, 'Şərh göndərilmədi');
        } finally {
            setSubmitting(false);
        }
    };

    if (!task) return null;

    return (
        <>
            <Modal
                title="Tapşırıq"
                open={open}
                onCancel={onCancel}
                footer={[
                    <Button key="close" type="primary" onClick={onCancel}>
                        Bağla
                    </Button>,
                ]}
                width="min(960px, 100vw)"
                className={styles.modal}
                destroyOnClose
            >
                <Row gutter={[24, 24]}>
                    <Col xs={24} lg={12}>
                        <h3 className={styles.sectionTitle}>Tapşırıq məlumatları</h3>
                        <Field label="Başlıq">{task.title}</Field>
                        <Field label="Status">
                            <StatusBadge status={task.status} />
                        </Field>
                        <Field label="Aktivlik">
                            {task.is_active ? (
                                <Tag color="green">Aktiv</Tag>
                            ) : (
                                <Tag color="red">Deaktiv</Tag>
                            )}
                        </Field>
                        <Field label="Yaradılma">
                            {task.created_at
                                ? dayjs(task.created_at).format('DD.MM.YYYY HH:mm')
                                : '—'}
                        </Field>
                        <Field label="Son yenilənmə">
                            {task.updated_at
                                ? dayjs(task.updated_at).format('DD.MM.YYYY HH:mm')
                                : '—'}
                        </Field>
                        <Field label="Qrup">{task.group_name || '—'}</Field>
                        <Field label="İcraçılar">
                            {task.assigned_to_names && task.assigned_to_names.length > 0
                                ? task.assigned_to_names.map((name, idx) => (
                                      <Tag key={idx} color="blue" style={{ marginBottom: 4 }}>
                                          {name}
                                      </Tag>
                                  ))
                                : 'Təyin edilməyib'}
                        </Field>
                        <Field label="Qeyd">
                            <span style={{ whiteSpace: 'pre-wrap' }}>{task.note || '—'}</span>
                        </Field>
                        <Field label="Servislər">
                            {task.services && task.services.length > 0
                                ? task.services.map((sid) => {
                                      const service = services.find((s) => s.id === sid);
                                      return (
                                          <Tag key={sid} style={{ marginBottom: 4 }}>
                                              {service ? service.name : sid}
                                          </Tag>
                                      );
                                  })
                                : '—'}
                        </Field>
                        <Button
                            type="link"
                            className={styles.historyBtn}
                            onClick={() => setHistoryOpen(true)}
                        >
                            Tapşırıq tarixçəsinə bax (müştəri üzrə)
                        </Button>
                    </Col>

                    <Col xs={24} lg={12}>
                        <h3 className={styles.sectionTitle}>Müştəri məlumatları</h3>
                        <Field label="Ad Soyad">{task.customer_name || '—'}</Field>
                        <Field label="Telefon">{task.customer_phone || '—'}</Field>
                        <Field label="Qeydiyyat No">{task.customer_register_number || '—'}</Field>
                        <Field label="Ünvan">{task.customer_address || '—'}</Field>
                        <Field label="Avadanlıq">{task.customer_equipment_name || '—'}</Field>
                        <Field label="Optik qutu">{task.customer_optic_box_name || '—'}</Field>
                    </Col>
                </Row>

                <Divider />

                <h3 className={styles.sectionTitle}>Aktivlik və şərhlər</h3>
                {actLoading ? (
                    <div style={{ textAlign: 'center', padding: 24 }}>
                        <Spin />
                    </div>
                ) : (
                    <div className={styles.activityList}>
                        {activities.length === 0 ? (
                            <div style={{ color: '#8c8c8c', fontSize: 13 }}>Hələ qeyd yoxdur.</div>
                        ) : (
                            activities.map((a) => (
                                <div key={a.id} className={styles.activityItem}>
                                    <div className={styles.activityMeta}>
                                        {a.created_at
                                            ? dayjs(a.created_at).format('DD.MM.YYYY HH:mm')
                                            : ''}{' '}
                                        · {a.user_name}
                                    </div>
                                    <div className={styles.activityAction}>{a.action_display}</div>
                                    {a.message ? (
                                        <div className={styles.activityMsg}>{a.message}</div>
                                    ) : null}
                                </div>
                            ))
                        )}
                    </div>
                )}

                <div className={styles.commentBox}>
                    <TextArea
                        rows={3}
                        placeholder="Şərh yazın..."
                        value={comment}
                        onChange={(e) => setComment(e.target.value)}
                        maxLength={2000}
                        showCount
                    />
                    <Button
                        type="primary"
                        style={{ marginTop: 8 }}
                        loading={submitting}
                        onClick={handleComment}
                        disabled={!comment.trim()}
                    >
                        Göndər
                    </Button>
                </div>
            </Modal>

            <CustomerHistoryModal
                open={historyOpen}
                onCancel={() => setHistoryOpen(false)}
                taskId={task.id}
                customerName={task.customer_name}
            />
        </>
    );
};

export default TaskDetailModal;
