import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design/app_colors.dart';
import '../services/auth_service.dart';
import '../services/user_management_service.dart';
import 'add_edit_user_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  // Active Tab Index:
  // 0: Manage Users
  // 1: Add User (or Edit User)
  // 2: Roles & Permissions (Upcoming)
  // 3: Activity Logs (Upcoming)
  int _activeTabIndex = 0;

  // Selected user for editing in Tab 1
  UserManagementItem? _editingUser;

  // Data state
  List<UserManagementItem> _users = [];
  List<UserManagementItem> _filteredUsers = [];

  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'ALL'; // 'ALL', 'ACTIVE', 'SUSPENDED'
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilters);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredUsers = _users.where((u) {
        // Status filter
        if (_statusFilter == 'ACTIVE' && !u.isActive) return false;
        if (_statusFilter == 'SUSPENDED' && u.isActive) return false;

        // Query filter
        if (query.isEmpty) return true;
        final username = u.username.toLowerCase();
        final email = u.email.toLowerCase();
        final role = (u.roleName ?? (u.isAdmin ? 'Admin' : 'No Role')).toLowerCase();
        return username.contains(query) || email.contains(query) || role.contains(query);
      }).toList();
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
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load users: $e';
      });
    }
  }

  void _startAddUser() {
    setState(() {
      _editingUser = null;
      _activeTabIndex = 1;
    });
  }

  void _startEditUser(UserManagementItem user) {
    setState(() {
      _editingUser = user;
      _activeTabIndex = 1;
    });
  }

  void _cancelUserForm() {
    setState(() {
      _editingUser = null;
      _activeTabIndex = 0;
    });
  }

  void _onUserFormSuccess() {
    setState(() {
      _editingUser = null;
      _activeTabIndex = 0;
    });
    _loadUsers();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Delete User Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently remove "${user.username}" (${user.email})?\n\n'
          'All active sessions for this account will be revoked immediately and permissions will be deleted.',
          style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete Permanently'),
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
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Page Title & Stats Header
                _buildPageHeader(),

                // 2. Browser Tab Bar (Matching Visual Language of Image 1)
                _buildBrowserTabBar(),

                // 3. Tab Body
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildCurrentTabContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // Top Page Title Header
  // ============================================================================
  Widget _buildPageHeader() {
    final totalCount = _users.length;
    final activeCount = _users.where((u) => u.isActive).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 16),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          // Left: Title and subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Management',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF0F172A),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Manage organization accounts, configure granular permissions, and inspect access policies.',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Right: Live Stats Counter Pills
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$activeCount Active',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 14, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 12),
                Text(
                  '$totalCount Total Accounts',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Refresh Button
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF475569)),
            tooltip: 'Refresh user list',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Browser Tab Bar (Matching Visual Language of Image 1)
  // ============================================================================
  Widget _buildBrowserTabBar() {
    final addTabLabel = _editingUser != null
        ? 'Edit User (${_editingUser!.username})'
        : 'Add User';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildBrowserTab(
            index: 0,
            label: 'Manage Users',
            icon: Icons.manage_accounts_outlined,
          ),
          const SizedBox(width: 6),
          _buildBrowserTab(
            index: 1,
            label: addTabLabel,
            icon: _editingUser != null ? Icons.edit_note_rounded : Icons.person_add_alt_1_outlined,
          ),
          const SizedBox(width: 6),
          _buildBrowserTab(
            index: 2,
            label: 'Roles & Permissions',
            icon: Icons.security_outlined,
            isPlaceholder: true,
          ),
          const SizedBox(width: 6),
          _buildBrowserTab(
            index: 3,
            label: 'Activity Logs',
            icon: Icons.history_toggle_off_rounded,
            isPlaceholder: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBrowserTab({
    required int index,
    required String label,
    required IconData icon,
    bool isPlaceholder = false,
  }) {
    final isActive = _activeTabIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          if (index == 1 && _editingUser != null && _activeTabIndex != 1) {
            // keep editingUser if clicking back to edit
          } else if (index == 1 && _activeTabIndex != 1) {
            _editingUser = null;
          }
          _activeTabIndex = index;
        });
      },
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: isActive
              ? Border(
                  top: const BorderSide(color: Color(0xFFC7D2FE), width: 1.5),
                  left: const BorderSide(color: Color(0xFFC7D2FE), width: 1.5),
                  right: const BorderSide(color: Color(0xFFC7D2FE), width: 1.5),
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 2.0,
                  ),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
              ),
            ),
            if (isPlaceholder) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Soon',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // Tab Content Switcher
  // ============================================================================
  Widget _buildCurrentTabContent() {
    switch (_activeTabIndex) {
      case 0:
        return _buildManageUsersTab();
      case 1:
        return _buildAddEditUserTab();
      case 2:
        return _buildRolesPermissionsPlaceholder();
      case 3:
        return _buildActivityLogsPlaceholder();
      default:
        return _buildManageUsersTab();
    }
  }

  // ============================================================================
  // Tab 0: Manage Users (Table View)
  // ============================================================================
  Widget _buildManageUsersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryColor),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Filter & Search Controls Bar
          _buildSearchAndFilterControls(),
          const SizedBox(height: 14),

          // User Table Data Grid
          Expanded(child: _buildUserTableGrid()),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search Input Field
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search by username, email, or role...',
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Status Filter Segment
          Row(
            children: [
              _buildFilterChip('ALL', 'All (${_users.length})'),
              const SizedBox(width: 6),
              _buildFilterChip('ACTIVE', 'Active (${_users.where((u) => u.isActive).length})'),
              const SizedBox(width: 6),
              _buildFilterChip('SUSPENDED', 'Suspended (${_users.where((u) => !u.isActive).length})'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _statusFilter == filterKey;

    return InkWell(
      onTap: () {
        setState(() {
          _statusFilter = filterKey;
          _applyFilters();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildUserTableGrid() {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded, size: 36, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            Text(
              _searchCtrl.text.isEmpty
                  ? 'No users registered yet.'
                  : 'No users matching "${_searchCtrl.text}".',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF475569),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Switch to the "Add User" tab to provision a new user account.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _startAddUser,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
              label: const Text('Add User'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(flex: 4, child: _buildTableHeaderText('User')),
                Expanded(flex: 4, child: _buildTableHeaderText('Email Address')),
                Expanded(flex: 3, child: _buildTableHeaderText('Role')),
                Expanded(flex: 2, child: _buildTableHeaderText('Status')),
                Expanded(flex: 3, child: _buildTableHeaderText('Last Login')),
                Expanded(flex: 2, child: Center(child: _buildTableHeaderText('Actions'))),
              ],
            ),
          ),

          // Table Rows
          Expanded(
            child: ListView.separated(
              itemCount: _filteredUsers.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                return _buildUserTableRow(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderText(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: const Color(0xFF475569),
        letterSpacing: 0.1,
      ),
    );
  }

  Widget _buildUserTableRow(UserManagementItem user) {
    final formattedLastLogin = _formatDate(user.lastLoginAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Row(
        children: [
          // 1. User Logo & Username
          Expanded(
            flex: 4,
            child: Row(
              children: [
                // Logo / Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: user.isAdmin
                          ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                          : [const Color(0xFF38BDF8), const Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (user.isAdmin ? const Color(0xFF6366F1) : const Color(0xFF2563EB))
                            .withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: user.isAdmin
                        ? const Icon(Icons.shield_rounded, size: 18, color: Colors.white)
                        : Text(
                            user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Username & Handle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '@${user.username.toLowerCase()}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Email Address
          Expanded(
            flex: 4,
            child: Text(
              user.email,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 3. Assigned Role
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: user.isAdmin
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFF7E22CE)),
                          const SizedBox(width: 4),
                          Text(
                            'Super Admin',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF7E22CE),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: user.roleName != null ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: user.roleName != null ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        user.roleName ?? 'No Role Assigned',
                        style: GoogleFonts.plusJakartaSans(
                          color: user.roleName != null ? const Color(0xFF4338CA) : const Color(0xFF64748B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
            ),
          ),

          // 4. Status Badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: user.isActive ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: user.isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: user.isActive ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.isActive ? 'Active' : 'Suspended',
                      style: GoogleFonts.plusJakartaSans(
                        color: user.isActive ? const Color(0xFF065F46) : const Color(0xFF9F1239),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Last Login
          Expanded(
            flex: 3,
            child: Text(
              formattedLastLogin,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ),

          // 6. Action Buttons
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Edit (Switches to Tab 1 with this user loaded)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4F46E5)),
                  tooltip: 'Edit User & Permissions',
                  onPressed: () => _startEditUser(user),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFEEF2FF),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                const SizedBox(width: 6),

                // Suspend / Activate
                IconButton(
                  icon: Icon(
                    user.isActive ? Icons.block_outlined : Icons.check_circle_outline_rounded,
                    size: 18,
                    color: user.isActive ? Colors.orange.shade800 : AppColors.success,
                  ),
                  tooltip: user.isActive ? 'Suspend Account' : 'Activate Account',
                  onPressed: () => _toggleUserStatus(user),
                  style: IconButton.styleFrom(
                    backgroundColor: (user.isActive ? Colors.orange : Colors.green).shade50,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                const SizedBox(width: 6),

                // Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  tooltip: 'Delete Account',
                  onPressed: () => _confirmDeleteUser(user),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Tab 1: Add / Edit User (Embedded Full Screen Tab)
  // ============================================================================
  Widget _buildAddEditUserTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AddEditUserPage(
        key: ValueKey(_editingUser?.userId ?? 'new_user_tab'),
        user: _editingUser,
        isEmbedded: true,
        onSuccess: _onUserFormSuccess,
        onCancel: _cancelUserForm,
      ),
    );
  }

  // ============================================================================
  // Tab 2: Roles & Permissions (Placeholder for upcoming instruction)
  // ============================================================================
  Widget _buildRolesPermissionsPlaceholder() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC7D2FE), width: 2),
              ),
              child: const Icon(Icons.security_rounded, size: 32, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 18),
            Text(
              'Roles & Permissions Management',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Coming in next update',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'This screen will allow configuring custom role hierarchies, permission inheritance, '
              'and bulk role assignments across master modules.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.5,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(() => _activeTabIndex = 0),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to Manage Users'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // Tab 3: Activity Logs (Placeholder for upcoming instruction)
  // ============================================================================
  Widget _buildActivityLogsPlaceholder() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFDE68A), width: 2),
              ),
              child: const Icon(Icons.history_toggle_off_rounded, size: 32, color: Color(0xFFD97706)),
            ),
            const SizedBox(height: 18),
            Text(
              'User Activity & Audit Trail',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Coming in next update',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'This screen will display real-time sign-in events, session revocations, '
              'and audit trail logs for all administrative account changes.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.5,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(() => _activeTabIndex = 0),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to Manage Users'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
