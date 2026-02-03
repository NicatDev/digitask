import axios from 'axios';

const baseURL = window.location.hostname === 'new.digitask.store'
    ? 'https://new-app.digitask.store/api/'
    : 'http://127.0.0.1:8000/api/';

const axiosInstance = axios.create({
    baseURL: baseURL,
    timeout: 5000,
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

axiosInstance.interceptors.response.use(
    (response) => {
        return response;
    },
    async (error) => {
        const originalRequest = error.config;

        const redirectToLogin = () => {
            if (window.location.pathname !== '/login') {
                window.location.href = '/login';
            }
        };

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
            originalRequest.url === baseURL + 'token/refresh/'
        ) {
            redirectToLogin();
            return Promise.reject(error);
        }
        if (
            error.response.data.code === 'token_not_valid' &&
            error.response.status === 401 &&
            error.response.statusText === 'Unauthorized'
        ) {
            const refreshToken = localStorage.getItem('refresh_token');

            if (refreshToken) {
                try {
                    const tokenParts = JSON.parse(atob(refreshToken.split('.')[1]));
                    const now = Math.ceil(Date.now() / 1000);

                    if (tokenParts.exp > now) {
                        return axiosInstance
                            .post('/token/refresh/', { refresh: refreshToken })
                            .then((response) => {
                                localStorage.setItem('access_token', response.data.access);
                                localStorage.setItem('refresh_token', response.data.refresh);

                                axiosInstance.defaults.headers['Authorization'] =
                                    'Bearer ' + response.data.access;
                                originalRequest.headers['Authorization'] =
                                    'Bearer ' + response.data.access;

                                return axiosInstance(originalRequest);
                            })
                            .catch((err) => {
                                console.log(err);
                                redirectToLogin();
                            });
                    } else {
                        redirectToLogin();
                    }
                } catch (err) {
                    redirectToLogin();
                }
            } else {
                redirectToLogin();
            }
        }

        // specific error handling done elsewhere
        return Promise.reject(error);
    }
);

export default axiosInstance;
