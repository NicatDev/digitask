import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

const String kCustomerAddressRequiredCode = 'customer_address_required';
const String kCustomerAddressRequiredMessage =
    'Müştəri ünvanını daxil etmədən tapşırığı tamamlamaq mümkün deyil. '
    'Əvvəlcə müştəri ünvanını əlavə edin (tapşırıq kartındakı narıncı ünvan ikonu).';

/// Ünvan var sayılır: xəritədə koordinat (lat + lng) qeyd olunub.
bool hasCustomerAddress(Map<String, dynamic>? task) {
  final c = task?['customer_coordinates'];
  if (c is! Map) return false;
  final lat = c['lat'];
  final lng = c['lng'];
  return lat != null && lat.toString().isNotEmpty && lng != null && lng.toString().isNotEmpty;
}

/// Tapşırıq "done"-a keçirilir və müştərinin ünvanı yoxdur?
bool isBlockedDoneWithoutAddress(Map<String, dynamic>? task, String nextStatus) {
  return nextStatus == 'done' &&
      (task?['status']?.toString() ?? '') != 'done' &&
      !hasCustomerAddress(task);
}

bool isCustomerAddressRequiredError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['code']?.toString() == kCustomerAddressRequiredCode) return true;
  }
  return false;
}

Future<void> showCustomerAddressRequiredDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Müştəri ünvanı əlavə edilməlidir',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Bağla',
            onPressed: () => Navigator.of(ctx).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: const Text(kCustomerAddressRequiredMessage, style: TextStyle(fontSize: 15, height: 1.4)),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          child: const Text('Anladım'),
        ),
      ],
    ),
  );
}
