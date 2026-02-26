from rest_framework import viewsets, status, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from django.db import transaction
from decimal import Decimal
from ..models import Warehouse, Product, WarehouseInventory, StockMovement, SerialNumberItem
from ..serializers import (
    WarehouseInventorySerializer,
    StockMovementSerializer,
    SerialNumberItemSerializer
)
from .common import StandardResultsSetPagination


class WarehouseInventoryViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = WarehouseInventory.objects.all()
    serializer_class = WarehouseInventorySerializer
    pagination_class = StandardResultsSetPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    search_fields = ['product__name', 'warehouse__name']
    filterset_fields = ['warehouse', 'product']


class SerialNumberItemViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = SerialNumberItem.objects.all()
    serializer_class = SerialNumberItemSerializer
    pagination_class = StandardResultsSetPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    search_fields = ['serial_number', 'product__name']
    filterset_fields = ['product', 'warehouse']


class StockMovementViewSet(viewsets.ModelViewSet):
    queryset = StockMovement.objects.all().order_by('-created_at')
    serializer_class = StockMovementSerializer
    pagination_class = StandardResultsSetPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['product__name', 'warehouse__name', 'reference_no', 'reason', 'serial_number']
    filterset_fields = ['warehouse', 'product', 'movement_type', 'created_by']

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)

    # ─── Normal (non-serial) stock adjustment ───
    @action(detail=False, methods=['post'], url_path='adjust')
    def adjust_stock(self, request):
        data = request.data
        warehouse_id = data.get('warehouse_id')
        product_id = data.get('product_id')
        m_type = data.get('movement_type')

        if not all([warehouse_id, product_id, m_type]):
            return Response({'error': 'warehouse_id, product_id, movement_type tələb olunur'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            qty = Decimal(str(data.get('quantity', 0)))
        except Exception:
            return Response({'error': 'Düzgün miqdar daxil edin'}, status=status.HTTP_400_BAD_REQUEST)

        if not qty or qty <= 0:
            return Response({'error': 'Miqdar 0-dan böyük olmalıdır'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            warehouse = Warehouse.objects.get(pk=warehouse_id)
            product = Product.objects.get(pk=product_id)

            if product.has_serial_number:
                return Response({'error': 'Bu serial nömrəli məhsuldur. /serial-adjust/ endpoint istifadə edin.'}, status=status.HTTP_400_BAD_REQUEST)

            inventory, _ = WarehouseInventory.objects.get_or_create(warehouse=warehouse, product=product)
            qty_old = inventory.quantity
            qty_new = qty_old

            if m_type == StockMovement.Type.IN:
                qty_new += qty
            elif m_type == StockMovement.Type.OUT:
                qty_new -= qty
            elif m_type == StockMovement.Type.ADJUST:
                qty_new += qty
            elif m_type == StockMovement.Type.RETURN:
                qty_new += qty
            elif m_type == StockMovement.Type.TRANSFER:
                return self._normal_transfer(request, data, warehouse, product, inventory, qty_old, qty)

            inventory.quantity = qty_new
            inventory.save()

            StockMovement.objects.create(
                warehouse=warehouse, product=product,
                movement_type=m_type, reason=data.get('reason', ''),
                quantity_old=qty_old, quantity_new=qty_new,
                created_by=request.user, reference_no=data.get('reference_no', ''),
                returned_by=data.get('returned_by', '') if m_type == StockMovement.Type.RETURN else None
            )

        return Response({'status': 'Stock adjusted', 'new_quantity': str(qty_new)})

    # ─── Serial number stock adjustment ───
    @action(detail=False, methods=['post'], url_path='serial-adjust')
    def serial_adjust_stock(self, request):
        data = request.data
        warehouse_id = data.get('warehouse_id')
        product_id = data.get('product_id')
        m_type = data.get('movement_type')
        serial_number_value = (data.get('serial_number') or '').strip()

        if not all([warehouse_id, product_id, m_type]):
            return Response({'error': 'warehouse_id, product_id, movement_type tələb olunur'}, status=status.HTTP_400_BAD_REQUEST)

        if not serial_number_value:
            return Response({'error': 'serial_number tələb olunur'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            warehouse = Warehouse.objects.get(pk=warehouse_id)
            product = Product.objects.get(pk=product_id)

            if not product.has_serial_number:
                return Response({'error': 'Bu məhsul serial nömrəli deyil. /adjust/ endpoint istifadə edin.'}, status=status.HTTP_400_BAD_REQUEST)

            inventory, _ = WarehouseInventory.objects.get_or_create(warehouse=warehouse, product=product)
            qty_old = inventory.quantity

            if m_type == StockMovement.Type.TRANSFER:
                return self._serial_transfer(request, data, warehouse, product, inventory, qty_old, serial_number_value)

            if m_type in [StockMovement.Type.IN, StockMovement.Type.RETURN, StockMovement.Type.ADJUST]:
                if SerialNumberItem.objects.filter(serial_number=serial_number_value).exists():
                    return Response({'error': f'Bu serial nömrə artıq mövcuddur: {serial_number_value}'}, status=status.HTTP_400_BAD_REQUEST)
                SerialNumberItem.objects.create(product=product, warehouse=warehouse, serial_number=serial_number_value)
                qty_new = qty_old + 1

            elif m_type == StockMovement.Type.OUT:
                try:
                    item = SerialNumberItem.objects.get(serial_number=serial_number_value, product=product, warehouse=warehouse)
                    item.delete()
                    qty_new = qty_old - 1
                except SerialNumberItem.DoesNotExist:
                    return Response({'error': f'Bu serial nömrə bu anbarda tapılmadı: {serial_number_value}'}, status=status.HTTP_400_BAD_REQUEST)
            else:
                return Response({'error': 'Dəstəklənməyən əməliyyat növü'}, status=status.HTTP_400_BAD_REQUEST)

            inventory.quantity = qty_new
            inventory.save()

            StockMovement.objects.create(
                warehouse=warehouse, product=product,
                movement_type=m_type, reason=data.get('reason', ''),
                quantity_old=qty_old, quantity_new=qty_new,
                created_by=request.user, reference_no=data.get('reference_no', ''),
                serial_number=serial_number_value,
                returned_by=data.get('returned_by', '') if m_type == StockMovement.Type.RETURN else None
            )

        return Response({'status': 'Serial stock adjusted', 'new_quantity': str(qty_new), 'serial_number': serial_number_value})

    # ─── Transfer helpers ───
    def _normal_transfer(self, request, data, warehouse, product, inventory, qty_old, qty):
        to_wh_id = data.get('to_warehouse_id')
        if not to_wh_id:
            return Response({'error': 'Hədəf anbar tələb olunur'}, status=status.HTTP_400_BAD_REQUEST)

        to_warehouse = Warehouse.objects.get(pk=to_wh_id)
        inventory.quantity = qty_old - qty
        inventory.save()

        to_inventory, _ = WarehouseInventory.objects.get_or_create(warehouse=to_warehouse, product=product)
        to_qty_old = to_inventory.quantity
        to_inventory.quantity = to_qty_old + qty
        to_inventory.save()

        StockMovement.objects.create(
            warehouse=warehouse, to_warehouse=to_warehouse, product=product,
            movement_type=StockMovement.Type.TRANSFER, reason=f"Transfer OUT → {to_warehouse.name}",
            quantity_old=qty_old, quantity_new=inventory.quantity,
            created_by=request.user, reference_no=data.get('reference_no', '')
        )
        StockMovement.objects.create(
            warehouse=to_warehouse, from_warehouse=warehouse, product=product,
            movement_type=StockMovement.Type.TRANSFER, reason=f"Transfer IN ← {warehouse.name}",
            quantity_old=to_qty_old, quantity_new=to_inventory.quantity,
            created_by=request.user, reference_no=data.get('reference_no', '')
        )
        return Response({'status': 'Transfer successful'})

    def _serial_transfer(self, request, data, warehouse, product, inventory, qty_old, serial_number_value):
        to_wh_id = data.get('to_warehouse_id')
        if not to_wh_id:
            return Response({'error': 'Hədəf anbar tələb olunur'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            item = SerialNumberItem.objects.get(serial_number=serial_number_value, product=product, warehouse=warehouse)
        except SerialNumberItem.DoesNotExist:
            return Response({'error': f'Bu serial nömrə bu anbarda tapılmadı: {serial_number_value}'}, status=status.HTTP_400_BAD_REQUEST)

        to_warehouse = Warehouse.objects.get(pk=to_wh_id)
        item.warehouse = to_warehouse
        item.save()

        inventory.quantity = qty_old - 1
        inventory.save()

        to_inventory, _ = WarehouseInventory.objects.get_or_create(warehouse=to_warehouse, product=product)
        to_qty_old = to_inventory.quantity
        to_inventory.quantity = to_qty_old + 1
        to_inventory.save()

        StockMovement.objects.create(
            warehouse=warehouse, to_warehouse=to_warehouse, product=product,
            movement_type=StockMovement.Type.TRANSFER, reason=f"Transfer OUT → {to_warehouse.name}",
            quantity_old=qty_old, quantity_new=inventory.quantity,
            created_by=request.user, reference_no=data.get('reference_no', ''),
            serial_number=serial_number_value
        )
        StockMovement.objects.create(
            warehouse=to_warehouse, from_warehouse=warehouse, product=product,
            movement_type=StockMovement.Type.TRANSFER, reason=f"Transfer IN ← {warehouse.name}",
            quantity_old=to_qty_old, quantity_new=to_inventory.quantity,
            created_by=request.user, reference_no=data.get('reference_no', ''),
            serial_number=serial_number_value
        )
        return Response({'status': 'Serial transfer successful', 'serial_number': serial_number_value})
