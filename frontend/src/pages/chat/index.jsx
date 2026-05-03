import React, { useEffect, useState, useRef } from 'react';
import styles from './style.module.scss';
import GroupList from './components/GroupList';
import ChatArea from './components/ChatArea';
import { getChatGroups, createChatGroup, getChatGroupDetails, getGroupMessages, addGroupMember, removeGroupMember, markMessagesRead, deleteChatGroup } from '../../axios/api/chat';
import { getMe } from '../../axios/api/account';
import { getServices, getTask } from '../../axios/api/tasks';
import { message } from 'antd';
import { useNotifications } from '../../context/NotificationContext';
import TaskDetailModal from '../tasks/components/TaskTab/components/TaskDetailModal';

const ChatPage = () => {
    const [groups, setGroups] = useState([]);
    const [selectedGroupId, setSelectedGroupId] = useState(null);
    const [messages, setMessages] = useState([]);
    const [currentUser, setCurrentUser] = useState(null);
    const [loadingMessages, setLoadingMessages] = useState(false);

    const [selectedGroupDetails, setSelectedGroupDetails] = useState(null);
    const [page, setPage] = useState(1);
    const [hasMore, setHasMore] = useState(true);
    const [taskModalOpen, setTaskModalOpen] = useState(false);
    const [selectedTask, setSelectedTask] = useState(null);
    const [services, setServices] = useState([]);

    // WebSocket
    const ws = useRef(null);
    const { lastChatNotification } = useNotifications();

    useEffect(() => {
        if (lastChatNotification) {
            setGroups(prevGroups => {
                return prevGroups.map(group => {
                    if (group.id === lastChatNotification.group_id) {
                        // Only increment unread if NOT the currently selected group (or if window not focused, but that's harder)
                        // Actually, if we are in the group, the chat WS handles the message.
                        // But the LIST needs to update "last message" regardless.
                        // And unread count only if not selected.

                        const isSelected = group.id === selectedGroupId;

                        return {
                            ...group,
                            last_message: {
                                content: lastChatNotification.message_content,
                                sender: lastChatNotification.sender_name,
                                created_at: lastChatNotification.created_at
                            },
                            unread_count: isSelected ? group.unread_count : (group.unread_count + 1)
                        };
                    }
                    return group;
                });
            });

            // Move updated group to top? Optional but nice.
        }
    }, [lastChatNotification]);

    useEffect(() => {
        fetchProfile();
        fetchGroups();
        getServices().then((res) => setServices(res.data.results || res.data || [])).catch(() => {});
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
                intentionalClose.current = true;
                ws.current.close();
            }
            if (reconnectTimeout.current) {
                clearTimeout(reconnectTimeout.current);
                reconnectTimeout.current = null;
            }
            if (markReadTimer.current) {
                clearTimeout(markReadTimer.current);
                markReadTimer.current = null;
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
        } catch {
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

    const reconnectTimeout = useRef(null);
    const markReadTimer = useRef(null);
    const intentionalClose = useRef(false);

    const connectWebSocket = (groupId) => {
        // Clear any pending reconnect
        if (reconnectTimeout.current) {
            clearTimeout(reconnectTimeout.current);
            reconnectTimeout.current = null;
        }

        if (ws.current) {
            intentionalClose.current = true;
            ws.current.close();
        }
        intentionalClose.current = false;

        const isProduction = window.location.hostname === 'new.digitask.digigroup.az' ||
            window.location.hostname === 'digitask.digigroup.az' ||
            window.location.hostname === 'app.digitask.digigroup.az';
        const wsBase = isProduction ? 'wss://app.digitask.digigroup.az' : 'ws://127.0.0.1:8000';
        const token = localStorage.getItem('access_token');
        if (!token) return;
        const url = `${wsBase}/ws/chat/groups/${groupId}/?token=${token}`;

        let retryCount = 0;
        const maxRetries = 10;

        const attemptConnect = () => {
            const socket = new WebSocket(url);
            ws.current = socket;

            socket.onopen = () => {
                console.log("Connected to Chat WS");
                retryCount = 0; // Reset retry count on successful connection
            };

            socket.onmessage = (event) => {
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

                // Debounce markAsRead + fetchGroups to avoid request flood
                if (data.id) {
                    if (markReadTimer.current) clearTimeout(markReadTimer.current);
                    markReadTimer.current = setTimeout(() => {
                        markMessagesRead(groupId).then(() => {
                            fetchGroups();
                        });
                    }, 1000);
                }
            };

            socket.onerror = (error) => {
                console.error("Chat WebSocket Error:", error);
            };

            socket.onclose = (event) => {
                console.log("Disconnected Chat WS, code:", event.code);
                // Only reconnect if this wasn't an intentional close
                if (!intentionalClose.current && retryCount < maxRetries) {
                    retryCount++;
                    const delay = Math.min(1000 * Math.pow(2, retryCount - 1), 30000); // Exponential backoff: 1s, 2s, 4s, 8s... max 30s
                    console.log(`Reconnecting in ${delay / 1000}s (attempt ${retryCount}/${maxRetries})...`);
                    reconnectTimeout.current = setTimeout(() => {
                        if (!intentionalClose.current) {
                            attemptConnect();
                        }
                    }, delay);
                }
            };
        };

        attemptConnect();
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

    const handleOpenTask = async (taskId) => {
        if (!taskId) return;
        try {
            const res = await getTask(taskId);
            setSelectedTask(res.data);
            setTaskModalOpen(true);
        } catch {
            message.error('Tapşırıq açılmadı');
        }
    };

    const handleAddGroup = async (values) => {
        try {
            await createChatGroup(values);
            fetchGroups();
            message.success("Qrup yaradıldı");
        } catch {
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
        } catch {
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

    return (
        <div className={styles.container}>
            {!selectedGroupId ? (
                <div className={styles.groupListContainer}>
                    <GroupList
                        groups={groups}
                        selectedGroupId={selectedGroupId}
                        onSelectGroup={setSelectedGroupId}
                        onAddGroup={handleAddGroup}
                        onDeleteGroup={handleDeleteGroup}
                    />
                </div>
            ) : (
                <div className={styles.chatAreaContainer}>
                    <ChatArea
                        group={selectedGroupDetails}
                        messages={messages}
                        currentUser={currentUser}
                        onSendMessage={handleSendMessage}
                        onOpenTask={handleOpenTask}
                        loading={loadingMessages}
                        onLoadMore={handleLoadMore}
                        hasMore={hasMore}
                        onAddMember={handleAddMember}
                        onRemoveMember={handleRemoveMember}
                        onBack={() => {
                            setSelectedGroupId(null);
                            setSelectedGroupDetails(null);
                            setMessages([]);
                        }}
                        onUpdateGroup={async (id, data) => {
                            try {
                                const { updateChatGroup } = await import('../../axios/api/chat');
                                await updateChatGroup(id, data);
                                loadGroupDetails(id);
                                message.success("Tənzimləmə yeniləndi");
                            } catch {
                                message.error("Xəta");
                            }
                        }}
                    />
                    <TaskDetailModal
                        open={taskModalOpen}
                        onCancel={() => setTaskModalOpen(false)}
                        task={selectedTask}
                        services={services}
                        canForTask={() => false}
                        canComment={false}
                        disableEdit
                        disableDelete
                        disableStatus
                        disableQuestionnaire
                        disableProducts
                        disableDocuments
                    />
                </div>
            )}
        </div>
    );
};

export default ChatPage;
