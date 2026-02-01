/**
 * Checks if user has specific permission
 * @param {Object} user - User object
 * @param {string|string[]} permissions - Required permission(s)
 * @param {boolean} requireAll - If true, requires all permissions. If false, requires at least one.
 * @returns {boolean}
 */
export const hasPermission = (user, permissions, requireAll = false) => {
    if (!user) return false;    

    // Admin always has access
    if (user.is_admin || user.is_super_admin) return true;

    // Normalize input to array
    const perms = Array.isArray(permissions) ? permissions : [permissions];

    if (requireAll) {
        return perms.every(p => user[p]);
    }
    return perms.some(p => user[p]);
};

// Permission Constants
export const PERMISSIONS = {
    // Task
    TASK_READER: 'is_task_reader',
    TASK_WRITER: 'is_task_writer',

    // Warehouse
    WAREHOUSE_READER: 'is_warehouse_reader',
    WAREHOUSE_WRITER: 'is_warehouse_writer',

    // Document
    DOCUMENT_READER: 'is_document_reader',
    DOCUMENT_WRITER: 'is_document_writer',

    // Admin
    ADMIN: 'is_admin',
    SUPER_ADMIN: 'is_super_admin'
};
