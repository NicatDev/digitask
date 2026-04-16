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
export const getCustomerOptions = (params) => axiosInstance.get('/tasks/customers/options/', { params });
export const createCustomer = (data) => axiosInstance.post('/tasks/customers/', data);
export const updateCustomer = (id, data) => axiosInstance.patch(`/tasks/customers/${id}/`, data);
export const deleteCustomer = (id) => axiosInstance.delete(`/tasks/customers/${id}/`);

// Equipment & Optic box (admin)
export const getEquipment = (params) => axiosInstance.get('/tasks/equipment/', { params });
export const createEquipment = (data) => axiosInstance.post('/tasks/equipment/', data);
export const updateEquipment = (id, data) => axiosInstance.patch(`/tasks/equipment/${id}/`, data);
export const deleteEquipment = (id) => axiosInstance.delete(`/tasks/equipment/${id}/`);

export const getOpticBoxes = (params) => axiosInstance.get('/tasks/optic-boxes/', { params });
export const createOpticBox = (data) => axiosInstance.post('/tasks/optic-boxes/', data);
export const updateOpticBox = (id, data) => axiosInstance.patch(`/tasks/optic-boxes/${id}/`, data);
export const deleteOpticBox = (id) => axiosInstance.delete(`/tasks/optic-boxes/${id}/`);

// Task Types API
export const getTaskTypes = () => axiosInstance.get('/tasks/task-types/');
export const createTaskType = (data) => axiosInstance.post('/tasks/task-types/', data);
export const updateTaskType = (id, data) => axiosInstance.patch(`/tasks/task-types/${id}/`, data);
export const deleteTaskType = (id) => axiosInstance.delete(`/tasks/task-types/${id}/`);

// Tasks API
export const getTasks = (params) => axiosInstance.get('/tasks/tasks/', { params });
export const getTask = (id) => axiosInstance.get(`/tasks/tasks/${id}/`);
export const createTask = (data) => axiosInstance.post('/tasks/tasks/', data, { timeout: 30000 });
export const updateTask = (id, data) => axiosInstance.patch(`/tasks/tasks/${id}/`, data, { timeout: 30000 });
export const deleteTask = (id) => axiosInstance.delete(`/tasks/tasks/${id}/`);
/** @param {string|{status: string, rescheduled_date?: string}} statusOrPayload */
export const updateTaskStatus = (id, statusOrPayload) => {
    const body =
        typeof statusOrPayload === 'string'
            ? { status: statusOrPayload }
            : statusOrPayload;
    return axiosInstance.patch(`/tasks/tasks/${id}/update_status/`, body);
};

export const getTaskActivity = (taskId) => axiosInstance.get(`/tasks/tasks/${taskId}/activity/`);
export const postTaskActivityComment = (taskId, body) =>
    axiosInstance.post(`/tasks/tasks/${taskId}/activity/`, { body });
export const getCustomerTasksForTask = (taskId) =>
    axiosInstance.get(`/tasks/tasks/${taskId}/customer_tasks/`);
/** Müştəri ID ilə tapşırıq tarixçəsi (yüngül siyahı) — modal açılanda çağırın */
export const getCustomerTaskHistoryByCustomerId = (customerId) =>
    axiosInstance.get('/tasks/tasks/by-customer/', { params: { customer: customerId } });
export const addTaskAssignee = (taskId, userId) => axiosInstance.post(`/tasks/tasks/${taskId}/add_assignee/`, { user_id: userId });
export const joinTask = (taskId) => axiosInstance.post(`/tasks/tasks/${taskId}/join_task/`);

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
export const getTaskDocuments = (params) => axiosInstance.get('/documents/documents/', { params });
export const createTaskDocument = (data) => {
    const formData = new FormData();
    formData.append('title', data.title);
    formData.append('file', data.file);
    if (data.task) formData.append('task', data.task);
    if (data.action) formData.append('action', data.action);
    if (data.stock_movement) formData.append('stock_movement', data.stock_movement);
    return axiosInstance.post('/documents/documents/', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
    });
};
export const deleteTaskDocument = (id) => axiosInstance.delete(`/documents/documents/${id}/`);
export const archiveDocument = (id, shelfId) => axiosInstance.post(`/documents/documents/${id}/archive/`, { shelf: shelfId });

// Shelves API
export const getShelves = (params) => axiosInstance.get('/documents/shelves/', { params });
export const getShelf = (id) => axiosInstance.get(`/documents/shelves/${id}/`);
export const createShelf = (data) => axiosInstance.post('/documents/shelves/', data);
export const updateShelf = (id, data) => axiosInstance.patch(`/documents/shelves/${id}/`, data);
export const deleteShelf = (id) => axiosInstance.delete(`/documents/shelves/${id}/`);
