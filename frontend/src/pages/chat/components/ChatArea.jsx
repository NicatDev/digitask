import React, { useEffect, useRef, useState } from 'react';
import { Button, Input, Avatar, List, Modal, Form, Select, message as antMessage, Switch } from 'antd';
import { SendOutlined, SettingOutlined, UserAddOutlined, DeleteOutlined, UserOutlined, ArrowLeftOutlined } from '@ant-design/icons';
// ... imports

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
    onBack // Prop for back button
}) => {
    // ... existing code ...

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
