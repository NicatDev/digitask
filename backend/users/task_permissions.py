import json
from typing import Any, Dict, Iterable, List


DESCRIPTION_CONFIG_PREFIX = "__cfg__:"

TASK_ACTION_KEYS = [
    "view_module",
    "create",
    "edit_general",
    "delete",
    "change_status",
    "manage_products",
    "manage_documents",
    "manage_surveys",
    "manage_assignees",
    "join_task",
    "toggle_active",
    "comment_activity",
    "edit_customer_address",
]


def _all_task_statuses() -> List[str]:
    from tasks.models import Task

    return [choice[0] for choice in Task.Status.choices]


def _coerce_bool_map(source: Any, allowed_keys: Iterable[str]) -> Dict[str, bool]:
    if not isinstance(source, dict):
        return {}
    allowed = set(allowed_keys)
    result: Dict[str, bool] = {}
    for key, value in source.items():
        key_str = str(key)
        if key_str in allowed:
            result[key_str] = value is True
    return result


def _coerce_status_list(source: Any) -> List[str]:
    if not isinstance(source, (list, tuple)):
        return []
    allowed = set(_all_task_statuses())
    out: List[str] = []
    for item in source:
        value = str(item)
        if value in allowed and value not in out:
            out.append(value)
    return out


def parse_role_description(description: str) -> Dict[str, Any]:
    raw = (description or "").strip()
    if not raw:
        return {"text": "", "task_permissions": {}, "task_status_visibility": {}}

    if raw.startswith(DESCRIPTION_CONFIG_PREFIX):
        payload = raw[len(DESCRIPTION_CONFIG_PREFIX) :].strip()
        try:
            parsed = json.loads(payload) if payload else {}
            return {
                "text": str(parsed.get("text") or ""),
                "task_permissions": _coerce_bool_map(parsed.get("task_permissions"), TASK_ACTION_KEYS),
                "task_status_visibility": {
                    "visible_statuses": _coerce_status_list(
                        (parsed.get("task_status_visibility") or {}).get("visible_statuses")
                    )
                },
            }
        except Exception:
            return {"text": raw, "task_permissions": {}, "task_status_visibility": {}}

    return {"text": raw, "task_permissions": {}, "task_status_visibility": {}}


def build_role_description(
    text: str,
    task_permissions: Dict[str, Any] | None = None,
    task_status_visibility: Dict[str, Any] | None = None,
) -> str:
    payload = {
        "text": (text or "").strip(),
        "task_permissions": _coerce_bool_map(task_permissions or {}, TASK_ACTION_KEYS),
        "task_status_visibility": {
            "visible_statuses": _coerce_status_list((task_status_visibility or {}).get("visible_statuses"))
        },
    }
    return f"{DESCRIPTION_CONFIG_PREFIX}{json.dumps(payload, ensure_ascii=True, separators=(',', ':'))}"


def _role_or_none(user):
    return getattr(user, "role", None) if user else None


def get_task_permissions_for_user(user) -> Dict[str, bool]:
    role = _role_or_none(user)
    parsed = parse_role_description(getattr(role, "description", "") if role else "")
    configured = _coerce_bool_map(parsed.get("task_permissions"), TASK_ACTION_KEYS)
    if configured:
        return configured

    # Backward-compatible defaults for old roles that do not have dynamic config yet.
    is_reader = bool(role and getattr(role, "is_task_reader", False))
    is_writer = bool(role and getattr(role, "is_task_writer", False))
    return {
        "view_module": is_reader or is_writer,
        "create": is_writer,
        "edit_general": is_writer,
        "delete": is_writer,
        "change_status": is_reader or is_writer,
        "manage_products": is_reader or is_writer,
        "manage_documents": is_reader or is_writer,
        "manage_surveys": is_reader or is_writer,
        "manage_assignees": is_writer,
        "join_task": is_reader or is_writer,
        "toggle_active": is_writer,
        "comment_activity": is_reader or is_writer,
        "edit_customer_address": is_writer,
    }


def can_task_action(user, action: str) -> bool:
    return get_task_permissions_for_user(user).get(action, False)


def get_task_status_visibility_for_user(user) -> Dict[str, List[str]]:
    role = _role_or_none(user)

    parsed = parse_role_description(getattr(role, "description", "") if role else "")
    visibility_cfg = parsed.get("task_status_visibility") or {}
    if isinstance(visibility_cfg, dict) and "visible_statuses" in visibility_cfg:
        return {"visible_statuses": _coerce_status_list(visibility_cfg.get("visible_statuses"))}
    return {"visible_statuses": []}
