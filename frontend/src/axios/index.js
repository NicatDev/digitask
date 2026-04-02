import axios from 'axios';

// Determine if we're in production
const isProduction = true || window.location.hostname === 'new.digitask.store' ||
    window.location.hostname === 'digitask.store' ||
    window.location.hostname === 'app.digitask.store';

const baseURL = isProduction
    ? 'https://app.digitask.store/api/'
    : 'http://127.0.0.1:8000/api/';

// Export these for use in other parts of the app
export const getBaseUrl = () => isProduction
    ? 'https://app.digitask.store'
    : 'http://127.0.0.1:8000';

export const getWsUrl = () => isProduction
    ? 'wss://app.digitask.store'
    : 'ws://127.0.0.1:8000';

const axiosInstance = axios.create({
    baseURL: baseURL,
    timeout: 15000,
    headers: {
        'Content-Type': 'application/json',
        'accept': 'application/json'
    }
});

axiosInstance.interceptors.request.use(
    (config) => {
        const token = localStorage.getItem('access_token');
        if (token) {
            config.headers['Authorization'] = `Bearer ${token}`;
        }
        return config;
    },
    (error) => {
        return Promise.reject(error);
    }
);

let isRefreshing = false;
let failedQueue = [];

const processQueue = (error, token = null) => {
    failedQueue.forEach(prom => {
        if (error) {
            prom.reject(error);
        } else {
            prom.resolve(token);
        }
    });

    failedQueue = [];
};

axiosInstance.interceptors.response.use(
    (response) => {
        return response;
    },
    async (error) => {
        const originalRequest = error.config;

        if (typeof error.response === 'undefined') {
            alert(
                'A server/network error occurred. ' +
                'Looks like CORS might be the problem. ' +
                'Sorry about this - we will get it fixed shortly.'
            );
            return Promise.reject(error);
        }

        if (
            error.response.status === 401 &&
            !originalRequest._retry
        ) {
            // Prevent infinite loop: if already on login page, don't refresh
            if (window.location.pathname === '/login') {
                return Promise.reject(error);
            }

            if (originalRequest.url.includes('/token/refresh/')) {
                window.location.href = '/login';
                return Promise.reject(error);
            }

            if (isRefreshing) {
                return new Promise(function (resolve, reject) {
                    failedQueue.push({ resolve, reject });
                }).then(token => {
                    originalRequest.headers['Authorization'] = 'Bearer ' + token;
                    return axiosInstance(originalRequest);
                }).catch(err => {
                    return Promise.reject(err);
                });
            }

            originalRequest._retry = true;
            isRefreshing = true;

            const refreshToken = localStorage.getItem('refresh_token');

            if (refreshToken) {
                return axios.post(baseURL + 'token/refresh/', { refresh: refreshToken })
                    .then((response) => {
                        const { access, refresh } = response.data;

                        localStorage.setItem('access_token', access);
                        if (refresh) {
                            localStorage.setItem('refresh_token', refresh);
                        }

                        axiosInstance.defaults.headers['Authorization'] = 'Bearer ' + access;
                        originalRequest.headers['Authorization'] = 'Bearer ' + access;

                        processQueue(null, access);
                        isRefreshing = false;

                        return axiosInstance(originalRequest);
                    })
                    .catch((err) => {
                        processQueue(err, null);
                        isRefreshing = false;
                        window.location.href = '/login';
                        return Promise.reject(err);
                    });
            } else {
                window.location.href = '/login';
                return Promise.reject(error);
            }
        }

        return Promise.reject(error);
    }
);

export default axiosInstance;
