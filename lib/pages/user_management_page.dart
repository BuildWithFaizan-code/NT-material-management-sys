import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../layout/widgets/modern_navbar_theme.dart';
import '../services/auth_service.dart';
import '../services/user_management_service.dart';
import 'add_edit_user_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<UserManagementItem> _users = [];
  List<UserManagementItem> _filteredUsers = [];

  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_users);
      } else {
        _filteredUsers = _users.where((u) {
          final username = u.username.toLowerCase();
          final email = u.email.toLowerCase();
          final role = (u.roleName ?? (u.isAdmin ? 'Admin' : 'No Role')).toLowerCase();
          return username.contains(query) || email.contains(query) || role.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await UserManagementService.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = list;
        _isLoading = false;
      });
      _onSearchChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load users: $e';
      });
    }
  }

  Future<void> _navigateToAddUser() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditUserPage()),
    );
    if (result == true && mounted) {
      _loadUsers();
    }
  }

  Future<void> _navigateToEditUser(UserManagementItem user) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditUserPage(user: user)),
    );
    if (result == true && mounted) {
      _loadUsers();
    }
  }

  Future<void> _toggleUserStatus(UserManagementItem user) async {
    final currentAdminId = AuthService.instance.currentUser?.userId;
    if (user.userId == currentAdminId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot change your own status.')),
      );
      return;
    }

    final newStatus = !user.isActive;
    try {
      await UserManagementService.setUserStatus(
        userId: user.userId,
        isActive: newStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User "${user.username}" has been ${newStatus ? "activated" : "suspended"}.',
          ),
          backgroundColor: newStatus ? AppColors.success : Colors.orange.shade800,
        ),
      );
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _confirmDeleteUser(UserManagementItem user) async {
    final currentAdminId = AuthService.instance.currentUser?.userId;
    if (user.userId == currentAdminId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot delete your own administrative account.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Text(
          'Are you sure you want to permanently remove "${user.username}" (${user.email})? '
          'All active sessions for this account will be revoked immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete User'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await UserManagementService.deleteUser(user.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User "${user.username}" has been removed.'),
              backgroundColor: AppColors.primaryColor,
            ),
          );
          _loadUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete user: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Never';
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildTopHeaderBar(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                                    const SizedBox(height: 12),
                                    Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                                    const SizedBox(height: 12),
                                    FilledButton(
                                      onPressed: _loadUsers,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            : _buildMainDataGrid(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeaderBar() {
    final totalCount = _users.length;
    final activeCount = _users.where((u) => u.isActive).length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.manage_accounts_outlined, color: AppColors.primaryColor, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Management',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    '$totalCount registered ($activeCount active)',
                    style: const TextStyle(color: AppColors.slateMuted, fontSize: 11.5),
                  ),
                ],
              ),
              const SizedBox(width: 24),

              // Search Bar
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ModernNavbarTheme.cardBorder),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by username, email, or role...',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.slateMuted),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.slateMuted),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Add User Button
              FilledButton.icon(
                onPressed: _navigateToAddUser,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                label: const Text('Add User'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainDataGrid() {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchCtrl.text.isEmpty
                  ? 'No users registered yet.'
                  : 'No users matching "${_searchCtrl.text}".',
              style: const TextStyle(color: AppColors.slateMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ModernNavbarTheme.cardBorder),
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Username', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primaryColor))),
                  Expanded(flex: 4, child: Text('Email Address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primaryColor))),
                  Expanded(flex: 3, child: Text('Role', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primaryColor))),
                  Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primaryColor))),
                  Expanded(flex: 3, child: Text('Last Login', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primaryColor))),
                  Expanded(flex: 2, child: Center(child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primaryColor)))),
                ],
              ),
            ),
            const Divider(height: 1),

            // Table Rows
            Expanded(
              child: ListView.separated(
                itemCount: _filteredUsers.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  final formattedLastLogin = _formatDate(user.lastLoginAt);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        // Username
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                                child: Text(
                                  user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppColors.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  user.username,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Email
                        Expanded(
                          flex: 4,
                          child: Text(
                            user.email,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.bodyText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Role
                        Expanded(
                          flex: 3,
                          child: user.isAdmin
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.purple.shade200),
                                    ),
                                    child: Text(
                                      'Super Admin',
                                      style: TextStyle(color: Colors.purple.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              : Text(
                                  user.roleName ?? 'No Role Assigned',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: user.roleName != null ? AppColors.bodyText : Colors.grey,
                                    fontStyle: user.roleName != null ? FontStyle.normal : FontStyle.italic,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),

                        // Status Badge
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: user.isActive ? AppColors.successLight : AppColors.errorLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: user.isActive ? AppColors.successBorder : AppColors.errorBorder,
                                ),
                              ),
                              child: Text(
                                user.isActive ? 'Active' : 'Suspended',
                                style: TextStyle(
                                  color: user.isActive ? AppColors.successDark : AppColors.errorDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Last Login
                        Expanded(
                          flex: 3,
                          child: Text(
                            formattedLastLogin,
                            style: const TextStyle(fontSize: 12, color: AppColors.slateMuted),
                          ),
                        ),

                        // Actions
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Edit
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryColor),
                                tooltip: 'Edit User & Permissions',
                                onPressed: () => _navigateToEditUser(user),
                              ),
                              // Suspend / Activate
                              IconButton(
                                icon: Icon(
                                  user.isActive ? Icons.block_outlined : Icons.check_circle_outline,
                                  size: 18,
                                  color: user.isActive ? Colors.orange.shade800 : AppColors.success,
                                ),
                                tooltip: user.isActive ? 'Suspend User' : 'Activate User',
                                onPressed: () => _toggleUserStatus(user),
                              ),
                              // Remove
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                tooltip: 'Remove User',
                                onPressed: () => _confirmDeleteUser(user),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
