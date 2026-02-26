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

    @action(detail=False, methods=['post'], url_path='adjust')
    def adjust_stock(self, request):
        data = request.data
        warehouse_id = data.get('warehouse_id')
        product_id = data.get('product_id')
        m_type = data.get('movement_type')
        serial_number_value = data.get('serial_number', '').strip()
        
        if not all([warehouse_id, product_id, m_type]):
            return Response({'error': 'Missing required fields'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            warehouse = Warehouse.objects.get(pk=warehouse_id)
            product = Product.objects.get(pk=product_id)
            
            inventory, created = WarehouseInventory.objects.get_or_create(
                warehouse=warehouse, product=product
            )
            
            qty_old = inventory.quantity

            # ─── Serial Nömrəli Məhsullar ───
            if product.has_serial_number:
                if m_type == StockMovement.Type.TRANSFER:
                    return self._handle_serial_transfer(
                        request, data, warehouse, product, inventory, qty_old, serial_number_value
                    )
                
                if not serial_number_value:
                    return Response({'error': 'Serial nömrə tələb olunur'}, status=status.HTTP_400_BAD_REQUEST)
                
                if m_type in [StockMovement.Type.IN, StockMovement.Type.RETURN]:
                    # Check uniqueness
                    if SerialNumberItem.objects.filter(serial_number=serial_number_value).exists():
                        return Response(
                            {'error': f'Bu serial nömrə artıq mövcuddur: {serial_number_value}'},
                            status=status.HTTP_400_BAD_REQUEST
                        )
                    SerialNumberItem.objects.create(
                        product=product, warehouse=warehouse, serial_number=serial_number_value
                    )
                    qty_new = qty_old + 1
                
                elif m_type == StockMovement.Type.OUT:
                    try:
                        item = SerialNumberItem.objects.get(
                            serial_number=serial_number_value, product=product, warehouse=warehouse
                        )
                        item.delete()
                        qty_new = qty_old - 1
                    except SerialNumberItem.DoesNotExist:
                        return Response(
                            {'error': f'Bu serial nömrə bu anbarda tapılmadı: {serial_number_value}'},
                            status=status.HTTP_400_BAD_REQUEST
                        )
                
                elif m_type == StockMovement.Type.ADJUST:
                    # For serial products, adjust can add or remove
                    if not SerialNumberItem.objects.filter(serial_number=serial_number_value).exists():
                        SerialNumberItem.objects.create(
                            product=product, warehouse=warehouse, serial_number=serial_number_value
                        )
                        qty_new = qty_old + 1
                    else:
                        return Response(
                            {'error': f'Bu serial nömrə artıq mövcuddur: {serial_number_value}'},
                            status=status.HTTP_400_BAD_REQUEST
                        )
                else:
                    return Response({'error': 'Dəstəklənməyən əməliyyat növü'}, status=status.HTTP_400_BAD_REQUEST)
                
                inventory.quantity = qty_new
                inventory.save()
                
                StockMovement.objects.create(
                    warehouse=warehouse,
                    product=product,
                    movement_type=m_type,
                    reason=data.get('reason', ''),
                    quantity_old=qty_old,
                    quantity_new=qty_new,
                    created_by=request.user,
                    reference_no=data.get('reference_no', ''),
                    serial_number=serial_number_value,
                    returned_by=data.get('returned_by', '') if m_type == StockMovement.Type.RETURN else None
                )
                
                return Response({'status': 'Stock adjusted', 'new_quantity': str(qty_new)})

            # ─── Normal Məhsullar (serial nömrəsiz) ───
            qty = Decimal(str(data.get('quantity', 0)))
            if not qty:
                return Response({'error': 'Miqdar tələb olunur'}, status=status.HTTP_400_BAD_REQUEST)
            
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
                return self._handle_normal_transfer(
                    request, data, warehouse, product, inventory, qty_old, qty
                )
            
            inventory.quantity = qty_new
            inventory.save()

            StockMovement.objects.create(
                warehouse=warehouse,
                product=product,
                movement_type=m_type,
                reason=data.get('reason', ''),
                quantity_old=qty_old,
                quantity_new=qty_new,
                created_by=request.user,
                reference_no=data.get('reference_no', ''),
                returned_by=data.get('returned_by', '') if m_type == StockMovement.Type.RETURN else None
            )

        return Response({'status': 'Stock adjusted', 'new_quantity': str(qty_new)})

    def _handle_serial_transfer(self, request, data, warehouse, product, inventory, qty_old, serial_number_value):
        """Transfer a serial-numbered item between warehouses."""
        to_wh_id = data.get('to_warehouse_id')
        if not to_wh_id:
            return Response({'error': 'Hədəf anbar tələb olunur'}, status=status.HTTP_400_BAD_REQUEST)
        if not serial_number_value:
            return Response({'error': 'Serial nömrə tələb olunur'}, status=status.HTTP_400_BAD_REQUEST)
        
        to_warehouse = Warehouse.objects.get(pk=to_wh_id)
        
        try:
            item = SerialNumberItem.objects.get(
                serial_number=serial_number_value, product=product, warehouse=warehouse
            )
        except SerialNumberItem.DoesNotExist:
            return Response(
                {'error': f'Bu serial nömrə bu anbarda tapılmadı: {serial_number_value}'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Move item to destination warehouse
        item.warehouse = to_warehouse
        item.save()
        
        # Update source inventory
        inventory.quantity = qty_old - 1
        inventory.save()
        
        # Update destination inventory
        to_inventory, _ = WarehouseInventory.objects.get_or_create(warehouse=to_warehouse, product=product)
        to_qty_old = to_inventory.quantity
        to_inventory.quantity = to_qty_old + 1
        to_inventory.save()
        
        # Create movement records
        StockMovement.objects.create(
            warehouse=warehouse, to_warehouse=to_warehouse, product=product,
            movement_type=StockMovement.Type.TRANSFER,
            reason=f"Transfer OUT to {to_warehouse.name}",
            quantity_old=qty_old, quantity_new=inventory.quantity,
            created_by=request.user, reference_no=data.get('reference_no', ''),
            serial_number=serial_number_value
        )
        StockMovement.objects.create(
            warehouse=to_warehouse, from_warehouse=warehouse, product=product,
            movement_type=StockMovement.Type.TRANSFER,
            reason=f"Transfer IN from {warehouse.name}",
            quantity_old=to_qty_old, quantity_new=to_inventory.quantity,
            created_by=request.user, reference_no=data.get('reference_no', ''),
            serial_number=serial_number_value
        )
        
        return Response({'status': 'Transfer successful'})

    def _handle_normal_transfer(self, request, data, warehouse, product, inventory, qty_old, qty):
        """Transfer a normal (non-serial) product between warehouses."""
        to_wh_id = data.get('to_warehouse_id')
        if not to_wh_id:
            return Response({'error': 'Hədəf anbar tələb olunur'}, status=status.HTTP_400_BAD_REQUEST)
        
        to_warehouse = Warehouse.objects.get(pk=to_wh_id)
        
        # Source
        inventory.quantity = qty_old - qty
        inventory.save()
        
        # Destination
        to_inventory, _ = WarehouseInventory.objects.get_or_create(warehouse=to_warehouse, product=product)
        to_qty_old = to_inventory.quantity
        to_inventory.quantity = to_qty_old + qty
        to_inventory.save()
        
        StockMovement.objects.create(
            warehouse=warehouse, to_warehouse=to_warehouse, product=product,
            movement_type=StockMovement.Type.TRANSFER,
            reason=f"Transfer OUT to {to_warehouse.name}",
            quantity_old=qty_old, quantity_new=inventory.quantity,
            created_by=request.user, reference_no=data.get('reference_no', '')
        )
        StockMovement.objects.create(
            warehouse=to_warehouse, from_warehouse=warehouse, product=product,
            movement_type=StockMovement.Type.TRANSFER,
            reason=f"Transfer IN from {warehouse.name}",
            quantity_old=to_qty_old, quantity_new=to_inventory.quantity,
            created_by=request.user, reference_no=data.get('reference_no', '')
        )
        
        return Response({'status': 'Transfer successful'})
