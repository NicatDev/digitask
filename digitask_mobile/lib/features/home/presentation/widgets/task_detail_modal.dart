import 'package:flutter/material.dart';

class TaskDetailModal extends StatelessWidget {
  final Map<String, dynamic> task;

  const TaskDetailModal({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final status = task['status']?.toString() ?? 'Unknown';
    final statusDisplay = task['status_display']?.toString() ?? status;
    
    // Task type details
    Map<String, dynamic>? taskTypeDetails;
    if (task['task_type_details'] is Map<String, dynamic>) {
      taskTypeDetails = task['task_type_details'] as Map<String, dynamic>;
    }

    // Status color
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'done':
      case 'completed':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.play_circle_filled;
        break;
      case 'todo':
      case 'pending':
        statusColor = const Color(0xFF3B82F6);
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    // Task type color
    Color taskTypeColor = const Color(0xFF2563EB);
    if (taskTypeDetails != null && taskTypeDetails['color'] != null) {
      final colorStr = taskTypeDetails['color'].toString().replaceAll('#', '');
      taskTypeColor = Color(int.tryParse('0xFF$colorStr') ?? 0xFF2563EB);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: taskTypeColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.task_alt, color: taskTypeColor, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task['title'] ?? 'Adsız tapşırıq',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (taskTypeDetails != null)
                                Text(
                                  taskTypeDetails['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: taskTypeColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Status: $statusDisplay',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    if (task['note'] != null && task['note'].toString().isNotEmpty) ...[
                      _buildSectionTitle('Qeyd'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          task['note'],
                          style: const TextStyle(fontSize: 15, height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Customer Info
                    _buildSectionTitle('Müştəri Məlumatları'),
                    const SizedBox(height: 12),
                    _buildInfoCard([
                      _buildInfoRow(Icons.person_outline, 'Ad', task['customer_name']?.toString()),
                      _buildInfoRow(Icons.location_on_outlined, 'Ünvan', task['customer_address']?.toString()),
                      _buildInfoRow(Icons.phone_outlined, 'Telefon', task['customer_phone']?.toString()),
                      _buildInfoRow(Icons.badge_outlined, 'Qeydiyyat №', task['customer_register_number']?.toString()),
                    ]),
                    const SizedBox(height: 24),

                    // Assignment Info
                    _buildSectionTitle('Təyinat'),
                    const SizedBox(height: 12),
                    _buildInfoCard([
                      _buildInfoRow(Icons.assignment_ind_outlined, 'Təyin edilən', task['assigned_to_name']?.toString()),
                      _buildInfoRow(Icons.group_outlined, 'Qrup', task['group_name']?.toString()),
                      _buildInfoRow(Icons.map_outlined, 'Region', task['region_name']?.toString()),
                    ]),
                    const SizedBox(height: 24),

                    // Services
                    if (task['task_services'] != null && (task['task_services'] as List).isNotEmpty) ...[
                      _buildSectionTitle('Xidmətlər'),
                      const SizedBox(height: 12),
                      ...((task['task_services'] as List).map((service) {
                        if (service is! Map<String, dynamic>) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.build_circle_outlined, color: Colors.blue),
                              const SizedBox(width: 12),
                              Text(
                                service['service_name'] ?? 'Xidmət',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      })),
                      const SizedBox(height: 24),
                    ],

                    // Products
                    if (task['task_products'] != null && (task['task_products'] as List).isNotEmpty) ...[
                      _buildSectionTitle('Məhsullar'),
                      const SizedBox(height: 12),
                      ...((task['task_products'] as List).map((product) {
                        if (product is! Map<String, dynamic>) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, color: Colors.green),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['product_name'] ?? 'Məhsul',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      '${product['quantity']} ${product['product_unit'] ?? ''}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if (product['is_deducted'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Çıxarılıb',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        );
                      })),
                      const SizedBox(height: 24),
                    ],

                    // Documents
                    if (task['task_documents'] != null && (task['task_documents'] as List).isNotEmpty) ...[
                      _buildSectionTitle('Sənədlər'),
                      const SizedBox(height: 12),
                      ...((task['task_documents'] as List).map((doc) {
                        if (doc is! Map<String, dynamic>) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.description_outlined, color: Colors.orange),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc['title'] ?? 'Sənəd',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    if (doc['shelf_name'] != null)
                                      Text(
                                        'Rəf: ${doc['shelf_name']}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                      ),
                                  ],
                                ),
                              ),
                              if (doc['confirmed'] == true)
                                const Icon(Icons.verified, color: Colors.green, size: 20),
                            ],
                          ),
                        );
                      })),
                      const SizedBox(height: 24),
                    ],

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Bağla'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: children.where((w) => w is! SizedBox).toList(),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
