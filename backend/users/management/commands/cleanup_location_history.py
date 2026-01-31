from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from users.models import LocationHistory

class Command(BaseCommand):
    help = 'Deletes location history records older than 1 month.'

    def handle(self, *args, **options):
        cutoff_date = timezone.now() - timedelta(days=30)
        
        count, _ = LocationHistory.objects.filter(timestamp__lt=cutoff_date).delete()
        
        self.stdout.write(self.style.SUCCESS(f'Successfully deleted {count} old location history records.'))
