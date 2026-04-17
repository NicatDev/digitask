import React, { useEffect, useMemo, useState } from 'react';
import {
    Alert,
    Button,
    Card,
    Col,
    Empty,
    Form,
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

const { Title, Text, Paragraph } = Typography;
const { Dragger } = Upload;
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
    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [items, setItems] = useState([]);
    const [statusFilter, setStatusFilter] = useState('');
    const [selected, setSelected] = useState(null);
    const [commentText, setCommentText] = useState('');
    const [rejectNote, setRejectNote] = useState('');
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
        setRejectNote('');
        setCommentText('');
    };

    const closeDetail = () => {
        setModalOpen(false);
        setSelected(null);
        setRejectNote('');
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
        if (status === 'rejected' && !rejectNote.trim()) {
            message.warning('Rədd səbəbi yazın');
            return;
        }
        try {
            await setSupportStatus(selected.id, {
                status,
                reject_note: status === 'rejected' ? rejectNote.trim() : '',
            });
            message.success('Status yeniləndi');
            refreshSelected();
        } catch {
            message.error('Status yenilənmədi');
        }
    };

    const sendComment = async () => {
        if (!selected?.id || !commentText.trim()) return;
        try {
            await addSupportComment(selected.id, commentText.trim());
            setCommentText('');
            message.success('Şərh əlavə olundu');
            refreshSelected();
        } catch {
            message.error('Şərh göndərilə bilmədi');
        }
    };

    const canComment = useMemo(() => {
        if (!selected || !user) return false;
        return isAdmin || selected.created_by === user.id;
    }, [selected, user, isAdmin]);

    return (
        <Space direction="vertical" size={16} style={{ width: '100%' }}>
            <Title level={2} style={{ marginBottom: 0 }}>Support</Title>
            <Row gutter={[16, 16]}>
                <Col xs={24} lg={10}>
                    <Card title="Supporta müraciət et">
                        <Form form={form} layout="vertical" onFinish={onSubmit}>
                            <Form.Item name="title" label="Başlıq" rules={[{ required: true, message: 'Başlıq tələb olunur' }]}>
                                <Input placeholder="Qısa başlıq" />
                            </Form.Item>
                            <Form.Item name="summary" label="Qısa xülasə" rules={[{ required: true, message: 'Xülasə tələb olunur' }]}>
                                <Input.TextArea rows={3} />
                            </Form.Item>
                            <Form.Item name="current_state" label="İndiki vəziyyət" rules={[{ required: true, message: 'Bu sahə tələb olunur' }]}>
                                <Input.TextArea rows={3} />
                            </Form.Item>
                            <Form.Item name="expected_state" label="Olmalı olan" rules={[{ required: true, message: 'Bu sahə tələb olunur' }]}>
                                <Input.TextArea rows={3} />
                            </Form.Item>
                            <Form.Item name="attachment" label="Şəkil və ya fayl">
                                <Dragger beforeUpload={() => false} maxCount={1}>
                                    <p className="ant-upload-drag-icon"><InboxOutlined /></p>
                                    <p>Faylı bura atın və ya seçin</p>
                                </Dragger>
                            </Form.Item>
                            <Button type="primary" htmlType="submit" loading={saving} block>
                                Təsdiqlə
                            </Button>
                        </Form>
                    </Card>
                </Col>
                <Col xs={24} lg={14}>
                    <Card
                        title="Support taskları"
                        extra={(
                            <Select
                                placeholder="Statusa görə filter"
                                allowClear
                                value={statusFilter || undefined}
                                onChange={(v) => setStatusFilter(v || '')}
                                style={{ minWidth: 180 }}
                                options={STATUS_OPTIONS}
                            />
                        )}
                        loading={loading}
                    >
                        {items.length === 0 && <Empty description="Support taskı yoxdur" />}
                        <Space direction="vertical" style={{ width: '100%' }}>
                            {items.map((it) => (
                                <Card
                                    key={it.id}
                                    size="small"
                                    hoverable
                                    onClick={() => openDetail(it)}
                                    title={<Text strong>{`#${it.id} - ${it.title}`}</Text>}
                                    extra={<Tag color={statusColor[it.status] || 'default'}>{it.status_display || it.status}</Tag>}
                                >
                                    <Paragraph ellipsis={{ rows: 2 }} style={{ marginBottom: 0 }}>
                                        {it.summary}
                                    </Paragraph>
                                    <Text type="secondary">{it.created_by_name}</Text>
                                </Card>
                            ))}
                        </Space>
                    </Card>
                </Col>
            </Row>

            <Modal
                open={modalOpen}
                onCancel={closeDetail}
                footer={null}
                width={840}
                title={selected ? `Support #${selected.id}` : 'Support'}
                destroyOnClose
            >
                {!selected ? null : (
                    <Space direction="vertical" style={{ width: '100%' }} size={12}>
                        <Tag color={statusColor[selected.status] || 'default'}>{selected.status_display || selected.status}</Tag>
                        <Text strong>Başlıq</Text>
                        <Paragraph>{selected.title}</Paragraph>
                        <Text strong>Qısa xülasə</Text>
                        <Paragraph>{selected.summary}</Paragraph>
                        <Text strong>İndiki vəziyyət</Text>
                        <Paragraph>{selected.current_state}</Paragraph>
                        <Text strong>Olmalı olan</Text>
                        <Paragraph>{selected.expected_state}</Paragraph>
                        {selected.attachment && (
                            <Alert
                                type="info"
                                message={<a href={selected.attachment} target="_blank" rel="noreferrer">Əlavə faylı aç</a>}
                            />
                        )}
                        {selected.reject_note && (
                            <Alert type="error" message={`Rədd qeydi: ${selected.reject_note}`} />
                        )}

                        {isAdmin && (
                            <Card size="small" title="Status idarəetməsi">
                                <Space wrap>
                                    <Button onClick={() => handleStatus('accepted')}>Accept</Button>
                                    <Button onClick={() => handleStatus('done')}>Done</Button>
                                    <Button onClick={() => handleStatus('solved')}>Solved</Button>
                                    <Button onClick={() => handleStatus('closed')}>Closed</Button>
                                </Space>
                                <Space.Compact style={{ width: '100%', marginTop: 10 }}>
                                    <Input
                                        value={rejectNote}
                                        onChange={(e) => setRejectNote(e.target.value)}
                                        placeholder="Reject səbəbi yazın"
                                    />
                                    <Button danger onClick={() => handleStatus('rejected')}>Reject</Button>
                                </Space.Compact>
                            </Card>
                        )}

                        <Card size="small" title="Şərhlər">
                            <Space direction="vertical" style={{ width: '100%' }}>
                                {(selected.comments || []).map((c) => (
                                    <Card size="small" key={c.id}>
                                        <Text strong>{c.user_name}</Text>
                                        <Paragraph style={{ marginTop: 8, marginBottom: 0 }}>{c.body}</Paragraph>
                                    </Card>
                                ))}
                                {(selected.comments || []).length === 0 && (
                                    <Text type="secondary">Hələ şərh yoxdur</Text>
                                )}
                            </Space>
                        </Card>

                        {canComment ? (
                            <Space.Compact style={{ width: '100%' }}>
                                <Input
                                    value={commentText}
                                    onChange={(e) => setCommentText(e.target.value)}
                                    placeholder="Şərh yazın"
                                />
                                <Button type="primary" onClick={sendComment}>Göndər</Button>
                            </Space.Compact>
                        ) : (
                            <Alert type="warning" message="Bu taska yalnız açan istifadəçi və adminlər şərh yaza bilər." />
                        )}
                    </Space>
                )}
            </Modal>
        </Space>
    );
};

export default SupportPage;
