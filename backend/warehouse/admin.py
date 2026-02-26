from django.contrib import admin
from .models import Warehouse, Product, ProductCategory, CategoryField, WarehouseInventory, StockMovement, SerialNumberItem

class InventoryInline(admin.TabularInline):
    model = WarehouseInventory
    extra = 0
    readonly_fields = ('quantity',)
    can_delete = False

class SerialNumberInline(admin.TabularInline):
    model = SerialNumberItem
    extra = 0
    readonly_fields = ('serial_number', 'warehouse', 'created_at')
    can_delete = False

class CategoryFieldInline(admin.TabularInline):
    model = CategoryField
    extra = 1

@admin.register(Warehouse)
class WarehouseAdmin(admin.ModelAdmin):
    list_display = ('name', 'region', 'is_active', 'address')
    search_fields = ('name', 'region__name', 'address', 'note')
    list_filter = ('region', 'is_active')
    inlines = [InventoryInline]
    list_per_page = 20

@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ('name', 'brand', 'model', 'has_serial_number', 'category', 'unit', 'price', 'is_active')
    search_fields = ('name', 'brand', 'model', 'note', 'serial_items__serial_number')
    list_filter = ('unit', 'brand', 'is_active', 'has_serial_number', 'category')
    inlines = [SerialNumberInline]
    list_per_page = 20

@admin.register(ProductCategory)
class ProductCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'is_active')
    inlines = [CategoryFieldInline]

@admin.register(WarehouseInventory)
class WarehouseInventoryAdmin(admin.ModelAdmin):
    list_display = ('warehouse', 'product', 'quantity')
    search_fields = ('warehouse__name', 'product__name')
    list_filter = ('warehouse', 'product__brand')
    list_per_page = 50

@admin.register(SerialNumberItem)
class SerialNumberItemAdmin(admin.ModelAdmin):
    list_display = ('serial_number', 'product', 'warehouse', 'created_at')
    search_fields = ('serial_number', 'product__name')
    list_filter = ('warehouse', 'product')
    list_per_page = 50

@admin.register(StockMovement)
class StockMovementAdmin(admin.ModelAdmin):
    list_display = ('product', 'movement_type', 'quantity_new', 'warehouse', 'serial_number', 'created_by', 'created_at')
    search_fields = ('product__name', 'reference_no', 'reason', 'serial_number', 'created_by__username')
    list_filter = ('movement_type', 'created_at', 'warehouse', 'product')
    readonly_fields = ('created_at',)
    list_per_page = 20
    date_hierarchy = 'created_at'
