import { message } from 'antd';

export const handleApiError = (error, defaultMessage = 'Əməliyyat uğursuz oldu') => {
    if (error.response && error.response.data) {
        const data = error.response.data;

        // Case 1: Array of errors (e.g. ["Error 1", "Error 2"])
        if (Array.isArray(data)) {
            data.forEach(err => message.error(err));
            return;
        }

        // Case 2: Object with field errors (e.g. { username: ["Exists"], email: ["Invalid"] })
        // or DRF 'detail' key (e.g. { detail: "Not found" })
        if (typeof data === 'object') {
            // Check for specific 'detail' key first
            if (data.detail) {
                message.error(data.detail);
                return;
            }

            // Iterate over fields
            Object.keys(data).forEach(key => {
                const errors = data[key];
                if (Array.isArray(errors)) {
                    errors.forEach(err => message.error(`${key}: ${err}`));
                } else if (typeof errors === 'string') {
                    message.error(`${key}: ${errors}`);
                }
            });
            return;
        }
    }

    // Fallback
    message.error(defaultMessage);
};
