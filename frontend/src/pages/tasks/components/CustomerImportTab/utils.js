import dayjs from 'dayjs';
import { message } from 'antd';
import { downloadCustomerImportFile } from '../../../../axios/api/tasks';

export const RUNNING = ['validating', 'importing', 'rolling_back'];

export const STATUS_META = {
    validating: { color: 'processing', label: 'Yoxlanılır' },
    preview: { color: 'gold', label: 'Təsdiq gözləyir' },
    importing: { color: 'processing', label: 'Yaradılır' },
    completed: { color: 'green', label: 'Tamamlandı' },
    interrupted: { color: 'red', label: 'Yarımçıq qaldı' },
    failed: { color: 'red', label: 'Alınmadı' },
    cancelled: { color: 'default', label: 'Ləğv edildi' },
    rolling_back: { color: 'processing', label: 'Geri qaytarılır' },
    rolled_back: { color: 'purple', label: 'Geri qaytarıldı' },
};

export const RESULT_META = {
    new: { color: 'green', label: 'Yaradılacaq' },
    created: { color: 'green', label: 'Yaradıldı' },
    existing: { color: 'blue', label: 'Artıq var' },
    duplicate_in_file: { color: 'cyan', label: 'Faylda təkrar' },
    problem: { color: 'red', label: 'Problemli' },
};

export const REF_LABELS = { region: 'Region', equipment: 'Avadanlıq', optic_box: 'Optik qutu' };

export const fmtDate = (v) => (v ? dayjs(v).format('DD.MM.YYYY HH:mm') : '—');

export const fmtSize = (bytes) => {
    if (!bytes) return '—';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
};

/** Xəta cavabından istifadəçi mesajı (blob cavablar da daxil) */
export const errorText = async (error, fallback = 'Əməliyyat alınmadı') => {
    const data = error?.response?.data;
    if (!data) return error?.message === 'Network Error' ? 'Serverlə əlaqə kəsildi. İnterneti yoxlayın.' : fallback;
    if (data instanceof Blob) {
        try {
            const parsed = JSON.parse(await data.text());
            return parsed?.detail || fallback;
        } catch {
            return fallback;
        }
    }
    if (typeof data === 'string') return fallback;
    return data.detail || fallback;
};

export const showError = async (error, fallback) => {
    message.error(await errorText(error, fallback), 6);
};

/** Serverdən faylı endirib brauzerdə yadda saxlayır */
export const downloadFile = async (path, params, fallbackName) => {
    try {
        const res = await downloadCustomerImportFile(path, params);
        const cd = res.headers?.['content-disposition'] || '';
        const match = /filename="?([^";]+)"?/i.exec(cd);
        const name = match ? match[1] : fallbackName;
        const url = URL.createObjectURL(res.data);
        const a = document.createElement('a');
        a.href = url;
        a.download = name;
        document.body.appendChild(a);
        a.click();
        a.remove();
        setTimeout(() => URL.revokeObjectURL(url), 2000);
    } catch (e) {
        await showError(e, 'Fayl endirilmədi');
    }
};

export const coordsText = (lat, lng) =>
    lat !== null && lat !== undefined && lng !== null && lng !== undefined ? `${lat}, ${lng}` : '—';
