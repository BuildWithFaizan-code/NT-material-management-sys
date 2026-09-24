import 'package:flutter/material.dart';
import '../../design/app_dimensions.dart';
import 'master_nav_item.dart';
import 'transaction_nav_item.dart';
import 'modern_navbar_theme.dart';
import '../../services/auth_service.dart';

class Sidebar extends StatelessWidget {
  final int currentIndex;
  final String activeSubItem;
  final String activeTransactionSubItem;
  final ValueChanged<int> onItemSelected;
  final ValueChanged<String>? onSubItemSelected;
  final ValueChanged<String>? onTransactionSubItemSelected;
  final VoidCallback onToggle;
  final bool isOpen;

  const Sidebar({
    super.key,
    required this.currentIndex,
    this.activeSubItem = '',
    this.activeTransactionSubItem = '',
    required this.onItemSelected,
    this.onSubItemSelected,
    this.onTransactionSubItemSelected,
    required this.onToggle,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        width: AppDimensions.sidebarWidth,
        decoration: BoxDecoration(
          color: ModernNavbarTheme.cardBg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: ModernNavbarTheme.cardBorder,
            width: 1,
          ),
          boxShadow: ModernNavbarTheme.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 4),
              // Scrollable menu list with hidden scrollbar
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    scrollbars: false,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: _buildMenuItems(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 4-pointed Sparkle Logo from reference
          const SizedBox(
            width: 14,
            height: 14,
            child: CustomPaint(
              painter: FourPointSparklePainter(color: ModernNavbarTheme.sparkle),
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            'Menu',
            style: TextStyle(
              color: ModernNavbarTheme.sparkle,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          // Collapse button
          _ModernToggleBtn(onTap: onToggle),
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Index 0: Dashboard (Home)
        _ModernSidebarItem(
          icon: Icons.home_outlined,
          label: 'Dashboard',
          selected: currentIndex == 0,
          onTap: () {
            onItemSelected(0);
          },
        ),
        const SizedBox(height: 2),

        // Index 1: Master (Expandable Dropdown Accordion)
        MasterNavItem(
          isMasterSelected: currentIndex == 1,
          activeSubItem: activeSubItem,
          onMasterHeaderTap: () {
            if (activeSubItem.isEmpty) {
              final auth = AuthService.instance;
              final isAdmin = (auth.currentUser?.isAdmin ?? false) ||
                  (auth.myPermissions?.isAdmin ?? false);
              final perms = auth.myPermissions;
              String defaultModule = 'Project Master';
              if (!isAdmin && perms != null) {
                final permitted = masterSubSections
                    .where((s) => perms.canViewModule(s.title))
                    .toList();
                if (permitted.isNotEmpty) {
                  defaultModule = permitted.first.title;
                }
              }
              onSubItemSelected?.call(defaultModule);
            }
            onItemSelected(1);
          },
          onSubItemSelected: (subTitle) {
            onSubItemSelected?.call(subTitle);
            onItemSelected(1);
          },
        ),
        const SizedBox(height: 2),

        // Index 2: Transaction (Expandable Dropdown Accordion)
        TransactionNavItem(
          isTransactionSelected: currentIndex == 2,
          activeSubItem: activeTransactionSubItem,
          onTransactionHeaderTap: () {
            if (activeTransactionSubItem.isEmpty) {
              onTransactionSubItemSelected?.call('Bill of Material (BOM)');
            }
            onItemSelected(2);
          },
          onSubItemSelected: (subTitle) {
            onTransactionSubItemSelected?.call(subTitle);
            onItemSelected(2);
          },
        ),
        const SizedBox(height: 2),

        // Index 3: Reports
        _ModernSidebarItem(
          icon: Icons.bar_chart_rounded,
          label: 'Reports',
          selected: currentIndex == 3,
          onTap: () {
            onItemSelected(3);
          },
        ),
        const SizedBox(height: 2),

        // Index 4: Box Register
        _ModernSidebarItem(
          icon: Icons.all_inbox_outlined,
          label: 'Box Register',
          selected: currentIndex == 4,
          onTap: () {
            onItemSelected(4);
          },
        ),
        const SizedBox(height: 2),

        // Index 5: Tools
        _ModernSidebarItem(
          icon: Icons.handyman_outlined,
          label: 'Tools',
          selected: currentIndex == 5,
          onTap: () {
            onItemSelected(5);
          },
        ),
        const SizedBox(height: 2),

        // Index 6: Live Updates
        _ModernSidebarItem(
          icon: Icons.update_rounded,
          label: 'Live Updates',
          selected: currentIndex == 6,
          onTap: () {
            onItemSelected(6);
          },
        ),
        const SizedBox(height: 2),

        // Index 7: Download
        _ModernSidebarItem(
          icon: Icons.download_outlined,
          label: 'Download',
          selected: currentIndex == 7,
          onTap: () {
            onItemSelected(7);
          },
        ),
        // Index 8: User Management (Admin Only)
        // NOTE: Hiding this nav item is a UX convenience only. Real enforcement is the
        // backend PermissionAuthorizationFilter and [Authorize(Policy = "AdminOnly")].
        if (AuthService.instance.currentUser?.isAdmin ?? false) ...[
          const SizedBox(height: 2),
          _ModernSidebarItem(
            icon: Icons.manage_accounts_outlined,
            label: 'User Management',
            selected: currentIndex == 8,
            onTap: () {
              onItemSelected(8);
            },
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// MODERN TOGGLE BUTTON (MINIMALIST CHEVRON / CLOSE)
// ============================================================================
class _ModernToggleBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _ModernToggleBtn({required this.onTap});

  @override
  State<_ModernToggleBtn> createState() => _ModernToggleBtnState();
}

class _ModernToggleBtnState extends State<_ModernToggleBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _hover ? ModernNavbarTheme.hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(
              Icons.chevron_left_rounded,
              color: ModernNavbarTheme.inactiveFg,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODERN SIDEBAR ITEM (BLACK PILL ACTIVE, MUTED INACTIVE)
// ============================================================================
class _ModernSidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModernSidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ModernSidebarItem> createState() => _ModernSidebarItemState();
}

class _ModernSidebarItemState extends State<_ModernSidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? ModernNavbarTheme.activePillBg
                : (_hover
                    ? ModernNavbarTheme.hoverBg
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: isSelected
                    ? ModernNavbarTheme.activePillFg
                    : ModernNavbarTheme.inactiveIcon,
                size: 16,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: isSelected
                        ? ModernNavbarTheme.activePillFg
                        : ModernNavbarTheme.inactiveFg,
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
