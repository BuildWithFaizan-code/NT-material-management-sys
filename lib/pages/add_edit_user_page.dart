import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../layout/widgets/modern_navbar_theme.dart';
import '../services/api_client.dart';
import '../services/role_service.dart';
import '../services/user_management_service.dart';

class AddEditUserPage extends StatefulWidget {
  final UserManagementItem? user;

  const AddEditUserPage({super.key, this.user});

  @override
  State<AddEditUserPage> createState() => _AddEditUserPageState();
}

class _AddEditUserPageState extends State<AddEditUserPage> {
  int _currentStep = 1;

  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _newRoleNameCtrl = TextEditingController();

  // Role state
  List<RoleItem> _roles = [];
  int? _selectedRoleId;
  bool _isCreatingNewRole = false;
  int _affectedUserCount = 0;

  // Matrix state
  List<ModuleItem> _modules = [];
  List<ActionItem> _actions = [];
  // moduleId -> Set of actionIds
  final Map<int, Set<int>> _selectedPermissions = {};

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initUserData();
    _loadMetadata();
  }

  void _initUserData() {
    if (widget.user != null) {
      _usernameCtrl.text = widget.user!.username;
      _emailCtrl.text = widget.user!.email;
      _selectedRoleId = widget.user!.roleId;
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _newRoleNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        RoleService.fetchRoles(),
        RoleService.fetchMatrixMetadata(),
      ]);

      final roles = results[0] as List<RoleItem>;
      final metadata = results[1] as MatrixMetadata;

      if (!mounted) return;

      setState(() {
        _roles = roles;
        _modules = metadata.modules;
        _actions = metadata.actions;
        _isLoading = false;
      });

      // If editing existing user with a role, load that role's permissions
      if (_selectedRoleId != null) {
        await _loadRolePermissions(_selectedRoleId!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load configuration: $e';
      });
    }
  }

  Future<void> _loadRolePermissions(int roleId) async {
    try {
      final details = await RoleService.fetchRolePermissions(roleId);
      if (!mounted) return;
      setState(() {
        _affectedUserCount = details.userCount;
        _selectedPermissions.clear();
        for (final p in details.permissions) {
          _selectedPermissions.putIfAbsent(p.moduleId, () => <int>{}).add(p.actionId);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load role permissions: $e')),
      );
    }
  }

  int get _totalSelectedCount {
    return _selectedPermissions.values.fold(0, (acc, set) => acc + set.length);
  }

  int get _maxPossibleCount => _modules.length * _actions.length;

  bool _isActionSelected(int moduleId, int actionId) {
    return _selectedPermissions[moduleId]?.contains(actionId) ?? false;
  }

  void _toggleAction(int moduleId, int actionId, bool? value) {
    setState(() {
      final set = _selectedPermissions.putIfAbsent(moduleId, () => <int>{});
      if (value == true) {
        set.add(actionId);
      } else {
        set.remove(actionId);
      }
    });
  }

  void _toggleRow(int moduleId, bool? value) {
    setState(() {
      final set = _selectedPermissions.putIfAbsent(moduleId, () => <int>{});
      if (value == true) {
        for (final a in _actions) {
          set.add(a.actionId);
        }
      } else {
        set.clear();
      }
    });
  }

  bool _isRowAllSelected(int moduleId) {
    final set = _selectedPermissions[moduleId];
    if (set == null || set.isEmpty) return false;
    return _actions.every((a) => set.contains(a.actionId));
  }

  void _toggleColumn(int actionId, bool? value) {
    setState(() {
      for (final m in _modules) {
        final set = _selectedPermissions.putIfAbsent(m.moduleId, () => <int>{});
        if (value == true) {
          set.add(actionId);
        } else {
          set.remove(actionId);
        }
      }
    });
  }

  bool _isColumnAllSelected(int actionId) {
    if (_modules.isEmpty) return false;
    return _modules.every((m) => _selectedPermissions[m.moduleId]?.contains(actionId) ?? false);
  }

  void _selectAll() {
    setState(() {
      for (final m in _modules) {
        final set = _selectedPermissions.putIfAbsent(m.moduleId, () => <int>{});
        for (final a in _actions) {
          set.add(a.actionId);
        }
      }
    });
  }

  void _clearAll() {
    setState(() {
      _selectedPermissions.clear();
    });
  }

  Future<void> _saveUserAndPermissions() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final List<RolePermissionPair> permissionPairs = [];
      _selectedPermissions.forEach((moduleId, actionIds) {
        for (final actionId in actionIds) {
          permissionPairs.add(RolePermissionPair(moduleId: moduleId, actionId: actionId));
        }
      });

      int? finalRoleId = _selectedRoleId;

      // 1. Create new role if requested
      if (_isCreatingNewRole) {
        final roleName = _newRoleNameCtrl.text.trim();
        if (roleName.isEmpty) {
          throw ApiException('New role name is required.');
        }

        final newRole = await RoleService.createRole(
          roleName: roleName,
          permissions: permissionPairs,
        );
        finalRoleId = newRole.roleId;
      } else if (finalRoleId != null) {
        // 2. Update existing role matrix
        await RoleService.updateRolePermissions(
          roleId: finalRoleId,
          permissions: permissionPairs,
        );
      }

      // 3. Create or update user
      if (widget.user == null) {
        await UserManagementService.createUser(
          username: _usernameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.isNotEmpty ? _passwordCtrl.text : null,
          roleId: finalRoleId,
        );
      } else {
        await UserManagementService.updateUser(
          userId: widget.user!.userId,
          email: _emailCtrl.text.trim(),
          roleId: finalRoleId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.user == null
                  ? 'User created successfully with assigned permissions.'
                  : 'User and permissions updated successfully.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.user != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
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
                child: Column(
                  children: [
                    _buildHeader(isEditing),
                    _buildStepIndicator(),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage != null
                              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                              : _currentStep == 1
                                  ? _buildStepOneContent(isEditing)
                                  : _buildStepTwoContent(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: ModernNavbarTheme.cardBorder, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primaryColor),
            tooltip: 'Back to Users',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit User & Permissions' : 'Create New User',
                style: const TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isEditing
                    ? 'Update user account credentials and customize role permissions'
                    : 'Provision new account and configure Master module permission matrix',
                style: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          if (_currentStep == 2)
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveUserAndPermissions,
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 16),
              label: Text(_isSaving ? 'Saving...' : 'Save User & Permissions'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: ModernNavbarTheme.cardBorder, width: 1)),
      ),
      child: Row(
        children: [
          _StepItem(
            stepNumber: 1,
            label: 'User & Role Details',
            isActive: _currentStep == 1,
            isCompleted: _currentStep > 1,
            onTap: () => setState(() => _currentStep = 1),
          ),
          const SizedBox(width: 24),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
          const SizedBox(width: 24),
          _StepItem(
            stepNumber: 2,
            label: 'Permission Matrix (17 Modules)',
            isActive: _currentStep == 2,
            isCompleted: false,
            onTap: () {
              if (_formKey.currentState?.validate() ?? false) {
                setState(() => _currentStep = 2);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepOneContent(bool isEditing) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
                ),
                const SizedBox(height: 16),

                // Username
                TextFormField(
                  controller: _usernameCtrl,
                  enabled: !isEditing,
                  decoration: InputDecoration(
                    labelText: 'Username *',
                    hintText: 'e.g. john_doe',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Username is required';
                    if (val.trim().length < 3) return 'Username must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email Address *',
                    hintText: 'e.g. user@domain.com',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Email is required';
                    if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password (only for new users)
                if (!isEditing) ...[
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Initial Password (leave empty for auto-generated)',
                      hintText: 'Min. 8 characters',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'User will be prompted to change their password upon first login.',
                    style: TextStyle(fontSize: 11, color: AppColors.slateMuted),
                  ),
                  const SizedBox(height: 24),
                ],

                const Divider(height: 32),
                const Text(
                  'Role Assignment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select an existing role to adopt its permissions, or create a brand new role.',
                  style: TextStyle(fontSize: 12, color: AppColors.slateMuted),
                ),
                const SizedBox(height: 16),

                // Role Selector Radio / Toggle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ModernNavbarTheme.cardBorder),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _isCreatingNewRole = false),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                !_isCreatingNewRole ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: !_isCreatingNewRole ? AppColors.primaryColor : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Assign Existing Role', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                    Text('Reuses an established permissions template', style: TextStyle(fontSize: 11.5, color: AppColors.slateMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 12),
                      InkWell(
                        onTap: () => setState(() => _isCreatingNewRole = true),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              Icon(
                                _isCreatingNewRole ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: _isCreatingNewRole ? AppColors.primaryColor : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('+ Create New Role on the Fly', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                    Text('Define a unique role and build its matrix in Step 2', style: TextStyle(fontSize: 11.5, color: AppColors.slateMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (!_isCreatingNewRole) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _selectedRoleId,
                    decoration: InputDecoration(
                      labelText: 'Select Role *',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                    ),
                    items: _roles.map((r) {
                      return DropdownMenuItem<int>(
                        value: r.roleId,
                        child: Text('${r.roleName} (${r.userCount} assigned)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedRoleId = val;
                      });
                      if (val != null) {
                        _loadRolePermissions(val);
                      }
                    },
                    validator: (val) {
                      if (!_isCreatingNewRole && val == null) {
                        return 'Please select a role';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  TextFormField(
                    controller: _newRoleNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'New Role Name *',
                      hintText: 'e.g. Warehouse Inventory Specialist',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    ),
                    validator: (val) {
                      if (_isCreatingNewRole && (val == null || val.trim().isEmpty)) {
                        return 'Role name is required';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 36),

                // Next button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        setState(() => _currentStep = 2);
                      }
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Next: Configure Permissions (Step 2) →', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepTwoContent() {
    final hasAffectedUsers = !_isCreatingNewRole && _selectedRoleId != null && _affectedUserCount > 0;

    return Column(
      children: [
        // Warning Banner for shared role edit
        if (hasAffectedUsers)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.amber.shade50,
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Changes here affect every user currently assigned to this role ($_affectedUserCount user(s) currently assigned).',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Matrix Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: ModernNavbarTheme.cardBorder, width: 1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_totalSelectedCount of $_maxPossibleCount permissions selected',
                  style: const TextStyle(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _selectAll,
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('Select All'),
                style: TextButton.styleFrom(foregroundColor: AppColors.success),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              ),
            ],
          ),
        ),

        // Matrix Grid Table
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: ModernNavbarTheme.cardBorder),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildMatrixHeader(),
                    const Divider(height: 1),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _modules.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final module = _modules[index];
                        return _buildMatrixRow(module);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom navigation bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: ModernNavbarTheme.cardBorder, width: 1)),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _currentStep = 1),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('← Back to Step 1'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveUserAndPermissions,
                icon: _isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(_isSaving ? 'Saving...' : 'Save User & Permissions'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatrixHeader() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            flex: 4,
            child: Text(
              'Master Module',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primaryColor),
            ),
          ),
          ..._actions.map((action) {
            final isAllSelected = _isColumnAllSelected(action.actionId);
            return Expanded(
              flex: 2,
              child: InkWell(
                onTap: () => _toggleColumn(action.actionId, !isAllSelected),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: isAllSelected,
                      activeColor: AppColors.primaryColor,
                      onChanged: (val) => _toggleColumn(action.actionId, val),
                    ),
                    Text(
                      action.actionName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }),
          const Expanded(
            flex: 2,
            child: Center(
              child: Text(
                'Row All',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.slateMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixRow(ModuleItem module) {
    final isRowAll = _isRowAllSelected(module.moduleId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 16, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    module.moduleName,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          ..._actions.map((action) {
            final isChecked = _isActionSelected(module.moduleId, action.actionId);
            return Expanded(
              flex: 2,
              child: Center(
                child: Checkbox(
                  value: isChecked,
                  activeColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) => _toggleAction(module.moduleId, action.actionId, val),
                ),
              ),
            );
          }),
          Expanded(
            flex: 2,
            child: Center(
              child: Checkbox(
                value: isRowAll,
                activeColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) => _toggleRow(module.moduleId, val),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int stepNumber;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final VoidCallback onTap;

  const _StepItem({
    required this.stepNumber,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color circleBg = isActive
        ? AppColors.primaryColor
        : (isCompleted ? AppColors.success : Colors.grey.shade300);
    final Color textColor = isActive ? AppColors.primaryColor : Colors.grey.shade700;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: circleBg, shape: BoxShape.circle),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '$stepNumber',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
