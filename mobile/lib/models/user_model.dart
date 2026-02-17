class User {
  final int id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? avatar;
  final bool isTaskReader;
  final bool isTaskWriter;
  final bool isDocumentReader;
  final bool isDocumentWriter;
  final bool isWarehouseReader;
  final bool isWarehouseWriter;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.avatar,
    this.isTaskReader = false,
    this.isTaskWriter = false,
    this.isDocumentReader = false,
    this.isDocumentWriter = false,
    this.isWarehouseReader = false,
    this.isWarehouseWriter = false,
  });

  String get fullName {
    final name = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return name.isNotEmpty ? name : email;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      avatar: json['avatar'],
      isTaskReader: json['is_task_reader'] ?? false,
      isTaskWriter: json['is_task_writer'] ?? false,
      isDocumentReader: json['is_document_reader'] ?? false,
      isDocumentWriter: json['is_document_writer'] ?? false,
      isWarehouseReader: json['is_warehouse_reader'] ?? false,
      isWarehouseWriter: json['is_warehouse_writer'] ?? false,
    );
  }
}
