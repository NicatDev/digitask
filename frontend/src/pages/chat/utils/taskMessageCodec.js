const TASK_MESSAGE_PREFIX = '[[DIGITASK_TASK_V1:';
const TASK_MESSAGE_SUFFIX = ']]';

const encodeBase64 = (value) =>
    btoa(unescape(encodeURIComponent(JSON.stringify(value))));

const decodeBase64 = (value) =>
    JSON.parse(decodeURIComponent(escape(atob(value))));

export const buildTaskChatPayload = (task, note = '') => ({
    kind: 'task',
    version: 1,
    note: note.trim(),
    task: {
        id: task.id,
        title: task.title || '',
        status: task.status || '',
        register_number: task.customer_register_number || '',
        customer: task.customer_name || '',
        assignees: Array.isArray(task.assigned_to_names) ? task.assigned_to_names : [],
    },
});

export const encodeTaskChatMessage = (payload) =>
    `${TASK_MESSAGE_PREFIX}${encodeBase64(payload)}${TASK_MESSAGE_SUFFIX}`;

export const decodeTaskChatMessage = (content) => {
    const text = String(content || '').trim();
    if (!text.startsWith(TASK_MESSAGE_PREFIX) || !text.endsWith(TASK_MESSAGE_SUFFIX)) {
        return null;
    }
    try {
        const raw = text.slice(TASK_MESSAGE_PREFIX.length, -TASK_MESSAGE_SUFFIX.length);
        const parsed = decodeBase64(raw);
        return parsed?.kind === 'task' ? parsed : null;
    } catch {
        return null;
    }
};

export const stripTaskChatMessage = (content) => {
    const decoded = decodeTaskChatMessage(content);
    if (!decoded) return content;
    const task = decoded.task || {};
    return `Tapşırıq #${task.id || ''}: ${task.title || ''}`.trim();
};
