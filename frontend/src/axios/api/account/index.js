import axiosInstance from '../../index';

// Users
export const getUsers = () => axiosInstance.get('users/');
export const getUser = (id) => axiosInstance.get(`users/${id}/`);
export const createUser = (data) => axiosInstance.post('users/', data);
export const updateUser = (id, data) => axiosInstance.put(`users/${id}/`, data);
export const updateUserStatus = (id, isActive) => axiosInstance.patch(`users/${id}/`, { is_active: isActive });
export const updateUserAvatar = (id, formData) => axiosInstance.patch(`users/${id}/`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
});

// Me endpoint
export const getMe = () => axiosInstance.get('users/me/');
export const loginUser = (data) => axiosInstance.post('token/', data);
export const deleteUser = (id) => axiosInstance.delete(`users/${id}/`);
export const changeUserPassword = (id, data) => axiosInstance.post(`users/${id}/change_password/`, data);

// Profile (me) update
export const updateMyProfile = (data) => axiosInstance.patch('users/me/', data);
export const updateMyAvatar = (formData) => axiosInstance.patch('users/me/', formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
});
export const changeMyPassword = (data) => axiosInstance.post('users/me/change_password/', data);

// Roles
export const getRoles = () => axiosInstance.get('roles/');
export const getRole = (id) => axiosInstance.get(`roles/${id}/`);
export const createRole = (data) => axiosInstance.post('roles/', data);
export const updateRole = (id, data) => axiosInstance.put(`roles/${id}/`, data);
export const updateRoleStatus = (id, isActive) => axiosInstance.patch(`roles/${id}/`, { is_active: isActive });
export const deleteRole = (id) => axiosInstance.delete(`roles/${id}/`);

// Groups
export const getGroups = () => axiosInstance.get('groups/');
export const getGroup = (id) => axiosInstance.get(`groups/${id}/`);
export const createGroup = (data) => axiosInstance.post('groups/', data);
export const updateGroup = (id, data) => axiosInstance.put(`groups/${id}/`, data);
export const updateGroupStatus = (id, isActive) => axiosInstance.patch(`groups/${id}/`, { is_active: isActive });
export const deleteGroup = (id) => axiosInstance.delete(`groups/${id}/`);

// Regions
export const getRegions = () => axiosInstance.get('regions/');
export const getRegion = (id) => axiosInstance.get(`regions/${id}/`);
export const createRegion = (data) => axiosInstance.post('regions/', data);
export const updateRegion = (id, data) => axiosInstance.put(`regions/${id}/`, data);
export const updateRegionStatus = (id, isActive) => axiosInstance.patch(`regions/${id}/`, { is_active: isActive });
export const deleteRegion = (id) => axiosInstance.delete(`regions/${id}/`);

