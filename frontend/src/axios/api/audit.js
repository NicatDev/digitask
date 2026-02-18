import axiosInstance from '../index';

export const getAuditLogs = (params) => {
    return axiosInstance.get('/audit/logs/', { params });
};
