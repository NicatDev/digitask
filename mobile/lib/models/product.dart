class Product {
  final int id;
  final String name;
  final String? description;
  final String unit;
  final String? unitDisplay;
  final String? brand;
  final String? model;
  final bool hasSerialNumber;
  final int? portCount;
  final String? size;
  final String? weight;
  final double? price;
  final double? minQuantity;
  final double? maxQuantity;
  final double totalStock;
  final int serialCount;
  final int? category;
  final String? categoryName;
  final Map<String, dynamic>? customFields;
  final bool isActive;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.unit,
    this.unitDisplay,
    this.brand,
    this.model,
    this.hasSerialNumber = false,
    this.portCount,
    this.size,
    this.weight,
    this.price,
    this.minQuantity,
    this.maxQuantity,
    this.totalStock = 0.0,
    this.serialCount = 0,
    this.category,
    this.categoryName,
    this.customFields,
    required this.isActive,
  });

  /// The display stock: for serial products use serial_count, otherwise total_stock
  double get displayStock => hasSerialNumber ? serialCount.toDouble() : totalStock;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      unit: json['unit'] ?? 'pcs',
      unitDisplay: json['unit_display'],
      brand: json['brand'],
      model: json['model'],
      hasSerialNumber: json['has_serial_number'] ?? false,
      portCount: json['port_count'],
      size: json['size'],
      weight: json['weight'],
      price: json['price'] != null ? double.tryParse(json['price'].toString()) : null,
      minQuantity: json['min_quantity'] != null ? double.tryParse(json['min_quantity'].toString()) : null,
      maxQuantity: json['max_quantity'] != null ? double.tryParse(json['max_quantity'].toString()) : null,
      totalStock: json['total_stock'] != null ? double.tryParse(json['total_stock'].toString()) ?? 0.0 : 0.0,
      serialCount: json['serial_count'] ?? 0,
      category: json['category'],
      categoryName: json['category_name'],
      customFields: json['custom_fields'] is Map ? Map<String, dynamic>.from(json['custom_fields']) : null,
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
      'has_serial_number': hasSerialNumber,
      'port_count': portCount,
      'size': size,
      'weight': weight,
      'price': price,
      'min_quantity': minQuantity,
      'max_quantity': maxQuantity,
      'category': category,
      'custom_fields': customFields,
      'is_active': isActive,
    };
  }
}
