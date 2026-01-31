import React, { useEffect, useRef, useState } from 'react';
import { Button, Input, Avatar, List, Modal, Form, Select, message as antMessage, Switch } from 'antd';
import { SendOutlined, SettingOutlined, UserAddOutlined, DeleteOutlined, UserOutlined } from '@ant-design/icons';
import styles from '../style.module.scss';
import dayjs from 'dayjs';
import { addGroupMember, removeGroupMember } from '../../../axios/api/chat';
import { getUsers } from '../../../axios/api/account';

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
    onUpdateGroup
}) => {
    const [inputValue, setInputValue] = useState('');
    const messagesEndRef = useRef(null);
    const messagesContainerRef = useRef(null);
    const [isSettingsOpen, setIsSettingsOpen] = useState(false);
    const [allUsers, setAllUsers] = useState([]);
    const [selectedUserToAdd, setSelectedUserToAdd] = useState(null);

    const handleSend = () => {
        if (!inputValue.trim()) return;
        onSendMessage(inputValue);
        setInputValue('');
    };

    const handleKeyPress = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSend();
        }
    };

    // Scroll Logic
    const [isFirstLoad, setIsFirstLoad] = useState(true);
    const prevMessagesRef = useRef([]);

    // Reset first load when group changes
    useEffect(() => {
        setIsFirstLoad(true);
        prevMessagesRef.current = [];
    }, [group?.id]);

    useEffect(() => {
        const prevMessages = prevMessagesRef.current;
        const newMessages = messages;

        // 1. Initial Load (First time messages appear for a group)
        if (isFirstLoad && newMessages.length > 0) {
            messagesEndRef.current?.scrollIntoView({ behavior: 'auto' });
            setIsFirstLoad(false);
        }
        // 2. New Message (Appended)
        else if (newMessages.length > prevMessages.length) {
            // Check if it's a prepend (Load More) or append (New Message)
            const isPrepend = newMessages.length > 0 && prevMessages.length > 0 && newMessages[0].id !== prevMessages[0].id;

            if (!isPrepend) {
                // It's an append (new message sent/received)
                messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
            }
        }

        prevMessagesRef.current = newMessages;
    }, [messages, isFirstLoad]);

    // Helper to format date
    const formatDate = (date) => {
        return dayjs(date).format('HH:mm');
    };

    // Settings Modal Handlers
    const openSettings = async () => {
        setIsSettingsOpen(true);
        try {
            const res = await getUsers(); // Fetch all users to add
            setAllUsers(res.data.results || res.data);
        } catch (e) {
            console.error(e);
        }
    };

    const handleAddUser = async (userId) => {
        try {
            await onAddMember(group.id, userId);
            antMessage.success('İstifadəçi əlavə olundu');
            setSelectedUserToAdd(null);
        } catch (e) {
            antMessage.error('Xəta baş verdi');
        }
    };

    const handleRemoveUser = async (userId) => {
        try {
            await onRemoveMember(group.id, userId);
            antMessage.success('İstifadəçi qrupdan çıxarıldı');
        } catch (e) {
            antMessage.error('Xəta baş verdi');
        }
    };


    if (!group) {
        return (
            <div className={styles.emptyState}>
                <SettingOutlined style={{ fontSize: 48 }} />
                <h3>Söhbətə başlamaq üçün qrup seçin</h3>
            </div>
        );
    }

    const isOwner = group.owner?.id === currentUser?.id;

    return (
        <div className={styles.chatArea}>
            <div className={styles.header}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <Avatar shape="square" src={group.image}>{group.name[0]}</Avatar>
                    <div>
                        <div style={{ fontWeight: 'bold' }}>{group.name}</div>
                        <div style={{ fontSize: 12, color: '#888' }}>{group.members?.length || 0} üzv</div>
                    </div>
                </div>
                {isOwner && (
                    <Button icon={<SettingOutlined />} onClick={openSettings}>Tənzimləmələr</Button>
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

                    return (
                        <div key={msg.id || index} className={`${styles.messageBubble} ${isMe ? styles.myMessage : styles.otherMessage}`}>
                            {showSender && <div className={styles.sender}>{msg.sender.first_name || msg.sender.email}</div>}
                            <div className={styles.content}>{msg.content}</div>
                            <div className={styles.time}>{formatDate(msg.created_at)}</div>
                        </div>
                    );
                })}
                <div ref={messagesEndRef} />
            </div>

            <div className={styles.inputArea}>
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
