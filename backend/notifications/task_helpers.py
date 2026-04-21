"""Tapşırıq bildirişləri üçün mətn və alıcı siyahıları."""

from django.contrib.auth import get_user_model

User = get_user_model()


def format_task_line(task) -> str:
    """Bütün tapşırıq bildirişlərində: ID + qeydiyyat nömrəsi."""
    reg = ''
    if task.customer_id:
        try:
            reg = (task.customer.register_number or '').strip()
        except Exception:
            reg = ''
    return f"Tapşırıq #{task.id} · Qeyd. № {reg or '—'}"


def user_ids_in_task_group(task) -> list:
    """Tapşırığın qrupu ilə eyni qrupda olan aktiv istifadəçilər."""
    if not task.group_id:
        return []
    return list(
        User.objects.filter(group_id=task.group_id, is_active=True).values_list('pk', flat=True)
    )


def user_ids_privileged_in_task_group(task) -> list:
    """Qrupda: is_admin, is_super_admin və ya is_task_view_all (və ya Django superuser)."""
    if not task.group_id:
        return []
    out = []
    for u in User.objects.filter(group_id=task.group_id, is_active=True).select_related('role'):
        r = u.role
        if u.is_superuser or (
            r and (r.is_admin or r.is_super_admin or getattr(r, 'is_task_view_all', False))
        ):
            out.append(u.pk)
    return out


def user_ids_assignee_change_recipients(task) -> list:
    """İcraçı əlavəsi: imtiyazlı qrup üzvləri ∪ cari icraçılar (qrup yoxdursa yalnız icraçılar)."""
    ass = set(task.assigned_to.values_list('pk', flat=True))
    if not task.group_id:
        return list(ass)
    priv = set(user_ids_privileged_in_task_group(task))
    return list(priv | ass)


def task_with_customer(task):
    """customer select_related olmasa belə bir sorğu ilə yüklə."""
    from tasks.models import Task

    return Task.objects.select_related('customer', 'group').filter(pk=task.pk).first() or task
