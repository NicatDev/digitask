from django.db import models
from django.conf import settings
from .common import Warehouse, Product

User = settings.AUTH_USER_MODEL

class WarehouseInventory(models.Model):
    """
    Warehouse + Product üçün “neçə dənə var” və əlavə info.
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

    class Meta:
        indexes = [
            models.Index(fields=["warehouse", "created_at"]),
            models.Index(fields=["product", "created_at"]),
            models.Index(fields=["movement_type", "created_at"]),
            models.Index(fields=["reference_no"]),
        ]
