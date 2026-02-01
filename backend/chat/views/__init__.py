from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.db.models import Count, Q, OuterRef, Subquery
from ..models import ChatGroup, GroupMembership, Message, MessageReadStatus
from ..serializers import (
    ChatGroupListSerializer, ChatGroupDetailSerializer, 
    MessageSerializer, UserSimpleSerializer
)
from django.contrib.auth import get_user_model

User = get_user_model()

class ChatGroupViewSet(viewsets.ModelViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        # Groups where user is a member OR user is the owner
        return ChatGroup.objects.filter(
            Q(memberships__user=user) | Q(owner=user)
        ).distinct().order_by('-created_at')

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance.owner != request.user:
            return Response({'detail': 'Yalnız qrup sahibi qrupu silə bilər.'}, status=status.HTTP_403_FORBIDDEN)
        return super().destroy(request, *args, **kwargs)

    def get_serializer_class(self):
        if self.action in ['retrieve', 'update', 'partial_update']:
            return ChatGroupDetailSerializer
        return ChatGroupListSerializer

    def perform_create(self, serializer):
        group = serializer.save(owner=self.request.user)
        # Add owner as member automatically
        GroupMembership.objects.create(group=group, user=self.request.user)

    @action(detail=True, methods=['post'], url_path='add-member')
    def add_member(self, request, pk=None):
        group = self.get_object()
        if group.owner != request.user:
            return Response({'detail': 'Only owner can add members.'}, status=status.HTTP_403_FORBIDDEN)
        
        user_id = request.data.get('user_id')
        user = get_object_or_404(User, pk=user_id)
        
        if GroupMembership.objects.filter(group=group, user=user).exists():
            return Response({'detail': 'User already in group.'}, status=status.HTTP_400_BAD_REQUEST)

        GroupMembership.objects.create(group=group, user=user)
        return Response({'detail': 'Member added.'})

    @action(detail=True, methods=['post'], url_path='remove-member')
    def remove_member(self, request, pk=None):
        group = self.get_object()
        if group.owner != request.user:
            return Response({'detail': 'Only owner can remove members.'}, status=status.HTTP_403_FORBIDDEN)
        
        user_id = request.data.get('user_id')
        if not user_id:
             return Response({'detail': 'User ID required.'}, status=status.HTTP_400_BAD_REQUEST)
             
        # Owner cannot remove themselves via this endpoint (should delete group instead or transfer ownership logic)
        if int(user_id) == group.owner.id:
             return Response({'detail': 'Owner cannot be removed. Delete group instead.'}, status=status.HTTP_400_BAD_REQUEST)

        GroupMembership.objects.filter(group=group, user_id=user_id).delete()
        return Response({'detail': 'Member removed.'})


from rest_framework.pagination import PageNumberPagination

class MessagePagination(PageNumberPagination):
    page_size = 30
    page_size_query_param = 'page_size'
    max_page_size = 100

class MessageViewSet(viewsets.ModelViewSet):
    serializer_class = MessageSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = MessagePagination

    def get_queryset(self):
        group_id = self.request.query_params.get('group')
        if not group_id:
            return Message.objects.none()
        
        # Check permission: User must be member of group
        if not GroupMembership.objects.filter(group_id=group_id, user=self.request.user).exists():
             return Message.objects.none()

        return Message.objects.filter(group_id=group_id).select_related('sender').order_by('-created_at')

    def perform_create(self, serializer):
        group = serializer.validated_data['group']
        # Verify membership
        if not GroupMembership.objects.filter(group=group, user=self.request.user).exists():
             raise permissions.PermissionDenied("You are not a member of this group.")
        
        message = serializer.save(sender=self.request.user)
        
        # Mark as read for sender
        MessageReadStatus.objects.create(message=message, user=self.request.user, read_at=message.created_at)

    @action(detail=False, methods=['post'], url_path='mark-read')
    def mark_read(self, request):
        group_id = request.data.get('group_id')
        if not group_id:
             return Response({'detail': 'Group ID required.'}, status=status.HTTP_400_BAD_REQUEST)

        # Mark all unread messages in this group as read for current user
        unread_messages = Message.objects.filter(group_id=group_id).exclude(
            read_statuses__user=request.user
        )
        
        # Bulk create/update is tricky with existing mix. 
        # Simpler: Get IDs of messages NOT in MessageReadStatus for this user
        # Note: existing logic assumes MessageReadStatus row matches "Read". If row missing = Unread.
        
        # Create ReadStatus for all missing
        new_statuses = []
        from django.utils import timezone
        now = timezone.now()
        
        for msg in unread_messages:
            new_statuses.append(MessageReadStatus(message=msg, user=request.user, read_at=now))
        
        MessageReadStatus.objects.bulk_create(new_statuses, ignore_conflicts=True)
        
        return Response({'detail': 'Messages marked as read.'})
