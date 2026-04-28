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
    "mark_external_archived",
]

TASK_STATUS_ACTION_KEYS = [
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
    "mark_external_archived",
]

TASK_STATUS_SCOPE_KEYS = ("mine", "group", "all")


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


def _coerce_status_scope_map(source: Any) -> Dict[str, str]:
    if not isinstance(source, dict):
        return {}
    allowed_statuses = set(_all_task_statuses())
    out: Dict[str, str] = {}
    for status, raw_scope in source.items():
        status_key = str(status)
        if status_key not in allowed_statuses:
            continue
        scope = str(raw_scope or "").strip().lower()
        if scope in TASK_STATUS_SCOPE_KEYS:
            out[status_key] = scope
    return out


def parse_role_description(description: str) -> Dict[str, Any]:
    raw = (description or "").strip()
    if not raw:
        return {"text": "", "task_permissions": {}, "task_status_visibility": {}, "task_status_permissions": {}}

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
                    ),
                    "status_scopes": _coerce_status_scope_map(
                        (parsed.get("task_status_visibility") or {}).get("status_scopes")
                    ),
                },
                "task_status_permissions": _coerce_status_action_map(parsed.get("task_status_permissions")),
            }
        except Exception:
            return {"text": raw, "task_permissions": {}, "task_status_visibility": {}, "task_status_permissions": {}}

    return {"text": raw, "task_permissions": {}, "task_status_visibility": {}, "task_status_permissions": {}}


def build_role_description(
    text: str,
    task_permissions: Dict[str, Any] | None = None,
    task_status_visibility: Dict[str, Any] | None = None,
    task_status_permissions: Dict[str, Any] | None = None,
) -> str:
    payload = {
        "text": (text or "").strip(),
        "task_permissions": _coerce_bool_map(task_permissions or {}, TASK_ACTION_KEYS),
        "task_status_visibility": {
            "visible_statuses": _coerce_status_list((task_status_visibility or {}).get("visible_statuses")),
            "status_scopes": _coerce_status_scope_map((task_status_visibility or {}).get("status_scopes")),
        },
        "task_status_permissions": _coerce_status_action_map(task_status_permissions or {}),
    }
    return f"{DESCRIPTION_CONFIG_PREFIX}{json.dumps(payload, ensure_ascii=True, separators=(',', ':'))}"


def _role_or_none(user):
    return getattr(user, "role", None) if user else None


def _coerce_status_action_map(source: Any) -> Dict[str, Dict[str, bool]]:
    if not isinstance(source, dict):
        return {}
    allowed_statuses = set(_all_task_statuses())
    out: Dict[str, Dict[str, bool]] = {}
    for status, mapping in source.items():
        status_key = str(status)
        if status_key not in allowed_statuses:
            continue
        out[status_key] = _coerce_bool_map(mapping, TASK_STATUS_ACTION_KEYS)
    return out


def get_task_permissions_for_user(user) -> Dict[str, bool]:
    role = _role_or_none(user)
    parsed = parse_role_description(getattr(role, "description", "") if role else "")
    return _coerce_bool_map(parsed.get("task_permissions"), TASK_ACTION_KEYS)


def can_task_action(user, action: str) -> bool:
    return can_task_action_for_task(user, action, None)


def get_task_status_permissions_for_user(user) -> Dict[str, Dict[str, bool]]:
    role = _role_or_none(user)
    parsed = parse_role_description(getattr(role, "description", "") if role else "")
    return _coerce_status_action_map(parsed.get("task_status_permissions"))


def can_task_action_for_task(user, action: str, task) -> bool:
    action = (action or "").strip()
    global_map = get_task_permissions_for_user(user)
    if action in ("view_module", "create"):
        return global_map.get(action, False)

    # Task-dependent actions are allowed only if that status is visible and explicitly enabled for that status.
    if task is None:
        return False

    status = getattr(task, "status", None)
    visible_statuses = set(get_task_status_visibility_for_user(user).get("visible_statuses", []))
    if status not in visible_statuses:
        return False

    status_map = get_task_status_permissions_for_user(user)
    return bool((status_map.get(status) or {}).get(action, False))


def get_task_status_visibility_for_user(user) -> Dict[str, Any]:
    role = _role_or_none(user)

    parsed = parse_role_description(getattr(role, "description", "") if role else "")
    visibility_cfg = parsed.get("task_status_visibility") or {}
    if isinstance(visibility_cfg, dict) and "visible_statuses" in visibility_cfg:
        return {
            "visible_statuses": _coerce_status_list(visibility_cfg.get("visible_statuses")),
            "status_scopes": _coerce_status_scope_map(visibility_cfg.get("status_scopes")),
        }
    return {"visible_statuses": [], "status_scopes": {}}
