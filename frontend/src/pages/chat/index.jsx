import React, { useEffect, useState, useRef } from 'react';
import styles from './style.module.scss';
import GroupList from './components/GroupList';
import ChatArea from './components/ChatArea';
import { getChatGroups, createChatGroup, getChatGroupDetails, getGroupMessages, addGroupMember, removeGroupMember, markMessagesRead, deleteChatGroup } from '../../axios/api/chat';
import { getMe } from '../../axios/api/account';
import { message } from 'antd';

const ChatPage = () => {
    const [groups, setGroups] = useState([]);
    const [selectedGroupId, setSelectedGroupId] = useState(null);
    const [messages, setMessages] = useState([]);
    const [currentUser, setCurrentUser] = useState(null);
    const [loadingMessages, setLoadingMessages] = useState(false);

    const [selectedGroupDetails, setSelectedGroupDetails] = useState(null);
    const [page, setPage] = useState(1);
    const [hasMore, setHasMore] = useState(true);

    // WebSocket
    const ws = useRef(null);

    useEffect(() => {
        fetchProfile();
        fetchGroups();
    }, []);

    useEffect(() => {
        if (selectedGroupId) {
            connectWebSocket(selectedGroupId);
            // Reset for new group
            setMessages([]);
            setPage(1);
            setHasMore(true);
            loadGroupHistory(selectedGroupId, 1);
            loadGroupDetails(selectedGroupId);
        } else {
            setSelectedGroupDetails(null);
        }
        return () => {
            if (ws.current) {
                ws.current.close();
            }
        };
    }, [selectedGroupId]);

    const fetchProfile = async () => {
        // ... existing ... 
        try {
            const res = await getMe();
            setCurrentUser(res.data);
        } catch (e) {
            console.error("Profile fetch error", e);
        }
    };

    const fetchGroups = async () => {
        // ... existing ...
        try {
            const res = await getChatGroups();
            setGroups(res.data.results || res.data);
        } catch (e) {
            message.error("Qrupları yükləmək mümkün olmadı");
        }
    };

    const loadGroupDetails = async (groupId) => {
        // ... existing ...
        try {
            const res = await getChatGroupDetails(groupId);
            setSelectedGroupDetails(res.data);
        } catch (e) {
            console.error("Group details fetch error", e);
        }
    };

    const connectWebSocket = (groupId) => {
        if (ws.current) {
            ws.current.close();
        }

        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const host = window.location.hostname; // e.g. localhost
        const port = '8000'; // Backend port
        const token = localStorage.getItem('access_token');
        const url = `${protocol}//${host}:${port}/ws/chat/groups/${groupId}/?token=${token}`;

        ws.current = new WebSocket(url);

        ws.current.onopen = () => {
            console.log("Connected to Chat WS");
        };

        ws.current.onmessage = (event) => {
            const data = JSON.parse(event.data);

            const normalizedMsg = {
                id: data.id,
                content: data.message,
                created_at: data.created_at,
                sender: {
                    id: data.sender_id,
                    first_name: data.sender,
                    email: ''
                },
                is_me: data.sender_id === currentUser?.id
            };

            setMessages(prev => [...prev, normalizedMsg]);

            if (data.id) {
                // Mark read immediately if focused
                markMessagesRead(groupId).then(() => {
                    fetchGroups(); // Refresh unread counts
                });
            }
        };

        ws.current.onclose = () => {
            console.log("Disconnected Chat WS");
        };
    };

    const loadGroupHistory = async (groupId, pageNum) => {
        setLoadingMessages(true);
        try {
            // Pagination logic:
            const res = await getGroupMessages(groupId, pageNum);

            const newMessages = res.data.results || [];
            // Backend returns ordered by -created_at (Newest first).
            // We want to display oldest at top, newest at bottom.
            // So we reverse the *chunk* we got.

            const orderedChunk = [...newMessages].reverse();

            if (pageNum === 1) {
                setMessages(orderedChunk);
                // Mark all read on initial load
                await markMessagesRead(groupId);
                fetchGroups(); // Update badges
            } else {
                setMessages(prev => [...orderedChunk, ...prev]);
            }

            setHasMore(!!res.data.next);

        } catch (e) {
            console.error(e);
        } finally {
            setLoadingMessages(false);
        }
    };

    const handleLoadMore = () => {
        if (!hasMore || loadingMessages) return;
        const nextPage = page + 1;
        setPage(nextPage);
        loadGroupHistory(selectedGroupId, nextPage);
    };

    const handleSendMessage = (text) => {
        // ... existing ...
        if (ws.current && ws.current.readyState === WebSocket.OPEN) {
            ws.current.send(JSON.stringify({ message: text }));
        } else {
            message.error("Bağlantı xətası. Yenidən cəhd edin.");
        }
    };

    const handleAddGroup = async (values) => {
        try {
            await createChatGroup(values);
            fetchGroups();
            message.success("Qrup yaradıldı");
        } catch (e) {
            message.error("Qrup yaratmaq mümkün olmadı");
        }
    };

    const handleAddMember = async (groupId, userId) => {
        try {
            await addGroupMember(groupId, userId);
            loadGroupDetails(groupId); // Refresh details
        } catch (e) {
            console.log(e)
            message.error("Xəta");
        }
    };

    const handleRemoveMember = async (groupId, userId) => {
        try {
            await removeGroupMember(groupId, userId);
            loadGroupDetails(groupId); // Refresh details
        } catch (e) {
            message.error("Xəta");
        }
    };

    const handleDeleteGroup = async (groupId) => {
        try {
            await deleteChatGroup(groupId);
            message.success("Qrup silindi");
            fetchGroups();
            if (selectedGroupId === groupId) {
                setSelectedGroupId(null);
                setMessages([]);
            }
        } catch (e) {
            // Check for 403 or other errors. Backend sends 403 if not owner.
            if (e.response && e.response.status === 403) {
                message.error(e.response.data.detail || "Bu qrupu silmək üçün icazəniz yoxdur");
            } else {
                message.error("Xəta baş verdi");
            }
        }
    };

    const selectedGroup = groups.find(g => g.id === selectedGroupId);

    return (
        <div className={styles.container}>
            <GroupList
                groups={groups}
                selectedGroupId={selectedGroupId}
                onSelectGroup={setSelectedGroupId}
                onAddGroup={handleAddGroup}
                onDeleteGroup={handleDeleteGroup}
            />
            <ChatArea
                group={selectedGroupDetails}
                messages={messages}
                currentUser={currentUser}
                onSendMessage={handleSendMessage}
                loading={loadingMessages}
                onLoadMore={handleLoadMore}
                hasMore={hasMore}
                onAddMember={handleAddMember}
                onRemoveMember={handleRemoveMember}
                onUpdateGroup={async (id, data) => {
                    try {
                        // assuming updateChatGroup exists and imported
                        const { updateChatGroup } = await import('../../axios/api/chat');
                        await updateChatGroup(id, data);
                        loadGroupDetails(id); // Refresh details
                        message.success("Tənzimləmə yeniləndi");
                    } catch (e) {
                        message.error("Xəta");
                    }
                }}
            // Pagination props can be added here
            />
        </div>
    );
};

export default ChatPage;
