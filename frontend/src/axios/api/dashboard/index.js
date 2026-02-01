import axiosInstance from '../../index';

// Events API
export const getEvents = (params) => axiosInstance.get('/dashboard/events/', { params });
export const createEvent = (data) => axiosInstance.post('/dashboard/events/', data);
export const updateEvent = (id, data) => axiosInstance.patch(`/dashboard/events/${id}/`, data);
export const deleteEvent = (id) => axiosInstance.delete(`/dashboard/events/${id}/`);

// Stats API
export const getDashboardStats = () => axiosInstance.get('/dashboard/stats/');
