import '../config/api_config.dart';
import 'api_client.dart';

class RoleItem {
  final int roleId;
  final String roleName;
  final int? createdBy;
  final DateTime createdAt;
  final int userCount;

  RoleItem({
    required this.roleId,
    required this.roleName,
    this.createdBy,
    required this.createdAt,
    required this.userCount,
  });

  factory RoleItem.fromJson(Map<String, dynamic> json) {
    return RoleItem(
      roleId: json['roleId'] as int? ?? 0,
      roleName: json['roleName'] as String? ?? '',
      createdBy: json['createdBy'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      userCount: json['userCount'] as int? ?? 0,
    );
  }
}

class ModuleItem {
  final int moduleId;
  final String moduleName;
  final String moduleGroup;
  final String controllerName;

  ModuleItem({
    required this.moduleId,
    required this.moduleName,
    required this.moduleGroup,
    required this.controllerName,
  });

  factory ModuleItem.fromJson(Map<String, dynamic> json) {
    return ModuleItem(
      moduleId: json['moduleId'] as int? ?? 0,
      moduleName: json['moduleName'] as String? ?? '',
      moduleGroup: json['moduleGroup'] as String? ?? '',
      controllerName: json['controllerName'] as String? ?? '',
    );
  }
}

class ActionItem {
  final int actionId;
  final String actionName;
  final String httpVerb;

  ActionItem({
    required this.actionId,
    required this.actionName,
    required this.httpVerb,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      actionId: json['actionId'] as int? ?? 0,
      actionName: json['actionName'] as String? ?? '',
      httpVerb: json['httpVerb'] as String? ?? '',
    );
  }
}

class RolePermissionPair {
  final int moduleId;
  final int actionId;

  const RolePermissionPair({
    required this.moduleId,
    required this.actionId,
  });

  Map<String, dynamic> toJson() => {
    'moduleId': moduleId,
    'actionId': actionId,
  };

  factory RolePermissionPair.fromJson(Map<String, dynamic> json) {
    return RolePermissionPair(
      moduleId: json['moduleId'] as int? ?? 0,
      actionId: json['actionId'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RolePermissionPair &&
          runtimeType == other.runtimeType &&
          moduleId == other.moduleId &&
          actionId == other.actionId;

  @override
  int get hashCode => Object.hash(moduleId, actionId);
}

class RoleDetails {
  final int roleId;
  final String roleName;
  final int userCount;
  final List<RolePermissionPair> permissions;

  RoleDetails({
    required this.roleId,
    required this.roleName,
    required this.userCount,
    required this.permissions,
  });

  factory RoleDetails.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['permissions'] as List<dynamic>? ?? [];
    return RoleDetails(
      roleId: json['roleId'] as int? ?? 0,
      roleName: json['roleName'] as String? ?? '',
      userCount: json['userCount'] as int? ?? 0,
      permissions: rawPerms
          .map((p) => RolePermissionPair.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MatrixMetadata {
  final List<ModuleItem> modules;
  final List<ActionItem> actions;

  MatrixMetadata({
    required this.modules,
    required this.actions,
  });

  factory MatrixMetadata.fromJson(Map<String, dynamic> json) {
    final rawModules = json['modules'] as List<dynamic>? ?? [];
    final rawActions = json['actions'] as List<dynamic>? ?? [];
    return MatrixMetadata(
      modules: rawModules
          .map((m) => ModuleItem.fromJson(m as Map<String, dynamic>))
          .toList(),
      actions: rawActions
          .map((a) => ActionItem.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Service handling Role and Permission API operations.
/// Exclusively routes through ApiClient.instance (no raw http calls).
class RoleService {
  static final String _rolesBaseUrl = '${ApiConfig.baseUrl}/roles';

  static Future<List<RoleItem>> fetchRoles() async {
    final response = await ApiClient.instance.get(_rolesBaseUrl);
    final body = ApiClient.instance.decodeResponse(response);
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((r) => RoleItem.fromJson(r as Map<String, dynamic>)).toList();
  }

  static Future<MatrixMetadata> fetchMatrixMetadata() async {
    final response = await ApiClient.instance.get('$_rolesBaseUrl/matrix-metadata');
    final body = ApiClient.instance.decodeResponse(response);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return MatrixMetadata.fromJson(data);
  }

  static Future<RoleDetails> fetchRolePermissions(int roleId) async {
    final response = await ApiClient.instance.get('$_rolesBaseUrl/$roleId/permissions');
    final body = ApiClient.instance.decodeResponse(response);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return RoleDetails.fromJson(data);
  }

  static Future<RoleItem> createRole({
    required String roleName,
    required List<RolePermissionPair> permissions,
  }) async {
    final response = await ApiClient.instance.post(
      _rolesBaseUrl,
      body: {
        'roleName': roleName.trim(),
        'permissions': permissions.map((p) => p.toJson()).toList(),
      },
    );
    final body = ApiClient.instance.decodeResponse(response);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return RoleItem.fromJson(data);
  }

  static Future<bool> updateRolePermissions({
    required int roleId,
    String? roleName,
    required List<RolePermissionPair> permissions,
  }) async {
    final response = await ApiClient.instance.put(
      '$_rolesBaseUrl/$roleId/permissions',
      body: {
        if (roleName != null) 'roleName': roleName.trim(),
        'permissions': permissions.map((p) => p.toJson()).toList(),
      },
    );
    final body = ApiClient.instance.decodeResponse(response);
    return body['data'] as bool? ?? false;
  }

  static Future<bool> deleteRole(int roleId) async {
    final response = await ApiClient.instance.delete('$_rolesBaseUrl/$roleId');
    final body = ApiClient.instance.decodeResponse(response);
    return body['success'] as bool? ?? true;
  }
}
