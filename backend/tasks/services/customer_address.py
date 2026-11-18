"""Müştəri ünvanı yoxlaması — tapşırığı tamamlamazdan əvvəl ünvan (xəritədə yer) mütləqdir."""
from rest_framework import status
from rest_framework.exceptions import APIException

CUSTOMER_ADDRESS_REQUIRED_CODE = "customer_address_required"
CUSTOMER_ADDRESS_REQUIRED_MESSAGE = (
    "Müştəri ünvanını daxil etmədən tapşırığı tamamlamaq mümkün deyil. "
    "Əvvəlcə müştəri ünvanını əlavə edin."
)


class CustomerAddressRequired(APIException):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = CUSTOMER_ADDRESS_REQUIRED_CODE

    def __init__(self):
        super().__init__(
            detail={
                "detail": CUSTOMER_ADDRESS_REQUIRED_MESSAGE,
                "code": CUSTOMER_ADDRESS_REQUIRED_CODE,
            }
        )


def customer_has_address(customer):
    """Ünvan sayılır: xəritədə koordinat (lat + lng) qeyd olunub."""
    if customer is None:
        return False
    coords = customer.address_coordinates or {}
    if not isinstance(coords, dict):
        return False
    return coords.get("lat") not in (None, "") and coords.get("lng") not in (None, "")


def ensure_customer_address_for_done(customer):
    if not customer_has_address(customer):
        raise CustomerAddressRequired()
