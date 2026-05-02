from django.db import models
from django.db.models import Case, IntegerField, Value, When
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..models import SupportComment, SupportRequest
from ..serializers import SupportCommentSerializer, SupportRequestSerializer


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

        status_param = (self.request.query_params.get("status") or "").strip()
        if status_param:
            queryset = queryset.filter(status=status_param)
        else:
            scope = (self.request.query_params.get("scope") or "active").strip().lower()
            past_statuses = (
                SupportRequest.Status.REJECTED,
                SupportRequest.Status.SOLVED,
                SupportRequest.Status.DONE,
            )
            if scope == "past":
                queryset = queryset.filter(status__in=past_statuses)
            elif scope == "active":
                queryset = queryset.exclude(status__in=past_statuses)

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

    @action(detail=True, methods=["post"])
    def comment(self, request, pk=None):
        support = self.get_object()
        user = request.user

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

        new_status = (request.data.get("status") or "").strip()
        reject_note = (request.data.get("reject_note") or "").strip()
        allowed = {choice for choice, _ in SupportRequest.Status.choices}
        if new_status not in allowed:
            return Response({"status": "Yanlış status."}, status=status.HTTP_400_BAD_REQUEST)
        if new_status == SupportRequest.Status.REJECTED and not reject_note:
            return Response({"reject_note": "Rədd səbəbi mütləqdir."}, status=status.HTTP_400_BAD_REQUEST)

        if new_status == SupportRequest.Status.DONE:
            return Response(
                {"status": "Done statusu artıq istifadə olunmur. Birbaşa «Həll edildi» seçin."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if new_status == SupportRequest.Status.ACCEPTED and support.status != SupportRequest.Status.NEW:
            return Response(
                {"status": "Yalnız «Yeni» müraciəti qəbul etmək olar."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if new_status == SupportRequest.Status.SOLVED and support.status != SupportRequest.Status.ACCEPTED:
            return Response(
                {"status": "Əvvəlcə müraciəti qəbul edin; qəbul edilmədən həll edilə bilməz."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if new_status == SupportRequest.Status.CLOSED and support.status != SupportRequest.Status.SOLVED:
            return Response(
                {"status": "Yalnız «Həll edildi» statusundan sonra bağlamaq olar."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if new_status == SupportRequest.Status.REJECTED and support.status == SupportRequest.Status.REJECTED:
            return Response(
                {"status": "Bu müraciət artıq rədd edilib."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        support.status = new_status
        support.reject_note = reject_note if new_status == SupportRequest.Status.REJECTED else ""
        if new_status == SupportRequest.Status.ACCEPTED:
            support.accepted_by = user
        support.save(update_fields=["status", "reject_note", "accepted_by", "updated_at"])
        return Response(SupportRequestSerializer(support, context={"request": request}).data)
