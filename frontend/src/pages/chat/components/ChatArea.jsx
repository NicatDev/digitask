import React, { useEffect, useRef, useState } from 'react';
import { Button, Input, Avatar, List, Modal, Form, Select, Switch, Popover } from 'antd';
import { SendOutlined, SettingOutlined, UserAddOutlined, DeleteOutlined, UserOutlined, ArrowLeftOutlined, RollbackOutlined, CloseOutlined, SmileOutlined } from '@ant-design/icons';
import styles from '../style.module.scss';
import { decodeReply, encodeReply } from '../utils/replyCodec';
import { decodeTaskChatMessage, stripTaskChatMessage } from '../utils/taskMessageCodec';

const { TextArea } = Input;

const ChatArea = ({
    group,
    messages,
    currentUser,
    onSendMessage,
    loading,
    onLoadMore,
    hasMore,
    onAddMember,
    onRemoveMember,
    onUpdateGroup,
    onOpenTask,
    onBack // Prop for back button
}) => {
    const [inputValue, setInputValue] = useState('');
    const [replyTo, setReplyTo] = useState(null);
    const [isSettingsOpen, setIsSettingsOpen] = useState(false);
    const [allUsers, setAllUsers] = useState([]);
    const [selectedUserToAdd, setSelectedUserToAdd] = useState(null);
    const messagesEndRef = useRef(null);
    const messagesContainerRef = useRef(null);
    const emojis = ['😀', '😁', '😂', '😊', '😍', '👍', '🙏', '👏', '🔥', '✅', '⚠️', '❤️'];

    const isOwner = currentUser && group && group.owner && (
        (typeof group.owner === 'object' ? group.owner.id : group.owner) === currentUser.id
    );

    useEffect(() => {
        if (messagesEndRef.current) {
            messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
        }
    }, [messages]);

    useEffect(() => {
        if (isSettingsOpen) {
            fetchUsers();
        }
    }, [isSettingsOpen]);

    const fetchUsers = async () => {
        try {
            const { getUsers } = await import('../../../axios/api/account');
            const res = await getUsers();
            setAllUsers(res.data.results || res.data);
        } catch (e) {
            console.error(e);
        }
    };

    const handleSend = () => {
        const t = inputValue.trim();
        if (!t) return;
        const payload = encodeReply(t, replyTo);
        onSendMessage(payload);
        setInputValue('');
        setReplyTo(null);
    };

    const handleKeyPress = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSend();
        }
    };

    const formatDate = (dateString) => {
        if (!dateString) return '';
        const date = new Date(dateString);
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    };

    const isSameDay = (a, b) => {
        if (!a || !b) return false;
        return (
            a.getFullYear() === b.getFullYear() &&
            a.getMonth() === b.getMonth() &&
            a.getDate() === b.getDate()
        );
    };

    const getDayLabel = (dateString) => {
        if (!dateString) return '';
        const date = new Date(dateString);
        const now = new Date();
        const yesterday = new Date();
        yesterday.setDate(now.getDate() - 1);

        if (isSameDay(date, now)) return 'Bu gün';
        if (isSameDay(date, yesterday)) return 'Dünən';
        return date.toLocaleDateString('az-AZ');
    };

    const openSettings = () => {
        setIsSettingsOpen(true);
    };

    const handleAddUser = (userId) => {
        if (onAddMember) onAddMember(group.id, userId);
        setSelectedUserToAdd(null);
    };

    const handleRemoveUser = (userId) => {
        if (onRemoveMember) onRemoveMember(group.id, userId);
    };

    if (!group) {
        return <div className={styles.chatArea} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>Yuklənir...</div>;
    }

    return (
        <div className={styles.chatArea}>
            <div className={styles.header}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div className={styles.backButton} onClick={onBack}>
                        <ArrowLeftOutlined />
                    </div>
                    <Avatar shape="square" src={group.image}>{group.name[0]}</Avatar>
                    <div>
                        <div style={{ fontWeight: 'bold' }}>{group.name}</div>
                        <div style={{ fontSize: 12, color: '#888' }}>{group.members?.length || 0} üzv</div>
                    </div>
                </div>
                {isOwner && (
                    <Button icon={<SettingOutlined />} onClick={openSettings}>
                        <span className={styles.settingsText}>Tənzimləmələr</span>
                    </Button>
                )}
            </div>

            <div className={styles.messages} ref={messagesContainerRef}>
                {hasMore && (
                    <div style={{ textAlign: 'center', padding: 10 }}>
                        <Button size="small" onClick={onLoadMore} loading={loading}>Daha çox yüklə</Button>
                    </div>
                )}

                {messages.map((msg, index) => {
                    const isMe = msg.is_me || msg.sender.id === currentUser?.id;
                    const showSender = !isMe && (index === 0 || messages[index - 1].sender.id !== msg.sender.id);
                    const messageDate = msg.created_at ? new Date(msg.created_at) : null;
                    const prevDate = index > 0 && messages[index - 1]?.created_at ? new Date(messages[index - 1].created_at) : null;
                    const showDateSeparator = index === 0 || !isSameDay(messageDate, prevDate);
                    const { reply, body } = decodeReply(msg.content);
                    const taskPayload = decodeTaskChatMessage(body);

                    return (
                        <React.Fragment key={msg.id || index}>
                            {showDateSeparator && (
                                <div className={styles.dateSeparator}>
                                    <span>{getDayLabel(msg.created_at)}</span>
                                </div>
                            )}
                            <div className={`${styles.messageRow} ${isMe ? styles.myRow : styles.otherRow}`}>
                                <Button
                                    type="text"
                                    size="small"
                                    className={styles.replyBtn}
                                    icon={<RollbackOutlined />}
                                    onClick={() =>
                                        setReplyTo({
                                            id: msg.id,
                                            sender: msg.sender?.first_name || msg.sender?.email || '',
                                            snippet: stripTaskChatMessage(body || '').slice(0, 80),
                                        })
                                    }
                                />
                                <div className={`${styles.messageBubble} ${isMe ? styles.myMessage : styles.otherMessage}`}>
                                    {showSender && <div className={styles.sender}>{msg.sender.first_name || msg.sender.email}</div>}
                                    {reply ? (
                                        <div className={styles.replyPreviewInBubble}>
                                            <div className={styles.replyMeta}>
                                                Cavab: {reply.sender || ''} #{reply.id}
                                            </div>
                                            <div className={styles.replySnippet}>{reply.snippet || ''}</div>
                                        </div>
                                    ) : null}
                                    {taskPayload ? (
                                        <div
                                            className={styles.taskMessageCard}
                                            onClick={() => onOpenTask?.(taskPayload.task?.id)}
                                        >
                                            <div className={styles.taskMessageTitle}>
                                                #{taskPayload.task?.id} {taskPayload.task?.title || 'Tapşırıq'}
                                            </div>
                                            <div className={styles.taskMessageGrid}>
                                                <span>Status</span><b>{taskPayload.task?.status || '—'}</b>
                                                <span>Qeydiyyat</span><b>{taskPayload.task?.register_number || '—'}</b>
                                                <span>Müştəri</span><b>{taskPayload.task?.customer || '—'}</b>
                                                <span>İcraçılar</span><b>{taskPayload.task?.assignees?.join(', ') || '—'}</b>
                                            </div>
                                            {taskPayload.note ? <div className={styles.taskMessageNote}>{taskPayload.note}</div> : null}
                                        </div>
                                    ) : (
                                        <div className={styles.content}>{body}</div>
                                    )}
                                    <div className={styles.time}>{formatDate(msg.created_at)}</div>
                                </div>
                            </div>
                        </React.Fragment>
                    );
                })}
                <div ref={messagesEndRef} />
            </div>

            <div className={styles.inputArea}>
                {replyTo ? (
                    <div className={styles.replyBar}>
                        <div className={styles.replyBarText}>
                            Cavab: {replyTo.sender} #{replyTo.id} — {replyTo.snippet}
                        </div>
                        <Button type="text" size="small" icon={<CloseOutlined />} onClick={() => setReplyTo(null)} />
                    </div>
                ) : null}
                <div className={styles.inputRow}>
                    <Popover
                        trigger="click"
                        placement="topLeft"
                        content={
                            <div className={styles.emojiGrid}>
                                {emojis.map((emoji) => (
                                    <button
                                        key={emoji}
                                        type="button"
                                        onClick={() => setInputValue((prev) => `${prev}${emoji}`)}
                                    >
                                        {emoji}
                                    </button>
                                ))}
                            </div>
                        }
                    >
                        <Button
                            shape="circle"
                            icon={<SmileOutlined />}
                            size="large"
                            disabled={!isOwner && group.only_owner_can_send}
                        />
                    </Popover>
                    <TextArea
                        value={inputValue}
                        onChange={(e) => setInputValue(e.target.value)}
                        onKeyPress={handleKeyPress}
                        placeholder={(!isOwner && group.only_owner_can_send) ? "Yalnız qrup rəhbəri yaza bilər" : "Mesajınızı yazın..."}
                        autoSize={{ minRows: 1, maxRows: 4 }}
                        style={{ borderRadius: 20 }}
                        disabled={!isOwner && group.only_owner_can_send}
                    />
                    <Button
                        type="primary"
                        shape="circle"
                        icon={<SendOutlined />}
                        size="large"
                        onClick={handleSend}
                        disabled={!isOwner && group.only_owner_can_send}
                    />
                </div>
            </div>

            {/* Settings Modal */}
            <Modal
                title="Qrup Tənzimləmələri"
                open={isSettingsOpen}
                onCancel={() => setIsSettingsOpen(false)}
                footer={null}
            >
                {isOwner && (
                    <div style={{ marginBottom: 24, paddingBottom: 16, borderBottom: '1px solid #f0f0f0' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                            <span>Yalnız Rəhbər (Admin) yaza bilsin</span>
                            <Switch
                                checked={group.only_owner_can_send}
                                onChange={(checked) => onUpdateGroup && onUpdateGroup(group.id, { only_owner_can_send: checked })}
                            />
                        </div>
                    </div>
                )}

                <h4>İstifadəçi Əlavə Et</h4>
                <div style={{ display: 'flex', gap: 10, marginBottom: 20 }}>
                    <Select
                        showSearch
                        style={{ flex: 1 }}
                        placeholder="İstifadəçi axtar..."
                        optionFilterProp="children"
                        onChange={(val) => setSelectedUserToAdd(val)}
                        value={selectedUserToAdd}
                    >
                        {allUsers.map(u => (
                            <Select.Option key={u.id} value={u.id}>
                                {u.first_name || ''} {u.last_name || ''} ({u.email})
                            </Select.Option>
                        ))}
                    </Select>
                    <Button
                        type="primary"
                        onClick={() => handleAddUser(selectedUserToAdd)}
                        disabled={!selectedUserToAdd}
                        icon={<UserAddOutlined />}
                    >
                        Əlavə et
                    </Button>
                </div>

                <h4>Üzvlər</h4>
                <List
                    dataSource={group.members}
                    renderItem={member => (
                        <List.Item
                            actions={[
                                (isOwner && member.user.id !== currentUser.id) &&
                                <Button type="text" danger icon={<DeleteOutlined />} onClick={() => handleRemoveUser(member.user.id)} />
                            ]}
                        >
                            <List.Item.Meta
                                avatar={<Avatar src={member.user.avatar} icon={<UserOutlined />} />}
                                title={`${member.user.first_name || ''} ${member.user.last_name || ''}`.trim() || member.user.email}
                                description={member.user.email}
                            />
                        </List.Item>
                    )}
                />
            </Modal>
        </div>
    );
};

export default ChatArea;
