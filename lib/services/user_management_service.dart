import '../config/api_config.dart';
import 'api_client.dart';

class UserManagementItem {
  final int userId;
  final String username;
  final String email;
  final bool isActive;
  final bool isAdmin;
  final int? roleId;
  final String? roleName;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  UserManagementItem({
    required this.userId,
    required this.username,
    required this.email,
    required this.isActive,
    required this.isAdmin,
    this.roleId,
    this.roleName,
    this.lastLoginAt,
    required this.createdAt,
  });

  factory UserManagementItem.fromJson(Map<String, dynamic> json) {
    return UserManagementItem(
      userId: json['userId'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      isAdmin: json['isAdmin'] as bool? ?? false,
      roleId: json['roleId'] as int?,
      roleName: json['roleName'] as String?,
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Service handling User Management operations.
/// Follows established conventions and routes exclusively through ApiClient.instance.
class UserManagementService {
  static final String _baseUrl = '${ApiConfig.baseUrl}/usermanagement/users';

  static Future<List<UserManagementItem>> fetchUsers() async {
    final response = await ApiClient.instance.get(_baseUrl);
    final body = ApiClient.instance.decodeResponse(response);
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((u) => UserManagementItem.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  static Future<UserManagementItem> fetchUserById(int userId) async {
    final response = await ApiClient.instance.get('$_baseUrl/$userId');
    final body = ApiClient.instance.decodeResponse(response);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return UserManagementItem.fromJson(data);
  }

  static Future<UserManagementItem> createUser({
    required String username,
    required String email,
    String? password,
    int? roleId,
    bool isAdmin = false,
  }) async {
    final response = await ApiClient.instance.post(
      _baseUrl,
      body: {
        'username': username.trim(),
        'email': email.trim(),
        if (password != null && password.isNotEmpty) 'password': password,
        'roleId': roleId,
        'isAdmin': isAdmin,
      },
    );
    final body = ApiClient.instance.decodeResponse(response);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return UserManagementItem.fromJson(data);
  }

  static Future<UserManagementItem> updateUser({
    required int userId,
    required String email,
    int? roleId,
    bool? isActive,
  }) async {
    final response = await ApiClient.instance.put(
      '$_baseUrl/$userId',
      body: {
        'email': email.trim(),
        'roleId': roleId,
        'isActive': ?isActive,
      },
    );
    final body = ApiClient.instance.decodeResponse(response);
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return UserManagementItem.fromJson(data);
  }

  static Future<bool> setUserStatus({
    required int userId,
    required bool isActive,
  }) async {
    final response = await ApiClient.instance.patch(
      '${ApiConfig.baseUrl}/usermanagement/users/$userId/status',
      body: isActive,
    );
    final body = ApiClient.instance.decodeResponse(response);
    return body['data'] as bool? ?? false;
  }

  static Future<bool> deleteUser(int userId) async {
    final response = await ApiClient.instance.delete('$_baseUrl/$userId');
    final body = ApiClient.instance.decodeResponse(response);
    return body['success'] as bool? ?? true;
  }
}
