import React, { useEffect, useState } from 'react';
import { Modal, Spin, Tag, Empty } from 'antd';
import dayjs from 'dayjs';
import { getCustomerTasksForTask } from '../../../../../../axios/api/tasks';
import { handleApiError } from '../../../../../../utils/errorHandler';
import { TASK_STATUSES } from '../../constants';
import styles from './style.module.scss';

const statusColor = (status) => {
    const found = TASK_STATUSES.find((s) => s.value === status);
    return found?.color || '#888';
};

const CustomerHistoryModal = ({ open, onCancel, taskId, customerName }) => {
    const [loading, setLoading] = useState(false);
    const [rows, setRows] = useState([]);

    useEffect(() => {
        if (!open || !taskId) return;
        let cancelled = false;
        (async () => {
            setLoading(true);
            try {
                const res = await getCustomerTasksForTask(taskId);
                if (!cancelled) {
                    setRows(Array.isArray(res.data) ? res.data : []);
                }
            } catch (e) {
                handleApiError(e, 'Tarixçə yüklənmədi');
                if (!cancelled) setRows([]);
            } finally {
                if (!cancelled) setLoading(false);
            }
        })();
        return () => {
            cancelled = true;
        };
    }, [open, taskId]);

    return (
        <Modal
            title={customerName ? `Müştəri: ${customerName}` : 'Tapşırıq tarixçəsi'}
            open={open}
            onCancel={onCancel}
            footer={null}
            width="min(960px, 100vw)"
            className={styles.historyModal}
            destroyOnClose
        >
            {loading ? (
                <div className={styles.centered}>
                    <Spin />
                </div>
            ) : rows.length === 0 ? (
                <Empty description="Tapşırıq yoxdur" />
            ) : (
                <ul className={styles.list}>
                    {rows.map((t) => (
                        <li key={t.id} className={styles.item}>
                            <div className={styles.itemTop}>
                                <span className={styles.taskId}>#{t.id}</span>
                                <Tag color={statusColor(t.status)}>{t.status_display || t.status}</Tag>
                                <span className={styles.date}>
                                    {t.created_at ? dayjs(t.created_at).format('DD.MM.YYYY HH:mm') : ''}
                                </span>
                            </div>
                            <div className={styles.title}>{t.title}</div>
                            <div className={styles.assignees}>
                                <strong>İcraçılar:</strong>{' '}
                                {t.assigned_to_names && t.assigned_to_names.length > 0
                                    ? t.assigned_to_names.join(', ')
                                    : '—'}
                            </div>
                        </li>
                    ))}
                </ul>
            )}
        </Modal>
    );
};

export default CustomerHistoryModal;
