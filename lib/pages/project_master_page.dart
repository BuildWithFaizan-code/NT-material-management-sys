import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import '../design/app_colors.dart';
import '../services/project_service.dart';

// ============================================================================
// DATA MODEL: ProjectMaster
// ============================================================================
class ProjectMaster {
  final int prjCode;
  final String prjName;
  final String dateCreated;

  ProjectMaster({
    required this.prjCode,
    required this.prjName,
    String? dateCreated,
  }) : dateCreated = formatDisplayDate(dateCreated);

  static String formatDisplayDate(dynamic dateInput) {
    if (dateInput == null) {
      return _formatDateTime(DateTime.now());
    }
    if (dateInput is DateTime) {
      return _formatDateTime(dateInput);
    }
    final str = dateInput.toString().trim();
    if (str.isEmpty || str == '03 Aug 2026') {
      return _formatDateTime(DateTime.now());
    }
    final parsed = DateTime.tryParse(str);
    if (parsed != null) {
      return _formatDateTime(parsed);
    }
    return str;
  }

  static String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year.toString();
    return '$day $month $year';
  }

  factory ProjectMaster.fromJson(Map<String, dynamic> json) {
    return ProjectMaster(
      prjCode: json['prjCode'] is int
          ? json['prjCode']
          : (json['PrjCode'] is int
              ? json['PrjCode']
              : int.tryParse(json['prjCode']?.toString() ?? json['PrjCode']?.toString() ?? '0') ?? 0),
      prjName: json['prjName'] as String? ?? json['PrjName'] as String? ?? '',
      dateCreated: formatDisplayDate(json['dateCreated'] ?? json['DateCreated']),
    );
  }

  Map<String, dynamic> toJson() => {
        'prjCode': prjCode,
        'prjName': prjName,
        'dateCreated': dateCreated,
      };

  ProjectMaster copyWith({
    int? prjCode,
    String? prjName,
    String? dateCreated,
  }) {
    return ProjectMaster(
      prjCode: prjCode ?? this.prjCode,
      prjName: prjName ?? this.prjName,
      dateCreated: dateCreated ?? this.dateCreated,
    );
  }
}

// ============================================================================
// MAIN PAGE: ProjectMasterPage (Compact, Spaced & Refined)
// ============================================================================
class ProjectMasterPage extends StatefulWidget {
  final ProjectService? projectService;
  const ProjectMasterPage({super.key, this.projectService});

  @override
  State<ProjectMasterPage> createState() => _ProjectMasterPageState();
}

class _ProjectMasterPageState extends State<ProjectMasterPage> {
  late final ProjectService _projectService;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<ProjectMaster> _projects = [];
  bool _isLoading = true;
  bool _isGridView = true;
  String? _errorMessage;
  String _searchQuery = '';
  int? _glowingProjectCode;
  bool _isGlowingEdit = false;
  Timer? _glowTimer;
  final ScrollController _contentScrollCtrl = ScrollController();

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _projectService = widget.projectService ?? ProjectService();
    _fetchProjects();
    _searchCtrl.addListener(() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() {
            _searchQuery = _searchCtrl.text.trim().toLowerCase();
          });
          _updateFilteredProjects();
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _glowTimer?.cancel();
    _contentScrollCtrl.dispose();
    super.dispose();
  }

  void _triggerGlow(int code, {bool isEdit = false}) {
    _glowTimer?.cancel();
    setState(() {
      _glowingProjectCode = code;
      _isGlowingEdit = isEdit;
    });

    // Smooth auto-scroll to the newly saved/updated project
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_contentScrollCtrl.hasClients) {
        final idx = _filteredProjects.indexWhere((p) => p.prjCode == code);
        if (idx != -1) {
          final targetOffset = _isGridView
              ? ((idx ~/ 2) * 180.0) - 40.0
              : (idx * 64.0) - 60.0;
          _contentScrollCtrl.animateTo(
            targetOffset.clamp(0.0, _contentScrollCtrl.position.maxScrollExtent),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });

    _glowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _glowingProjectCode = null;
          _isGlowingEdit = false;
        });
      }
    });
  }

  /// Live End-to-End API Fetch
  Future<void> _fetchProjects({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await _projectService.fetchProjects();
      if (mounted) {
        setState(() {
          _projects = data;
          _isLoading = false;
        });
        _updateFilteredProjects();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  List<ProjectMaster> _cachedFilteredProjects = [];

  void _updateFilteredProjects() {
    if (_searchQuery.isEmpty) {
      _cachedFilteredProjects = List.from(_projects);
    } else {
      _cachedFilteredProjects = _projects.where((p) {
        final codeMatch = p.prjCode.toString().contains(_searchQuery);
        final nameMatch = p.prjName.toLowerCase().contains(_searchQuery);
        final dateMatch = p.dateCreated.toLowerCase().contains(_searchQuery);
        return codeMatch || nameMatch || dateMatch;
      }).toList();
    }
  }

  List<ProjectMaster> get _filteredProjects => _cachedFilteredProjects;

  void _showProjectFormDrawer({ProjectMaster? projectToEdit}) async {
    int nextCode = 101;
    if (projectToEdit == null) {
      nextCode = await _projectService.fetchNextCode();
    }

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 14, right: 14),
            child: _FloatingProjectFormDrawer(
              project: projectToEdit,
              nextCode: nextCode,
              projectService: _projectService,
              onSuccess: (savedProject, isEdit) async {
                await _fetchProjects(showLoading: false); // Live Silent Refresh from DB
                _triggerGlow(savedProject.prjCode, isEdit: isEdit);
              },
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.fastOutSlowIn)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  Future<void> _confirmDelete(ProjectMaster project) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () => _projectService.deleteProject(project.prjCode),
      ),
    );

    if (deleted == true) {
      await _fetchProjects();
    }
  }

  void _showComprehensiveExportModal() {
    showDialog(
      context: context,
      builder: (ctx) => _ProjectExportModalDialog(projects: _filteredProjects),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Glassmorphism Header Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xF2FFFFFF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 14),
                          _buildActionBar(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Main Content Body (Loading / Error / Empty / Data Table)
                    Expanded(
                      child: _isLoading
                          ? _buildShimmerLoading()
                          : (_errorMessage != null
                              ? _buildErrorState()
                              : (_filteredProjects.isEmpty
                                  ? _buildEmptyState()
                                  : _buildTableCard())),
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

  /// Page Header
  /// Page Header
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _ProjectMaster3DLogoWidget(size: 42),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Project Master',
              style: TextStyle(
                color: AppColors.primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage and organize enterprise project codes & description registers',
              style: TextStyle(
                color: AppColors.neutralDark.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Top Action Bar with Search Input, Emerald View Toggle, and Primary Action Button
  Widget _buildActionBar() {
    return Row(
      children: [
        // Search Input Field
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: AppColors.neutralDark, fontSize: 13, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search project code or description...',
                hintStyle: TextStyle(
                  color: AppColors.neutralDark.withValues(alpha: 0.4),
                  fontSize: 12.5,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.secondaryColor,
                  size: 18,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.secondaryColor, width: 1.4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Animated Layout View Toggle Button with Sliding Accent Line
        _LayoutViewModeToggle(
          isGridView: _isGridView,
          onViewChanged: (isGrid) => setState(() => _isGridView = isGrid),
        ),
        const SizedBox(width: 10),

        // Animated Export Button (Circulating Light Edge Orbit)
        _AnimatedExportButton(onPressed: _showComprehensiveExportModal),
        const SizedBox(width: 10),

        // + Add New Project Primary Button (Matching AppColors Secondary Accent)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 2,
            shadowColor: AppColors.secondaryColor.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: () => _showProjectFormDrawer(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text(
            'Add New Project',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // VIBRANT CARD LAYOUT & TABLE GRID WITH ANIMATED SWITCHER VIEW TRANSITION
  // ============================================================================
  Widget _buildTableCard() {
    return Column(
      children: [
        // Section Header Bar for Card Grid Mode (Showing Title & Stat Count Badges)
        if (_isGridView) ...[
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: const Icon(
                    Icons.grid_view_rounded,
                    size: 15,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'PROJECT DIRECTORY',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                // Total Projects Badge (Matching Emerald Theme)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_open_rounded, size: 12, color: Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text(
                        'Total: ${_projects.length}',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Filtered / Active Badge (Matching Emerald Theme)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Text(
                        'Showing: ${_filteredProjects.length}',
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Scrollable List or Grid of Modern Glassmorphism Project Cards with Cool 3D Flip & Slide Transition
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchProjects,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                final isGrid = child.key == const ValueKey('grid_view_mode');
                final slideOffset = Tween<Offset>(
                  begin: Offset(isGrid ? -0.06 : 0.06, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ));

                final rotateY = Tween<double>(
                  begin: isGrid ? -0.12 : 0.12,
                  end: 0.0,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ));

                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    return SlideTransition(
                      position: slideOffset,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(rotateY.value),
                        alignment: Alignment.center,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      ),
                    );
                  },
                );
              },
              child: _isGridView
                  ? GridView.builder(
                      key: const ValueKey('grid_view_mode'),
                      controller: _contentScrollCtrl,
                      itemCount: _filteredProjects.length,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 420,
                        mainAxisExtent: 168,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (ctx, index) {
                        final project = _filteredProjects[index];
                        final isGlowing = _glowingProjectCode == project.prjCode;
                        return _UniqueProjectGridCard(
                          project: project,
                          isGlowing: isGlowing,
                          isGlowingEdit: isGlowing && _isGlowingEdit,
                          onEdit: () => _showProjectFormDrawer(projectToEdit: project),
                          onDelete: () => _confirmDelete(project),
                        );
                      },
                    )
                  : ListView.builder(
                      key: const ValueKey('list_view_mode'),
                      controller: _contentScrollCtrl,
                      itemCount: _filteredProjects.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (ctx, index) {
                        final project = _filteredProjects[index];
                        final isGlowing = _glowingProjectCode == project.prjCode;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _UniqueProjectRowCard(
                            project: project,
                            isGlowing: isGlowing,
                            isGlowingEdit: isGlowing && _isGlowingEdit,
                            onEdit: () => _showProjectFormDrawer(projectToEdit: project),
                            onDelete: () => _confirmDelete(project),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
      children: List.generate(
        5,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Container(
                  width: 90,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFFEBF0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: Color(0xFFE53E3E),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'API Connection Offline',
            style: TextStyle(
              color: AppColors.neutralDark,
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              _errorMessage ?? 'Unable to connect to ASP.NET Core backend API.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.neutralDark.withValues(alpha: 0.6),
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _fetchProjects,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry API Connection', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_late_outlined,
              size: 40,
              color: AppColors.secondaryColor,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Projects Found',
            style: TextStyle(
              color: AppColors.neutralDark,
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'No project matching "$_searchQuery". Try clearing your search.'
                : 'Get started by creating your first Project Master record.',
            style: TextStyle(
              color: AppColors.neutralDark.withValues(alpha: 0.6),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              if (_searchQuery.isNotEmpty) {
                _searchCtrl.clear();
              } else {
                _showProjectFormDrawer();
              }
            },
            icon: Icon(_searchQuery.isNotEmpty ? Icons.clear_rounded : Icons.add_rounded, size: 16),
            label: Text(_searchQuery.isNotEmpty ? 'Clear Search' : 'Add Project', style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TASK 2: ANIMATED EXPORT BUTTON WITH CIRCULATING LIGHT EDGE ORBIT
// ============================================================================
class _AnimatedExportButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AnimatedExportButton({required this.onPressed});

  @override
  State<_AnimatedExportButton> createState() => _AnimatedExportButtonState();
}

class _AnimatedExportButtonState extends State<_AnimatedExportButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _isHovered = false;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _ctrl.reset();
        if (mounted) {
          setState(() => _isAnimating = false);
        }
        widget.onPressed();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerClickOrbit() {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    _ctrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _triggerClickOrbit,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final progress = _ctrl.value;

            return CustomPaint(
              painter: _OrbitButtonBorderPainter(
                progress: progress,
                isHovered: _isHovered,
                isAnimating: _isAnimating,
              ),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isAnimating ? AppColors.secondaryColor : AppColors.divider,
                    width: _isAnimating ? 1.4 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isAnimating
                          ? AppColors.secondaryColor.withValues(alpha: 0.3)
                          : AppColors.secondaryColor.withValues(alpha: _isHovered ? 0.18 : 0.05),
                      blurRadius: _isAnimating || _isHovered ? 12 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.file_download_outlined,
                      size: 16,
                      color: _isAnimating || _isHovered ? AppColors.secondaryColor : AppColors.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _isAnimating || _isHovered ? AppColors.secondaryColor : AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrbitButtonBorderPainter extends CustomPainter {
  final double progress;
  final bool isHovered;
  final bool isAnimating;

  _OrbitButtonBorderPainter({
    required this.progress,
    required this.isHovered,
    required this.isAnimating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isAnimating || progress <= 0.0 || progress >= 1.0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    final path = Path()..addRRect(rrect);

    final metrics = path.computeMetrics().first;
    final totalLen = metrics.length;
    final beamLen = totalLen * 0.35;

    final start = progress * totalLen;
    final end = (start + beamLen) % totalLen;

    Path extractPath;
    if (start + beamLen <= totalLen) {
      extractPath = metrics.extractPath(start, start + beamLen);
    } else {
      extractPath = metrics.extractPath(start, totalLen);
      extractPath.addPath(metrics.extractPath(0, end), Offset.zero);
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF25D366).withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);

    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF0C3B2E).withValues(alpha: 0.2),
          const Color(0xFF25D366),
          const Color(0xFF10B981),
          Colors.white,
        ],
        stops: const [0.0, 0.25, 0.6, 0.85, 1.0],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(rect);

    canvas.drawPath(extractPath, glowPaint);
    canvas.drawPath(extractPath, beamPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitButtonBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isHovered != isHovered ||
        oldDelegate.isAnimating != isAnimating;
  }
}

// ============================================================================
// STYLISH 3D BRAND LOGO EMBLEM WIDGET FOR PROJECT MASTER
// ============================================================================
// ============================================================================
// HYPER-REALISTIC 3D NOTEPAD BRAND LOGO WIDGET FOR PROJECT MASTER
// ============================================================================
// ============================================================================
// 100% IDENTICAL PURPLE SPIRAL NOTEPAD & CYAN PENCIL BRAND LOGO WIDGET
// ============================================================================
class _ProjectMaster3DLogoWidget extends StatelessWidget {
  final double size;
  const _ProjectMaster3DLogoWidget({this.size = 40.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.1,
      height: size * 1.1,
      child: CustomPaint(
        painter: _IdenticalNotepadLogoPainter(),
      ),
    );
  }
}

/// Custom Vector Painter rendering a 100% identical Purple Spiral Notepad & Cyan Pencil Emblem
class _IdenticalNotepadLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Purple/Magenta Spiral Notebook Body Container
    final padWidth = w * 0.78;
    final padHeight = h * 0.94;
    final padRect = Rect.fromLTWH(0, h * 0.03, padWidth, padHeight);
    final padRRect = RRect.fromRectAndRadius(padRect, const Radius.circular(8));

    // Vibrant Purple / Magenta Gradient
    final notebookPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFD946EF), // Neon Magenta
          Color(0xFFA855F7), // Bright Purple
          Color(0xFF9333EA), // Deep Violet
        ],
      ).createShader(padRect);

    canvas.drawRRect(padRRect, notebookPaint);

    // 2. White Spiral Binder Punch-out Circles (Left Margin Edge)
    final ringCount = 6;
    final ringRadius = w * 0.055;
    final startY = padRect.top + 10.0;
    final endY = padRect.bottom - 10.0;
    final ringSpacing = (endY - startY) / (ringCount - 1);
    final ringPaint = Paint()..color = Colors.white;

    for (int i = 0; i < ringCount; i++) {
      final cy = startY + (i * ringSpacing);
      canvas.drawCircle(Offset(4.5, cy), ringRadius, ringPaint);
    }

    // 3. Top Label Badge (White Rounded Rectangle)
    final labelWidth = padWidth * 0.52;
    final labelHeight = padHeight * 0.18;
    final labelLeft = (padWidth - labelWidth) / 2 + 5;
    final labelTop = padRect.top + (padHeight * 0.13);
    final labelRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelLeft, labelTop, labelWidth, labelHeight),
      const Radius.circular(5.5),
    );
    canvas.drawRRect(labelRRect, Paint()..color = Colors.white);

    // 4. White Smiley Face: Two Eyes
    final eyeRadius = w * 0.045;
    final eyeY = padRect.top + (padHeight * 0.52);
    final eyeLeftX = padWidth * 0.35 + 3;
    final eyeRightX = padWidth * 0.72 + 3;

    canvas.drawCircle(Offset(eyeLeftX, eyeY), eyeRadius, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(eyeRightX, eyeY), eyeRadius, Paint()..color = Colors.white);

    // 5. White Smiley Face: Arc Smile Line
    final smilePath = Path();
    final smileRect = Rect.fromLTWH(
      padWidth * 0.28 + 3,
      padRect.top + (padHeight * 0.50),
      padWidth * 0.52,
      padHeight * 0.32,
    );
    smilePath.addArc(smileRect, 0.2, 2.74);

    final smilePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.082
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(smilePath, smilePaint);

    // 6. Diagonal Electric Cyan Pencil on Bottom-Right Corner
    canvas.save();

    final pencilCenterX = w * 0.75;
    final pencilCenterY = h * 0.56;
    canvas.translate(pencilCenterX, pencilCenterY);
    canvas.rotate(-0.54); // ~ -31 degrees angle

    final pW = w * 0.23; // Pencil width
    final pH = h * 0.65; // Pencil length

    // Pencil Main Shaft (Electric Cyan Gradient)
    final pencilRect = Rect.fromLTWH(0, 0, pW, pH * 0.72);
    final pencilPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF00E5FF), // Electric Cyan
          Color(0xFF00A3FF), // Cyan Blue
          Color(0xFF0066FF), // Royal Electric Blue
        ],
      ).createShader(pencilRect);

    final pencilRRect = RRect.fromRectAndCorners(
      pencilRect,
      topLeft: const Radius.circular(4.5),
      topRight: const Radius.circular(4.5),
    );
    canvas.drawRRect(pencilRRect, pencilPaint);

    // Eraser Band Separator Line
    canvas.drawLine(
      Offset(0, pH * 0.16),
      Offset(pW, pH * 0.16),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 1.2,
    );

    // Pencil Tip Cone (Triangle pointing down)
    final tipPath = Path()
      ..moveTo(0, pH * 0.72)
      ..lineTo(pW, pH * 0.72)
      ..lineTo(pW / 2, pH)
      ..close();

    canvas.drawPath(
      tipPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF00A3FF),
            Color(0xFF0044FF),
          ],
        ).createShader(Rect.fromLTWH(0, pH * 0.72, pW, pH * 0.28)),
    );

    // White Lead Tip Detail
    final leadPath = Path()
      ..moveTo(pW * 0.35, pH * 0.86)
      ..lineTo(pW * 0.65, pH * 0.86)
      ..lineTo(pW / 2, pH)
      ..close();
    canvas.drawPath(leadPath, Paint()..color = Colors.white);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 1. RESPONSIVE CARD GRID COMPONENT (_UniqueProjectGridCard)
// ============================================================================
class _UniqueProjectGridCard extends StatefulWidget {
  final ProjectMaster project;
  final bool isGlowing;
  final bool isGlowingEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UniqueProjectGridCard({
    required this.project,
    this.isGlowing = false,
    this.isGlowingEdit = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_UniqueProjectGridCard> createState() => _UniqueProjectGridCardState();
}

class _UniqueProjectGridCardState extends State<_UniqueProjectGridCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.55).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.isGlowing) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _UniqueProjectGridCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGlowing != oldWidget.isGlowing) {
      if (widget.isGlowing) {
        _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
        _glowController.reset();
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Widget _buildUniqueProjectEmblem(int prjCode) {
    IconData iconData;
    List<Color> gradientColors;
    Color shadowColor;

    switch (prjCode % 5) {
      case 1:
        // Project #1: Royal Sapphire Launch Rocket Emblem
        iconData = Icons.rocket_launch_rounded;
        gradientColors = const [Color(0xFF2563EB), Color(0xFF3B82F6), Color(0xFF06B6D4)];
        shadowColor = const Color(0xFF2563EB);
        break;
      case 2:
        // Project #2: Emerald Cyber Shield Emblem
        iconData = Icons.shield_moon_rounded;
        gradientColors = const [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)];
        shadowColor = const Color(0xFF059669);
        break;
      case 3:
        // Project #3: Neon Violet Crystal Token Emblem
        iconData = Icons.token_rounded;
        gradientColors = const [Color(0xFF7C3AED), Color(0xFF9333EA), Color(0xFFD946EF)];
        shadowColor = const Color(0xFF7C3AED);
        break;
      case 4:
        // Project #4: Warm Amber Energy Emblem
        iconData = Icons.local_fire_department_rounded;
        gradientColors = const [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFBBF24)];
        shadowColor = const Color(0xFFD97706);
        break;
      default:
        // Project #5/0: Cyan Tech Dashboard Cube Emblem
        iconData = Icons.space_dashboard_rounded;
        gradientColors = const [Color(0xFF0891B2), Color(0xFF06B6D4), Color(0xFF38BDF8)];
        shadowColor = const Color(0xFF0891B2);
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.38),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          iconData,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color glowColor = widget.isGlowingEdit
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
    final Color glowBgColor = widget.isGlowingEdit
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFF0FDF4);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowAlpha = widget.isGlowing ? _glowAnimation.value : 0.0;

        return GestureDetector(
          onDoubleTap: widget.onEdit, // Double-Click Grid Card to open update screen!
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _isHovered ? -4.0 : 0.0, 0),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: widget.isGlowing
                    ? glowBgColor
                    : (_isHovered ? Colors.white : const Color(0xFFFAFAFC)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isGlowing
                      ? glowColor
                      : (_isHovered ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                  width: widget.isGlowing ? 2.0 : (_isHovered ? 1.6 : 1.0),
                ),
                boxShadow: widget.isGlowing
                    ? [
                        BoxShadow(
                          color: glowColor.withValues(alpha: glowAlpha),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : (_isHovered
                        ? [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                              blurRadius: 16,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Top Enhanced Holographic Gradient Accent Line
                  Positioned(
                    top: -15,
                    left: 10,
                    right: 10,
                    child: Container(
                      height: 4.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isHovered
                              ? const [Color(0xFF2563EB), Color(0xFF4F46E5), Color(0xFF06B6D4), Color(0xFFD946EF)]
                              : const [Color(0xFF818CF8), Color(0xFFC7D2FE), Color(0xFF93C5FD)],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: _isHovered
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.65),
                                  blurRadius: 10,
                                  spreadRadius: 1.5,
                                ),
                              ]
                            : [],
                      ),
                    ),
                  ),

                  // Main Card Contents Column
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Row: Code Pill + Active Status + Action Capsule
                        Row(
                          children: [
                            // Holographic Code Chip (Single Clean Hashtag)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFC7D2FE), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                '#${widget.project.prjCode}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF4F46E5),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            if (widget.isGlowing) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: widget.isGlowingEdit
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: widget.isGlowingEdit
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.isGlowingEdit
                                          ? Icons.auto_awesome_rounded
                                          : Icons.stars_rounded,
                                      size: 12,
                                      color: widget.isGlowingEdit
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF047857),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      widget.isGlowingEdit ? 'UPDATED' : 'NEW',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: widget.isGlowingEdit
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          const Spacer(),

                          // Sleek Action Capsule Container
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ActionIconButton(
                                  icon: Icons.edit_outlined,
                                  color: const Color(0xFF2563EB),
                                  hoverBg: const Color(0xFFEFF6FF),
                                  tooltip: 'Edit Project',
                                  onPressed: widget.onEdit,
                                ),
                                const SizedBox(width: 4),
                                _ActionIconButton(
                                  icon: Icons.delete_outline_rounded,
                                  color: const Color(0xFFEF4444),
                                  hoverBg: const Color(0xFFFEF2F2),
                                  tooltip: 'Delete Project',
                                  onPressed: widget.onDelete,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Center Body: Dynamic 3D Unique Logo Emblem + Project Title
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            // DYNAMIC 3D UNIQUE LOGO EMBLEM
                            _buildUniqueProjectEmblem(widget.project.prjCode),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.project.prjName,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  height: 1.25,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Subtle Card Divider Line
                      Container(
                        height: 1,
                        color: const Color(0xFFF1F5F9),
                      ),

                      // Bottom Footer: Slate Date Pill + Verified Register Tag
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  color: Color(0xFF475569),
                                  size: 11.5,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  widget.project.dateCreated,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 10, color: Color(0xFF059669)),
                                SizedBox(width: 4),
                                Text(
                                  'REGISTERED',
                                  style: TextStyle(
                                    color: Color(0xFF047857),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }
}

// ============================================================================
// 2. MODERN LIST ROW CARD COMPONENT (_UniqueProjectRowCard)
// ============================================================================
class _UniqueProjectRowCard extends StatefulWidget {
  final ProjectMaster project;
  final bool isGlowing;
  final bool isGlowingEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UniqueProjectRowCard({
    required this.project,
    this.isGlowing = false,
    this.isGlowingEdit = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_UniqueProjectRowCard> createState() => _UniqueProjectRowCardState();
}

class _UniqueProjectRowCardState extends State<_UniqueProjectRowCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.55).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.isGlowing) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _UniqueProjectRowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGlowing != oldWidget.isGlowing) {
      if (widget.isGlowing) {
        _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
        _glowController.reset();
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color glowColor = widget.isGlowingEdit
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
    final Color glowBgColor = widget.isGlowingEdit
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFF0FDF4);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowAlpha = widget.isGlowing ? _glowAnimation.value : 0.0;

        return GestureDetector(
          onDoubleTap: widget.onEdit, // Double-Click Row to open update screen!
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isGlowing
                    ? glowBgColor
                    : (_isHovered ? Colors.white : const Color(0xFFFAFAFC)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isGlowing
                      ? glowColor
                      : (_isHovered ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                  width: widget.isGlowing ? 2.0 : (_isHovered ? 1.5 : 1.0),
                ),
                boxShadow: widget.isGlowing
                    ? [
                        BoxShadow(
                          color: glowColor.withValues(alpha: glowAlpha),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : (_isHovered
                        ? [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.10),
                              blurRadius: 12,
                              spreadRadius: 0,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 5,
                              offset: const Offset(0, 1.5),
                            ),
                          ]),
              ),
              child: Row(
                children: [
                  // Left Accent Indicator Bar (Fixes Hover Glitch)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: widget.isGlowing ? 4.5 : (_isHovered ? 3.5 : 2.5),
                    height: 24,
                    decoration: BoxDecoration(
                      color: widget.isGlowing
                          ? glowColor
                          : (_isHovered ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 1. # CODE BADGE + NEW / UPDATED STAR BADGE (Fixed Width 150)
                  SizedBox(
                    width: 150,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFEFF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFA5F3FC), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0891B2).withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '#${widget.project.prjCode}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF0E7490),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (widget.isGlowing) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: widget.isGlowingEdit
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: widget.isGlowingEdit
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.isGlowingEdit
                                      ? Icons.auto_awesome_rounded
                                      : Icons.stars_rounded,
                                  size: 12,
                                  color: widget.isGlowingEdit
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF047857),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  widget.isGlowingEdit ? 'UPDATED' : 'NEW',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: widget.isGlowingEdit
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF047857),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 2. PROJECT DESCRIPTION (High-Contrast Neutral Dark Charcoal with Icon Tag)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                            ),
                            child: const Icon(
                              Icons.business_center_rounded,
                              color: Color(0xFF2563EB),
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.project.prjName,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                letterSpacing: -0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 3. CREATION DATE PILL (Warm Amber Tint #FFFBEB, Border #FDE68A, Text #B45309)
                SizedBox(
                  width: 140,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: Color(0xFFD97706),
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.project.dateCreated,
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. ACTION BUTTONS (Curvy Action Container with Smooth Hover Feedback)
                SizedBox(
                  width: 85,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ActionIconButton(
                            icon: Icons.edit_outlined,
                            color: const Color(0xFF059669),
                            hoverBg: const Color(0xFFECFDF5),
                            tooltip: 'Edit Project',
                            onPressed: widget.onEdit,
                          ),
                          const SizedBox(width: 4),
                          _ActionIconButton(
                            icon: Icons.delete_outline_rounded,
                            color: const Color(0xFFEF4444),
                            hoverBg: const Color(0xFFFEF2F2),
                            tooltip: 'Delete Project',
                            onPressed: widget.onDelete,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }
}

// ============================================================================
// SLEEK ACTION BUTTON WITH HOVER STATE ANIMATION
// ============================================================================
class _ActionIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color hoverBg;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.hoverBg,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _isHovered ? widget.hoverBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STEPPED TRACK PROGRESS LINE VIEW TOGGLE SWITCHER (INSPIRED BY REFERENCE IMAGE)
// ============================================================================
class _LayoutViewModeToggle extends StatefulWidget {
  final bool isGridView;
  final ValueChanged<bool> onViewChanged;

  const _LayoutViewModeToggle({
    required this.isGridView,
    required this.onViewChanged,
  });

  @override
  State<_LayoutViewModeToggle> createState() => _LayoutViewModeToggleState();
}

class _LayoutViewModeToggleState extends State<_LayoutViewModeToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _progressAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeInOutCubic,
    );

    if (!widget.isGridView) {
      _animCtrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _LayoutViewModeToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGridView != oldWidget.isGridView) {
      if (widget.isGridView) {
        _animCtrl.reverse();
      } else {
        _animCtrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double toggleWidth = 190.0;
    const double toggleHeight = 44.0;

    return Container(
      height: toggleHeight,
      width: toggleWidth,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Soft Slate Surface Capsule
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, child) {
          final progress = _progressAnim.value;
          final isGrid = widget.isGridView;

          return Stack(
            alignment: Alignment.center,
            children: [
              // 1. Inactive Background Track Line (Spans horizontally behind nodes)
              Positioned(
                left: 32,
                right: 32,
                child: Container(
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 2. Active Animated Progress Fill Line (Fills fluidly from left to right node)
              Positioned(
                left: 32,
                right: 32,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fullTrackWidth = constraints.maxWidth;
                    final fillWidth = fullTrackWidth * progress;

                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 4.0,
                        width: fillWidth,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2563EB), // Vibrant Royal Blue
                              Color(0xFF4F46E5), // Indigo Accent
                              Color(0xFFD946EF), // Neon Magenta Accent
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 3. Stepped Node Badges (Cards Node on Left, List Node on Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Node: CARDS
                  Tooltip(
                    message: 'Switch to Card Grid Layout',
                    child: InkWell(
                      onTap: () => widget.onViewChanged(true),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isGrid ? Colors.white : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isGrid ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                            width: isGrid ? 1.8 : 1.0,
                          ),
                          boxShadow: isGrid
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              scale: isGrid ? 1.12 : 0.95,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.grid_view_rounded,
                                size: 15,
                                color: isGrid ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Cards',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isGrid ? FontWeight.w800 : FontWeight.w600,
                                color: isGrid ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Right Node: LIST
                  Tooltip(
                    message: 'Switch to Compact List Layout',
                    child: InkWell(
                      onTap: () => widget.onViewChanged(false),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: !isGrid ? Colors.white : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: !isGrid ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                            width: !isGrid ? 1.8 : 1.0,
                          ),
                          boxShadow: !isGrid
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              scale: !isGrid ? 1.12 : 0.95,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.view_headline_rounded,
                                size: 15,
                                color: !isGrid ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'List',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: !isGrid ? FontWeight.w800 : FontWeight.w600,
                                color: !isGrid ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// 100% IDENTICAL PURPLE FOLDER WITH PAPER CLIP & GREEN LABEL LOGO WIDGET
// ============================================================================
class _IdenticalFolderLogoWidget extends StatelessWidget {
  final double size;
  const _IdenticalFolderLogoWidget({this.size = 38.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IdenticalFolderLogoPainter(),
      ),
    );
  }
}

/// Custom Vector Painter rendering a 100% identical Purple Folder, Paper Clip & Green Label
class _IdenticalFolderLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final darkOutlinePaint = Paint()
      ..color = const Color(0xFF1E1B4B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Main Folder Path Outer Contour (Folder tab on top-left + main body)
    final folderPath = Path();
    folderPath.moveTo(w * 0.12, h * 0.18);
    folderPath.lineTo(w * 0.44, h * 0.18);
    folderPath.lineTo(w * 0.54, h * 0.32);
    folderPath.lineTo(w * 0.88, h * 0.32);
    folderPath.arcToPoint(Offset(w * 0.94, h * 0.38), radius: const Radius.circular(5));
    folderPath.lineTo(w * 0.94, h * 0.88);
    folderPath.arcToPoint(Offset(w * 0.88, h * 0.94), radius: const Radius.circular(5));
    folderPath.lineTo(w * 0.12, h * 0.94);
    folderPath.arcToPoint(Offset(w * 0.06, h * 0.88), radius: const Radius.circular(5));
    folderPath.lineTo(w * 0.06, h * 0.24);
    folderPath.arcToPoint(Offset(w * 0.12, h * 0.18), radius: const Radius.circular(5));
    folderPath.close();

    // Fill Main Folder Base (Lavender Purple)
    canvas.drawPath(folderPath, Paint()..color = const Color(0xFFC084FC));

    // 2. Two-Tone Shadow Crescent on Bottom Right (Darker Purple Shade)
    final shadowPath = Path();
    shadowPath.moveTo(w * 0.65, h * 0.94);
    shadowPath.arcToPoint(Offset(w * 0.94, h * 0.65), radius: Radius.circular(w * 0.35));
    shadowPath.lineTo(w * 0.94, h * 0.88);
    shadowPath.arcToPoint(Offset(w * 0.88, h * 0.94), radius: const Radius.circular(5));
    shadowPath.close();
    canvas.drawPath(shadowPath, Paint()..color = const Color(0xFFA855F7));

    // Draw Dark Outline on Main Folder
    canvas.drawPath(folderPath, darkOutlinePaint);

    // Folder Front Flap Horizontal Seam Line
    final flapSeamPath = Path();
    flapSeamPath.moveTo(w * 0.06, h * 0.32);
    flapSeamPath.lineTo(w * 0.54, h * 0.32);
    canvas.drawPath(flapSeamPath, darkOutlinePaint);

    // 3. Green Label Box on Bottom Left
    final labelW = w * 0.36;
    final labelH = h * 0.20;
    final labelRect = Rect.fromLTWH(w * 0.16, h * 0.65, labelW, labelH);
    final labelRRect = RRect.fromRectAndRadius(labelRect, const Radius.circular(4.5));

    // Green Fill (#84CC16)
    canvas.drawRRect(labelRRect, Paint()..color = const Color(0xFF84CC16));
    // Green Label Dark Outline
    canvas.drawRRect(labelRRect, darkOutlinePaint);

    // 4. White Paper Clip on Top Right Flap
    final clipW = w * 0.15;
    final clipH = h * 0.38;
    final clipLeft = w * 0.68;
    final clipTop = h * 0.24;

    final clipRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(clipLeft, clipTop, clipW, clipH),
      Radius.circular(clipW / 2),
    );
    canvas.drawRRect(clipRRect, Paint()..color = Colors.white);
    canvas.drawRRect(clipRRect, darkOutlinePaint);

    // Inner Paper Clip Loop Wire Line
    final innerLoopPath = Path();
    innerLoopPath.moveTo(clipLeft + clipW * 0.5, clipTop + clipH * 0.25);
    innerLoopPath.lineTo(clipLeft + clipW * 0.5, clipTop + clipH * 0.65);
    canvas.drawPath(innerLoopPath, darkOutlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// FLOATING DRAWER OVERLAY
// ============================================================================
class _FloatingProjectFormDrawer extends StatefulWidget {
  final ProjectMaster? project;
  final int nextCode;
  final ProjectService projectService;
  final Function(ProjectMaster, bool) onSuccess;

  const _FloatingProjectFormDrawer({
    this.project,
    required this.nextCode,
    required this.projectService,
    required this.onSuccess,
  });

  @override
  State<_FloatingProjectFormDrawer> createState() =>
      _FloatingProjectFormDrawerState();
}

class _FloatingProjectFormDrawerState
    extends State<_FloatingProjectFormDrawer> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;

  bool _isSaving = false;
  bool _isSaveSuccess = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final isEdit = widget.project != null;
    _codeCtrl = TextEditingController(
      text: isEdit ? widget.project!.prjCode.toString() : widget.nextCode.toString(),
    );
    _nameCtrl = TextEditingController(
      text: isEdit ? widget.project!.prjName : '',
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _isSaveSuccess = false;
      _errorMsg = null;
    });

    final code = int.parse(_codeCtrl.text);
    final name = _nameCtrl.text.trim();
    final isEdit = widget.project != null;

    try {
      bool success = false;
      if (isEdit) {
        success = await widget.projectService.updateProject(code, name);
      } else {
        success = await widget.projectService.createProject(code, name);
      }

      if (mounted) {
        if (success) {
          setState(() {
            _isSaving = false;
            _isSaveSuccess = true;
          });
          final saved = ProjectMaster(
            prjCode: code,
            prjName: name,
            dateCreated: isEdit
                ? (widget.project?.dateCreated != null && widget.project!.dateCreated != '03 Aug 2026'
                    ? widget.project!.dateCreated
                    : ProjectMaster.formatDisplayDate(DateTime.now()))
                : ProjectMaster.formatDisplayDate(DateTime.now()),
          );
          Future.delayed(const Duration(milliseconds: 650), () {
            if (mounted) {
              widget.onSuccess(saved, isEdit);
              Navigator.of(context).pop();
            }
          });
        } else {
          setState(() {
            _isSaving = false;
            _errorMsg = 'API returned failure status for save operation.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMsg = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.project != null;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 420,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(-4, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Floating Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
                  child: Row(
                    children: [
                      const _IdenticalFolderLogoWidget(size: 38),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Edit Project Master' : 'Create Project Master',
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.neutralDark,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            isEdit ? 'Update details for #${widget.project!.prjCode}' : 'Add a new project code register',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.neutralDark.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Form Body
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMsg != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBF0),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFEB2B2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFE53E3E), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMsg!,
                                    style: const TextStyle(color: Color(0xFF9B2C2C), fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // COOL & AMAZING SEPARATE FORM CARD BOX
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section Header Badge
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(color: const Color(0xFFC7D2FE)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_document, size: 12, color: Color(0xFF4F46E5)),
                                        SizedBox(width: 4),
                                        Text(
                                          'PROJECT DETAILS',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF4F46E5),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // 1. PROJECT CODE FIELD (No Brackets)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFC7D2FE)),
                                    ),
                                    child: const Icon(
                                      Icons.tag_rounded,
                                      size: 14,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Project Code',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFC7D2FE)),
                                    ),
                                    child: const Text(
                                      'AUTO-GENERATED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF4F46E5),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                                ),
                                child: TextFormField(
                                  controller: _codeCtrl,
                                  readOnly: true,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E1B4B),
                                  ),
                                  decoration: const InputDecoration(
                                    filled: false,
                                    prefixIcon: Icon(Icons.numbers_rounded, size: 17, color: Color(0xFF6366F1)),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 2. PROJECT NAME FIELD (Renamed & Themed)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: const Icon(
                                      Icons.business_center_rounded,
                                      size: 14,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Project Name *',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              TextFormField(
                                controller: _nameCtrl,
                                autofocus: true,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Project name is required';
                                  }
                                  if (val.trim().length < 3) {
                                    return 'Project name must be at least 3 characters';
                                  }
                                  return null;
                                },
                                decoration: InputDecoration(
                                  hintText: 'e.g. Solar ERP Expansion & Modernization',
                                  hintStyle: TextStyle(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.38),
                                    fontSize: 12.5,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF2563EB)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFBFDBFE)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFBFDBFE)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Realistic 3D Material Management Illustration Card
                        const _RealisticMaterialManagement3DCard(),
                      ],
                    ),
                  ),
                ),

                // Floating Action Bar with Curvy Buttons
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            side: const BorderSide(color: AppColors.divider, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.neutralDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedSuccessButton(
                          status: _isSaveSuccess
                              ? ButtonStatus.success
                              : (_isSaving ? ButtonStatus.loading : ButtonStatus.idle),
                          onPressed: _submit,
                          idleText: isEdit ? 'Update Project' : 'Save Project',
                          loadingText: 'Saving...',
                          successText: 'Saved!',
                          idleIcon: isEdit ? Icons.check_rounded : Icons.save_rounded,
                          idleBackgroundColor: AppColors.secondaryColor,
                          successBackgroundColor: const Color(0xFF10B981),
                          height: 44,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ULTRA-REALISTIC 3D MATERIAL MANAGEMENT SCENE (Nature, Moving Truck, Driver & Speech Bubble)
// ============================================================================
class _RealisticMaterialManagement3DCard extends StatefulWidget {
  const _RealisticMaterialManagement3DCard();

  @override
  State<_RealisticMaterialManagement3DCard> createState() =>
      _RealisticMaterialManagement3DCardState();
}

class _RealisticMaterialManagement3DCardState
    extends State<_RealisticMaterialManagement3DCard>
    with TickerProviderStateMixin {
  late AnimationController _driveCtrl;       // Continuous truck driving loop
  late AnimationController _waveCtrl;        // Driver waving animation
  late AnimationController _bubbleFloatCtrl; // Floating speech bubble bobbing

  @override
  void initState() {
    super.initState();

    // 1. Truck Drive Loop (Drives across, pauses/loops continuously)
    _driveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // 2. Driver Hand Waving Animation
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // 3. Floating Speech Bubble Bobbing Animation
    _bubbleFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _driveCtrl.dispose();
    _waveCtrl.dispose();
    _bubbleFloatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryColor.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AnimatedBuilder(
          animation: Listenable.merge([_driveCtrl, _waveCtrl, _bubbleFloatCtrl]),
          builder: (context, _) {
            final driveProgress = _driveCtrl.value; // 0.0 to 1.0
            final waveProgress = _waveCtrl.value;   // 0.0 to 1.0
            final bubbleBob = _bubbleFloatCtrl.value * 4.0; // 0px to 4px float

            return LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

                // Calculate Truck X position along path (Driving Left to Right)
                final truckTotalDist = w + 220;
                final currentTruckX = -140 + (driveProgress * truckTotalDist);

                // Driver Window position (Cab is now on the FRONT RIGHT side: currentTruckX + cargoW + 16)
                final driverWindowX = currentTruckX + 100 + 16;
                final driverWindowY = h * 0.58 - bubbleBob;

                return Stack(
                  children: [
                    // Custom Painter for 3D Sky, Clouds, Mountains, Trees, Warehouse & Truck Body
                    CustomPaint(
                      size: Size(w, h),
                      painter: _Realistic3DFactoryPainter(
                        driveProgress: driveProgress,
                        waveProgress: waveProgress,
                        truckX: currentTruckX,
                      ),
                    ),

                    // FLOATING SPEECH BUBBLE FROM DRIVER
                    if (currentTruckX > -40 && currentTruckX < w - 40)
                      Positioned(
                        left: (driverWindowX - 60).clamp(10.0, w - 160.0),
                        top: driverWindowY - 38,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: (currentTruckX > -20 && currentTruckX < w - 60) ? 1.0 : 0.0,
                          child: _FloatingDriverSpeechBubble(bobOffset: bubbleBob),
                        ),
                      ),

                    // TOP OVERLAY BADGE (Frosted Glass with Live Glowing Status Indicator)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.secondaryColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Live Pulsing Green Status Dot
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.inventory_2_rounded,
                              size: 14,
                              color: AppColors.secondaryColor,
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Material Management',
                              style: TextStyle(
                                color: AppColors.neutralDark,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// FLOATING SPEECH BUBBLE WIDGET
// ============================================================================
class _FloatingDriverSpeechBubble extends StatelessWidget {
  final double bobOffset;
  const _FloatingDriverSpeechBubble({required this.bobOffset});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: AppColors.secondaryColor.withValues(alpha: 0.2),
                blurRadius: 6,
              ),
            ],
            border: Border.all(color: AppColors.secondaryColor.withValues(alpha: 0.4), width: 1.2),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hi! 👋 Material Dispatch Ready!',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        // Speech Bubble Arrow Pointer
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: CustomPaint(
            size: const Size(10, 6),
            painter: _SpeechBubbleArrowPainter(),
          ),
        ),
      ],
    );
  }
}

class _SpeechBubbleArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = Colors.white,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = AppColors.secondaryColor.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ULTRA-REALISTIC 3D CUSTOM PAINTER (Sky, Clouds, Nature Trees, Factory & Truck)
// ============================================================================
class _Realistic3DFactoryPainter extends CustomPainter {
  final double driveProgress;
  final double waveProgress;
  final double truckX;

  _Realistic3DFactoryPainter({
    required this.driveProgress,
    required this.waveProgress,
    required this.truckX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ------------------------------------------------------------------------
    // 1. SKY & ATMOSPHERE GRADIENT
    // ------------------------------------------------------------------------
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFCEE5FD), // Crisp Sky Blue
          Color(0xFFEAF3FC), // Horizon Fog
          Color(0xFFF4F9FF), // Ground Fog
        ],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // Sun Glare Disc & Volumetric Radial Sunlight Beams
    final sunCenter = Offset(w * 0.85, h * 0.22);
    canvas.drawCircle(
      sunCenter,
      36,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // Volumetric Sunlight Beams Radiating Downwards
    final sunRayPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFEF08A).withValues(alpha: 0.28),
          const Color(0xFFFEF08A).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 140));
    canvas.drawCircle(sunCenter, 140, sunRayPaint);

    // ------------------------------------------------------------------------
    // 2. DRIFTING VOLUMETRIC 3D CLOUDS & MIGRATING BIRDS FLOCK
    // ------------------------------------------------------------------------
    final cloudOffset = driveProgress * w * 0.4;
    _draw3DCloud(canvas, (w * 0.15 + cloudOffset) % (w + 80) - 40, h * 0.14, 0.85);
    _draw3DCloud(canvas, (w * 0.60 + cloudOffset * 0.7) % (w + 80) - 40, h * 0.20, 1.1);
    _draw3DCloud(canvas, (w * 0.88 + cloudOffset * 0.5) % (w + 80) - 40, h * 0.12, 0.75);

    // Distant Migrating Birds Flock
    _drawMigratingBirds(canvas, w, h, driveProgress);

    // ------------------------------------------------------------------------
    // 3. DISTANT MOUNTAIN RANGE SILHOUETTE
    // ------------------------------------------------------------------------
    final mountainPath = Path()
      ..moveTo(0, h * 0.60)
      ..lineTo(w * 0.12, h * 0.42)
      ..lineTo(w * 0.28, h * 0.56)
      ..lineTo(w * 0.45, h * 0.38)
      ..lineTo(w * 0.62, h * 0.54)
      ..lineTo(w * 0.80, h * 0.40)
      ..lineTo(w, h * 0.58)
      ..lineTo(w, h * 0.70)
      ..lineTo(0, h * 0.70)
      ..close();

    final mountainPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB4CDDF), Color(0xFFCDE0ED)],
      ).createShader(Rect.fromLTWH(0, h * 0.38, w, h * 0.32));
    canvas.drawPath(mountainPath, mountainPaint);

    // ------------------------------------------------------------------------
    // 4. REALISTIC NATURE TREES (BACKGROUND LAYER)
    // ------------------------------------------------------------------------
    _drawRealisticPineTree(canvas, w * 0.04, h * 0.38, 0.95);
    _drawRealisticOakTree(canvas, w * 0.16, h * 0.40, 1.1);
    _drawRealisticPineTree(canvas, w * 0.44, h * 0.36, 1.05);
    _drawRealisticOakTree(canvas, w * 0.78, h * 0.42, 0.90);
    _drawRealisticPineTree(canvas, w * 0.94, h * 0.37, 1.15);

    // ------------------------------------------------------------------------
    // 5. 3D FACTORY INFRASTRUCTURE (WAREHOUSES, CHIMNEY & SOLAR PANELS)
    // ------------------------------------------------------------------------
    final sageLeft = w * 0.08;
    final sageTop = h * 0.32;
    final sageW = w * 0.36;
    final sageH = h * 0.44;

    // Building Drop Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sageLeft + 6, sageTop + 8, sageW, sageH),
        const Radius.circular(16),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Left Warehouse Front Face (Sage Green #6EA477)
    final sageFrontPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6EA477), Color(0xFF45744E)],
      ).createShader(Rect.fromLTWH(sageLeft, sageTop, sageW, sageH));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sageLeft, sageTop, sageW, sageH),
        const Radius.circular(16),
      ),
      sageFrontPaint,
    );

    // Architectural Horizontal Cladding Panel Grooves
    final panelGroovePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.07)
      ..strokeWidth = 1.2;
    for (double py = sageTop + 24; py < sageTop + sageH - 12; py += 18) {
      canvas.drawLine(Offset(sageLeft + 6, py), Offset(sageLeft + sageW - 6, py), panelGroovePaint);
    }

    // Concrete Base Foundation Footing with Subtle Hazard Stripes
    final baseFootingH = 10.0;
    final baseFootingY = sageTop + sageH - baseFootingH;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(sageLeft, baseFootingY, sageW, baseFootingH),
        bottomLeft: const Radius.circular(16),
        bottomRight: const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFF2E4633),
    );

    // Roof Bevel Highlight
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(sageLeft, sageTop, sageW, 12),
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF8EB996), Color(0xFF6EA477)],
        ).createShader(Rect.fromLTWH(sageLeft, sageTop, sageW, 12)),
    );

    // Rooftop Industrial HVAC Condenser Unit
    final hvacX = sageLeft + sageW * 0.55;
    final hvacY = sageTop - 9;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(hvacX, hvacY, 22, 9), const Radius.circular(2)),
      Paint()..color = const Color(0xFF37474F),
    );
    canvas.drawRect(
      Rect.fromLTWH(hvacX + 3, hvacY + 2, 6, 5),
      Paint()..color = const Color(0xFF263238),
    );
    canvas.drawCircle(Offset(hvacX + 15, hvacY + 4.5), 2.5, Paint()..color = const Color(0xFF78909C));

    // Warehouse Stenciled Facility Signage Badge
    _drawTextBadge(canvas, 'FACILITY A', sageLeft + 14, sageTop + 4, const Color(0xFF2A4832), Colors.white);

    // Glass Windows on Left Warehouse with Realistic Frames
    for (int i = 0; i < 3; i++) {
      final winX = sageLeft + 14 + (i * 26);
      final winY = sageTop + 20;

      // Window Frame
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(winX - 1, winY - 1, 20, 20), const Radius.circular(5)),
        Paint()..color = const Color(0xFF2D4E35),
      );
      // Window Glass
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(winX, winY, 18, 18), const Radius.circular(4)),
        Paint()..color = const Color(0xFFE2F3E7).withValues(alpha: 0.95),
      );
      final streakPath = Path()
        ..moveTo(winX + 3, winY + 15)
        ..lineTo(winX + 11, winY + 3)
        ..lineTo(winX + 15, winY + 3)
        ..lineTo(winX + 7, winY + 15)
        ..close();
      canvas.drawPath(streakPath, Paint()..color = Colors.white.withValues(alpha: 0.7));
    }

    // Right Building (3D Royal Blue Logistics Facility)
    final blueLeft = w * 0.46;
    final blueTop = h * 0.35;
    final blueW = w * 0.46;
    final blueH = h * 0.41;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(blueLeft + 6, blueTop + 6, blueW, blueH),
        const Radius.circular(16),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final blueFrontPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5386E4), Color(0xFF2C56B1)],
      ).createShader(Rect.fromLTWH(blueLeft, blueTop, blueW, blueH));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(blueLeft, blueTop, blueW, blueH),
        const Radius.circular(16),
      ),
      blueFrontPaint,
    );

    // Architectural Seam Lines on Blue Warehouse
    for (double py = blueTop + 26; py < blueTop + blueH - 12; py += 22) {
      canvas.drawLine(Offset(blueLeft + 6, py), Offset(blueLeft + blueW - 6, py), Paint()..color = Colors.black.withValues(alpha: 0.08)..strokeWidth = 1.2);
    }

    // Solar Panels on Blue Roof with Gloss Shimmer
    for (int i = 0; i < 3; i++) {
      final panelX = blueLeft + 12 + (i * 32);
      final panelY = blueTop - 8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(panelX, panelY, 26, 8), const Radius.circular(3)),
        Paint()..color = const Color(0xFF1E3A8A),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(panelX + 1, panelY + 1, 24, 6), const Radius.circular(2)),
        Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.8),
      );
      // Grid cell lines on solar panels
      canvas.drawLine(Offset(panelX + 9, panelY + 1), Offset(panelX + 9, panelY + 7), Paint()..color = const Color(0xFF93C5FD).withValues(alpha: 0.6)..strokeWidth = 0.8);
      canvas.drawLine(Offset(panelX + 17, panelY + 1), Offset(panelX + 17, panelY + 7), Paint()..color = const Color(0xFF93C5FD).withValues(alpha: 0.6)..strokeWidth = 0.8);
    }

    // Animated Spinning Rooftop Wind Turbines
    final turbineAngle = driveProgress * math.pi * 16;
    _drawSpinningTurbine(canvas, blueLeft + 35, blueTop - 12, turbineAngle);
    _drawSpinningTurbine(canvas, blueLeft + 85, blueTop - 12, turbineAngle + 1.2);

    // Industrial Exhaust Chimney Stack & Plowing Smoke
    final stackX = blueLeft + blueW - 28;
    final stackY = blueTop - 28;

    final pipePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4168C2), Color(0xFF1E3A8A)],
      ).createShader(Rect.fromLTWH(stackX, stackY, 16, 30));
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(stackX, stackY, 16, 30),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      ),
      pipePaint,
    );

    // Stack Metallic Reinforcement Bands
    final bandPaint = Paint()..color = const Color(0xFFE2E8F0).withValues(alpha: 0.75)..strokeWidth = 1.5;
    canvas.drawLine(Offset(stackX, stackY + 7), Offset(stackX + 16, stackY + 7), bandPaint);
    canvas.drawLine(Offset(stackX, stackY + 16), Offset(stackX + 16, stackY + 16), bandPaint);

    // Puffing Smoke Clouds (4 Tiers with Realistic Expansion)
    final smokeCycle = (driveProgress * 3.5) % 1.0;
    for (int i = 0; i < 4; i++) {
      final opacity = (0.75 - (i * 0.18) - (smokeCycle * 0.15)).clamp(0.0, 1.0);
      final smokeY = stackY - 8 - (i * 11) - (smokeCycle * 14);
      final smokeDriftX = stackX + 8 + (i * 3.5) + (smokeCycle * 5);
      final radius = 6.0 + (i * 3.5) + (smokeCycle * 3.0);

      canvas.drawCircle(
        Offset(smokeDriftX, smokeY),
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 + i),
      );
    }

    // Warehouse Bay Loading Shutter Door
    final bayX = blueLeft + 18;
    final bayY = blueTop + 36;
    final bayW = blueW * 0.54;
    final bayH = blueH - 36;

    // Bay Door Frame / Enclosure
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(bayX - 2, bayY - 2, bayW + 4, bayH + 2), const Radius.circular(8)),
      Paint()..color = const Color(0xFF0F172A),
    );

    // Roll-up Shutter Curtain
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(bayX, bayY, bayW, bayH), const Radius.circular(6)),
      Paint()..color = const Color(0xFF1E293B),
    );

    // Shutter Slats with Depth & Rivets
    final shutterPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.5;
    for (double y = bayY + 6; y < bayY + bayH; y += 7) {
      canvas.drawLine(Offset(bayX + 3, y), Offset(bayX + bayW - 3, y), shutterPaint);
      // Track rivet details
      canvas.drawCircle(Offset(bayX + 2, y), 0.75, Paint()..color = const Color(0xFF94A3B8));
      canvas.drawCircle(Offset(bayX + bayW - 2, y), 0.75, Paint()..color = const Color(0xFF94A3B8));
    }

    // Bay Signage Badge above loading dock
    _drawTextBadge(canvas, 'BAY 01 · DISPATCH', bayX + 4, bayY - 14, const Color(0xFF1E3A8A), const Color(0xFF93C5FD));

    // Pulsating Amber Warning Beacon above Shutter Door
    final beaconPulse = (math.sin(driveProgress * math.pi * 8) * 0.5 + 0.5);
    final beaconX = bayX + bayW * 0.5;
    final beaconY = bayY - 3;
    canvas.drawCircle(
      Offset(beaconX, beaconY),
      5.0,
      Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.35 + (beaconPulse * 0.45))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(Offset(beaconX, beaconY), 2.2, Paint()..color = const Color(0xFFFCD34D));

    // Security Keypad / Intercom Box on Bay Frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(bayX + bayW + 4, bayY + bayH * 0.4, 5, 8), const Radius.circular(1.5)),
      Paint()..color = const Color(0xFF334155),
    );
    canvas.drawCircle(Offset(bayX + bayW + 6.5, bayY + bayH * 0.4 + 2.5), 1.0, Paint()..color = const Color(0xFF10B981)); // Active Green LED

    // ------------------------------------------------------------------------
    // 6. FOREGROUND NATURE TREES & STREET LAMPS
    // ------------------------------------------------------------------------
    _drawRealisticPineTree(canvas, w * 0.01, h * 0.44, 1.25);
    _drawStreetLamp(canvas, w * 0.42, h * 0.58);
    _drawStreetLamp(canvas, w * 0.84, h * 0.58);

    // ------------------------------------------------------------------------
    // 7. ASPHALT ROAD WITH 3D CURB & DASHED LINES
    // ------------------------------------------------------------------------
    final roadTop = h * 0.74;
    final roadH = h * 0.26;

    // Roadside Nature Grass & Botanical Wildflowers along the curb
    _drawRoadsideVegetation(canvas, w, roadTop);

    // Road Shadow
    canvas.drawRect(
      Rect.fromLTWH(0, roadTop - 4, w, 4),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Concrete Curb Edge
    canvas.drawRect(
      Rect.fromLTWH(0, roadTop, w, 4),
      Paint()..color = const Color(0xFFB0BEC5),
    );

    // Asphalt Main Surface
    final roadPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF546E7A), Color(0xFF37474F)],
      ).createShader(Rect.fromLTWH(0, roadTop + 4, w, roadH - 4));
    canvas.drawRect(Rect.fromLTWH(0, roadTop + 4, w, roadH - 4), roadPaint);

    // White Center Dashed Markings with Retroreflective Cat's Eyes
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2.5;
    final dashOffset = (driveProgress * 32) % 32;
    for (double x = -dashOffset; x < w + 32; x += 32) {
      final markY = roadTop + (roadH * 0.5);
      canvas.drawLine(Offset(x, markY), Offset(x + 16, markY), dashPaint);
      // Amber Cat's Eye Reflector Stud at Dash Start
      canvas.drawCircle(Offset(x + 1, markY), 1.2, Paint()..color = const Color(0xFFFBBF24));
    }

    // ------------------------------------------------------------------------
    // 8. REALISTIC MOVING 3D DELIVERY TRUCK & DRIVER
    // ------------------------------------------------------------------------
    _drawUltraRealistic3DTruck(canvas, size, truckX, roadTop);
  }

  // ==========================================================================
  // ULTRA-REALISTIC 3D TRUCK & DRIVER DRAWING METHOD (DRIVING FORWARD RIGHT)
  // ==========================================================================
  void _drawUltraRealistic3DTruck(Canvas canvas, Size size, double tx, double roadTop) {
    final truckY = roadTop - 38;
    final cargoW = 100.0;
    final cargoH = 44.0;
    final cabW = 32.0;
    final cabH = cargoH - 8;
    final cabX = tx + cargoW; // Front Cab is on the RIGHT side facing forward!

    // Truck Drop Shadow on Asphalt
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tx - 6, truckY + cargoH + 2, cargoW + cabW + 12, 10),
        const Radius.circular(6),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Glowing Headlight Beam on Road (Projecting FORWARD to the Right)
    final beamPath = Path()
      ..moveTo(cabX + cabW, truckY + 20)
      ..lineTo(cabX + cabW + 68, truckY + 34)
      ..lineTo(cabX + cabW + 58, truckY + 44)
      ..lineTo(cabX + cabW, truckY + 30)
      ..close();
    canvas.drawPath(
      beamPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFEF08A).withValues(alpha: 0.65),
            const Color(0xFFFEF08A).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(cabX + cabW, truckY + 20, 68, 24)),
    );

    // ------------------------------------------------------------------------
    // A. UNDERCARRIAGE CHASSIS & DIESEL FUEL TANK
    // ------------------------------------------------------------------------
    // Steel Chassis Rail
    canvas.drawRect(
      Rect.fromLTWH(tx + 4, truckY + cargoH - 3, cargoW + cabW - 8, 4),
      Paint()..color = const Color(0xFF1E293B),
    );

    // Cylindrical Diesel Fuel Tank with Chrome Straps
    final tankX = tx + 36;
    final tankY = truckY + cargoH - 2;
    final tankW = 28.0;
    final tankH = 7.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tankX, tankY, tankW, tankH), const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF94A3B8), Color(0xFF475569), Color(0xFF334155)],
        ).createShader(Rect.fromLTWH(tankX, tankY, tankW, tankH)),
    );
    // Chrome straps on tank
    final strapPaint = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1.0;
    canvas.drawLine(Offset(tankX + 6, tankY), Offset(tankX + 6, tankY + tankH), strapPaint);
    canvas.drawLine(Offset(tankX + tankW - 6, tankY), Offset(tankX + tankW - 6, tankY + tankH), strapPaint);

    // ------------------------------------------------------------------------
    // B. CARGO BOX (Glossy Corrugated Amber Orange #E65B2B - TRAILING REAR)
    // ------------------------------------------------------------------------
    final cargoPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFA07A), Color(0xFFE65B2B), Color(0xFFB3360A)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(tx, truckY, cargoW, cargoH));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tx, truckY, cargoW, cargoH),
        const Radius.circular(8),
      ),
      cargoPaint,
    );

    // Metallic Roof Highlight Strip
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(tx, truckY, cargoW, 5),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFFFD1B3),
    );

    // 3D Corrugated Lines
    final groovePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.14)
      ..strokeWidth = 1.8;
    for (double gx = tx + 14; gx < tx + cargoW - 8; gx += 13) {
      canvas.drawLine(Offset(gx, truckY + 6), Offset(gx, truckY + cargoH - 6), groovePaint);
    }

    // Rear Cargo Door Locking Rods with Latch Handles (Trailing Rear Edge)
    final rodPaint = Paint()..color = const Color(0xFFCBD5E1)..strokeWidth = 1.4;
    canvas.drawLine(Offset(tx + 4, truckY + 5), Offset(tx + 4, truckY + cargoH - 5), rodPaint);
    canvas.drawLine(Offset(tx + 7, truckY + 5), Offset(tx + 7, truckY + cargoH - 5), rodPaint);
    // Door hinges
    canvas.drawRect(Rect.fromLTWH(tx + 2, truckY + 10, 3, 4), Paint()..color = const Color(0xFF64748B));
    canvas.drawRect(Rect.fromLTWH(tx + 2, truckY + cargoH - 14, 3, 4), Paint()..color = const Color(0xFF64748B));

    // Corner Protectors on Cargo Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tx, truckY, 6, 6), const Radius.circular(2)),
      Paint()..color = const Color(0xFF475569),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tx, truckY + cargoH - 6, 6, 6), const Radius.circular(2)),
      Paint()..color = const Color(0xFF475569),
    );

    // Rear Ruby-Red LED Taillight with Soft Glowing Aura
    canvas.drawCircle(
      Offset(tx - 1, truckY + cargoH - 8),
      4.5,
      Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tx - 2, truckY + cargoH - 11, 3, 6), const Radius.circular(1.5)),
      Paint()..color = const Color(0xFFDC2626),
    );

    // ------------------------------------------------------------------------
    // C. DRIVER CAB (Metallic Royal Blue #2B6CB0 - FORWARD LEADING FRONT)
    // ------------------------------------------------------------------------
    final cabY = truckY + 8;

    final cabPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF60A5FA), Color(0xFF2563EB), Color(0xFF1D4ED8)],
      ).createShader(Rect.fromLTWH(cabX, cabY, cabW, cabH));

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cabX, cabY, cabW, cabH),
        topRight: const Radius.circular(10),
        bottomRight: const Radius.circular(6),
      ),
      cabPaint,
    );

    // Driver Window Frame
    final winRect = Rect.fromLTWH(cabX + 8, cabY + 5, 16, 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(winRect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF1E293B), // Dark interior
    );

    // ------------------------------------------------------------------------
    // D. ANIMATED DRIVER CHARACTER SNEAKING OUT WINDOW & WAVING HAND 👋
    // ------------------------------------------------------------------------
    final driverHeadX = cabX + 15;
    final driverHeadY = cabY + 11;

    // Driver Skin Head
    canvas.drawCircle(Offset(driverHeadX, driverHeadY), 5.5, Paint()..color = const Color(0xFFFDBA74));

    // Driver Cap (#0C3B2E Deep Emerald)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(driverHeadX, driverHeadY - 1), radius: 5.5),
      3.14, 3.14, true,
      Paint()..color = AppColors.primaryColor,
    ); // Emerald Cap Dome
    canvas.drawRect(
      Rect.fromLTWH(driverHeadX + 1, driverHeadY - 3, 5, 2),
      Paint()..color = AppColors.primaryColor,
    ); // Cap Visor pointing FORWARD RIGHT

    // Smiling Face Eyes (facing right)
    canvas.drawCircle(Offset(driverHeadX + 2, driverHeadY - 1), 0.8, Paint()..color = Colors.black);

    // Waving Arm & Hand 👋 (waving outward to the right)
    final waveAngle = (waveProgress * 0.6) - 0.3; // Swing back and forth
    final armStartX = driverHeadX + 4;
    final armStartY = driverHeadY + 3;
    final armEndX = armStartX + 6 + (waveAngle * 6);
    final armEndY = armStartY - 6 + (waveAngle * 4);

    canvas.drawLine(
      Offset(armStartX, armStartY),
      Offset(armEndX, armEndY),
      Paint()
        ..color = AppColors.secondaryColor
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    ); // Uniform Sleeve
    canvas.drawCircle(
      Offset(armEndX, armEndY),
      2.5,
      Paint()..color = const Color(0xFFFDBA74),
    ); // Waving Hand

    // Glass Reflection on Window
    final streakPath = Path()
      ..moveTo(cabX + 9, cabY + 19)
      ..lineTo(cabX + 19, cabY + 7)
      ..lineTo(cabX + 23, cabY + 7)
      ..lineTo(cabX + 13, cabY + 19)
      ..close();
    canvas.drawPath(streakPath, Paint()..color = Colors.white.withValues(alpha: 0.35));

    // Aerodynamic Side View Mirror with Chrome Arm
    final mirrorPaint = Paint()..color = const Color(0xFFCBD5E1)..strokeWidth = 1.2;
    canvas.drawLine(Offset(cabX + 23, cabY + 13), Offset(cabX + 27, cabY + 11), mirrorPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cabX + 26, cabY + 8, 3.5, 7), const Radius.circular(1.5)),
      Paint()..color = const Color(0xFF334155),
    );

    // Chrome Front Grille Slats on Front Edge
    final grillePaint = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1.0;
    for (double gy = cabY + 16; gy < cabY + cabH - 6; gy += 3.5) {
      canvas.drawLine(Offset(cabX + cabW - 3, gy), Offset(cabX + cabW, gy), grillePaint);
    }

    // Lower Front Bumper & Fog Light
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cabX + cabW - 4, cabY + cabH - 5, 4, 3), const Radius.circular(1)),
      Paint()..color = const Color(0xFFFEF08A).withValues(alpha: 0.8),
    );

    // Headlight Lens Bulb (Front Right Edge)
    canvas.drawCircle(Offset(cabX + cabW - 2, cabY + cabH - 10), 3.5, Paint()..color = const Color(0xFFFEF08A));

    // ------------------------------------------------------------------------
    // E. 3D ROTATING WHEELS WITH 5-SPOKE ALLOY RIMS & RUBBER TREADS
    // ------------------------------------------------------------------------
    final wheelRotationAngle = driveProgress * math.pi * 12; // Dynamic rotation angle

    _draw3DRotatingWheel(canvas, tx + 20, truckY + cargoH + 1, wheelRotationAngle);
    _draw3DRotatingWheel(canvas, tx + 75, truckY + cargoH + 1, wheelRotationAngle);
    _draw3DRotatingWheel(canvas, cabX + 18, truckY + cargoH + 1, wheelRotationAngle);
  }

  // ==========================================================================
  // 3D ROTATING WHEEL WITH 5-SPOKE ALLOY STAR & TREAD DETAILED DRAWING
  // ==========================================================================
  void _draw3DRotatingWheel(Canvas canvas, double cx, double cy, double angle) {
    canvas.save();
    canvas.translate(cx, cy);

    // Rubber Tire Outer Ring with Tread Grip
    canvas.drawCircle(Offset.zero, 9.5, Paint()..color = const Color(0xFF0F172A));
    canvas.drawCircle(Offset.zero, 7.2, Paint()..color = const Color(0xFF334155));

    // Outer Rim Lip
    canvas.drawCircle(
      Offset.zero,
      6.8,
      Paint()
        ..color = const Color(0xFF94A3B8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Rotating 5-Spoke Stylized Alloy Star & Wheel Hub
    canvas.rotate(angle);

    final spokePaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final rad = i * (2 * math.pi / 5);
      final sx = 5.8 * math.cos(rad);
      final sy = 5.8 * math.sin(rad);
      canvas.drawLine(Offset.zero, Offset(sx, sy), spokePaint);

      // Chrome Lug Nut on Spoke Root
      final lx = 3.2 * math.cos(rad);
      final ly = 3.2 * math.sin(rad);
      canvas.drawCircle(Offset(lx, ly), 0.65, Paint()..color = const Color(0xFFCBD5E1));
    }

    // Center Alloy Hubcap Pin with Brand Emblem Core
    canvas.drawCircle(Offset.zero, 2.5, Paint()..color = const Color(0xFF64748B));
    canvas.drawCircle(Offset.zero, 1.2, Paint()..color = const Color(0xFF0F172A));

    canvas.restore();
  }

  // ==========================================================================
  // NATURE & SIGNAGE DETAILED HELPERS
  // ==========================================================================
  void _drawMigratingBirds(Canvas canvas, double w, double h, double progress) {
    final birdOffset = (progress * w * 0.15) % (w * 0.5);
    final birds = [
      Offset(w * 0.28 + birdOffset, h * 0.16),
      Offset(w * 0.31 + birdOffset, h * 0.14),
      Offset(w * 0.34 + birdOffset, h * 0.15),
      Offset(w * 0.37 + birdOffset, h * 0.17),
    ];

    final birdPaint = Paint()
      ..color = const Color(0xFF475569).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (final pt in birds) {
      final wingSpan = 3.5;
      final wingFlap = math.sin((progress * 20) + pt.dx) * 1.2;
      final birdPath = Path()
        ..moveTo(pt.dx - wingSpan, pt.dy + wingFlap)
        ..quadraticBezierTo(pt.dx - wingSpan * 0.5, pt.dy - 1.5, pt.dx, pt.dy)
        ..quadraticBezierTo(pt.dx + wingSpan * 0.5, pt.dy - 1.5, pt.dx + wingSpan, pt.dy + wingFlap);
      canvas.drawPath(birdPath, birdPaint);
    }
  }

  void _drawRoadsideVegetation(Canvas canvas, double w, double roadTop) {
    final grassPaint = Paint()
      ..color = const Color(0xFF4E9F6E)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Grass Tufts and Wildflowers along the curb
    final tuftPositions = [0.06, 0.14, 0.25, 0.39, 0.52, 0.68, 0.82, 0.93];
    for (final factor in tuftPositions) {
      final gx = w * factor;
      final gy = roadTop - 1;

      // 3 Blades of Grass per tuft
      canvas.drawLine(Offset(gx, gy), Offset(gx - 2.5, gy - 5), grassPaint);
      canvas.drawLine(Offset(gx, gy), Offset(gx, gy - 6.5), grassPaint);
      canvas.drawLine(Offset(gx, gy), Offset(gx + 2.5, gy - 5), grassPaint);

      // Wildflower Accent Dot
      if (factor == 0.14 || factor == 0.52 || factor == 0.82) {
        final flowerColor = factor == 0.14 ? const Color(0xFFF59E0B) : (factor == 0.52 ? const Color(0xFFEC4899) : const Color(0xFF38BDF8));
        canvas.drawCircle(Offset(gx, gy - 7.5), 1.5, Paint()..color = flowerColor);
      }
    }
  }

  void _drawTextBadge(Canvas canvas, String text, double x, double y, Color bg, Color fg) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: fg,
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = Rect.fromLTWH(x, y, tp.width + 8, tp.height + 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(3)),
      Paint()..color = bg.withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(x + 4, y + 1.5));
  }

  // ==========================================================================
  // NATURE TREES & STREET LAMPS DRAWING HELPERS
  // ==========================================================================
  void _drawRealisticPineTree(Canvas canvas, double tx, double ty, double scale) {
    canvas.save();
    canvas.translate(tx, ty);
    canvas.scale(scale);

    // Trunk
    canvas.drawRect(
      const Rect.fromLTWH(-3, 20, 6, 16),
      Paint()..color = const Color(0xFF4A2E1B),
    );

    // Layered Pine Foliage Cone Shapes
    for (int i = 0; i < 3; i++) {
      final topY = i * 8.0;
      final botY = 18.0 + (i * 6.0);
      final radius = 14.0 - (i * 2.5);

      final pinePath = Path()
        ..moveTo(0, topY)
        ..lineTo(-radius, botY)
        ..lineTo(radius, botY)
        ..close();

      final foliagePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4E9F6E - (i * 0x00101000)),
            Color(0xFF265E39 - (i * 0x00080800)),
          ],
        ).createShader(Rect.fromLTWH(-radius, topY, radius * 2, botY - topY));

      canvas.drawPath(pinePath, foliagePaint);
    }

    canvas.restore();
  }

  void _drawRealisticOakTree(Canvas canvas, double tx, double ty, double scale) {
    canvas.save();
    canvas.translate(tx, ty);
    canvas.scale(scale);

    // Trunk
    canvas.drawRect(
      const Rect.fromLTWH(-4, 18, 8, 18),
      Paint()..color = const Color(0xFF3E2723),
    );

    // Volumetric Oak Foliage Balls
    final oakPuffs = [
      const Offset(0, 0),
      const Offset(-10, 8),
      const Offset(10, 8),
      const Offset(0, 12),
    ];

    for (final p in oakPuffs) {
      canvas.drawCircle(
        p,
        13,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6BBA86), Color(0xFF2E6B43)],
          ).createShader(Rect.fromCircle(center: p, radius: 13)),
      );
    }

    canvas.restore();
  }

  void _drawStreetLamp(Canvas canvas, double lx, double ly) {
    // Pole
    canvas.drawLine(
      Offset(lx, ly),
      Offset(lx, ly + 36),
      Paint()
        ..color = const Color(0xFF475569)
        ..strokeWidth = 2.0,
    );
    // Lamp Head
    canvas.drawCircle(
      Offset(lx - 3, ly),
      3.5,
      Paint()..color = const Color(0xFFFEF08A),
    );
    // Glow Aura
    canvas.drawCircle(
      Offset(lx - 3, ly),
      8.0,
      Paint()
        ..color = const Color(0xFFFEF08A).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Downward Light Pool on Ground
    final lightPoolPath = Path()
      ..moveTo(lx - 12, ly + 36)
      ..lineTo(lx + 6, ly + 36)
      ..lineTo(lx + 16, ly + 46)
      ..lineTo(lx - 22, ly + 46)
      ..close();
    canvas.drawPath(
      lightPoolPath,
      Paint()
        ..color = const Color(0xFFFEF08A).withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _drawSpinningTurbine(Canvas canvas, double tx, double ty, double angle) {
    canvas.save();
    canvas.translate(tx, ty);

    // Base Dome Vent
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-8, 0, 16, 6), const Radius.circular(3)),
      Paint()..color = const Color(0xFF1E3A8A),
    );

    // Rotating Fan Blades
    canvas.rotate(angle);
    final bladePaint = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.85)
      ..strokeWidth = 2.0;

    for (int i = 0; i < 3; i++) {
      final a = i * (2 * 3.1415926535 / 3);
      canvas.drawLine(
        Offset.zero,
        Offset(7 * (a == 0 ? 1 : (a == 2.09439510239 ? -0.5 : -0.5)), 7 * (a == 0 ? 0 : (a == 2.09439510239 ? 0.866 : -0.866))),
        bladePaint,
      );
    }
    canvas.drawCircle(Offset.zero, 2.2, Paint()..color = const Color(0xFFE2E8F0));
    canvas.restore();
  }

  void _draw3DCloud(Canvas canvas, double cx, double cy, double scale) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);

    final cloudPuffs = [
      const Offset(0, 0),
      const Offset(12, -4),
      const Offset(24, 0),
      const Offset(14, 6),
    ];

    for (final p in cloudPuffs) {
      canvas.drawCircle(
        p,
        11,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Realistic3DFactoryPainter oldDelegate) {
    return oldDelegate.driveProgress != driveProgress ||
        oldDelegate.waveProgress != waveProgress ||
        oldDelegate.truckX != truckX;
  }
}

// ============================================================================
// COMPREHENSIVE PROJECT EXPORT MODAL DIALOG
// ============================================================================
class _ProjectExportModalDialog extends StatefulWidget {
  final List<ProjectMaster> projects;

  const _ProjectExportModalDialog({required this.projects});

  @override
  State<_ProjectExportModalDialog> createState() => _ProjectExportModalDialogState();
}

class _ProjectExportModalDialogState extends State<_ProjectExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'

  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<int> _selectedProjectCodes;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedProjectCodes = widget.projects.map((p) => p.prjCode).toSet();
    _modalSearchCtrl.addListener(() {
      setState(() {
        _modalSearchQuery = _modalSearchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _modalSearchCtrl.dispose();
    _exportTimer?.cancel();
    super.dispose();
  }

  List<ProjectMaster> get _filteredPreviewProjects {
    if (_modalSearchQuery.isEmpty) return widget.projects;
    return widget.projects.where((p) {
      final codeMatch = p.prjCode.toString().contains(_modalSearchQuery);
      final nameMatch = p.prjName.toLowerCase().contains(_modalSearchQuery);
      final dateMatch = p.dateCreated.toLowerCase().contains(_modalSearchQuery);
      return codeMatch || nameMatch || dateMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewProjects;
    if (preview.isEmpty) return false;
    return preview.every((p) => _selectedProjectCodes.contains(p.prjCode));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewProjects;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final p in preview) {
          _selectedProjectCodes.remove(p.prjCode);
        }
      } else {
        for (final p in preview) {
          _selectedProjectCodes.add(p.prjCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedProjectCodes.isEmpty) {
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    _exportTimer?.cancel();
    int currentStep = 0;
    _exportTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      currentStep++;
      final double progress = (currentStep / 20.0).clamp(0.0, 1.0);

      setState(() {
        _exportProgress = progress;
      });

      if (progress >= 1.0) {
        timer.cancel();
        _finalizeFileAndComplete();
      }
    });
  }

  Future<void> _openFileInSystemExplorer(String filePath) async {
    if (Platform.isWindows) {
      try {
        await Process.run('explorer.exe', ['/select,', filePath]);
        return;
      } catch (_) {}
    }
    try {
      final fileUri = Uri.file(filePath);
      await launchUrl(fileUri);
    } catch (_) {}
  }

  Future<void> _finalizeFileAndComplete() async {
    try {
      final selectedList = widget.projects
          .where((p) => _selectedProjectCodes.contains(p.prjCode))
          .toList();

      final String userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
      final String downloadsPath = '$userProfile\\Downloads';
      final Directory dir = Directory(downloadsPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'ProjectMaster_Export_$timestamp.$extension';
      final filePath = '$downloadsPath\\$fileName';

      final file = File(filePath);

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Project Master');
        final excel_pkg.Sheet sheet = excel['Project Master'];

        // Set Generous Column Widths (Prevents text clipping)
        sheet.setColumnWidth(0, 22.0); // PROJECT CODE
        sheet.setColumnWidth(1, 38.0); // PROJECT NAME
        sheet.setColumnWidth(2, 28.0); // DATE CREATED

        // Define Grid Cell Borders
        final cellBorder = excel_pkg.Border(
          borderStyle: excel_pkg.BorderStyle.Thin,
          borderColorHex: excel_pkg.ExcelColor.fromHexString('#CBD5E1'),
        );

        final excel_pkg.CellStyle headerStyle = excel_pkg.CellStyle(
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#0C3B2E'),
          fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
          bold: true,
          horizontalAlign: excel_pkg.HorizontalAlign.Center,
          verticalAlign: excel_pkg.VerticalAlign.Center,
          leftBorder: cellBorder,
          rightBorder: cellBorder,
          topBorder: cellBorder,
          bottomBorder: cellBorder,
        );

        final excel_pkg.CellStyle evenStyle = excel_pkg.CellStyle(
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#F8FAFC'),
          horizontalAlign: excel_pkg.HorizontalAlign.Center,
          verticalAlign: excel_pkg.VerticalAlign.Center,
          leftBorder: cellBorder,
          rightBorder: cellBorder,
          topBorder: cellBorder,
          bottomBorder: cellBorder,
        );

        final excel_pkg.CellStyle oddStyle = excel_pkg.CellStyle(
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign: excel_pkg.HorizontalAlign.Center,
          verticalAlign: excel_pkg.VerticalAlign.Center,
          leftBorder: cellBorder,
          rightBorder: cellBorder,
          topBorder: cellBorder,
          bottomBorder: cellBorder,
        );

        // Set Header Row Height & Append Headers
        sheet.setRowHeight(0, 26.0);
        sheet.appendRow([
          excel_pkg.TextCellValue('PROJECT CODE'),
          excel_pkg.TextCellValue('PROJECT NAME'),
          excel_pkg.TextCellValue('DATE CREATED'),
        ]);

        for (int col = 0; col < 3; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        // Append Data Rows with Heights & Styles
        for (int i = 0; i < selectedList.length; i++) {
          final p = selectedList[i];
          final style = (i % 2 == 0) ? evenStyle : oddStyle;
          final int rIdx = i + 1;

          sheet.setRowHeight(rIdx, 22.0);
          sheet.appendRow([
            excel_pkg.IntCellValue(p.prjCode),
            excel_pkg.TextCellValue(p.prjName),
            excel_pkg.TextCellValue(p.dateCreated.isNotEmpty ? p.dateCreated : '-'),
          ]);

          for (int col = 0; col < 3; col++) {
            sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
          }
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await file.writeAsBytes(fileBytes);
        }
      } else {
        final pdfDoc = pw.Document();

        pdfDoc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            maxPages: 1000,
            header: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'PROJECT MASTER REGISTER REPORT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF0C3B2E),
                      ),
                    ),
                    pw.Text(
                      'NEW TECH INFOSOL MMS',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Records: ${selectedList.length}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Exported on: ${DateTime.now().toString().split('.')[0]}',
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1, color: const PdfColor.fromInt(0xFF0C3B2E)),
                pw.SizedBox(height: 8),
              ],
            ),
            footer: (context) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by New Tech MMS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
            build: (context) => [
              pw.TableHelper.fromTextArray(
                headers: ['SR NO', 'PROJECT CODE', 'PROJECT NAME', 'DATE CREATED'],
                data: selectedList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final p = entry.value;
                  return [
                    '${idx + 1}',
                    '${p.prjCode}',
                    p.prjName,
                    p.dateCreated.isNotEmpty ? p.dateCreated : '-',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0C3B2E)),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8),
                  1: const pw.FlexColumnWidth(2.0),
                  2: const pw.FlexColumnWidth(5.0),
                  3: const pw.FlexColumnWidth(2.5),
                },
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF8FAFC),
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              ),
            ],
          ),
        );
        final pdfBytes = await pdfDoc.save();
        await file.writeAsBytes(pdfBytes);
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        // Quick 650ms delay for user to see the animated checkmark directly on the button
        await Future.delayed(const Duration(milliseconds: 650));

        if (!mounted) return;
        Navigator.of(context).pop();

        await _openFileInSystemExplorer(filePath);
      }
    } catch (e, stack) {
      debugPrint('Export project master failed: $e\n$stack');
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 920,
            height: 610,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.93),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.98), width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              // LEFT COLUMN: Format Selector & Options (440px)
              SizedBox(
                width: 440,
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF5EE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.sim_card_download_outlined, color: Color(0xFF0C3B2E), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Export Project Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              SizedBox(height: 2),
                              Text('Select format & download records to your PC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),

                      // Side-by-Side Format Cards (With Big 3D Excel & PDF Brand Logos)
                      Row(
                        children: [
                          Expanded(
                            child: _buildSideBySideCard(
                              formatKey: 'XLSX',
                              title: 'Excel (.xlsx)',
                              subtitle: 'Structured sheet with zebra rows',
                              logoWidget: const Excel3DBrandLogoWidget(size: 42),
                              brandColor: const Color(0xFF2E7D32),
                              bgColor: const Color(0xFFEAF5EE),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSideBySideCard(
                              formatKey: 'PDF',
                              title: 'PDF (.pdf)',
                              subtitle: 'Clean printable report document',
                              logoWidget: const Pdf3DBrandLogoWidget(size: 42),
                              brandColor: const Color(0xFFC62828),
                              bgColor: const Color(0xFFFFEBEE),
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      if (_isExporting) ...[
                        LinearProgressIndicator(
                          value: _exportProgress,
                          backgroundColor: AppColors.divider,
                          color: const Color(0xFF0C3B2E),
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Generating Export File... ${(_exportProgress * 100).toInt()}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12.5)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AnimatedSuccessButton(
                              status: _isExporting
                                  ? ButtonStatus.loading
                                  : (_isExportSuccess ? ButtonStatus.success : ButtonStatus.idle),
                              onPressed: _startExportProcess,
                              idleText: 'Download File',
                              loadingText: 'Exporting...',
                              successText: 'Exported!',
                              idleIcon: Icons.file_download_outlined,
                              idleBackgroundColor: const Color(0xFF0C3B2E),
                              successBackgroundColor: const Color(0xFF10B981),
                              height: 44,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
                    const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
                    Expanded(
                      flex: 7,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 26, 26, 26),
                        color: const Color(0xFFF8FAFC).withValues(alpha: 0.7),
                        child: Column(
                          children: [
                            _buildPreviewTableToolbar(),
                            const SizedBox(height: 14),
                            Expanded(child: _buildPreviewDataTable()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.06),
                      hoverColor: Colors.black.withValues(alpha: 0.12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.neutralDark, size: 18),
                    tooltip: 'Close Modal',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideBySideCard({
    required String formatKey,
    required String title,
    required String subtitle,
    required Widget logoWidget,
    required Color brandColor,
    required Color bgColor,
  }) {
    final isSelected = _selectedFormat == formatKey;

    return InkWell(
      onTap: _isExporting ? null : () => setState(() => _selectedFormat = formatKey),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? brandColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                logoWidget,
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: isSelected ? brandColor : Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? brandColor : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF64748B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTableToolbar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _modalSearchCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search records...',
                hintStyle: TextStyle(fontSize: 11.5, color: AppColors.neutralDark.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.secondaryColor),
                suffixIcon: _modalSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () => _modalSearchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            Checkbox(
              value: _isAllFilteredSelected,
              onChanged: (val) => _toggleSelectAllFiltered(),
              activeColor: AppColors.secondaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            const Text(
              'Select All',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_selectedProjectCodes.length} of ${widget.projects.length} selected',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
          ),
        ),
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final previewList = _filteredPreviewProjects;
    if (previewList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'No project records found',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              height: 40,
              color: const Color(0xFF0C3B2E),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const Row(
                children: [
                  SizedBox(width: 36, child: Text('SEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 80, child: Text('CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(child: Text('PROJECT NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 110, child: Text('DATE CREATED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final p = previewList[idx];
                  final isSelected = _selectedProjectCodes.contains(p.prjCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedProjectCodes.remove(p.prjCode);
                        } else {
                          _selectedProjectCodes.add(p.prjCode);
                        }
                      });
                    },
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      color: isSelected ? AppColors.secondaryColor.withValues(alpha: 0.04) : Colors.white,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Checkbox(
                              value: isSelected,
                              activeColor: AppColors.secondaryColor,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedProjectCodes.add(p.prjCode);
                                  } else {
                                    _selectedProjectCodes.remove(p.prjCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '${p.prjCode}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              p.prjName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(
                              p.dateCreated,
                              style: TextStyle(fontSize: 11, color: AppColors.neutralDark.withValues(alpha: 0.7)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
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

// ============================================================================
// AUTHENTIC VECTOR BRAND LOGO WIDGETS
// ============================================================================

/// Authentic 3D Microsoft Excel Brand Badge Logo
class Excel3DBrandLogoWidget extends StatelessWidget {
  final double size;
  const Excel3DBrandLogoWidget({super.key, this.size = 42.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF107C41).withValues(alpha: 0.38),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CustomPaint(
          size: Size(size, size),
          painter: _Excel3DLogoPainter(),
        ),
      ),
    );
  }
}

class _Excel3DLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient (Dark to medium Excel green)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F6C36), Color(0xFF107C41), Color(0xFF1F9A55)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Right side 3D Grid Panel (Lighter green sheet with white grid cells)
    final sheetPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
      ).createShader(Rect.fromLTWH(w * 0.42, 0, w * 0.58, h));

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.42, 0, w * 0.58, h), Radius.circular(w * 0.08)),
      sheetPaint,
    );

    // Grid lines
    final linePaint = Paint()
      ..color = const Color(0xFF107C41).withValues(alpha: 0.35)
      ..strokeWidth = w * 0.045;

    // Horizontal grid lines
    canvas.drawLine(Offset(w * 0.45, h * 0.28), Offset(w * 0.92, h * 0.28), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.50), Offset(w * 0.92, h * 0.50), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.72), Offset(w * 0.92, h * 0.72), linePaint);

    // Vertical grid line
    canvas.drawLine(Offset(w * 0.68, h * 0.12), Offset(w * 0.68, h * 0.88), linePaint);

    // 3D Elevated Left Block (Dark Green Front Plate)
    final platePath = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * 0.52, h), Radius.circular(w * 0.18)));

    // Shadow under left plate
    canvas.drawPath(
      platePath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final plateGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF185ABD), Color(0xFF107C41), Color(0xFF0E5C2F)],
        stops: [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w * 0.52, h));

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * 0.52, h), Radius.circular(w * 0.18)),
      plateGradient,
    );

    // Gloss highlight on top of plate
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w * 0.52, h * 0.4));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * 0.52, h * 0.4), Radius.circular(w * 0.18)),
      glossPaint,
    );

    // Bold Embossed White 'X'
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'X',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.62,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(1, 1.5),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.09, h * 0.08));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Authentic 3D Adobe PDF Brand Badge Logo
class Pdf3DBrandLogoWidget extends StatelessWidget {
  final double size;
  const Pdf3DBrandLogoWidget({super.key, this.size = 42.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.38),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CustomPaint(
          size: Size(size, size),
          painter: _Pdf3DLogoPainter(),
        ),
      ),
    );
  }
}

class _Pdf3DLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient (Deep Red Adobe gradient)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF3B30), Color(0xFFD32F2F), Color(0xFF8E0000)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 3D Folded Top Right Corner
    final foldPath = Path()
      ..moveTo(w * 0.70, 0)
      ..lineTo(w, h * 0.30)
      ..lineTo(w * 0.70, h * 0.30)
      ..close();

    final foldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF8A80), Color(0xFFB71C1C)],
      ).createShader(Rect.fromLTWH(w * 0.70, 0, w * 0.30, h * 0.30));

    canvas.drawPath(foldPath, foldPaint);

    // Fold Shadow
    final foldShadow = Path()
      ..moveTo(w * 0.70, h * 0.30)
      ..lineTo(w, h * 0.30)
      ..lineTo(w * 0.70, h * 0.40)
      ..close();
    canvas.drawPath(foldShadow, Paint()..color = Colors.black.withValues(alpha: 0.25));

    // Gloss Highlight Header
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.45));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.45), glossPaint);

    // Authentic Adobe Ribbon Curve / 'PDF' Text Badge
    final ribbonPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;

    final ribbonPath = Path();
    ribbonPath.moveTo(w * 0.22, h * 0.72);
    ribbonPath.cubicTo(w * 0.22, h * 0.38, w * 0.48, h * 0.35, w * 0.50, h * 0.55);
    ribbonPath.cubicTo(w * 0.52, h * 0.75, w * 0.78, h * 0.72, w * 0.78, h * 0.42);

    canvas.drawPath(
      ribbonPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.09
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.drawPath(ribbonPath, ribbonPaint);

    // PDF text at top
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.26,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0.8, 0.8),
              blurRadius: 1.5,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.22, h * 0.15));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// CONFIRM DELETE DIALOG (WITH IN-BUTTON ANIMATED DELETE CONFIRMATION)
// ============================================================================
class _ConfirmDeleteDialog extends StatefulWidget {
  final Future<bool> Function() onDelete;

  const _ConfirmDeleteDialog({
    required this.onDelete,
  });

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  ButtonStatus _status = ButtonStatus.idle;

  Future<void> _handleDelete() async {
    setState(() => _status = ButtonStatus.loading);
    try {
      final success = await widget.onDelete();
      if (!mounted) return;
      if (success) {
        setState(() => _status = ButtonStatus.success);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        setState(() => _status = ButtonStatus.idle);
      }
    } catch (_) {
      if (mounted) setState(() => _status = ButtonStatus.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 350,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Right Close X Button
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(false),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // 100% IDENTICAL IMAGE 2 VECTOR ILLUSTRATION (Person throwing red files into trash)
            SizedBox(
              width: 180,
              height: 130,
              child: CustomPaint(
                painter: _IdenticalDeleteDialogIllustrationPainter(),
              ),
            ),
            const SizedBox(height: 16),

            // Red Small Single Message Title matching exact user request
            const Text(
              'Are you sure you want to delete this',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons Row matching Image 2 (Delete on Left, Cancel on Right)
            Row(
              children: [
                // Red Delete Button (Left)
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: AnimatedSuccessButton(
                      status: _status,
                      onPressed: _handleDelete,
                      idleText: 'Delete',
                      loadingText: 'Deleting...',
                      successText: 'Deleted!',
                      idleIcon: Icons.delete_rounded,
                      idleBackgroundColor: const Color(0xFFEF4444),
                      successBackgroundColor: const Color(0xFFDC2626),
                      height: 40,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Soft Pink Cancel Button (Right)
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF0F2),
                        foregroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _status == ButtonStatus.loading ? null : () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED SUCCESS BUTTON WIDGET (PREMIUM CONFETTI BURST + RIPPLE ANIMATION)
// ============================================================================
enum ButtonStatus { idle, loading, success }

class AnimatedSuccessButton extends StatefulWidget {
  final ButtonStatus status;
  final VoidCallback? onPressed;
  final String idleText;
  final String loadingText;
  final String successText;
  final IconData idleIcon;
  final Color idleBackgroundColor;
  final Color successBackgroundColor;
  final double height;

  const AnimatedSuccessButton({
    super.key,
    required this.status,
    required this.onPressed,
    required this.idleText,
    this.loadingText = 'Processing...',
    this.successText = 'Success!',
    this.idleIcon = Icons.save_rounded,
    this.idleBackgroundColor = const Color(0xFF0C3B2E),
    this.successBackgroundColor = const Color(0xFF10B981),
    this.height = 44,
  });

  @override
  State<AnimatedSuccessButton> createState() => _AnimatedSuccessButtonState();
}

class _AnimatedSuccessButtonState extends State<AnimatedSuccessButton>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _rippleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _checkController, curve: Curves.easeOut));

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.02), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _checkController, curve: Curves.easeInOut));

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 60),
    ]).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeOut));

    if (widget.status == ButtonStatus.success) {
      _triggerSuccess();
    }
  }

  void _triggerSuccess() {
    _checkController.forward(from: 0.0);
    _rippleController.forward(from: 0.0);
    _glowController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant AnimatedSuccessButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == ButtonStatus.success && oldWidget.status != ButtonStatus.success) {
      _triggerSuccess();
    } else if (widget.status == ButtonStatus.idle) {
      _checkController.reset();
      _rippleController.reset();
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    _rippleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.status == ButtonStatus.success;
    final isLoading = widget.status == ButtonStatus.loading;

    return AnimatedBuilder(
      animation: Listenable.merge([_checkController, _rippleController, _glowController]),
      builder: (context, child) {
        return Transform.scale(
          scale: isSuccess ? _bounceAnimation.value : 1.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Ripple burst ring
              if (isSuccess)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: (1.0 - _rippleAnimation.value).clamp(0.0, 1.0),
                      duration: const Duration(milliseconds: 100),
                      child: Transform.scale(
                        scale: 1.0 + (_rippleAnimation.value * 0.25),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: widget.successBackgroundColor.withValues(alpha: 0.6),
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Main button body
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: isSuccess
                      ? LinearGradient(
                          colors: [
                            widget.successBackgroundColor,
                            widget.successBackgroundColor.withValues(alpha: 0.85),
                            const Color(0xFF059669),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSuccess
                      ? null
                      : (widget.onPressed == null
                          ? widget.idleBackgroundColor.withValues(alpha: 0.6)
                          : widget.idleBackgroundColor),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    if (isSuccess)
                      BoxShadow(
                        color: widget.successBackgroundColor
                            .withValues(alpha: 0.3 + (_glowAnimation.value * 0.35)),
                        blurRadius: 8 + (_glowAnimation.value * 16),
                        spreadRadius: _glowAnimation.value * 3,
                        offset: const Offset(0, 2),
                      )
                    else
                      BoxShadow(
                        color: widget.idleBackgroundColor.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (isLoading || isSuccess) ? null : widget.onPressed,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          else if (isSuccess)
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: const Icon(Icons.check_circle_rounded, size: 22, color: Colors.white),
                            )
                          else
                            Icon(widget.idleIcon, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              isLoading
                                  ? widget.loadingText
                                  : (isSuccess ? widget.successText : widget.idleText),
                              key: ValueKey<String>(
                                isLoading
                                    ? 'loading'
                                    : (isSuccess ? 'success' : widget.idleText),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Sparkle particles
              if (isSuccess) ...List.generate(6, (i) {
                final angle = (i * 60.0) * (3.14159 / 180.0);
                final distance = 18.0 + (_rippleAnimation.value * 22.0);
                return Positioned(
                  left: (widget.height / 2) - 3 + (distance * math.cos(angle)),
                  top: (widget.height / 2) - 3 + (distance * math.sin(angle)),
                  child: AnimatedOpacity(
                    opacity: (1.0 - _rippleAnimation.value).clamp(0.0, 1.0),
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? Colors.white
                            : widget.successBackgroundColor.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.successBackgroundColor.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// 100% IDENTICAL IMAGE 2 VECTOR ILLUSTRATION
class _IdenticalDeleteDialogIllustrationPainter extends CustomPainter {
  const _IdenticalDeleteDialogIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Soft Oval Ground Shadow
    final shadowPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawOval(Rect.fromLTWH(w * 0.12, h * 0.78, w * 0.76, h * 0.12), shadowPaint);

    // 2. Background Windows (Light Stroke Rounded Rectangles)
    final windowPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // Left Window (With 4 Grid Panes)
    final leftWin = Rect.fromLTWH(w * 0.22, h * 0.16, w * 0.24, h * 0.38);
    canvas.drawRRect(RRect.fromRectAndRadius(leftWin, const Radius.circular(3)), windowPaint);
    canvas.drawLine(Offset(leftWin.left + leftWin.width / 2, leftWin.top), Offset(leftWin.left + leftWin.width / 2, leftWin.bottom), windowPaint);
    canvas.drawLine(Offset(leftWin.left, leftWin.top + leftWin.height / 2), Offset(leftWin.right, leftWin.top + leftWin.height / 2), windowPaint);

    // Right Window (Single Frame)
    final rightWin = Rect.fromLTWH(w * 0.54, h * 0.20, w * 0.22, h * 0.28);
    canvas.drawRRect(RRect.fromRectAndRadius(rightWin, const Radius.circular(3)), windowPaint);

    // 3. Red Trash Bin (Right Side)
    final binBody = Path()
      ..moveTo(w * 0.60, h * 0.48)
      ..lineTo(w * 0.80, h * 0.48)
      ..lineTo(w * 0.77, h * 0.86)
      ..lineTo(w * 0.63, h * 0.86)
      ..close();
    canvas.drawPath(binBody, Paint()..color = const Color(0xFFEF4444));

    // Trash bin vertical stripe lines
    final stripePaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(w * 0.65, h * 0.50), Offset(w * 0.66, h * 0.84), stripePaint);
    canvas.drawLine(Offset(w * 0.70, h * 0.50), Offset(w * 0.70, h * 0.84), stripePaint);
    canvas.drawLine(Offset(w * 0.75, h * 0.50), Offset(w * 0.74, h * 0.84), stripePaint);

    // Trash bin top rim
    final binLid = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.58, h * 0.44, w * 0.24, h * 0.06), const Radius.circular(3));
    canvas.drawRRect(binLid, Paint()..color = const Color(0xFFEF4444));

    // 4. Person Figure (Standing Left Side)
    final skinPaint = Paint()..color = const Color(0xFFFFCCBC);
    final hairPaint = Paint()..color = const Color(0xFF0F172A);
    final coralShirtPaint = Paint()..color = const Color(0xFFEF4444);
    final navyPantsPaint = Paint()..color = const Color(0xFF1E293B);

    // Head (Peach Face + Black Hair Cap)
    final headCenter = Offset(w * 0.38, h * 0.32);
    canvas.drawCircle(headCenter, w * 0.07, skinPaint);
    final hairPath = Path()
      ..addArc(Rect.fromCircle(center: headCenter, radius: w * 0.07), math.pi, math.pi);
    canvas.drawPath(hairPath, hairPaint);

    // Torso (Coral Red Shirt)
    canvas.drawRect(Rect.fromLTWH(w * 0.33, h * 0.39, w * 0.10, h * 0.18), coralShirtPaint);

    // Arms extending over to the trash bin
    final armPath = Path()
      ..moveTo(w * 0.38, h * 0.41)
      ..lineTo(w * 0.55, h * 0.37)
      ..lineTo(w * 0.55, h * 0.44)
      ..lineTo(w * 0.38, h * 0.48)
      ..close();
    canvas.drawPath(armPath, coralShirtPaint);

    // Red block/paper in hand going into bin
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.53, h * 0.41, 14, 10), const Radius.circular(2)), Paint()..color = const Color(0xFFF87171));

    // Legs (Dark Navy)
    canvas.drawRect(Rect.fromLTWH(w * 0.33, h * 0.57, w * 0.04, h * 0.25), navyPantsPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.39, h * 0.57, w * 0.04, h * 0.25), navyPantsPaint);

    // Red Shoes
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.31, h * 0.81, w * 0.07, h * 0.04), const Radius.circular(2)), coralShirtPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.38, h * 0.81, w * 0.07, h * 0.04), const Radius.circular(2)), coralShirtPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
