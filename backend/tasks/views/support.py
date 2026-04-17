from django.db import models
from django.db.models import Case, IntegerField, Value, When
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..models import SupportComment, SupportRequest
from ..serializers import SupportCommentSerializer, SupportRequestSerializer


def _is_support_admin(user):
    role = getattr(user, "role", None)
    return bool(
        user.is_superuser
        or (role and getattr(role, "is_admin", False))
        or (role and getattr(role, "is_super_admin", False))
    )


class SupportRequestViewSet(viewsets.ModelViewSet):
    queryset = SupportRequest.objects.all()
    serializer_class = SupportRequestSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_queryset(self):
        user = self.request.user
        queryset = SupportRequest.objects.select_related("created_by", "accepted_by").prefetch_related(
            "comments",
            "comments__user",
        )

        if not _is_support_admin(user):
            queryset = queryset.filter(created_by=user)

        status_param = (self.request.query_params.get("status") or "").strip()
        if status_param:
            queryset = queryset.filter(status=status_param)

        mine_param = (self.request.query_params.get("mine") or "").lower()
        if mine_param == "true":
            queryset = queryset.filter(created_by=user)

        search = (self.request.query_params.get("search") or "").strip()
        if search:
            queryset = queryset.filter(
                models.Q(title__icontains=search)
                | models.Q(summary__icontains=search)
                | models.Q(created_by__first_name__icontains=search)
                | models.Q(created_by__last_name__icontains=search)
                | models.Q(created_by__username__icontains=search)
            )

        queryset = queryset.annotate(
            _status_order=Case(
                When(status=SupportRequest.Status.NEW, then=Value(0)),
                When(status=SupportRequest.Status.ACCEPTED, then=Value(1)),
                When(status=SupportRequest.Status.REJECTED, then=Value(2)),
                When(status=SupportRequest.Status.DONE, then=Value(3)),
                When(status=SupportRequest.Status.SOLVED, then=Value(4)),
                When(status=SupportRequest.Status.CLOSED, then=Value(5)),
                default=Value(99),
                output_field=IntegerField(),
            )
        ).order_by("_status_order", "-created_at")
        return queryset

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)

    def partial_update(self, request, *args, **kwargs):
        support = self.get_object()
        if not _is_support_admin(request.user):
            return Response(
                {"detail": "Yalnız admin və super admin support statusunu dəyişə bilər."},
                status=status.HTTP_403_FORBIDDEN,
            )

        return super().partial_update(request, *args, **kwargs)

    @action(detail=True, methods=["post"])
    def comment(self, request, pk=None):
        support = self.get_object()
        user = request.user
        can_comment = _is_support_admin(user) or support.created_by_id == user.id
        if not can_comment:
            return Response(
                {"detail": "Yalnız müraciəti açan və adminlər şərh yaza bilər."},
                status=status.HTTP_403_FORBIDDEN,
            )

        body = (request.data.get("body") or "").strip()
        if not body:
            return Response({"body": "Şərh boş ola bilməz."}, status=status.HTTP_400_BAD_REQUEST)

        comment = SupportComment.objects.create(
            support_request=support,
            user=user,
            body=body,
        )
        return Response(SupportCommentSerializer(comment).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=["patch"])
    def set_status(self, request, pk=None):
        support = self.get_object()
        user = request.user
        if not _is_support_admin(user):
            return Response(
                {"detail": "Yalnız admin və super admin status dəyişə bilər."},
                status=status.HTTP_403_FORBIDDEN,
            )

        new_status = (request.data.get("status") or "").strip()
        reject_note = (request.data.get("reject_note") or "").strip()
        allowed = {choice for choice, _ in SupportRequest.Status.choices}
        if new_status not in allowed:
            return Response({"status": "Yanlış status."}, status=status.HTTP_400_BAD_REQUEST)
        if new_status == SupportRequest.Status.REJECTED and not reject_note:
            return Response({"reject_note": "Rədd səbəbi mütləqdir."}, status=status.HTTP_400_BAD_REQUEST)

        support.status = new_status
        support.reject_note = reject_note if new_status == SupportRequest.Status.REJECTED else ""
        if new_status == SupportRequest.Status.ACCEPTED:
            support.accepted_by = user
        support.save(update_fields=["status", "reject_note", "accepted_by", "updated_at"])
        return Response(SupportRequestSerializer(support, context={"request": request}).data)
