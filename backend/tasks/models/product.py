from django.db import models
from .task import Task
from .customer import Customer
from warehouse.models import Product, Warehouse


class TaskProduct(models.Model):
    """Tapşırıq üçün seçilmiş məhsullar"""
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name="task_products")
    product = models.ForeignKey(Product, on_delete=models.PROTECT, related_name="task_products")
    warehouse = models.ForeignKey(Warehouse, on_delete=models.PROTECT, related_name="task_products")
    quantity = models.DecimalField(max_digits=18, decimal_places=3)
    is_deducted = models.BooleanField(default=False)  # Anbardan çıxarılıbmı?
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["task"]),
            models.Index(fields=["product"]),
            models.Index(fields=["warehouse"]),
        ]

    def __str__(self):
        return f"{self.task.title} - {self.product.name} ({self.quantity})"
