/** Cədvəl sütun ardıcıllığı sabit qalır; görünürlük User.task_table_column_visibility-də saxlanılır. */

/** Sütun enləri (~10% kompakt; horizontal scroll üçün ümumi qənaət). */
export const TASK_TABLE_COLUMN_META = [
    { key: 'id', title: 'ID', width: 78 },
    { key: 'title', title: 'Başlıq', width: 198 },
    { key: 'task_type', title: 'Növ', width: 126 },
    { key: 'customer_name', title: 'Müştəri', width: 180 },
    { key: 'customer_phone', title: 'Əlaqə No', width: 135 },
    { key: 'customer_register_number', title: 'Qeydiyyat No', width: 153 },
    { key: 'group_name', title: 'Qrup', width: 135 },
    { key: 'services', title: 'Servislər', width: 171 },
    { key: 'assigned_to_names', title: 'İcraçılar', width: 180 },
    { key: 'location', title: 'Ünvan', width: 72 },
    { key: 'status', title: 'Status', width: 112 },
    { key: 'created_at', title: 'Yaradılıb', width: 151 },
    { key: 'rescheduled_date', title: 'Təxirə tarixi', width: 133 },
    { key: 'is_active', title: 'Aktiv', width: 81 },
    { key: 'action', title: 'Əməliyyat', width: 378 },
];

/** `TaskTable` sütun təyini üçün tək mənbə */
export const TASK_TABLE_COLUMN_WIDTHS = Object.fromEntries(
    TASK_TABLE_COLUMN_META.map((c) => [c.key, c.width]),
);

/** Defolt: bütün sütunlar görünür. */
export const TASK_TABLE_KEYS_DEFAULT_HIDDEN = new Set();

/** Həmişə görünən (modalda dəyişməz) */
export const TASK_TABLE_FIXED_KEYS = new Set(['action']);

const TOGGLE_KEYS = TASK_TABLE_COLUMN_META.filter((c) => !TASK_TABLE_FIXED_KEYS.has(c.key)).map((c) => c.key);

export function defaultColumnVisibility() {
    const v = {};
    for (const key of TOGGLE_KEYS) {
        v[key] = !TASK_TABLE_KEYS_DEFAULT_HIDDEN.has(key);
    }
    return v;
}

/** API-dən gələn user obyektinə görə görünürlük (cədvəl sütunları). */
export function mergeColumnVisibilityFromUser(user) {
    const defaults = defaultColumnVisibility();
    if (!user) return defaults;
    const stored = user.task_table_column_visibility;
    if (!stored || typeof stored !== 'object') return defaults;
    const merged = { ...defaults };
    for (const key of TOGGLE_KEYS) {
        if (Object.prototype.hasOwnProperty.call(stored, key)) {
            merged[key] = Boolean(stored[key]);
        }
    }
    return merged;
}

/** PATCH users/me/ üçün yalnız sütun açarları. */
export function serializeColumnVisibilityForApi(visibility) {
    const toSave = {};
    for (const key of TOGGLE_KEYS) {
        toSave[key] = Boolean(visibility[key]);
    }
    return toSave;
}

export function sumVisibleTableWidth(visibility) {
    let sum = 0;
    for (const col of TASK_TABLE_COLUMN_META) {
        if (TASK_TABLE_FIXED_KEYS.has(col.key)) {
            sum += col.width;
            continue;
        }
        if (visibility[col.key] !== false) {
            sum += col.width;
        }
    }
    return Math.max(sum, 720);
}
