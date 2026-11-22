import React, { useState } from 'react';
import { Alert, Button, Card, Col, Popconfirm, Progress, Row, Space, Statistic, Tag, Typography } from 'antd';
import {
    CheckCircleOutlined, CloseCircleOutlined, EyeOutlined, PlayCircleOutlined,
    RollbackOutlined, StopOutlined, WarningOutlined,
} from '@ant-design/icons';
import { cancelCustomerImport, confirmCustomerImport, resumeCustomerImport } from '../../../../axios/api/tasks';
import { REF_LABELS, STATUS_META, showError } from './utils';
import styles from './style.module.scss';

const { Text, Paragraph } = Typography;

const pct = (done, total) => (total ? Math.min(100, Math.round((done / total) * 100)) : 0);

/** Hazırkı importun vəziyyəti: yoxlanılır → təsdiq → yaradılır → nəticə */
const ActiveBatchPanel = ({ batch, onChange, onOpenDetails, onRollback, onDismiss }) => {
    const [busy, setBusy] = useState(null);
    if (!batch) return null;
    const st = STATUS_META[batch.status] || { color: 'default', label: batch.status_label };
    const notes = batch.summary?.notes || [];
    const planned = Object.entries(batch.summary?.planned_refs || {}).filter(([, v]) => v?.length);

    const run = async (key, fn, fallback) => {
        setBusy(key);
        try {
            const res = await fn(batch.id);
            onChange(res.data);
        } catch (e) {
            await showError(e, fallback);
        } finally {
            setBusy(null);
        }
    };

    const stats = (
        <Row gutter={[12, 12]} className={styles.statsRow}>
            <Col xs={12} md={6}>
                <Card size="small" className={styles.statNew}>
                    <Statistic
                        title={batch.status === 'preview' ? 'Yaradılacaq' : 'Yaradıldı'}
                        value={batch.status === 'preview' ? batch.new_count : batch.created_count}
                        prefix={<CheckCircleOutlined />}
                    />
                </Card>
            </Col>
            <Col xs={12} md={6}>
                <Card size="small" className={styles.statExisting}>
                    <Statistic title="Artıq var" value={batch.existing_count + batch.duplicate_in_file_count} />
                </Card>
            </Col>
            <Col xs={12} md={6}>
                <Card size="small" className={styles.statProblem}>
                    <Statistic title="Problemli" value={batch.problem_count} prefix={<CloseCircleOutlined />} />
                </Card>
            </Col>
            <Col xs={12} md={6}>
                <Card size="small" className={styles.statWarn}>
                    <Statistic title="Xəbərdarlıq" value={batch.warning_count} prefix={<WarningOutlined />} />
                </Card>
            </Col>
        </Row>
    );

    return (
        <Card
            className={styles.activeCard}
            title={
                <Space wrap>
                    <span>Hazırkı import</span>
                    <Tag color={st.color}>{st.label}</Tag>
                    <Text type="secondary" style={{ fontWeight: 400 }}>{batch.original_filename}</Text>
                </Space>
            }
            extra={['completed', 'failed', 'cancelled', 'rolled_back'].includes(batch.status) && (
                <Button size="small" type="text" onClick={onDismiss}>Bağla</Button>
            )}
        >
            {batch.status === 'validating' && (
                <>
                    <Paragraph>{batch.phase || 'Fayl yoxlanılır'}… Bu mərhələdə heç bir müştəri yaradılmır.</Paragraph>
                    <Progress percent={pct(batch.progress_done, batch.progress_total)} status="active" />
                </>
            )}

            {batch.status === 'preview' && (
                <>
                    <Alert
                        type="info"
                        showIcon
                        style={{ marginBottom: 12 }}
                        title="Fayl yoxlanıldı. Hələ heç nə yaradılmayıb."
                        description="Nəticələrə baxın. Hər şey qaydasındadırsa “Təsdiqlə” düyməsini basın — yalnız yeni müştərilər yaradılacaq."
                    />
                    {stats}
                    {notes.map((n) => <Alert key={n.code + n.message} type="warning" showIcon title={n.message} style={{ marginBottom: 8 }} />)}
                    {planned.length > 0 && (
                        <Alert
                            type="warning"
                            showIcon
                            style={{ marginBottom: 12 }}
                            title="Sistemdə tapılmadığı üçün yenisi yaradılacaq:"
                            description={planned.map(([kind, list]) => (
                                <div key={kind}>
                                    <b>{REF_LABELS[kind]}:</b>{' '}
                                    {list.map((x) => `${x.name} (${x.rows} müştəri)`).join(', ')}
                                </div>
                            ))}
                        />
                    )}
                    <Space wrap>
                        <Button icon={<EyeOutlined />} onClick={() => onOpenDetails(batch)}>Nəticələrə bax</Button>
                        <Popconfirm
                            title={`${batch.new_count} yeni müştəri yaradılsın?`}
                            description="Mövcud müştərilər dəyişdirilməyəcək."
                            okText="Bəli, yarat"
                            cancelText="Xeyr"
                            disabled={!batch.new_count}
                            onConfirm={() => run('confirm', confirmCustomerImport, 'Təsdiq alınmadı')}
                        >
                            <Button type="primary" icon={<CheckCircleOutlined />} disabled={!batch.new_count} loading={busy === 'confirm'}>
                                Təsdiqlə və {batch.new_count} müştəri yarat
                            </Button>
                        </Popconfirm>
                        <Button icon={<StopOutlined />} loading={busy === 'cancel'}
                                onClick={() => run('cancel', cancelCustomerImport, 'Ləğv alınmadı')}>
                            Ləğv et
                        </Button>
                    </Space>
                    {!batch.new_count && (
                        <Paragraph type="secondary" style={{ marginTop: 8, marginBottom: 0 }}>
                            Yaradılacaq yeni müştəri yoxdur.
                        </Paragraph>
                    )}
                </>
            )}

            {batch.status === 'importing' && (
                <>
                    <Paragraph>
                        Müştərilər yaradılır… <Text type="secondary">Səhifəni bağlasanız da proses davam edir.</Text>
                    </Paragraph>
                    <Progress
                        percent={pct(batch.progress_done, batch.progress_total)}
                        status="active"
                        format={() => `${batch.created_count} / ${batch.progress_total}`}
                    />
                </>
            )}

            {batch.status === 'rolling_back' && (
                <>
                    <Paragraph>Geri qaytarılır… Bu bir neçə saniyə çəkə bilər.</Paragraph>
                    <Progress percent={100} status="active" showInfo={false} />
                </>
            )}

            {batch.status === 'interrupted' && (
                <>
                    <Alert type="error" showIcon style={{ marginBottom: 12 }} title="Import yarımçıq qaldı" description={batch.error_message} />
                    {stats}
                    <Space wrap>
                        <Button type="primary" icon={<PlayCircleOutlined />} loading={busy === 'resume'}
                                onClick={() => run('resume', resumeCustomerImport, 'Davam etdirmək alınmadı')}>
                            Davam et
                        </Button>
                        <Button danger icon={<RollbackOutlined />} onClick={() => onRollback(batch)}>Geri qaytar</Button>
                        <Button icon={<EyeOutlined />} onClick={() => onOpenDetails(batch)}>Detallara bax</Button>
                    </Space>
                </>
            )}

            {batch.status === 'completed' && (
                <>
                    <Alert
                        type="success"
                        showIcon
                        style={{ marginBottom: 12 }}
                        title={`Hazırdır: ${batch.created_count} yeni müştəri yaradıldı.`}
                        description={batch.problem_count
                            ? `${batch.problem_count} problemli sətir yaradılmadı — “Detallara bax”-dan onları Excel kimi endirib düzəldə bilərsiniz.`
                            : undefined}
                    />
                    {stats}
                    <Space wrap>
                        <Button icon={<EyeOutlined />} onClick={() => onOpenDetails(batch)}>Detallara bax</Button>
                        {batch.can_rollback && (
                            <Button danger icon={<RollbackOutlined />} onClick={() => onRollback(batch)}>Geri qaytar</Button>
                        )}
                    </Space>
                </>
            )}

            {batch.status === 'rolled_back' && (
                <Alert type="info" showIcon
                       title={`Geri qaytarıldı: ${batch.rollback_summary?.deleted_customers ?? 0} müştəri silindi. Sistem importdan əvvəlki vəziyyətdədir.`} />
            )}

            {batch.status === 'failed' && (
                <Alert type="error" showIcon title="Fayl qəbul olunmadı" description={batch.error_message} />
            )}

            {batch.status === 'cancelled' && <Alert type="info" showIcon title="Import ləğv edildi. Heç nə yaradılmadı." />}

            {['preview', 'completed', 'rolled_back'].includes(batch.status) && batch.error_message && (
                <Alert type="warning" showIcon style={{ marginTop: 12 }} title={batch.error_message} />
            )}
        </Card>
    );
};

export default ActiveBatchPanel;
