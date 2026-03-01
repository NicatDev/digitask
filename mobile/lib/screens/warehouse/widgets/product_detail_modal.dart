import 'package:flutter/material.dart';
import 'package:mobile/models/product.dart';

class ProductDetailModal extends StatelessWidget {
  final Product product;

  const ProductDetailModal({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      if (product.hasSerialNumber) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                          child: const Text('SN', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 24),

            if (product.categoryName != null)
              _row('Kateqoriya', product.categoryName!),
            if (product.brand != null && product.brand!.isNotEmpty)
              _row('Brend', product.brand!),
            if (product.model != null && product.model!.isNotEmpty)
              _row('Model', product.model!),
            _row('Vahid', product.unitDisplay ?? product.unit),
            _row('Stok', product.hasSerialNumber
                ? '${product.displaySerialCount} ədəd'
                : '${product.displayStock.toStringAsFixed(2)} ${product.unit}'),
            if (product.price != null)
              _row('Qiymət', '${product.price!.toStringAsFixed(2)} ₼'),
            if (product.size != null && product.size!.isNotEmpty)
              _row('Ölçü', product.size!),
            if (product.weight != null && product.weight!.isNotEmpty)
              _row('Çəki', product.weight!),
            if (product.portCount != null)
              _row('Port sayı', product.portCount.toString()),
            if (product.minQuantity != null)
              _row('Min stok', product.minQuantity!.toStringAsFixed(2)),
            if (product.maxQuantity != null)
              _row('Max stok', product.maxQuantity!.toStringAsFixed(2)),
            _row('Status', product.isActive ? 'Aktiv' : 'Deaktiv'),

            // Category data (dynamic fields)
            if (product.categoryData != null && product.categoryData!.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Kateqoriya Məlumatları', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ...product.categoryData!.entries
                  .where((e) => e.value != null && e.value.toString().isNotEmpty)
                  .map((e) {
                    String displayVal;
                    if (e.value is bool) {
                      displayVal = e.value ? 'Bəli' : 'Xeyr';
                    } else {
                      displayVal = e.value.toString();
                    }
                    return _row(e.key, displayVal);
                  }),
            ],

            if (product.description != null && product.description!.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Təsvir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(product.description!, style: const TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
