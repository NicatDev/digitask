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
  final Map<String, Map<String, bool>> taskStatusPermissions;

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
    this.taskStatusPermissions = const {},
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

    final parsedTaskStatusPermissions = <String, Map<String, bool>>{};
    if (json['task_status_permissions'] is Map) {
      (json['task_status_permissions'] as Map).forEach((statusKey, value) {
        final row = <String, bool>{};
        if (value is Map) {
          value.forEach((actionKey, actionVal) {
            row[actionKey.toString()] = actionVal == true;
          });
        }
        parsedTaskStatusPermissions[statusKey.toString()] = row;
      });
    }

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
      taskStatusPermissions: parsedTaskStatusPermissions,
    );
  }

  bool hasTaskAction(String action, {String? status}) {
    if (action == 'create' || action == 'view_module') {
      return taskPermissions[action] == true;
    }
    final visibleStatuses =
        (taskStatusVisibility['visible_statuses'] as List?)?.cast<dynamic>() ?? const [];
    if (status == null || status.isEmpty) return false;
    if (!visibleStatuses.contains(status)) return false;

    // Tapşırıq sənədləri: yalnız status üzrə icazə; qlobal sənəd yazıcı / task_permissions yox.
    if (action == 'manage_documents') {
      return taskStatusPermissions[status]?['manage_documents'] == true;
    }

    if (taskStatusPermissions[status]?[action] == true) return true;
    return taskPermissions[action] == true;
  }
}
