from rest_framework import serializers
from ..models import TaskActivity


class TaskActivitySerializer(serializers.ModelSerializer):
    user_name = serializers.SerializerMethodField()
    action_display = serializers.CharField(source="get_action_display", read_only=True)

    class Meta:
        model = TaskActivity
        fields = [
            "id",
            "action",
            "action_display",
            "message",
            "meta",
            "user",
            "user_name",
            "created_at",
        ]

    def get_user_name(self, obj):
        u = obj.user
        return u.get_full_name() or u.username or str(u.pk)
