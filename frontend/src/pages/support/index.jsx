import React, { useEffect, useMemo, useState } from 'react';
import {
    Alert,
    Button,
    Card,
    Col,
    Empty,
    Form,
    Grid,
    Input,
    Modal,
    Row,
    Select,
    Space,
    Tag,
    Typography,
    Upload,
    message,
} from 'antd';
import { InboxOutlined } from '@ant-design/icons';
import {
    addSupportComment,
    createSupportRequest,
    getSupportRequests,
    setSupportStatus,
} from '../../axios/api/tasks';
import { useAuth } from '../../context/AuthContext';
import styles from './support.module.scss';

const { Title, Text, Paragraph } = Typography;
const { Dragger } = Upload;
const { useBreakpoint } = Grid;

const STATUS_OPTIONS = [
    { value: 'new', label: 'Yeni' },
    { value: 'accepted', label: 'Qəbul edildi' },
    { value: 'rejected', label: 'Rədd edildi' },
    { value: 'done', label: 'Done' },
    { value: 'solved', label: 'Həll edildi' },
    { value: 'closed', label: 'Bağlandı' },
];

const statusColor = {
    new: 'blue',
    accepted: 'gold',
    rejected: 'red',
    done: 'cyan',
    solved: 'green',
    closed: 'default',
};

const SupportPage = () => {
    const [form] = Form.useForm();
    const { user } = useAuth();
    const screens = useBreakpoint();
    const isMobile = !screens.md;

    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [items, setItems] = useState([]);
    const [statusFilter, setStatusFilter] = useState('');
    const [selected, setSelected] = useState(null);
    const [commentText, setCommentText] = useState('');
    const [rejectModalOpen, setRejectModalOpen] = useState(false);
    const [rejectReason, setRejectReason] = useState('');
    const [modalOpen, setModalOpen] = useState(false);

    const isAdmin = Boolean(user?.is_admin || user?.is_super_admin || user?.is_superuser);

    const fetchData = async () => {
        setLoading(true);
        try {
            const { data } = await getSupportRequests({ status: statusFilter || undefined });
            const list = Array.isArray(data?.results) ? data.results : data;
            setItems(Array.isArray(list) ? list : []);
        } catch {
            message.error('Support məlumatları yüklənmədi');
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchData();
    }, [statusFilter]);

    const onSubmit = async (values) => {
        const formData = new FormData();
        formData.append('title', values.title);
        formData.append('summary', values.summary);
        formData.append('current_state', values.current_state);
        formData.append('expected_state', values.expected_state);
        if (values.attachment?.file?.originFileObj) {
            formData.append('attachment', values.attachment.file.originFileObj);
        }
        setSaving(true);
        try {
            await createSupportRequest(formData);
            message.success('Support müraciəti yaradıldı');
            form.resetFields();
            fetchData();
        } catch {
            message.error('Support müraciəti yaradıla bilmədi');
        } finally {
            setSaving(false);
        }
    };

    const openDetail = (item) => {
        setSelected(item);
        setModalOpen(true);
        setRejectReason('');
        setCommentText('');
    };

    const closeDetail = () => {
        setModalOpen(false);
        setSelected(null);
        setRejectReason('');
        setCommentText('');
    };

    const refreshSelected = async () => {
        if (!selected?.id) return;
        try {
            const { data } = await getSupportRequests();
            const list = Array.isArray(data?.results) ? data.results : data;
            const found = (Array.isArray(list) ? list : []).find((it) => it.id === selected.id);
            if (found) setSelected(found);
        } catch {
            // noop
        }
        fetchData();
    };

    const handleStatus = async (status) => {
        if (!selected?.id) return;
        try {
            await setSupportStatus(selected.id, { status, reject_note: '' });
            message.success('Status yeniləndi');
            refreshSelected();
        } catch {
            message.error('Status yenilənmədi');
        }
    };

    const submitReject = async () => {
        if (!selected?.id) return;
        const note = rejectReason.trim();
        if (!note) {
            message.warning('Rədd səbəbi yazın');
            return;
        }
        try {
            await setSupportStatus(selected.id, {
                status: 'rejected',
                reject_note: note,
            });
            message.success('Müraciət rədd edildi');
            setRejectModalOpen(false);
            setRejectReason('');
            refreshSelected();
        } catch {
            message.error('Rədd edilmədi');
        }
    };

    const sendComment = async () => {
        if (!selected?.id || !commentText.trim()) return;
        try {
            const { data } = await addSupportComment(selected.id, commentText.trim());
            const nextComments = [...(selected.comments || []), data];
            setSelected((prev) => (prev ? { ...prev, comments: nextComments } : prev));
            setItems((prev) =>
                prev.map((it) => (it.id === selected.id ? { ...it, comments: nextComments } : it)),
            );
            setCommentText('');
            message.success('Şərh əlavə olundu');
        } catch {
            message.error('Şərh göndərilə bilmədi');
        }
    };

    const canComment = useMemo(() => {
        if (!selected || !user) return false;
        return isAdmin || selected.created_by === user.id;
    }, [selected, user, isAdmin]);

    const detailField = (label, content) => (
        <div className={styles.detailBlock}>
            <span className={styles.detailSectionLabel}>{label}</span>
            <div>{content}</div>
        </div>
    );

    return (
        <div className={styles.page}>
            <header className={styles.pageHeader}>
                <Title level={2} className={styles.pageTitle}>
                    Dəstək mərkəzi
                </Title>
                <p className={styles.pageSubtitle}>
                    Problem və ya təklifinizi qeyd edin; komanda üzvləri müraciətləri izləyir və cavab
                    yaza bilər.
                </p>
            </header>

            <Row gutter={[16, 16]}>
                <Col xs={24} lg={10}>
                    <Card className={styles.formCard} title="Yeni müraciət">
                        <Form form={form} layout="vertical" onFinish={onSubmit} requiredMark="optional">
                            <Form.Item
                                name="title"
                                label="Başlıq"
                                rules={[{ required: true, message: 'Başlıq tələb olunur' }]}
                            >
                                <Input placeholder="Qısa başlıq" size="large" />
                            </Form.Item>
                            <Form.Item
                                name="summary"
                                label="Qısa xülasə"
                                rules={[{ required: true, message: 'Xülasə tələb olunur' }]}
                            >
                                <Input.TextArea rows={isMobile ? 4 : 3} placeholder="Nə baş verir?" />
                            </Form.Item>
                            <Form.Item
                                name="current_state"
                                label="İndiki vəziyyət"
                                rules={[{ required: true, message: 'Bu sahə tələb olunur' }]}
                            >
                                <Input.TextArea rows={isMobile ? 4 : 3} placeholder="Hal-hazırda nə görürsünüz?" />
                            </Form.Item>
                            <Form.Item
                                name="expected_state"
                                label="Olmalı olan"
                                rules={[{ required: true, message: 'Bu sahə tələb olunur' }]}
                            >
                                <Input.TextArea rows={isMobile ? 4 : 3} placeholder="Gözlədiyiniz nəticə" />
                            </Form.Item>
                            <Form.Item name="attachment" label="Şəkil və ya fayl (istəyə bağlı)">
                                <Dragger beforeUpload={() => false} maxCount={1}>
                                    <p className="ant-upload-drag-icon">
                                        <InboxOutlined />
                                    </p>
                                    <p className="ant-upload-text">Faylı seçin və ya bura sürüyün</p>
                                    <p className="ant-upload-hint">Tək fayl, maks. ölçü server limitinə uyğun</p>
                                </Dragger>
                            </Form.Item>
                            <Button type="primary" htmlType="submit" loading={saving} block size="large">
                                Müraciəti göndər
                            </Button>
                        </Form>
                    </Card>
                </Col>
                <Col xs={24} lg={14}>
                    <Card className={styles.listCard} title="Müraciətlər" loading={loading}>
                        <div className={styles.listToolbar}>
                            <span className={styles.listToolbarLabel}>Status üzrə süzgəc</span>
                            <Select
                                className={styles.statusFilter}
                                placeholder="Hamısı"
                                allowClear
                                value={statusFilter || undefined}
                                onChange={(v) => setStatusFilter(v || '')}
                                options={STATUS_OPTIONS}
                                size="large"
                            />
                        </div>
                        {items.length === 0 && !loading ? (
                            <Empty description="Hələ müraciət yoxdur" />
                        ) : (
                            <div className={styles.taskList}>
                                {items.map((it) => (
                                    <Card
                                        key={it.id}
                                        className={styles.taskItem}
                                        size="small"
                                        hoverable
                                        onClick={() => openDetail(it)}
                                        title={(
                                            <Text strong className={styles.taskItemTitle}>
                                                #{it.id} — {it.title}
                                            </Text>
                                        )}
                                        extra={(
                                            <Tag color={statusColor[it.status] || 'default'}>
                                                {it.status_display || it.status}
                                            </Tag>
                                        )}
                                    >
                                        <Paragraph
                                            className={styles.taskItemSummary}
                                            ellipsis={{ rows: 2 }}
                                        >
                                            {it.summary}
                                        </Paragraph>
                                        <Text type="secondary" style={{ fontSize: 12 }}>
                                            {it.created_by_name}
                                        </Text>
                                    </Card>
                                ))}
                            </div>
                        )}
                    </Card>
                </Col>
            </Row>

            <Modal
                open={modalOpen}
                onCancel={closeDetail}
                footer={null}
                width={isMobile ? '100%' : 840}
                wrapClassName={styles.supportModalWrap}
                centered={!isMobile}
                title={selected ? `Müraciət #${selected.id}` : 'Müraciət'}
                destroyOnClose
            >
                {!selected ? null : (
                    <Space direction="vertical" style={{ width: '100%' }} size={14}>
                        <div>
                            <Tag color={statusColor[selected.status] || 'default'} style={{ margin: 0 }}>
                                {selected.status_display || selected.status}
                            </Tag>
                        </div>

                        {detailField('Başlıq', <Paragraph style={{ marginBottom: 0 }}>{selected.title}</Paragraph>)}
                        {detailField(
                            'Qısa xülasə',
                            <Paragraph style={{ marginBottom: 0 }}>{selected.summary}</Paragraph>,
                        )}
                        {detailField(
                            'İndiki vəziyyət',
                            <Paragraph style={{ marginBottom: 0, whiteSpace: 'pre-wrap' }}>
                                {selected.current_state}
                            </Paragraph>,
                        )}
                        {detailField(
                            'Olmalı olan',
                            <Paragraph style={{ marginBottom: 0, whiteSpace: 'pre-wrap' }}>
                                {selected.expected_state}
                            </Paragraph>,
                        )}

                        {selected.attachment && (
                            <Alert
                                type="info"
                                showIcon
                                message={(
                                    <a href={selected.attachment} target="_blank" rel="noreferrer">
                                        Əlavə faylı / şəkli aç
                                    </a>
                                )}
                            />
                        )}
                        {selected.reject_note && (
                            <Alert type="error" showIcon message={`Rədd qeydi: ${selected.reject_note}`} />
                        )}

                        {isAdmin && (
                            <Card size="small" title="Status" styles={{ body: { paddingTop: 12 } }}>
                                <div className={styles.statusActions}>
                                    {selected.status === 'new' && (
                                        <Button
                                            type="primary"
                                            className={styles.actionBtn}
                                            onClick={() => handleStatus('accepted')}
                                        >
                                            Qəbul et
                                        </Button>
                                    )}
                                    {selected.status === 'accepted' && (
                                        <Button
                                            className={styles.actionBtn}
                                            style={{ borderColor: '#08979c', color: '#08979c' }}
                                            onClick={() => handleStatus('done')}
                                        >
                                            Done
                                        </Button>
                                    )}
                                    {selected.status === 'done' && (
                                        <Button
                                            className={styles.actionBtn}
                                            style={{ borderColor: '#389e0d', color: '#389e0d' }}
                                            onClick={() => handleStatus('solved')}
                                        >
                                            Solved
                                        </Button>
                                    )}
                                    {['done', 'solved'].includes(selected.status) && selected.status !== 'closed' && (
                                        <Button className={styles.actionBtn} onClick={() => handleStatus('closed')}>
                                            Bağla
                                        </Button>
                                    )}
                                    {['new', 'accepted'].includes(selected.status) && (
                                        <Button
                                            danger
                                            type="primary"
                                            ghost
                                            className={styles.actionBtn}
                                            onClick={() => {
                                                setRejectReason('');
                                                setRejectModalOpen(true);
                                            }}
                                        >
                                            Rədd et
                                        </Button>
                                    )}
                                </div>
                            </Card>
                        )}

                        <Card size="small" title="Şərhlər" styles={{ body: { paddingTop: 12 } }}>
                            <Space direction="vertical" style={{ width: '100%' }} size={10}>
                                {(selected.comments || []).map((c) => (
                                    <Card
                                        size="small"
                                        key={c.id}
                                        styles={{ body: { padding: '12px 14px' } }}
                                        style={{ background: '#fafafa' }}
                                    >
                                        <Text strong>{c.user_name}</Text>
                                        <Paragraph style={{ marginTop: 8, marginBottom: 0, whiteSpace: 'pre-wrap' }}>
                                            {c.body}
                                        </Paragraph>
                                    </Card>
                                ))}
                                {(selected.comments || []).length === 0 && (
                                    <Text type="secondary">Hələ şərh yoxdur</Text>
                                )}
                            </Space>
                        </Card>

                        {canComment ? (
                            <div className={styles.commentRow}>
                                <Input
                                    className={styles.commentInput}
                                    value={commentText}
                                    onChange={(e) => setCommentText(e.target.value)}
                                    placeholder="Şərh yazın"
                                    onPressEnter={(e) => {
                                        if (!e.shiftKey) {
                                            e.preventDefault();
                                            sendComment();
                                        }
                                    }}
                                />
                                <Button
                                    type="primary"
                                    className={styles.commentSubmit}
                                    onClick={sendComment}
                                    disabled={!commentText.trim()}
                                >
                                    Göndər
                                </Button>
                            </div>
                        ) : (
                            <Alert
                                type="warning"
                                showIcon
                                message="Bu müraciətə yalnız onu açan istifadəçi və adminlər şərh yaza bilər."
                            />
                        )}
                    </Space>
                )}
            </Modal>

            <Modal
                title="Rədd səbəbi"
                open={rejectModalOpen}
                okText="Təsdiq et"
                cancelText="Ləğv et"
                onOk={submitReject}
                onCancel={() => {
                    setRejectModalOpen(false);
                    setRejectReason('');
                }}
                destroyOnClose
                width={isMobile ? '100%' : 520}
                wrapClassName={styles.supportModalWrap}
                centered={!isMobile}
            >
                <Input.TextArea
                    rows={isMobile ? 5 : 4}
                    value={rejectReason}
                    onChange={(e) => setRejectReason(e.target.value)}
                    placeholder="Rədd etmə səbəbini yazın..."
                    maxLength={2000}
                    showCount
                />
            </Modal>
        </div>
    );
};

export default SupportPage;
