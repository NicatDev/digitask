from .service import ServiceSerializer, ColumnSerializer
from .equipment import EquipmentSerializer, OpticBoxSerializer
from .customer import CustomerSerializer
from .task import (
    TaskSerializer,
    TaskServiceSerializer,
    TaskServiceValueSerializer,
    TaskStatusUpdateSerializer,
    TaskCustomerHistorySerializer,
)
from .task_activity import TaskActivitySerializer

from .product import TaskProductSerializer, TaskProductCreateSerializer
