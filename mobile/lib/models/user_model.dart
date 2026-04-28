class User {
  final int id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? avatar;
  final bool isTaskReader;
  final bool isTaskWriter;
  final bool isTaskViewAll;
  final bool isDocumentReader;
  final bool isDocumentWriter;
  final bool isWarehouseReader;
  final bool isWarehouseWriter;
  final bool isAdmin;
  final bool isSuperAdmin;
  final Map<String, bool> taskPermissions;
  final Map<String, dynamic> taskStatusVisibility;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.avatar,
    this.isTaskReader = false,
    this.isTaskWriter = false,
    this.isTaskViewAll = false,
    this.isDocumentReader = false,
    this.isDocumentWriter = false,
    this.isWarehouseReader = false,
    this.isWarehouseWriter = false,
    this.isAdmin = false,
    this.isSuperAdmin = false,
    this.taskPermissions = const {},
    this.taskStatusVisibility = const {},
  });

  String get fullName {
    final name = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return name.isNotEmpty ? name : email;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final rawTaskPermissions = (json['task_permissions'] is Map)
        ? (json['task_permissions'] as Map)
        : const {};
    final parsedTaskPermissions = <String, bool>{};
    rawTaskPermissions.forEach((key, value) {
      parsedTaskPermissions[key.toString()] = value == true;
    });

    return User(
      id: json['id'],
      email: json['email'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      avatar: json['avatar'],
      isTaskReader: json['is_task_reader'] ?? false,
      isTaskWriter: json['is_task_writer'] ?? false,
      isTaskViewAll: json['is_task_view_all'] ?? false,
      isDocumentReader: json['is_document_reader'] ?? false,
      isDocumentWriter: json['is_document_writer'] ?? false,
      isWarehouseReader: json['is_warehouse_reader'] ?? false,
      isWarehouseWriter: json['is_warehouse_writer'] ?? false,
      isAdmin: json['is_admin'] ?? false,
      isSuperAdmin: json['is_super_admin'] ?? false,
      taskPermissions: parsedTaskPermissions,
      taskStatusVisibility: (json['task_status_visibility'] is Map)
          ? Map<String, dynamic>.from(json['task_status_visibility'])
          : const {},
    );
  }

  bool hasTaskAction(String action) {
    final dynamic val = taskPermissions[action];
    if (val is bool) return val;

    // Backward-compatible fallback
    switch (action) {
      case 'create':
      case 'edit_general':
      case 'delete':
      case 'toggle_active':
      case 'manage_assignees':
      case 'edit_customer_address':
        return isTaskWriter;
      case 'change_status':
      case 'manage_products':
      case 'manage_documents':
      case 'manage_surveys':
      case 'join_task':
      case 'comment_activity':
      case 'view_module':
        return isTaskReader || isTaskWriter;
      case 'view_all_statuses':
        return isTaskViewAll;
      default:
        return false;
    }
  }
}
