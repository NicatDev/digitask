from rest_framework import viewsets, status, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from django.db import transaction
from decimal import Decimal
from ..models import Warehouse, Product, WarehouseInventory, StockMovement
from ..serializers import (
    WarehouseInventorySerializer,
    StockMovementSerializer
)
from .common import StandardResultsSetPagination

class WarehouseInventoryViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = WarehouseInventory.objects.all()
    serializer_class = WarehouseInventorySerializer
    pagination_class = StandardResultsSetPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    search_fields = ['product__name', 'warehouse__name']
    filterset_fields = ['warehouse', 'product']

class StockMovementViewSet(viewsets.ModelViewSet):
    queryset = StockMovement.objects.all().order_by('-created_at')
    serializer_class = StockMovementSerializer
    pagination_class = StandardResultsSetPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['product__name', 'warehouse__name', 'reference_no', 'reason']
    filterset_fields = ['warehouse', 'product', 'movement_type', 'created_by']

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)

    @action(detail=False, methods=['post'], url_path='adjust')
    def adjust_stock(self, request):
        data = request.data
        warehouse_id = data.get('warehouse_id')
        product_id = data.get('product_id')
        qty = Decimal(str(data.get('quantity', 0)))
        m_type = data.get('movement_type')
        
        if not all([warehouse_id, product_id, qty, m_type]):
            return Response({'error': 'Missing required fields'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            warehouse = Warehouse.objects.get(pk=warehouse_id)
            product = Product.objects.get(pk=product_id)
            
            inventory, created = WarehouseInventory.objects.get_or_create(
                warehouse=warehouse, product=product
            )
            
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
                reference_no=data.get('reference_no', '')
            )
            
            if m_type == StockMovement.Type.TRANSFER:
                to_wh_id = data.get('to_warehouse_id')
                if not to_wh_id:
                     # This check should probably return a response or raise a DRF ValidationError properly
                     return Response({'error': "Target warehouse required for transfer"}, status=status.HTTP_400_BAD_REQUEST)
                
                to_warehouse = Warehouse.objects.get(pk=to_wh_id)
                to_inventory, _ = WarehouseInventory.objects.get_or_create(
                    warehouse=to_warehouse, product=product
                )
                
                # Correct Transfer Logic:
                # 1. Source (Warehouse) -> Already decreased by base logic (treated as OUT essentially or delta applied)
                # wait, in my original code:
                # if m_type == TRANSFER:
                #   inventory.quantity = qty_old - qty 
                #   I overwrote the adjustment.
                
                # Let's fix logical consistency from previous file.
                # In previous file, I did generic mix, then overwrote for Transfer.
                # Here I should just do it cleanly.

                # Let's clean up logic:
                # Revert the generic change for Transfer to avoid double accounting or confusion, 
                # OR handle it specifically.
                
                # Actually, let's keep it simple. Only apply generic logic if NOT transfer, or handle transfer completely separately.
                # But to preserve existing behavior:
                
                # Reset source inventory change from generic block if it was wrong?
                # Generic block: 
                # elif m_type == StockMovement.Type.ADJUST: ...
                # Wait, TRANSFER wasn't in the generic block in previous code?
                # Ah, I missed 'TRANSFER' case in logic block above in previous file?
                # No, I didn't have TRANSFER in the if/elif chain for `qty_new` calculation in the view I just pasted.
                # Wait, looking at `views.py` I read earlier:
                # if m_type == IN ... elif OUT ... elif ADJUST ... elif RETURN
                # It didn't handle TRANSFER in the generic `qty_new` calculation!
                # So `qty_new` remained `qty_old` for transfer in that block.
                # Then `inventory.quantity = qty_new` saved it as unchanged.
                # THEN in `if m_type == TRANSFER`: it did `inventory.quantity = qty_old - qty` and saved.
                
                # So, I should explicitly handle TRANSFER in the if/elif chain or leave it as is.
                # I will create a cleaner version here.
                pass

            # RETHINKING LOGIC FOR CLEANER IMPLEMENTATION IN REFACTOR
            # If Transfer:
            # Source: -qty
            # Dest: +qty
            
            if m_type == StockMovement.Type.TRANSFER:
                 # Source
                 inventory.quantity = qty_old - qty
                 inventory.save()

                 to_wh_id = data.get('to_warehouse_id')
                 if not to_wh_id:
                      raise ValueError("Target warehouse required")

                 to_warehouse = Warehouse.objects.get(pk=to_wh_id)
                 to_inventory, _ = WarehouseInventory.objects.get_or_create(warehouse=to_warehouse, product=product)
                 
                 to_qty_old = to_inventory.quantity
                 to_inventory.quantity = to_qty_old + qty
                 to_inventory.save()
                 
                 # Create 2 records? One OUT from source, One IN to dest. Or 1 Record with from/to?
                 # My model has from/to fields.
                 # Usually 2 records are better for localized history in each warehouse tab.
                 # Creating Record 1 (OUT equivalent)
                 StockMovement.objects.create(
                    warehouse=warehouse,
                    to_warehouse=to_warehouse,
                    product=product,
                    movement_type=StockMovement.Type.TRANSFER,
                    reason=f"Transfer OUT to {to_warehouse.name}",
                    quantity_old=qty_old,
                    quantity_new=inventory.quantity,
                    created_by=request.user,
                    reference_no=data.get('reference_no', '')
                 )
                 # Record 2 (IN equivalent)
                 StockMovement.objects.create(
                    warehouse=to_warehouse,
                    from_warehouse=warehouse,
                    product=product,
                    movement_type=StockMovement.Type.TRANSFER,
                    reason=f"Transfer IN from {warehouse.name}",
                    quantity_old=to_qty_old,
                    quantity_new=to_inventory.quantity,
                    created_by=request.user,
                    reference_no=data.get('reference_no', '')
                 )
                 
                 return Response({'status': 'Transfer successful'})

        return Response({'status': 'Stock adjusted', 'new_quantity': qty_new})
