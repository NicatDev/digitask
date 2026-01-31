import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async

class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.group_id = self.scope['url_route']['kwargs']['group_id']
        self.room_group_name = f'chat_{self.group_id}'
        self.user = self.scope['user']

        if self.user.is_anonymous:
            await self.close()
            return

        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        await self.accept()

    async def disconnect(self, close_code):
        # Leave room group
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name
            )

    # Receive message from WebSocket
    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message = text_data_json['message']
        sender_name = self.user.get_full_name()

        # Save message to database
        saved_message = await self.save_message(self.group_id, message)

        # Send message to room group
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'chat_message',
                'message': message,
                'sender': sender_name,
                'sender_id': self.user.id,
                'created_at': saved_message.created_at.isoformat(),
                'msg_id': saved_message.id
            }
        )

    # Receive message from room group
    async def chat_message(self, event):
        message = event['message']
        sender = event['sender']
        sender_id = event['sender_id']
        created_at = event['created_at']
        msg_id = event['msg_id']

        # Send message to WebSocket
        await self.send(text_data=json.dumps({
            'message': message,
            'sender': sender,
            'sender_id': sender_id,
            'created_at': created_at,
            'id': msg_id
        }))

    @database_sync_to_async
    def save_message(self, group_id, content):
        from .models import Message, ChatGroup
        group = ChatGroup.objects.get(id=group_id)
        
        # Permission check
        if group.only_owner_can_send and group.owner != self.user:
             # Ideally raise error that can be caught and sent back
             raise Exception("Only owner can send messages in this group.")

        message = Message.objects.create(group=group, sender=self.user, content=content)
        return message


class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope['user']
        if self.user.is_anonymous:
            await self.close()
            return
            
        self.room_group_name = f'user_notifications_{self.user.id}'
        
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        await self.accept()
        
    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name
            )
        
    async def notification_message(self, event):
        await self.send(text_data=json.dumps(event))

class LocationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope['user']
        if self.user.is_anonymous:
            await self.close()
            return
            
        self.room_group_name = 'live_tracking'
        
        # Add to tracking group (everyone joins to receive updates? Or only admins?)
        # For now, everyone joins so they can see each other if needed, or we restrict in frontend.
        # Ideally, only admins should receive "all" updates.
        # But let's keep it simple: Everyone joins.
        
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        await self.accept()
        
        # Update online status
        await self.update_online_status(True)

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(
                self.room_group_name,
                self.channel_name
            )
        # Update online status
        await self.update_online_status(False)

    async def receive(self, text_data):
        data = json.loads(text_data)
        
        if data.get('type') == 'location_update':
            lat = data.get('latitude')
            lng = data.get('longitude')
            
            if lat is not None and lng is not None:
                # Save to DB
                await self.save_location(lat, lng)
                
                # Broadcast
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        'type': 'location_message',
                        'user_id': self.user.id,
                        'latitude': lat,
                        'longitude': lng,
                        'is_online': True
                    }
                )

    async def location_message(self, event):
        # Forward to websocket
        await self.send(text_data=json.dumps(event))

    @database_sync_to_async
    def update_online_status(self, is_online):
        from users.models import UserLocation
        # Create profile if not exists
        loc, _ = UserLocation.objects.get_or_create(user=self.user)
        loc.is_online = is_online
        loc.save()
        
        # Notify group about status change?
        # Maybe later.

    @database_sync_to_async
    def save_location(self, lat, lng):
        from users.models import UserLocation, LocationHistory
        from math import radians, sin, cos, sqrt, atan2

        # 1. Update Current Profile (Always)
        loc, _ = UserLocation.objects.get_or_create(user=self.user)
        loc.latitude = lat
        loc.longitude = lng
        loc.is_online = True
        loc.save()

        # 2. Check overlap logic (20m rule) for History
        last_history = LocationHistory.objects.filter(user=self.user).order_by('-timestamp').first()
        
        should_save_history = True
        if last_history:
            # Haversine Distance
            R = 6371000 # Radius of Earth in meters
            lat1, lon1 = radians(last_history.latitude), radians(last_history.longitude)
            lat2, lon2 = radians(lat), radians(lng)
            
            dlat = lat2 - lat1
            dlon = lon2 - lon1
            
            a = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlon / 2)**2
            c = 2 * atan2(sqrt(a), sqrt(1 - a))
            distance = R * c
            
            if distance < 20: # Meters
                should_save_history = False
        
        if should_save_history:
            LocationHistory.objects.create(user=self.user, latitude=lat, longitude=lng)

