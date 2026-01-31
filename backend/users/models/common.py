from django.db import models

class Region(models.Model):
    name = models.CharField(max_length=120, unique=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name

class Group(models.Model):
    region = models.ForeignKey(Region, on_delete=models.CASCADE, related_name="groups")
    name = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        unique_together = ("region", "name")

    def __str__(self):
        return f"{self.region.name} - {self.name}"
