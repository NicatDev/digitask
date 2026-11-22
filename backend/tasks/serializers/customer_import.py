from rest_framework import serializers

from ..models import CustomerImportBatch, CustomerImportRow


def _user_name(u):
    if not u:
        return None
    return (u.get_full_name() or "").strip() or u.username


class CustomerImportBatchSerializer(serializers.ModelSerializer):
    status_label = serializers.CharField(source="get_status_display", read_only=True)
    created_by_name = serializers.SerializerMethodField()
    confirmed_by_name = serializers.SerializerMethodField()
    rolled_back_by_name = serializers.SerializerMethodField()
    can_rollback = serializers.SerializerMethodField()
    has_file = serializers.SerializerMethodField()

    class Meta:
        model = CustomerImportBatch
        fields = [
            "id", "source_type", "original_filename", "file_size", "has_file",
            "status", "status_label", "phase", "progress_total", "progress_done",
            "total_rows", "new_count", "existing_count", "duplicate_in_file_count",
            "problem_count", "warning_count", "created_count",
            "summary", "created_refs", "rollback_summary", "error_message",
            "created_by_name", "confirmed_by_name", "rolled_back_by_name",
            "created_at", "confirmed_at", "finished_at", "rolled_back_at",
            "can_rollback",
        ]

    def get_created_by_name(self, obj):
        return _user_name(obj.created_by)

    def get_confirmed_by_name(self, obj):
        return _user_name(obj.confirmed_by)

    def get_rolled_back_by_name(self, obj):
        return _user_name(obj.rolled_back_by)

    def get_can_rollback(self, obj):
        latest_id = self.context.get("latest_confirmed_id")
        if latest_id is None:
            from ..services.customer_import_v2.runner import can_rollback
            return can_rollback(obj)
        return obj.status in ("completed", "interrupted") and str(obj.pk) == str(latest_id)

    def get_has_file(self, obj):
        return bool(obj.file)


class CustomerImportRowSerializer(serializers.ModelSerializer):
    result_label = serializers.CharField(source="get_result_display", read_only=True)

    class Meta:
        model = CustomerImportRow
        fields = [
            "id", "row_number", "raw", "data", "result", "result_label",
            "reasons", "warnings", "matches", "duplicate_of_row", "created_customer",
        ]
