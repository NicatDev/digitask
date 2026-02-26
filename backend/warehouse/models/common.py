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


class ProductCategory(models.Model):
    """Product category with dynamic fields."""
    name = models.CharField(max_length=200)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name_plural = "Product Categories"
        ordering = ['name']

    def __str__(self):
        return self.name


class CategoryField(models.Model):
    """Dynamic field definition for a product category."""
    class FieldType(models.TextChoices):
        STRING = 'string', 'String'
        NUMBER = 'number', 'Number'
        BOOLEAN = 'boolean', 'Boolean'
        DATE = 'date', 'Date'

    category = models.ForeignKey(ProductCategory, on_delete=models.CASCADE, related_name='fields')
    name = models.CharField(max_length=100)
    field_type = models.CharField(max_length=20, choices=FieldType.choices, default=FieldType.STRING)
    is_required = models.BooleanField(default=False)

    class Meta:
        unique_together = ("category", "name")
        ordering = ['id']

    def __str__(self):
        return f"{self.category.name} - {self.name} ({self.field_type})"


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
    
    has_serial_number = models.BooleanField(default=False)
    
    port_count = models.IntegerField(default=1, null=True, blank=True)
    size = models.CharField(max_length=100, null=True, blank=True)
    weight = models.CharField(max_length=100, null=True, blank=True)
    price = models.DecimalField(max_digits=18, decimal_places=3, default=0, null=True, blank=True)
    
    note = models.TextField(blank=True)

    min_quantity = models.DecimalField(max_digits=18, decimal_places=3, null=True, blank=True)
    max_quantity = models.DecimalField(max_digits=18, decimal_places=3, null=True, blank=True) 
    
    category = models.ForeignKey(
        ProductCategory, on_delete=models.SET_NULL, 
        null=True, blank=True, related_name='products'
    )
    category_data = models.JSONField(default=dict, blank=True)
    
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name
