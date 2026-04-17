from rest_framework import serializers

from ..models import SupportRequest, SupportComment


class SupportCommentSerializer(serializers.ModelSerializer):
    user_name = serializers.SerializerMethodField()

    class Meta:
        model = SupportComment
        fields = ["id", "support_request", "user", "user_name", "body", "created_at"]
        read_only_fields = ["id", "support_request", "user", "user_name", "created_at"]

    def get_user_name(self, obj):
        name = obj.user.get_full_name().strip()
        return name if name else obj.user.username


class SupportRequestSerializer(serializers.ModelSerializer):
    created_by_name = serializers.SerializerMethodField()
    accepted_by_name = serializers.SerializerMethodField()
    comments = SupportCommentSerializer(many=True, read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)

    class Meta:
        model = SupportRequest
        fields = [
            "id",
            "title",
            "summary",
            "current_state",
            "expected_state",
            "attachment",
            "status",
            "status_display",
            "reject_note",
            "created_by",
            "created_by_name",
            "accepted_by",
            "accepted_by_name",
            "created_at",
            "updated_at",
            "comments",
        ]
        read_only_fields = [
            "id",
            "created_by",
            "created_by_name",
            "accepted_by",
            "accepted_by_name",
            "created_at",
            "updated_at",
            "comments",
            "status_display",
        ]

    def get_created_by_name(self, obj):
        name = obj.created_by.get_full_name().strip()
        return name if name else obj.created_by.username

    def get_accepted_by_name(self, obj):
        if not obj.accepted_by:
            return ""
        name = obj.accepted_by.get_full_name().strip()
        return name if name else obj.accepted_by.username

    def validate(self, attrs):
        status = attrs.get("status", self.instance.status if self.instance else SupportRequest.Status.NEW)
        reject_note = (attrs.get("reject_note") or "").strip()
        if status == SupportRequest.Status.REJECTED and not reject_note:
            raise serializers.ValidationError({"reject_note": "Rədd səbəbi mütləqdir."})
        return attrs
