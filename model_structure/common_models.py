from django.db import models

class Region(models.Model):
    name = models.CharField(max_length=120, unique=True)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class RegionGroup(models.Model):
    """
    Hər regiona bağlı qrup. Gələcəkdə Task-lar group üzrə görünəcək.
    """
    region = models.ForeignKey(Region, on_delete=models.CASCADE, related_name="groups")
    name = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        unique_together = ("region", "name")
        indexes = [models.Index(fields=["region", "name"])]

    def __str__(self):
        return f"{self.region.name} - {self.name}"


class Customer(models.Model):
    full_name = models.CharField(max_length=200)
    register_number = models.CharField(max_length=60, blank=True)
    phone_number = models.CharField(max_length=30, blank=True)
    passport_image = models.ImageField(upload_to="customers/passports/", null=True, blank=True)

    region = models.ForeignKey(Region, on_delete=models.PROTECT, related_name="customers")
    address = models.CharField(max_length=255, blank=True)
    address_coordinates = models.JSONField(default=dict, blank=True)  # {"lat":..., "lng":...}

    def __str__(self):
        return self.full_name


