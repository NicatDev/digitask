import axiosInstance from '../../index';

// Services API
export const getServices = () => axiosInstance.get('/tasks/services/');
export const getService = (id) => axiosInstance.get(`/tasks/services/${id}/`);
export const createService = (data) => axiosInstance.post('/tasks/services/', data);
export const updateService = (id, data) => axiosInstance.patch(`/tasks/services/${id}/`, data);
export const deleteService = (id) => axiosInstance.delete(`/tasks/services/${id}/`);

// Columns API
export const getColumns = (params) => axiosInstance.get('/tasks/columns/', { params });
export const getColumn = (id) => axiosInstance.get(`/tasks/columns/${id}/`);
export const createColumn = (data) => axiosInstance.post('/tasks/columns/', data);
export const updateColumn = (id, data) => axiosInstance.patch(`/tasks/columns/${id}/`, data);
export const deleteColumn = (id) => axiosInstance.delete(`/tasks/columns/${id}/`);

// Customers API
export const getCustomers = (params) => axiosInstance.get('/tasks/customers/', { params });
export const getCustomer = (id) => axiosInstance.get(`/tasks/customers/${id}/`);
export const createCustomer = (data) => axiosInstance.post('/tasks/customers/', data);
export const updateCustomer = (id, data) => axiosInstance.patch(`/tasks/customers/${id}/`, data);
export const deleteCustomer = (id) => axiosInstance.delete(`/tasks/customers/${id}/`);

// Tasks API
export const getTasks = (params) => axiosInstance.get('/tasks/tasks/', { params });
export const getTask = (id) => axiosInstance.get(`/tasks/tasks/${id}/`);
export const createTask = (data) => axiosInstance.post('/tasks/tasks/', data);
export const updateTask = (id, data) => axiosInstance.patch(`/tasks/tasks/${id}/`, data);
export const deleteTask = (id) => axiosInstance.delete(`/tasks/tasks/${id}/`);
export const updateTaskStatus = (id, status) => axiosInstance.patch(`/tasks/tasks/${id}/update_status/`, { status });

// TaskServices API
export const getTaskServices = (params) => axiosInstance.get('/tasks/task-services/', { params });
export const createTaskService = (data) => axiosInstance.post('/tasks/task-services/', data);
export const updateTaskService = (id, data) => axiosInstance.patch(`/tasks/task-services/${id}/`, data);
export const deleteTaskService = (id) => axiosInstance.delete(`/tasks/task-services/${id}/`);
