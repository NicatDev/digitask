from django.contrib import admin
from .models import Warehouse, Product, WarehouseInventory, StockMovement

class InventoryInline(admin.TabularInline):
    model = WarehouseInventory
    extra = 0
    readonly_fields = ('quantity',)
    can_delete = False

@admin.register(Warehouse)
class WarehouseAdmin(admin.ModelAdmin):
    list_display = ('name', 'region', 'is_active', 'address')
    search_fields = ('name', 'region__name', 'address', 'note')
    list_filter = ('region', 'is_active')
    inlines = [InventoryInline]
    list_per_page = 20

@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ('name', 'brand', 'model', 'serial_number', 'unit', 'price', 'is_active')
    search_fields = ('name', 'brand', 'model', 'serial_number', 'note')
    list_filter = ('unit', 'brand', 'is_active')
    list_per_page = 20

@admin.register(WarehouseInventory)
class WarehouseInventoryAdmin(admin.ModelAdmin):
    list_display = ('warehouse', 'product', 'quantity')
    search_fields = ('warehouse__name', 'product__name', 'product__serial_number')
    list_filter = ('warehouse', 'product__brand')
    list_per_page = 50

@admin.register(StockMovement)
class StockMovementAdmin(admin.ModelAdmin):
    list_display = ('product', 'movement_type', 'quantity_new', 'warehouse', 'created_by', 'created_at')
    search_fields = ('product__name', 'reference_no', 'reason', 'created_by__username')
    list_filter = ('movement_type', 'created_at', 'warehouse', 'product')
    readonly_fields = ('created_at',)
    list_per_page = 20
    date_hierarchy = 'created_at'
