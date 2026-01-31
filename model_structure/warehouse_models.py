from django.db import models
from core.models import Region, RegionGroup

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
    # min max ona gore lazimdiki biz minimum deyerden daha asagi olanda sari reng xeberdarliq iconu qoyaq
    # maximum deyerden yuxari olanda qirmizi reng xeberdarliq iconu qoyaq

    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class WarehouseInventory(models.Model):
    """
    Warehouse + Product üçün “neçə dənə var” və əlavə info.
    Bu sənin istədiyin “warehouse və product-a bağlı bir model”dir.
    """
    warehouse = models.ForeignKey(Warehouse, on_delete=models.CASCADE, related_name="inventory_items")
    product = models.ForeignKey(Product, on_delete=models.PROTECT, related_name="inventory_items")

    quantity = models.DecimalField(max_digits=18, decimal_places=3, default=0)



    class Meta:
        unique_together = ("warehouse", "product")
        indexes = [
            models.Index(fields=["warehouse"]),
            models.Index(fields=["product"]),
            models.Index(fields=["warehouse", "product"]),
        ]

    def __str__(self):
        return f"{self.warehouse} - {self.product} = {self.quantity}"



User = settings.AUTH_USER_MODEL


class StockMovement(models.Model):
    class Type(models.TextChoices):
        IN = "in", "Import (idxal/giriş)"                 # anbara giriş
        OUT = "out", "Export (ixrac/çıxış)"               # anbardan çıxış
        TRANSFER = "transfer", "Transfer (köçürmə)"       # anbarlar arası
        ADJUST = "adjust", "Adjustment (korreksiya)"      # inventar düzəlişi
        RETURN = "return", "Return (qayıtma)"             # geri qaytarma

    # harada dəyişdi
    warehouse = models.ForeignKey(Warehouse, on_delete=models.PROTECT, related_name="movements")

    # transfer üçün: haradan hara
    from_warehouse = models.ForeignKey(
        Warehouse, on_delete=models.PROTECT, null=True, blank=True, related_name="transfer_out_movements"
    )
    to_warehouse = models.ForeignKey(
        Warehouse, on_delete=models.PROTECT, null=True, blank=True, related_name="transfer_in_movements"
    )

    product = models.ForeignKey(Product, on_delete=models.PROTECT, related_name="movements")

    movement_type = models.CharField(max_length=12, choices=Type.choices)
    reason = models.CharField(max_length=255, blank=True, null=True)

    # qəti tövsiyə: delta saxla (müsbət=artım, mənfi=azalma)
    quantity_old = models.DecimalField(max_digits=18, decimal_places=3)
    quantity_new = models.DecimalField(max_digits=18, decimal_places=3)

    created_by = models.ForeignKey(User, on_delete=models.PROTECT, null=True, blank=True, related_name="stock_movements")
    created_at = models.DateTimeField(auto_now_add=True)

    # gələcəkdə: sənəd/akt nömrəsi, invoice və s.
    reference_no = models.CharField(max_length=80, blank=True)

    # gələcəkdə task-a bağlamaq istəsən (opsional)
    task = models.ForeignKey("tasks.Task", on_delete=models.PROTECT, null=True, blank=True) # istəsən FK edərik (tasks.Task)

    class Meta:
        indexes = [
            models.Index(fields=["warehouse", "created_at"]),
            models.Index(fields=["product", "created_at"]),
            models.Index(fields=["movement_type", "created_at"]),
            models.Index(fields=["reference_no"]),
        ]

  