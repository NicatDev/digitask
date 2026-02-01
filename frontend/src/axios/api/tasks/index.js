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

// Task Types API
export const getTaskTypes = () => axiosInstance.get('/tasks/task-types/');
export const createTaskType = (data) => axiosInstance.post('/tasks/task-types/', data);
export const updateTaskType = (id, data) => axiosInstance.patch(`/tasks/task-types/${id}/`, data);
export const deleteTaskType = (id) => axiosInstance.delete(`/tasks/task-types/${id}/`);

// Tasks API
export const getTasks = (params) => axiosInstance.get('/tasks/tasks/', { params });
export const getTask = (id) => axiosInstance.get(`/tasks/tasks/${id}/`);
export const createTask = (data) => axiosInstance.post('/tasks/tasks/', data);
export const updateTask = (id, data) => axiosInstance.patch(`/tasks/tasks/${id}/`, data);
export const deleteTask = (id) => axiosInstance.delete(`/tasks/tasks/${id}/`);
export const updateTaskStatus = (id, status) => axiosInstance.patch(`/tasks/tasks/${id}/update_status/`, { status });

// TaskServices API
export const getTaskServices = (params) => axiosInstance.get('/tasks/task-services/', { params });
export const createTaskService = (data) => axiosInstance.post('/tasks/task-services/', data, {
    headers: { 'Content-Type': undefined }
});
export const updateTaskService = (id, data) => axiosInstance.patch(`/tasks/task-services/${id}/`, data, {
    headers: { 'Content-Type': undefined }
});
export const deleteTaskService = (id) => axiosInstance.delete(`/tasks/task-services/${id}/`);

// TaskProducts API
export const getTaskProducts = (params) => axiosInstance.get('/tasks/task-products/', { params });
export const createTaskProducts = (taskId, products) => axiosInstance.post('/tasks/task-products/bulk-create/', {
    task_id: taskId,
    products
});
export const deleteTaskProduct = (id) => axiosInstance.delete(`/tasks/task-products/${id}/`);

// TaskDocuments API
export const getTaskDocuments = (params) => axiosInstance.get('/tasks/task-documents/', { params });
export const createTaskDocument = (data) => {
    const formData = new FormData();
    formData.append('title', data.title);
    formData.append('file', data.file);
    if (data.task) formData.append('task', data.task);
    if (data.warehouse) formData.append('warehouse', data.warehouse);
    if (data.stock_movement) formData.append('stock_movement', data.stock_movement);
    return axiosInstance.post('/tasks/task-documents/', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
    });
};
export const deleteTaskDocument = (id) => axiosInstance.delete(`/tasks/task-documents/${id}/`);
export const archiveDocument = (id, shelfId) => axiosInstance.post(`/tasks/task-documents/${id}/archive/`, { shelf: shelfId });

// Shelves API
export const getShelves = (params) => axiosInstance.get('/tasks/shelves/', { params });
export const getShelf = (id) => axiosInstance.get(`/tasks/shelves/${id}/`);
export const createShelf = (data) => axiosInstance.post('/tasks/shelves/', data);
export const updateShelf = (id, data) => axiosInstance.patch(`/tasks/shelves/${id}/`, data);
export const deleteShelf = (id) => axiosInstance.delete(`/tasks/shelves/${id}/`);
