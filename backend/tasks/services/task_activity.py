from ..models import Task, TaskActivity


def task_status_label(value):
    """Human-readable label for a Task.Status value string."""
    for c in Task.Status:
        if c.value == value:
            return c.label
    return value or ""


def log_task_activity(task, user, action, message="", meta=None):
    if task is None or user is None:
        return None
    return TaskActivity.objects.create(
        task=task,
        user=user,
        action=action,
        message=message or "",
        meta=meta or {},
    )
