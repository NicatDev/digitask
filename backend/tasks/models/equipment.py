from django.db import models


class Equipment(models.Model):
    """Avadanlıq — admin-managed list; optional on Customer."""

    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]
        verbose_name = "Avadanlıq"
        verbose_name_plural = "Avadanlıqlar"

    def __str__(self):
        return self.name


class OpticBox(models.Model):
    """Optik qutu — admin-managed list; optional on Customer."""

    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]
        verbose_name = "Optik qutu"
        verbose_name_plural = "Optik qutular"

    def __str__(self):
        return self.name
