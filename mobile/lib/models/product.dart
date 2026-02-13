class Product {
  final int id;
  final String name;
  final String? description;
  final String unit;
  final String? unitDisplay;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final int? portCount;
  final String? size;
  final String? weight;
  final double? price;
  final double? minQuantity;
  final double? maxQuantity;
  final double totalStock;
  final bool isActive;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.unit,
    this.unitDisplay,
    this.brand,
    this.model,
    this.serialNumber,
    this.portCount,
    this.size,
    this.weight,
    this.price,
    this.minQuantity,
    this.maxQuantity,
    this.totalStock = 0.0,
    required this.isActive,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      unit: json['unit'] ?? 'pcs',
      unitDisplay: json['unit_display'],
      brand: json['brand'],
      model: json['model'],
      serialNumber: json['serial_number'],
      portCount: json['port_count'],
      size: json['size'],
      weight: json['weight'],
      price: json['price'] != null ? double.tryParse(json['price'].toString()) : null,
      minQuantity: json['min_quantity'] != null ? double.tryParse(json['min_quantity'].toString()) : null,
      maxQuantity: json['max_quantity'] != null ? double.tryParse(json['max_quantity'].toString()) : null,
      totalStock: json['total_stock'] != null ? double.tryParse(json['total_stock'].toString()) ?? 0.0 : 0.0,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'unit': unit,
      'brand': brand,
      'model': model,
      'serial_number': serialNumber,
      'port_count': portCount,
      'size': size,
      'weight': weight,
      'price': price,
      'min_quantity': minQuantity,
      'max_quantity': maxQuantity,
      'is_active': isActive,
    };
  }
}
