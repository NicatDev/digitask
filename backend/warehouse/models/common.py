from django.db import models
from users.models.common import Region

class Warehouse(models.Model):
    name = models.CharField(max_length=160)
    region = models.ForeignKey(Region, on_delete=models.PROTECT, related_name="warehouses")
    is_active = models.BooleanField(default=True)
    address = models.CharField(max_length=255, blank=True)
    coordinates = models.JSONField(default=dict, blank=True)  # {"lat":..., "lng":...}
    note = models.TextField(blank=True)

    class Meta:
        unique_together = ("region", "name")
        indexes = [models.Index(fields=["region", "name"]), models.Index(fields=["is_active"])]

    def __str__(self):
        return self.name

class Product(models.Model):
    class Unit(models.TextChoices):
        PCS = "pcs", "Piece"
        KG = "kg", "Kilogram"
        G = "g", "Gram"
        L = "l", "Liter"
        ML = "ml", "Milliliter"
        M = "m", "Meter"
        CM = "cm", "Centimeter"
        MM = "mm", "Millimeter"
        BOX = "box", "Box"
        PACK = "pack", "Pack"
        SET = "set", "Set"
        BAG = "bag", "Bag"
        TON = "ton", "Ton"
    
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)

    unit = models.CharField(
        max_length=10,
        choices=Unit.choices,
        default=Unit.PCS,
    )
    image = models.ImageField(upload_to="products/images/", null=True, blank=True)

    brand = models.CharField(max_length=100, blank=True)
    model = models.CharField(max_length=100, blank=True)
    serial_number = models.CharField(max_length=100, blank=True)
    port_count = models.IntegerField(default=1, null=True, blank=True)
    size = models.CharField(max_length=100,null=True, blank=True)
    weight = models.CharField(max_length=100,null=True, blank=True)
    price = models.DecimalField(max_digits=18, decimal_places=3, default=0, null=True, blank=True)
    
    note = models.TextField(blank=True)

    min_quantity = models.DecimalField(max_digits=18, decimal_places=3, null=True, blank=True)
    max_quantity = models.DecimalField(max_digits=18, decimal_places=3, null=True, blank=True) 
    
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name
