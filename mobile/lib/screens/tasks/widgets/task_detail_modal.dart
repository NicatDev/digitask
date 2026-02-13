import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskDetailModal extends StatelessWidget {
  final Map<String, dynamic> task;

  const TaskDetailModal({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final createdAt = task['created_at'] != null
        ? dateFormat.format(DateTime.parse(task['created_at']))
        : '-';
    final updatedAt = task['updated_at'] != null
        ? dateFormat.format(DateTime.parse(task['updated_at']))
        : '-';

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      maxChildSize: 1.0,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        task['title'] ?? 'Tapşırıq',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle('Tapşırıq Məlumatları'),
                    _infoRow('Status', task['status_display'] ?? task['status'] ?? '-'),
                    _infoRow('Qeyd', task['note'] ?? '-'),
                    _infoRow('Təyin edilən', task['assigned_to_name'] ?? 'Təyin olunmayıb'),
                    _infoRow('Qrup', task['group_name'] ?? '-'),
                    _infoRow('Region', task['region_name'] ?? '-'),
                    _infoRow('Tapşırıq Tipi', task['task_type_details']?['name'] ?? '-'),
                    _infoRow('Yaradılma tarixi', createdAt),
                    _infoRow('Son yenilənmə', updatedAt),
                    _infoRow('Aktiv', task['is_active'] == true ? 'Bəli' : 'Xeyr'),
                    
                    const SizedBox(height: 16),
                    _sectionTitle('Müştəri Məlumatları'),
                    _infoRow('Ad', task['customer_name'] ?? '-'),
                    _infoRow('Ünvan', task['customer_address'] ?? '-'),
                    _infoRow('Telefon', task['customer_phone'] ?? '-'),
                    _infoRow('Qeydiyyat №', task['customer_register_number'] ?? '-'),
                    
                    // Services
                    if (task['task_services'] != null && (task['task_services'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionTitle('Xidmətlər'),
                      ..._buildServicesList(task['task_services']),
                    ],

                    // Products
                    if (task['task_products'] != null && (task['task_products'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionTitle('Məhsullar'),
                      ..._buildProductsList(task['task_products']),
                    ],

                    // Documents
                    if (task['task_documents'] != null && (task['task_documents'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionTitle('Sənədlər'),
                      ..._buildDocumentsList(task['task_documents']),
                    ],
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  List<Widget> _buildServicesList(List<dynamic> services) {
    return services.map<Widget>((s) {
      final serviceName = s['service_name'] ?? 'Xidmət';
      final note = s['note'] ?? '';
      final values = s['values'] as List<dynamic>? ?? [];
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (note.isNotEmpty) Text(note, style: const TextStyle(color: Colors.grey)),
              ...values.map((v) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${v['column_name'] ?? v['column_key'] ?? '-'}: ${v['value'] ?? '-'}'),
              )),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildProductsList(List<dynamic> products) {
    return products.map<Widget>((p) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(p['product_name'] ?? 'Məhsul'),
          subtitle: Text('Say: ${p['quantity'] ?? '-'}'),
        ),
      );
    }).toList();
  }

  List<Widget> _buildDocumentsList(List<dynamic> docs) {
    return docs.map<Widget>((d) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.attach_file),
          title: Text(d['name'] ?? 'Sənəd'),
          subtitle: Text(d['file'] ?? '-'),
        ),
      );
    }).toList();
  }
}
