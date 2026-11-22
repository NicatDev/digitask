from django.db.models import Q
from django.http import HttpResponse
from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import BasePermission, IsAuthenticated
from rest_framework.response import Response

from ..models import CustomerImportBatch, CustomerImportRow
from ..serializers.customer_import import CustomerImportBatchSerializer, CustomerImportRowSerializer
from ..services.customer_import_v2 import runner
from ..services.customer_import_v2.export import export_rows
from ..services.customer_import_v2.parsers import ImportFileError
from ..services.customer_import_v2.templates import build_excel_template, build_json_sample

XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

# Tarixçə tabları → nəticə kodları
RESULT_GROUPS = {
    "new": ["new", "created"],
    "existing": ["existing", "duplicate_in_file"],
    "problem": ["problem"],
}


class IsCustomerImportAdmin(BasePermission):
    message = "Bu səhifə yalnız administratorlar üçündür."

    def has_permission(self, request, view):
        u = request.user
        if not u or not u.is_authenticated:
            return False
        if u.is_superuser:
            return True
        role = getattr(u, "role", None)
        return bool(role and role.is_active and (role.is_admin or role.is_super_admin))


class BatchPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


class RowPagination(PageNumberPagination):
    page_size = 50
    page_size_query_param = "page_size"
    max_page_size = 500


def _file_response(content, filename, content_type):
    resp = HttpResponse(content, content_type=content_type)
    resp["Content-Disposition"] = f'attachment; filename="{filename}"'
    resp["Cache-Control"] = "no-store"
    return resp


class CustomerImportBatchViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """
    Yeni müştəri importu (Excel / JSON).
    Yalnız yeni müştəri yaradır; mövcudları dəyişmir və silmir.
    """
    queryset = CustomerImportBatch.objects.select_related("created_by", "confirmed_by", "rolled_back_by")
    serializer_class = CustomerImportBatchSerializer
    permission_classes = [IsAuthenticated, IsCustomerImportAdmin]
    pagination_class = BatchPagination
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        latest = runner.latest_confirmed_batch()
        ctx["latest_confirmed_id"] = latest.pk if latest else ""
        return ctx

    def get_object(self):
        obj = super().get_object()
        return runner.refresh_stale(obj)

    def list(self, request, *args, **kwargs):
        for b in CustomerImportBatch.objects.filter(status__in=CustomerImportBatch.RUNNING_STATUSES):
            runner.refresh_stale(b)
        return super().list(request, *args, **kwargs)

    def _batch_response(self, batch, code=status.HTTP_200_OK):
        batch.refresh_from_db()
        return Response(self.get_serializer(batch).data, status=code)

    @staticmethod
    def _error(message, code=status.HTTP_400_BAD_REQUEST):
        return Response({"detail": message}, status=code)

    # --- şablonlar ---
    @action(detail=False, methods=["get"], url_path="template")
    def template(self, request):
        return _file_response(build_excel_template(), "musteri-import-sablonu.xlsx", XLSX)

    @action(detail=False, methods=["get"], url_path="sample-json")
    def sample_json(self, request):
        return _file_response(build_json_sample(), "musteri-import-numunesi.json", "application/json; charset=utf-8")

    # --- hazırkı vəziyyət (səhifə açılanda) ---
    @action(detail=False, methods=["get"], url_path="active")
    def active(self, request):
        qs = CustomerImportBatch.objects.filter(
            status__in=["validating", "preview", "importing", "interrupted", "rolling_back"]
        ).order_by("-created_at")
        for b in qs:
            b = runner.refresh_stale(b)
            if b.status in ("validating", "preview", "importing", "interrupted", "rolling_back"):
                return Response(self.get_serializer(b).data)
        return Response(None)

    # --- yükləmə ---
    @action(detail=False, methods=["post"], url_path="upload")
    def upload(self, request):
        f = request.FILES.get("file")
        if not f:
            return self._error("Fayl seçilməyib.")
        try:
            batch = runner.upload(f, request.user)
        except ImportFileError as exc:
            return self._error(str(exc))
        except runner.ImportActionError as exc:
            return self._error(str(exc), status.HTTP_409_CONFLICT)
        return self._batch_response(batch, status.HTTP_201_CREATED)

    # --- əməliyyatlar ---
    def _act(self, fn, *args):
        try:
            batch = fn(*args)
        except runner.ImportActionError as exc:
            return self._error(str(exc), status.HTTP_409_CONFLICT)
        return self._batch_response(batch)

    @action(detail=True, methods=["post"])
    def confirm(self, request, pk=None):
        return self._act(runner.confirm, self.get_object(), request.user)

    @action(detail=True, methods=["post"])
    def cancel(self, request, pk=None):
        return self._act(runner.cancel, self.get_object())

    @action(detail=True, methods=["post"])
    def resume(self, request, pk=None):
        return self._act(runner.resume, self.get_object(), request.user)

    @action(detail=True, methods=["get"], url_path="rollback-check")
    def rollback_check(self, request, pk=None):
        return Response(runner.rollback_check(self.get_object()))

    @action(detail=True, methods=["post"])
    def rollback(self, request, pk=None):
        return self._act(runner.start_rollback, self.get_object(), request.user)

    # --- sətirlər (tarixçə detalları) ---
    def _rows_qs(self, batch, request):
        qs = CustomerImportRow.objects.filter(batch=batch)
        group = request.query_params.get("group")
        if group in RESULT_GROUPS:
            qs = qs.filter(result__in=RESULT_GROUPS[group])
        result = request.query_params.get("result")
        if result:
            qs = qs.filter(result=result)
        if request.query_params.get("with_warnings") == "true":
            qs = qs.exclude(warnings=[])
        search = (request.query_params.get("search") or "").strip()
        if search:
            cond = (
                Q(data__full_name__icontains=search)
                | Q(data__register_number__icontains=search)
                | Q(data__phone_number__icontains=search)
                | Q(data__address__icontains=search)
            )
            if search.isdigit():
                cond |= Q(row_number=int(search))
                digits = search.lstrip("0")
                if len(digits) >= 5:
                    cond |= Q(keys__icontains=digits)
            qs = qs.filter(cond)
        return qs.order_by("row_number", "id")

    @action(detail=True, methods=["get"])
    def rows(self, request, pk=None):
        batch = self.get_object()
        qs = self._rows_qs(batch, request)
        paginator = RowPagination()
        page = paginator.paginate_queryset(qs, request, view=self)
        return paginator.get_paginated_response(CustomerImportRowSerializer(page, many=True).data)

    @action(detail=True, methods=["get"], url_path="rows/export")
    def rows_export(self, request, pk=None):
        batch = self.get_object()
        qs = self._rows_qs(batch, request)
        group = request.query_params.get("group") or "all"
        stamp = timezone.localtime(batch.created_at).strftime("%Y%m%d-%H%M")
        return _file_response(export_rows(qs), f"import-{stamp}-{group}.xlsx", XLSX)
