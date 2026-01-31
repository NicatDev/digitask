import axiosInstance from '../../index';

export const getChatGroups = () => axiosInstance.get('/chat/groups/');
export const getChatGroupDetails = (id) => axiosInstance.get(`/chat/groups/${id}/`);
export const createChatGroup = (data) => axiosInstance.post('/chat/groups/', data);
export const updateChatGroup = (id, data) => axiosInstance.patch(`/chat/groups/${id}/`, data); // For removing members or other updates
export const deleteChatGroup = (id) => axiosInstance.delete(`/chat/groups/${id}/`);

export const addGroupMember = (id, userId) => axiosInstance.post(`/chat/groups/${id}/add-member/`, { user_id: userId });
export const removeGroupMember = (id, userId) => axiosInstance.post(`/chat/groups/${id}/remove-member/`, { user_id: userId });

export const getGroupMessages = (groupId, page = 1) => axiosInstance.get(`/chat/messages/?group=${groupId}&page=${page}`);
export const sendGroupMessage = (data) => axiosInstance.post('/chat/messages/', data);
export const markMessagesRead = (groupId) => axiosInstance.post('/chat/messages/mark-read/', { group_id: groupId });
