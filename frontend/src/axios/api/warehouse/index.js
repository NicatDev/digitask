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

// Helper to get Regions (re-using account api if needed or direct call if exposed specific)
// But regions are in users/api/account usually. We can reuse 'getRegions' from account.js
