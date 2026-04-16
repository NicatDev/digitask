export function decodeReply(raw = '') {
    if (typeof raw !== 'string') return { reply: null, body: '' };
    const prefix = '@@reply:';
    if (!raw.startsWith(prefix)) return { reply: null, body: raw };
    const end = raw.indexOf('@@', prefix.length);
    if (end === -1) return { reply: null, body: raw };
    const jsonPart = raw.slice(prefix.length, end);
    const rest = raw.slice(end + 2);
    const body = rest.startsWith('\n') ? rest.slice(1) : rest;
    try {
        const reply = JSON.parse(jsonPart);
        if (!reply || typeof reply !== 'object') return { reply: null, body: raw };
        return { reply, body };
    } catch {
        return { reply: null, body: raw };
    }
}

export function stripReply(raw = '') {
    return decodeReply(raw).body;
}

export function encodeReply(body, replyTo) {
    const cleanBody = (body ?? '').toString();
    if (!replyTo) return cleanBody;
    const meta = {
        id: replyTo.id,
        sender: replyTo.sender,
        snippet: replyTo.snippet,
    };
    return `@@reply:${JSON.stringify(meta)}@@\n${cleanBody}`;
}

