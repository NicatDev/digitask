/**
 * Checks if user has specific permission
 * @param {Object} user - User object
 * @param {string|string[]} permissions - Required permission(s)
 * @param {boolean} requireAll - If true, requires all permissions. If false, requires at least one.
 * @returns {boolean}
 */
export const hasPermission = (user, permissions, requireAll = false) => {
    if (!user) return false;    

    // Normalize input to array
    const perms = Array.isArray(permissions) ? permissions : [permissions];
    const isTaskPermissionRequest = perms.some(p => p === 'is_task_reader' || p === 'is_task_writer');
    if (!isTaskPermissionRequest && (user.is_admin || user.is_super_admin)) {
        return true;
    }

    const hasSingle = (p) => {
        if (user[p]) return true;
        // Dynamic task permission compatibility for older route checks.
        if (p === 'is_task_reader') {
            return !!user.task_permissions?.view_module;
        }
        if (p === 'is_task_writer') {
            return !!(
                user.task_permissions?.create ||
                user.task_permissions?.edit_general ||
                user.task_permissions?.delete
            );
        }
        return false;
    };
    if (requireAll) {
        return perms.every(hasSingle);
    }
    return perms.some(hasSingle);
};

export const hasTaskActionPermission = (user, action) => {
    if (!user) return false;
    const fromMap = user.task_permissions?.[action];
    if (typeof fromMap === 'boolean') return fromMap;
    return false;
};

// Permission Constants
export const PERMISSIONS = {
    // Task
    TASK_READER: 'is_task_reader',
    TASK_WRITER: 'is_task_writer',
    TASK_VIEW_ALL: 'is_task_view_all',

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

export const TASK_ACTIONS = {
    CREATE: 'create',
    EDIT_GENERAL: 'edit_general',
    DELETE: 'delete',
    CHANGE_STATUS: 'change_status',
    MANAGE_PRODUCTS: 'manage_products',
    MANAGE_DOCUMENTS: 'manage_documents',
    MANAGE_SURVEYS: 'manage_surveys',
    MANAGE_ASSIGNEES: 'manage_assignees',
    JOIN_TASK: 'join_task',
    TOGGLE_ACTIVE: 'toggle_active',
    COMMENT_ACTIVITY: 'comment_activity',
    EDIT_CUSTOMER_ADDRESS: 'edit_customer_address',
};
