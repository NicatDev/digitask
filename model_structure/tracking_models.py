class UserLocation(models.Model):
    """
    İstifadəçinin SON location-u (current/last known).
    Tez-tez oxunacağı üçün ayrıca saxlayırıq.
    """
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="current_location")

    # GeoJSON kimi də saxlamaq olar, amma sadə saxlayırıq
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)

    accuracy_m = models.PositiveIntegerField(null=True, blank=True)  # metr
    speed_m_s = models.DecimalField(max_digits=8, decimal_places=3, null=True, blank=True)
    heading_deg = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)  # kompas istiqaməti

    provider = models.CharField(max_length=30, blank=True)  # gps/network/fused və s.
    is_active = models.BooleanField(default=True)  # user paylaşımı söndürəndə false edə bilərsən

    # hansı group kontekstində paylaşır (opsional; 1 user bir neçə group-da ola bilər)
    # Bu sahə “məcburi deyil”. İstəsən sil.
    group = models.ForeignKey(RegionGroup, on_delete=models.PROTECT, null=True, blank=True, related_name="live_locations")

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["updated_at"]),
            models.Index(fields=["group", "updated_at"]),
        ]

    def __str__(self):
        return f"{self.user_id}: {self.latitude},{self.longitude}"


class UserLocationPing(models.Model):
    """
    History (telemetriya). Çox data ola bilər.
    İstəsən retention policy (məs: 30 gün) tətbiq edərsən.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="location_pings")

    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)

    accuracy_m = models.PositiveIntegerField(null=True, blank=True)
    speed_m_s = models.DecimalField(max_digits=8, decimal_places=3, null=True, blank=True)
    heading_deg = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)

    provider = models.CharField(max_length=30, blank=True)

    # cihaz/app məlumatları (opsional)
    device_id = models.CharField(max_length=80, blank=True)
    app_version = models.CharField(max_length=30, blank=True)

    # bu ping hansı group kontekstində gəlib (opsional)
    group = models.ForeignKey(RegionGroup, on_delete=models.PROTECT, null=True, blank=True, related_name="location_pings")

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "created_at"]),
            models.Index(fields=["group", "created_at"]),
            models.Index(fields=["created_at"]),
        ]

    def __str__(self):
        return f"{self.user_id} @ {self.created_at}"