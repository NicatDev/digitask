import service from '../../index';

// Warehouses
export const getWarehouses = (params) => service.get('/warehouse/warehouses/', { params });
export const createWarehouse = (data) => service.post('/warehouse/warehouses/', data);
export const updateWarehouse = (id, data) => service.patch(`/warehouse/warehouses/${id}/`, data);
export const deleteWarehouse = (id) => service.delete(`/warehouse/warehouses/${id}/`);

// Products
export const getProducts = (params) => service.get('/warehouse/products/', { params });
export const createProduct = (data) => service.post('/warehouse/products/', data);
export const updateProduct = (id, data) => service.patch(`/warehouse/products/${id}/`, data);
export const deleteProduct = (id) => service.delete(`/warehouse/products/${id}/`);

// Inventory
export const getInventory = (params) => service.get('/warehouse/inventory/', { params });

// Stock Movements
export const getStockMovements = (params) => service.get('/warehouse/movements/', { params });
export const adjustStock = (data) => service.post('/warehouse/movements/adjust/', data);

// Categories
export const getCategories = (params) => service.get('/warehouse/categories/', { params });
export const createCategory = (data) => service.post('/warehouse/categories/', data);
export const updateCategory = (id, data) => service.patch(`/warehouse/categories/${id}/`, data);
export const deleteCategory = (id) => service.delete(`/warehouse/categories/${id}/`);
export const addCategoryField = (categoryId, data) => service.post(`/warehouse/categories/${categoryId}/add-field/`, data);
export const removeCategoryField = (categoryId, fieldId) => service.delete(`/warehouse/categories/${categoryId}/remove-field/${fieldId}/`);

// Serial Number Items
export const getSerialItems = (params) => service.get('/warehouse/serial-items/', { params });
