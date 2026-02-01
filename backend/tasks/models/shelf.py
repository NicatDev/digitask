from django.db import models


class Shelf(models.Model):
    """Rəf modeli - sənədlərin arxivləşdirilməsi üçün"""
    name = models.CharField(max_length=100)
    location = models.CharField(max_length=200, blank=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        verbose_name = 'Rəf'
        verbose_name_plural = 'Rəflər'

    def __str__(self):
        return self.name
