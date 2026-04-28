import React, { useEffect, useState, useCallback, useMemo } from 'react';
import { Modal, Button, Input, Spin, Tag, Row, Col, Divider, Tabs, message } from 'antd';
import { FileOutlined, CheckCircleOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';
import { TASK_STATUSES } from '../../constants';
import {
    getTaskActivity,
    postTaskActivityComment,
} from '../../../../../../axios/api/tasks';
import { getBaseUrl } from '../../../../../../axios/index';
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
    const found = TASK_STATUSES.find((s) => s.value === status);
    return <Tag color={found?.color || 'default'}>{found?.label || status}</Tag>;
};

/** Backend bəzən nisbi media URL qaytarır — brauzerdə açılması üçün tam ünvan. */
const resolveMediaUrl = (raw) => {
    if (raw == null || raw === '') return '';
    const s = String(raw).trim();
    if (!s) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    const path = s.startsWith('/') ? s : `/${s}`;
    return `${getBaseUrl()}${path}`;
};

const IMAGE_EXT = /\.(jpe?g|png|gif|webp|bmp|svg)(\?.*)?$/i;

const TaskDetailModal = ({ open, onCancel, task, services = [], onRefresh, onMarkExternalArchived }) => {
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

    const mediaItems = useMemo(() => {
        if (!task) return { images: [], files: [] };
        const images = [];
        const files = [];

        const taskServices = task.task_services;
        if (Array.isArray(taskServices)) {
            taskServices.forEach((ts) => {
                const serviceName = ts?.service_name || 'Xidmət';
                const values = ts?.values;
                if (!Array.isArray(values)) return;
                values.forEach((v) => {
                    const colName = v.column_name || v.column_key || 'Sahə';
                    const colType = v.column_type || '';
                    const val = v.value;
                    if (val == null || val === '') return;
                    const url = resolveMediaUrl(val);
                    const label = `${serviceName} — ${colName}`;
                    if (colType === 'image' || (typeof val === 'string' && IMAGE_EXT.test(val))) {
                        images.push({ key: `ts-${ts.id}-${v.id}`, url, label });
                    } else if (colType === 'file') {
                        files.push({ key: `ts-${ts.id}-${v.id}`, url, label });
                    }
                });
            });
        }

        const docs = task.task_documents;
        if (Array.isArray(docs)) {
            docs.forEach((d) => {
                const raw = d.file_url || d.file;
                if (raw == null || raw === '') return;
                const url = resolveMediaUrl(raw);
                const title = d.title || d.name || 'Sənəd';
                if (IMAGE_EXT.test(url)) {
                    images.push({ key: `doc-${d.id}`, url, label: title });
                } else {
                    files.push({ key: `doc-${d.id}`, url, label: title });
                }
            });
        }

        return { images, files };
    }, [task]);

    const handleComment = async () => {
        const t = comment.trim();
        if (!t || !task?.id) return;
        setSubmitting(true);
        try {
            const res = await postTaskActivityComment(task.id, t);
            const newAct = res.data;
            if (newAct && typeof newAct === 'object') {
                setActivities((prev) => [newAct, ...prev]);
            }
            setComment('');
            message.success('Şərh əlavə olundu');
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
                <Tabs
                    defaultActiveKey="task"
                    items={[
                        {
                            key: 'task',
                            label: 'Tapşırıq',
                            children: (
                                <Row gutter={[24, 24]}>
                                    <Col xs={24}>
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
                        <Field label="Reporter">{task.reporter_name || '—'}</Field>
                        <Field label="Qeyd">
                            <span style={{ whiteSpace: 'pre-wrap' }}>{task.note || '—'}</span>
                        </Field>
                        {task.status === 'pending' && (
                            <Field label="Təxirə salınma qeydi">
                                <span style={{ whiteSpace: 'pre-wrap' }}>{task.pending_note || '—'}</span>
                            </Field>
                        )}
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
                        <Field label="Xarici sistemə köçürülmə">
                            <Button
                                icon={<CheckCircleOutlined />}
                                type={task.is_externally_archived ? 'default' : 'primary'}
                                onClick={() => onMarkExternalArchived?.(task)}
                                disabled={task.is_externally_archived}
                            >
                                {task.is_externally_archived
                                    ? 'Tapşırıq məlumatları arxivləşdirildi'
                                    : 'Tapşırıq məlumatları arxivləşdirildi'}
                            </Button>
                        </Field>
                        <Button
                            type="link"
                            className={styles.historyBtn}
                            onClick={() => setHistoryOpen(true)}
                        >
                            Tapşırıq tarixçəsinə bax (müştəri üzrə)
                        </Button>

                        {(mediaItems.images.length > 0 || mediaItems.files.length > 0) && (
                            <>
                                <h3 className={styles.sectionTitle}>Şəkillər və fayllar</h3>
                                {mediaItems.images.length > 0 && (
                                    <div className={styles.mediaGrid}>
                                        {mediaItems.images.map((item) => (
                                            <figure key={item.key} className={styles.mediaFigure}>
                                                <figcaption className={styles.mediaCaption}>{item.label}</figcaption>
                                                <a href={item.url} target="_blank" rel="noreferrer">
                                                    <img
                                                        className={styles.mediaThumb}
                                                        src={item.url}
                                                        alt={item.label}
                                                    />
                                                </a>
                                            </figure>
                                        ))}
                                    </div>
                                )}
                                {mediaItems.files.length > 0 && (
                                    <ul className={styles.fileList}>
                                        {mediaItems.files.map((item) => (
                                            <li key={item.key}>
                                                <a href={item.url} target="_blank" rel="noreferrer">
                                                    <FileOutlined /> {item.label}
                                                </a>
                                            </li>
                                        ))}
                                    </ul>
                                )}
                            </>
                        )}
                    </Col>

                </Row>
                            ),
                        },
                        {
                            key: 'customer',
                            label: 'Müştəri',
                            children: (
                                <>
                                    <h3 className={styles.sectionTitle}>Müştəri məlumatları</h3>
                                    <Field label="Ad Soyad">{task.customer_name || '—'}</Field>
                                    <Field label="Telefon">{task.customer_phone || '—'}</Field>
                                    <Field label="Qeydiyyat No">{task.customer_register_number || '—'}</Field>
                                    <Field label="Ünvan">{task.customer_address || '—'}</Field>
                                    <Field label="Avadanlıq">{task.customer_equipment_name || '—'}</Field>
                                    <Field label="Optik qutu">{task.customer_optic_box_name || '—'}</Field>
                                </>
                            ),
                        },
                        {
                            key: 'activity',
                            label: 'Aktivlik',
                            children: (
                                <>
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
                                </>
                            ),
                        },
                    ]}
                />
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
