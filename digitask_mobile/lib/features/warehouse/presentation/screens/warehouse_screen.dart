import 'package:flutter/material.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Anbarlar'),
              Tab(text: 'Məhsullar'),
              Tab(text: 'Tarixçə'),
            ],
          ),
        ),
        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWarehousesList(),
              _buildProductsList(),
              _buildHistoryList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarehousesList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWarehouseCard('Anbar 1', 'Bakı, Nərimanov', 45, Colors.green),
        _buildWarehouseCard('Anbar 2', 'Bakı, Nəsimi', 32, Colors.orange),
        _buildWarehouseCard('Anbar 3', 'Sumqayıt', 78, Colors.blue),
      ],
    );
  }

  Widget _buildWarehouseCard(String name, String address, int products, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.warehouse, color: color),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(address),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$products məhsul',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProductCard('Router', 'Şəbəkə', 120, 'ədəd'),
        _buildProductCard('Kabel', 'Material', 500, 'metr'),
        _buildProductCard('Modem', 'Şəbəkə', 85, 'ədəd'),
        _buildProductCard('Switch', 'Şəbəkə', 34, 'ədəd'),
      ],
    );
  }

  Widget _buildProductCard(String name, String category, int quantity, String unit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.inventory_2, color: Colors.blue),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(category),
        trailing: Text(
          '$quantity $unit',
          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHistoryCard('Router çıxış', 'Anbar 1 → Tapşırıq #45', '01 Feb', false),
        _buildHistoryCard('Kabel giriş', 'Təchizatçı → Anbar 2', '31 Yan', true),
        _buildHistoryCard('Modem çıxış', 'Anbar 1 → Tapşırıq #42', '30 Yan', false),
      ],
    );
  }

  Widget _buildHistoryCard(String title, String description, String date, bool isIncoming) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isIncoming ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncoming ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(description),
        trailing: Text(
          date,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ),
    );
  }
}
