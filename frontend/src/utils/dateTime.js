import dayjs from 'dayjs';

// Serverdən xam mətn kimi gələn vaxt: "2026-11-26T18:42:00Z" / "...+04:00" (zona göstərilməlidir)
const ISO_WITH_ZONE = /^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})$/;

export const isIsoDateTime = (value) => typeof value === 'string' && ISO_WITH_ZONE.test(value);

/** Xam ISO vaxtı istifadəçinin yerli vaxtı ilə göstərir; digər dəyərlərə toxunmur. */
export const toLocalDisplay = (value) =>
    isIsoDateTime(value) ? dayjs(value).format('DD.MM.YYYY HH:mm:ss') : value;

/** JSON.stringify üçün replacer */
export const localTimeReplacer = (_key, value) => toLocalDisplay(value);
