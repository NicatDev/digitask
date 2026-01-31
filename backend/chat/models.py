from django.db import models
from django.conf import settings

User = settings.AUTH_USER_MODEL

class ChatGroup(models.Model):
    name = models.CharField(max_length=255)
    owner = models.ForeignKey(User, on_delete=models.PROTECT, related_name="owned_groups")
    image = models.ImageField(upload_to="chat/groups/", null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)
    only_owner_can_send = models.BooleanField(default=False)

    def __str__(self):
        return self.name

class GroupMembership(models.Model):
    group = models.ForeignKey(ChatGroup, on_delete=models.CASCADE, related_name="memberships")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="group_memberships")
    joined_at = models.DateTimeField(auto_now_add=True)
    
    # Permission settings specific to member in group (future proofing)
    can_send_messages = models.BooleanField(default=True)

    class Meta:
        unique_together = ("group", "user")

    def __str__(self):
        return f"{self.user} in {self.group}"

class Message(models.Model):
    group = models.ForeignKey(ChatGroup, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(User, on_delete=models.PROTECT, related_name="sent_messages")
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"{self.sender}: {self.content[:20]}"

class MessageReadStatus(models.Model):
    message = models.ForeignKey(Message, on_delete=models.CASCADE, related_name="read_statuses")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="message_read_statuses")
    read_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        unique_together = ("message", "user")
        indexes = [
            models.Index(fields=["user", "read_at"]),
        ]

    def __str__(self):
        status = "Read" if self.read_at else "Unread"
        return f"{self.user} - {status}"
