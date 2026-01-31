
class GroupChat(models.Model):
    """
    Hər RegionGroup üçün chat.
    """
    group = models.OneToOneField(RegionGroup, on_delete=models.CASCADE, related_name="chat")

    owner = models.ForeignKey(User, on_delete=models.PROTECT, related_name="owned_group_chats")

    # True olsa: yalnız owner mesaj yaza bilər
    only_owner_can_write = models.BooleanField(default=False)

    title = models.CharField(max_length=120, blank=True)  # istəsən "Bakı-1 Chat" kimi

    created_at = models.DateTimeField(auto_now_add=True)

    def clean(self):
        # owner həmin group-un üzvü olmalıdır (məntiqli rule)
        if self.group_id and self.owner_id:
            is_member = UserGroupMembership.objects.filter(
                user_id=self.owner_id, group_id=self.group_id, is_active=True
            ).exists()
            if not is_member:
                raise ValidationError({"owner": "Chat owner bu group-un üzvü olmalıdır."})

    def __str__(self):
        return self.title or f"Chat: {self.group}"


class GroupChatMessage(models.Model):
    chat = models.ForeignKey(GroupChat, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(User, on_delete=models.PROTECT, related_name="group_chat_messages")

    text = models.TextField()

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]
        indexes = [
            models.Index(fields=["chat", "created_at"]),
            models.Index(fields=["sender", "created_at"]),
        ]