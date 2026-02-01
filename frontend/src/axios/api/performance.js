import request from '../index';

export const getUserPerformance = (params) => {
    return request.get('/performance/user-stats/', { params });
};
