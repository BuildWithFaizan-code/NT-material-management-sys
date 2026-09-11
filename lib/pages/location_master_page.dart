import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import '../design/app_colors.dart';
import '../services/location_service.dart';

// ============================================================================
// DATA MODEL: LocationMaster
// ============================================================================
class LocationMaster {
  final int locCode;
  final String locName;
  final String locPrefix;
  final String locSeries;
  final String createdDate;

  LocationMaster({
    required this.locCode,
    required this.locName,
    String? locPrefix,
    String? locSeries,
    String? createdDate,
  })  : locPrefix = locPrefix ?? 'Location',
        locSeries = locSeries ?? '',
        createdDate = formatDisplayDate(createdDate);

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

  factory LocationMaster.fromJson(Map<String, dynamic> json) {
    return LocationMaster(
      locCode: json['locCode'] is int
          ? json['locCode']
          : (json['LocCode'] is int
              ? json['LocCode']
              : int.tryParse(json['locCode']?.toString() ?? json['LocCode']?.toString() ?? '0') ?? 0),
      locName: json['locName'] as String? ?? json['LocName'] as String? ?? '',
      locPrefix: json['locPrefix'] as String? ?? json['LocPrefix'] as String? ?? 'Location',
      locSeries: json['locSeries'] as String? ?? json['LocSeries'] as String? ?? '',
      createdDate: formatDisplayDate(json['createdDate'] ?? json['CreatedDate']),
    );
  }

  Map<String, dynamic> toJson() => {
        'locCode': locCode,
        'locName': locName,
        'locPrefix': locPrefix,
        'locSeries': locSeries,
        'createdDate': createdDate,
      };

  LocationMaster copyWith({
    int? locCode,
    String? locName,
    String? locPrefix,
    String? locSeries,
    String? createdDate,
  }) {
    return LocationMaster(
      locCode: locCode ?? this.locCode,
      locName: locName ?? this.locName,
      locPrefix: locPrefix ?? this.locPrefix,
      locSeries: locSeries ?? this.locSeries,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}

// ============================================================================
// MAIN PAGE: LocationMasterPage (Standardized App Color Palette & Spacing)
// ============================================================================
class LocationMasterPage extends StatefulWidget {
  final LocationService? locationService;
  const LocationMasterPage({super.key, this.locationService});

  @override
  State<LocationMasterPage> createState() => _LocationMasterPageState();
}

class _LocationMasterPageState extends State<LocationMasterPage> {
  late final LocationService _locationService;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<LocationMaster> _locations = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  int? _glowingLocCode;
  bool _isGlowingEdit = false;
  Timer? _glowTimer;
  Timer? _debounceTimer;
  final ScrollController _tableScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? LocationService();
    _fetchLocations();
    _searchCtrl.addListener(() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() {
            _searchQuery = _searchCtrl.text.trim().toLowerCase();
          });
          _updateFilteredLocations();
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
    _tableScrollCtrl.dispose();
    super.dispose();
  }

  void _triggerGlow(int locCode, {bool isEdit = false}) {
    _glowTimer?.cancel();
    setState(() {
      _glowingLocCode = locCode;
      _isGlowingEdit = isEdit;
    });

    // Smooth auto-scroll to the newly saved/updated record
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tableScrollCtrl.hasClients) {
        final idx = _filteredLocations.indexWhere((l) => l.locCode == locCode);
        if (idx != -1) {
          final targetOffset = (idx * 54.0) - 60.0;
          _tableScrollCtrl.animateTo(
            targetOffset.clamp(0.0, _tableScrollCtrl.position.maxScrollExtent),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });

    _glowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _glowingLocCode = null;
          _isGlowingEdit = false;
        });
      }
    });
  }

  /// Live End-to-End API Fetch
  Future<void> _fetchLocations({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await _locationService.fetchLocations();
      if (mounted) {
        setState(() {
          _locations = data;
          _isLoading = false;
        });
        _updateFilteredLocations();
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

  List<LocationMaster> _cachedFilteredLocations = [];

  void _updateFilteredLocations() {
    if (_searchQuery.isEmpty) {
      _cachedFilteredLocations = List.from(_locations);
    } else {
      _cachedFilteredLocations = _locations.where((l) {
        final codeMatch = l.locCode.toString().contains(_searchQuery);
        final nameMatch = l.locName.toLowerCase().contains(_searchQuery);
        final prefixMatch = l.locPrefix.toLowerCase().contains(_searchQuery);
        final dateMatch = l.createdDate.toLowerCase().contains(_searchQuery);
        return codeMatch || nameMatch || prefixMatch || dateMatch;
      }).toList();
    }
  }

  List<LocationMaster> get _filteredLocations => _cachedFilteredLocations;

  void _showLocationFormDrawer({LocationMaster? locationToEdit}) async {
    int nextCode = 1;
    if (locationToEdit == null) {
      nextCode = await _locationService.fetchNextCode();
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
            child: _FloatingLocationFormDrawer(
              location: locationToEdit,
              nextCode: nextCode,
              locationService: _locationService,
              onSuccess: (savedLoc, isEdit) async {
                await _fetchLocations(showLoading: false); // Live Silent Refresh from DB
                _triggerGlow(savedLoc.locCode, isEdit: isEdit);
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

  Future<void> _confirmDelete(LocationMaster location) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () => _locationService.deleteLocation(location.locCode),
      ),
    );

    if (deleted == true) {
      await _fetchLocations();
    }
  }

  void _showComprehensiveExportModal() {
    showDialog(
      context: context,
      builder: (ctx) => _LocationExportModalDialog(locations: _filteredLocations),
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
                    // Department Master Style Glassmorphism Top Header Bar
                    _buildTopHeaderBar(),
                    const SizedBox(height: 14),

                    // Main Content Body (Department Master Full-Width Data Table Desk)
                    Expanded(
                      child: _isLoading
                          ? _buildShimmerLoading()
                          : (_errorMessage != null
                              ? _buildErrorState()
                              : (_filteredLocations.isEmpty
                                  ? _buildEmptyState()
                                  : _buildMainDataGridDesk())),
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

  // ============================================================================
  // 1. TOP HEADER BAR (DEPARTMENT MASTER STYLE WITH LANDSCAPE LOGO & MAIN GREEN BUTTON)
  // ============================================================================
  Widget _buildTopHeaderBar() {
    final totalLocations = _locations.length;
    final activeSeriesCount = _locations.where((l) => l.locPrefix.isNotEmpty).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xF2FFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Image 1 Vector Landscape Logo + Title & Subtitle (Left) + Colorful KPI Pills (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // Image 1 Vector Map Landscape Logo Emblem (Big & Clearly Visible)
                        const _LocationLandscapeLogoWidget(size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Location Master',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Manage enterprise physical facilities, warehouses & spatial node registers',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // KPI Graph Cards (Image 2 Style - Green & Dark Green)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LocationKpiGraphCard(
                        label: 'Total Locations',
                        value: totalLocations.toString(),
                        gradientColors: const [
                          Color(0xFF10B981), // Fresh Emerald Green
                          Color(0xFF059669), // Rich Medium Green
                        ],
                        graphType: _LocationGraphType.locations,
                      ),
                      const SizedBox(width: 10),
                      _LocationKpiGraphCard(
                        label: 'Active Series',
                        value: activeSeriesCount.toString(),
                        gradientColors: const [
                          Color(0xFF047857), // Deep Forest Green
                          Color(0xFF064E3B), // Dark Pine Green
                        ],
                        graphType: _LocationGraphType.series,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Row 2: Search Bar (Left) + Export & Main Green New Location Button (Right)
              Row(
                children: [
                  // Search Field
                  SizedBox(
                    width: 290,
                    height: 38,
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.neutralDark),
                      decoration: InputDecoration(
                        hintText: 'Search locations... (Ctrl+K)',
                        hintStyle: TextStyle(fontSize: 11, color: AppColors.neutralDark.withValues(alpha: 0.5)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF10B981)),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 13),
                                onPressed: () => _searchCtrl.clear(),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Export Button
                  _AnimatedExportButton(onPressed: _showComprehensiveExportModal),

                  const SizedBox(width: 10),

                  // Primary "+ Add New Location" Button (Matching Project Master AppColors.secondaryColor)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondaryColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _showLocationFormDrawer(),
                      icon: const Icon(Icons.add_location_alt_rounded, size: 16, color: Colors.white),
                      label: const Text(
                        '+ Add New Location',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryColor, // Exact Sage Green #6D9773 from Project Master
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  // ============================================================================
  // 2. MAIN DATA GRID DESK (FULL-WIDTH DATA TABLE LIKE DEPARTMENT MASTER)
  // ============================================================================
  Widget _buildMainDataGridDesk() {
    final displayList = _filteredLocations;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Sheet Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                const _IdenticalLocationPinLogoWidget(size: 26),
                const SizedBox(width: 10),
                const Text(
                  'Location',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${displayList.length} Records',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
          ),

          // Responsive Data Grid Columns + Scrollable Rows
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = math.max(constraints.maxWidth, 850.0);

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        children: [
                          // Column Header Bar
                          Container(
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 150,
                                  child: Row(
                                    children: [
                                      Icon(Icons.tag_rounded, size: 13, color: Color(0xFF6366F1)),
                                      SizedBox(width: 3),
                                      Text('CODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFF43F5E)),
                                      SizedBox(width: 5),
                                      Text('LOCATION NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Icon(Icons.bookmark_rounded, size: 13, color: Color(0xFFF59E0B)),
                                      SizedBox(width: 5),
                                      Text('PREFIX SERIES', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                SizedBox(
                                  width: 130,
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF06B6D4)),
                                      SizedBox(width: 5),
                                      Text('DATE CREATED', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                SizedBox(
                                  width: 80,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.settings_outlined, size: 13, color: Color(0xFF64748B)),
                                      SizedBox(width: 3),
                                      Text('ACTIONS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Rows List
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _fetchLocations,
                              child: ListView.builder(
                                controller: _tableScrollCtrl,
                                itemCount: displayList.length,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
                                itemBuilder: (ctx, index) {
                                  final location = displayList[index];
                                  final isGlowing = _glowingLocCode == location.locCode;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: _UniqueLocationRowCard(
                                      location: location,
                                      isGlowing: isGlowing,
                                      isGlowingEdit: isGlowing && _isGlowingEdit,
                                      onEdit: () => _showLocationFormDrawer(locationToEdit: location),
                                      onDelete: () => _confirmDelete(location),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
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
            onPressed: _fetchLocations,
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
              Icons.location_off_outlined,
              size: 40,
              color: AppColors.secondaryColor,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Locations Found',
            style: TextStyle(
              color: AppColors.neutralDark,
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'No location matching "$_searchQuery". Try clearing your search.'
                : 'Get started by adding your first Location Master record.',
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
                _showLocationFormDrawer();
              }
            },
            icon: Icon(_searchQuery.isNotEmpty ? Icons.clear_rounded : Icons.add_location_alt_rounded, size: 16),
            label: Text(_searchQuery.isNotEmpty ? 'Clear Search' : 'Add Location', style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SLEEK KPI GRAPH CARD WIDGET (REFERENCE IMAGE 2 STYLE - GREEN & DARK GREEN)
// ============================================================================
enum _LocationGraphType { locations, series }

class _LocationKpiGraphCard extends StatefulWidget {
  final String label;
  final String value;
  final List<Color> gradientColors;
  final _LocationGraphType graphType;
  static const double cardWidth = 175;
  static const double cardHeight = 52;

  const _LocationKpiGraphCard({
    required this.label,
    required this.value,
    required this.gradientColors,
    required this.graphType,
  });

  @override
  State<_LocationKpiGraphCard> createState() => _LocationKpiGraphCardState();
}

class _LocationKpiGraphCardState extends State<_LocationKpiGraphCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.gradientColors.last;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: _LocationKpiGraphCard.cardWidth,
        height: _LocationKpiGraphCard.cardHeight,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: _isHovered ? 0.38 : 0.22),
              blurRadius: _isHovered ? 12 : 6,
              offset: Offset(0, _isHovered ? 3.5 : 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Right Side: 3D Translucent Vector Graphic & Sleek Graph
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 65,
              child: CustomPaint(
                painter: _LocationKpiGraphPainter(
                  graphType: widget.graphType,
                  isHovered: _isHovered,
                ),
              ),
            ),
            // Left Side: Label on Top, Bold Metric Value on Bottom
            Positioned.fill(
              right: 68,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        height: 1.05,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationKpiGraphPainter extends CustomPainter {
  final _LocationGraphType graphType;
  final bool isHovered;

  const _LocationKpiGraphPainter({
    required this.graphType,
    required this.isHovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Subtle 3D Translucent Vector Silhouette (Image 2 style)
    if (graphType == _LocationGraphType.locations) {
      // 3D Facility / Spatial Building footprint on right
      final bldgPaint = Paint()..color = Colors.white.withValues(alpha: isHovered ? 0.22 : 0.15);
      final bldgStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withValues(alpha: isHovered ? 0.35 : 0.22);

      // 3D Isometric building box
      final bX = w * 0.40;
      final bY = h * 0.18;
      final bW = 26.0;
      final bH = 26.0;
      final bD = 8.0;

      // Front
      final frontRect = Rect.fromLTWH(bX, bY, bW, bH);
      canvas.drawRect(frontRect, bldgPaint);
      canvas.drawRect(frontRect, bldgStroke);

      // Side
      final sidePath = Path()
        ..moveTo(bX + bW, bY)
        ..lineTo(bX + bW + bD, bY - bD * 0.5)
        ..lineTo(bX + bW + bD, bY + bH - bD * 0.5)
        ..lineTo(bX + bW, bY + bH)
        ..close();
      canvas.drawPath(sidePath, Paint()..color = Colors.white.withValues(alpha: isHovered ? 0.16 : 0.10));
      canvas.drawPath(sidePath, bldgStroke);

      // Top
      final topPath = Path()
        ..moveTo(bX, bY)
        ..lineTo(bX + bD, bY - bD * 0.5)
        ..lineTo(bX + bW + bD, bY - bD * 0.5)
        ..lineTo(bX + bW, bY)
        ..close();
      canvas.drawPath(topPath, Paint()..color = Colors.white.withValues(alpha: isHovered ? 0.28 : 0.18));
      canvas.drawPath(topPath, bldgStroke);

      // Window grid on building
      final winPaint = Paint()..color = Colors.white.withValues(alpha: isHovered ? 0.40 : 0.26);
      for (double r = bY + 4; r <= bY + bH - 6; r += 7) {
        canvas.drawRect(Rect.fromLTWH(bX + 4, r, 5, 4), winPaint);
        canvas.drawRect(Rect.fromLTWH(bX + 11, r, 5, 4), winPaint);
        canvas.drawRect(Rect.fromLTWH(bX + 18, r, 5, 4), winPaint);
      }
    } else {
      // 3D Tag / Register Silhouette
      final tagPaint = Paint()..color = Colors.white.withValues(alpha: isHovered ? 0.20 : 0.14);
      final tagStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withValues(alpha: isHovered ? 0.35 : 0.22);

      final tX = w * 0.42;
      final tY = h * 0.20;
      final tW = 25.0;
      final tH = 24.0;

      // 3D Tag block
      final frontTag = Path()
        ..moveTo(tX + 7, tY)
        ..lineTo(tX + tW, tY)
        ..lineTo(tX + tW, tY + tH)
        ..lineTo(tX, tY + tH)
        ..lineTo(tX, tY + 7)
        ..close();
      canvas.drawPath(frontTag, tagPaint);
      canvas.drawPath(frontTag, tagStroke);

      // Tag hole
      canvas.drawCircle(Offset(tX + 6, tY + 6), 2.2, Paint()..color = Colors.white.withValues(alpha: isHovered ? 0.38 : 0.25));

      // Barcode lines on tag
      final barPaint = Paint()
        ..color = Colors.white.withValues(alpha: isHovered ? 0.38 : 0.24)
        ..strokeWidth = 1.2;
      for (double bx = tX + 5; bx <= tX + tW - 4; bx += 3.5) {
        canvas.drawLine(Offset(bx, tY + 12), Offset(bx, tY + tH - 4), barPaint);
      }
    }

    // 2. High-Precision Curved Sparkline Graph with Translucent Area Fill
    final padL = 3.0;
    final padR = 3.0;
    final padT = 7.0;
    final padB = 4.0;
    final usableW = w - padL - padR;
    final usableH = h - padT - padB;

    final List<Offset> normalizedPoints;
    if (graphType == _LocationGraphType.locations) {
      normalizedPoints = const [
        Offset(0.00, 0.78),
        Offset(0.32, 0.52),
        Offset(0.68, 0.38),
        Offset(1.00, 0.12),
      ];
    } else {
      normalizedPoints = const [
        Offset(0.00, 0.70),
        Offset(0.30, 0.30),
        Offset(0.65, 0.48),
        Offset(1.00, 0.14),
      ];
    }

    final pixelPoints = normalizedPoints.map((p) {
      return Offset(padL + p.dx * usableW, padT + p.dy * usableH);
    }).toList();

    // Area Fill Path
    final areaPath = Path();
    areaPath.moveTo(pixelPoints.first.dx, h);
    areaPath.lineTo(pixelPoints.first.dx, pixelPoints.first.dy);

    for (int i = 0; i < pixelPoints.length - 1; i++) {
      final p0 = pixelPoints[i];
      final p1 = pixelPoints[i + 1];
      final cx1 = p0.dx + (p1.dx - p0.dx) / 2;
      final cy1 = p0.dy;
      final cx2 = p0.dx + (p1.dx - p0.dx) / 2;
      final cy2 = p1.dy;
      areaPath.cubicTo(cx1, cy1, cx2, cy2, p1.dx, p1.dy);
    }
    areaPath.lineTo(pixelPoints.last.dx, h);
    areaPath.close();

    final areaGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: isHovered ? 0.32 : 0.20),
        Colors.white.withValues(alpha: 0.0),
      ],
    );
    canvas.drawPath(areaPath, Paint()..shader = areaGradient.createShader(Rect.fromLTWH(0, 0, w, h)));

    // Line Path
    final linePath = Path();
    linePath.moveTo(pixelPoints.first.dx, pixelPoints.first.dy);
    for (int i = 0; i < pixelPoints.length - 1; i++) {
      final p0 = pixelPoints[i];
      final p1 = pixelPoints[i + 1];
      final cx1 = p0.dx + (p1.dx - p0.dx) / 2;
      final cy1 = p0.dy;
      final cx2 = p0.dx + (p1.dx - p0.dx) / 2;
      final cy2 = p1.dy;
      linePath.cubicTo(cx1, cy1, cx2, cy2, p1.dx, p1.dy);
    }

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawPath(linePath, linePaint);

    // Circular Ring Nodes along the sparkline (Image 2 style)
    final nodeFillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final nodeStrokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (final pt in pixelPoints) {
      canvas.drawCircle(pt, 3.2, nodeFillPaint);
      canvas.drawCircle(pt, 3.2, nodeStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LocationKpiGraphPainter oldDelegate) {
    return oldDelegate.graphType != graphType || oldDelegate.isHovered != isHovered;
  }
}

// ============================================================================
// ANIMATED EXPORT BUTTON (Circulating Edge Light Orbit Animation)
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
// LOCATION ROW CARD (Compact Code Badge, Red Pin Markdown, Distinct Actions)
// ============================================================================
class _UniqueLocationRowCard extends StatefulWidget {
  final LocationMaster location;
  final bool isGlowing;
  final bool isGlowingEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UniqueLocationRowCard({
    required this.location,
    this.isGlowing = false,
    this.isGlowingEdit = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_UniqueLocationRowCard> createState() => _UniqueLocationRowCardState();
}

class _UniqueLocationRowCardState extends State<_UniqueLocationRowCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  AnimationController? _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isGlowing) {
      _initGlow();
    } else {
      _glowAnimation = const AlwaysStoppedAnimation(0.0);
    }
  }

  void _initGlow() {
    if (_glowController == null) {
      _glowController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      );
      _glowAnimation = Tween<double>(begin: 0.25, end: 0.70).animate(
        CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
      );
    }
    _glowController!.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _UniqueLocationRowCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGlowing != oldWidget.isGlowing) {
      if (widget.isGlowing) {
        _initGlow();
      } else {
        _glowController?.stop();
        _glowController?.reset();
      }
    }
  }

  @override
  void dispose() {
    _glowController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedCode = widget.location.locCode < 10
        ? '#0${widget.location.locCode}'
        : '#${widget.location.locCode}';

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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.isGlowing
                    ? glowBgColor
                    : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isGlowing
                      ? glowColor
                      : (_isHovered ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                  width: widget.isGlowing ? 2.0 : (_isHovered ? 1.4 : 1.0),
                ),
                boxShadow: widget.isGlowing
                    ? [
                        BoxShadow(
                          color: glowColor.withValues(alpha: glowAlpha),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : (_isHovered
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.08),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]),
              ),
              child: Row(
                children: [
                  // Left Hover/Glow Accent Bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: widget.isGlowing ? 4.5 : 3.5,
                    height: 22,
                    decoration: BoxDecoration(
                      color: (widget.isGlowing || _isHovered)
                          ? (widget.isGlowing ? glowColor : const Color(0xFF10B981))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // CODE Badge + NEW / UPDATED Star Badge (Fixed Width 150)
                  SizedBox(
                    width: 150,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC7D2FE), width: 1.2),
                          ),
                          child: Text(
                            formattedCode,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF4F46E5),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              letterSpacing: 0.3,
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
                  const SizedBox(width: 10),

                  // Location Name with Red Location Pin Badge 📍
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBF0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFE53E3E),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.location.locName,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Prefix Series Tag (Sleek Dark Slate Tag)
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_offer_rounded,
                              color: Color(0xFF38BDF8),
                              size: 12,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                widget.location.locPrefix,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Date Created Pill
                  SizedBox(
                    width: 130,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            widget.location.createdDate,
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Sleek Action Capsule Container (Emerald Edit + Crimson Delete)
                  SizedBox(
                    width: 80,
                    child: Center(
                      child: Container(
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
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              color: const Color(0xFF10B981),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Edit Location (Double-Click Row)',
                              onPressed: widget.onEdit,
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              color: const Color(0xFFEF4444),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Delete Location',
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
// FLOATING LOCATION FORM DRAWER OVERLAY
// ============================================================================
class _FloatingLocationFormDrawer extends StatefulWidget {
  final LocationMaster? location;
  final int nextCode;
  final LocationService locationService;
  final Function(LocationMaster, bool) onSuccess;

  const _FloatingLocationFormDrawer({
    this.location,
    required this.nextCode,
    required this.locationService,
    required this.onSuccess,
  });

  @override
  State<_FloatingLocationFormDrawer> createState() =>
      _FloatingLocationFormDrawerState();
}

class _FloatingLocationFormDrawerState
    extends State<_FloatingLocationFormDrawer> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _prefixCtrl;

  bool _isSaving = false;
  bool _isSaveSuccess = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final isEdit = widget.location != null;
    _codeCtrl = TextEditingController(
      text: isEdit ? widget.location!.locCode.toString() : widget.nextCode.toString(),
    );
    _nameCtrl = TextEditingController(
      text: isEdit ? widget.location!.locName : '',
    );
    _prefixCtrl = TextEditingController(
      text: isEdit ? widget.location!.locPrefix : 'Location',
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _prefixCtrl.dispose();
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
    final prefix = _prefixCtrl.text.trim();
    final isEdit = widget.location != null;

    try {
      bool success = false;
      if (isEdit) {
        success = await widget.locationService.updateLocation(code, name, prefix);
      } else {
        success = await widget.locationService.createLocation(code, name, prefix);
      }

      if (mounted) {
        if (success) {
          setState(() {
            _isSaving = false;
            _isSaveSuccess = true;
          });
          final saved = LocationMaster(
            locCode: code,
            locName: name,
            locPrefix: prefix,
            createdDate: isEdit
                ? (widget.location?.createdDate != null && widget.location!.createdDate != '03 Aug 2026'
                    ? widget.location!.createdDate
                    : LocationMaster.formatDisplayDate(DateTime.now()))
                : LocationMaster.formatDisplayDate(DateTime.now()),
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
    final isEdit = widget.location != null;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 440,
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
                // Floating Header (Compact)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
                  child: Row(
                    children: [
                      const _FoldedMapPinLogoWidget(size: 38),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Edit Location Master' : 'Create Location Master',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.neutralDark,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            isEdit ? 'Update details for #${widget.location!.locCode}' : 'Add a new location code register',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.neutralDark.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Form Body (Responsive & Compact)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMsg != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBF0),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFEB2B2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFE53E3E), size: 15),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _errorMsg!,
                                    style: const TextStyle(color: Color(0xFF9B2C2C), fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // UNIFIED FORM CARD BOX (COMPACT & SLEEK SIZE)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Box Header with Registration Emblem Logo
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: const Icon(
                                        Icons.app_registration_rounded,
                                        color: Color(0xFF047857),
                                        size: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Location Master Record',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          'Enter location attributes & prefix registers',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 8),

                                // 1. LOCATION CODE (Compact)
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFC7D2FE)),
                                      ),
                                      child: const Icon(Icons.tag_rounded, size: 11, color: Color(0xFF4F46E5)),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Location Code',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFC7D2FE)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.bolt_rounded, size: 10, color: Color(0xFF4F46E5)),
                                          SizedBox(width: 2),
                                          Text(
                                            'AUTO-GENERATED',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF4F46E5),
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 36,
                                  child: TextFormField(
                                    controller: _codeCtrl,
                                    readOnly: true,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFF5F3FF),
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.tag_rounded, size: 13, color: Color(0xFF4F46E5)),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFDDD6FE), width: 1.2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFDDD6FE), width: 1.2),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // 2. LOCATION NAME * (Compact)
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEBF0),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFFECDD3)),
                                      ),
                                      child: const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFFE53E3E)),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Location Name *',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 36,
                                  child: TextFormField(
                                    controller: _nameCtrl,
                                    autofocus: true,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Location name is required';
                                      }
                                      if (val.trim().length < 2) {
                                        return 'Location name must be at least 2 characters';
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'e.g. SURAT, AHMEDABAD, PUNE, INDORE',
                                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEBF0),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.location_city_rounded, size: 13, color: Color(0xFFE53E3E)),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFFFF5F5),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFFECDD3), width: 1.2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFFECDD3), width: 1.2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFE53E3E), width: 1.5),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // 3. PREFIX / CATEGORY (Compact)
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFA7F3D0)),
                                      ),
                                      child: const Icon(Icons.local_offer_rounded, size: 11, color: Color(0xFF047857)),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Prefix / Category',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: 36,
                                  child: TextFormField(
                                    controller: _prefixCtrl,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Location, CAPCONS, Central Warehouse',
                                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.category_rounded, size: 13, color: Color(0xFF047857)),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF0FDF4),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFA7F3D0), width: 1.2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFA7F3D0), width: 1.2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // TASK 2: COMPACT RESPONSIVE 3D EARTH GLOBE CARD (ZERO SCROLLING)
                        const _Realistic3DEarthMapCard(),
                      ],
                    ),
                  ),
                ),

                // Action Buttons (Compact)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            side: const BorderSide(color: AppColors.divider, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.neutralDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AnimatedSuccessButton(
                          status: _isSaveSuccess
                              ? ButtonStatus.success
                              : (_isSaving ? ButtonStatus.loading : ButtonStatus.idle),
                          onPressed: _submit,
                          idleText: isEdit ? 'Update Location' : 'Save Location',
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
// TASK 2: ULTRA-REALISTIC 3D EARTH GLOBE & CHARACTER LOCATION EXPLORER
// ============================================================================
class _Realistic3DEarthMapCard extends StatefulWidget {
  const _Realistic3DEarthMapCard();

  @override
  State<_Realistic3DEarthMapCard> createState() =>
      _Realistic3DEarthMapCardState();
}

class _Realistic3DEarthMapCardState extends State<_Realistic3DEarthMapCard>
    with TickerProviderStateMixin {
  late AnimationController _globeRotateCtrl;
  late AnimationController _characterSneakCtrl;
  late AnimationController _bubbleFloatCtrl;
  late AnimationController _wavyWaveCtrl;
  late AnimationController _notifPopCtrl;
  late AnimationController _charFlightCtrl;

  int _currentLocIndex = 0;
  int _prevLocIndex = 0;

  final List<Map<String, dynamic>> _earthLocations = [
    {'title': 'Surat Diamond Hub', 'icon': '📍💎', 'desc': 'Travelling to Surat Diamond Hub!', 'angle': 0.15, 'yOff': -16.0},
    {'title': 'Ahmedabad Textile Hub', 'icon': '📍🧵', 'desc': 'Exploring Ahmedabad Textile Hub!', 'angle': 0.55, 'yOff': -4.0},
    {'title': 'Pune Industrial Park', 'icon': '📍🏭', 'desc': 'Visiting Pune Industrial Park!', 'angle': 0.95, 'yOff': 14.0},
    {'title': 'Mumbai Central Port', 'icon': '📍🚢', 'desc': 'Checking Mumbai Central Warehouse!', 'angle': 1.35, 'yOff': 8.0},
    {'title': 'Indore Supply Depot', 'icon': '📍📦', 'desc': 'Navigating Indore Supply Depot!', 'angle': 1.75, 'yOff': -12.0},
    {'title': 'Delhi Tech Center', 'icon': '📍🌐', 'desc': 'Connecting Delhi Tech Hub!', 'angle': 2.15, 'yOff': -22.0},
  ];

  @override
  void initState() {
    super.initState();

    // 1. Earth Globe Rotation
    _globeRotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // 2. Character Sneaking & Tapping Animation
    _characterSneakCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // 3. Speech Bubble Bobbing Animation
    _bubbleFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // 4. Wavy Sine Wave Energy Flow Animation
    _wavyWaveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // 5. Dynamic Notification Pop-Up Controller (Pops in, stays briefly, pops out)
    _notifPopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _notifPopCtrl.forward();

    // 6. Smooth 3D Flight Transition Controller between locations
    _charFlightCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _charFlightCtrl.forward();

    // Auto cycle locations every 4 seconds
    _startAutoCycle();
  }

  void _startAutoCycle() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) break;
      _triggerNextLocation();
    }
  }

  void _triggerNextLocation() {
    setState(() {
      _prevLocIndex = _currentLocIndex;
      _currentLocIndex = (_currentLocIndex + 1) % _earthLocations.length;
    });
    _characterSneakCtrl.forward(from: 0.0);
    _notifPopCtrl.forward(from: 0.0);
    _charFlightCtrl.forward(from: 0.0);
  }

  @override
  void dispose() {
    _globeRotateCtrl.dispose();
    _characterSneakCtrl.dispose();
    _bubbleFloatCtrl.dispose();
    _wavyWaveCtrl.dispose();
    _notifPopCtrl.dispose();
    _charFlightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeLoc = _earthLocations[_currentLocIndex];

    return Container(
      width: double.infinity,
      height: 185,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B132B), // Deep Space Midnight
            Color(0xFF1C2541), // Deep Oceanic Blue
            Color(0xFF0284C7), // Atmosphere Cyan Glow
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.40),
          width: 1.4,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AnimatedBuilder(
          animation: Listenable.merge([_globeRotateCtrl, _characterSneakCtrl, _bubbleFloatCtrl, _wavyWaveCtrl, _notifPopCtrl, _charFlightCtrl]),
          builder: (context, _) {
            final rotateAngle = _globeRotateCtrl.value * 2 * math.pi;
            final sneakProgress = _characterSneakCtrl.value;
            final bubbleBob = _bubbleFloatCtrl.value * 3.0;
            final wavyProgress = _wavyWaveCtrl.value;
            final notifVal = _notifPopCtrl.value;

            // Notification Pop-up Scale & Opacity Physics
            double notifScale = 0.0;
            double notifOpacity = 0.0;
            if (notifVal < 0.22) {
              final t = notifVal / 0.22;
              notifScale = Curves.elasticOut.transform(t);
              notifOpacity = t.clamp(0.0, 1.0);
            } else if (notifVal < 0.78) {
              notifScale = 1.0;
              notifOpacity = 1.0;
            } else {
              final t = (notifVal - 0.78) / 0.22;
              notifScale = (1.0 - t).clamp(0.0, 1.0);
              notifOpacity = (1.0 - t).clamp(0.0, 1.0);
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

                // SHIFTED DOWN FOR GENEROUS WHITE SPACE & HEADROOM
                final globeCenterX = w * 0.50;
                final globeCenterY = h * 0.64;
                final globeRadius = 42.0;

                // DYNAMIC 3D ORBITAL FLIGHT INTERPOLATION BETWEEN LOCATIONS
                final flightProgress = Curves.easeInOutCubic.transform(_charFlightCtrl.value);

                final prevLoc = _earthLocations[_prevLocIndex];
                final currLoc = _earthLocations[_currentLocIndex];

                final prevAngle = (prevLoc['angle'] as double) * math.pi;
                final currAngle = (currLoc['angle'] as double) * math.pi;

                final prevY = (prevLoc['yOff'] as double);
                final currY = (currLoc['yOff'] as double);

                final smoothAngle = prevAngle + ((currAngle - prevAngle) * flightProgress);
                final smoothY = prevY + ((currY - prevY) * flightProgress);
                final flightArc = math.sin(flightProgress * math.pi) * 8.0;

                final orbitRx = globeRadius + 20.0 + flightArc;
                final orbitRy = globeRadius * 0.50;
                final charX = globeCenterX + (math.cos(smoothAngle) * orbitRx);
                final charY = globeCenterY + (math.sin(smoothAngle) * orbitRy) + smoothY;

                return Stack(
                  children: [
                    // 3D REALISTIC EARTH GLOBE CANVAS WITH SATURN RINGS & SHOOTING COMETS
                    CustomPaint(
                      size: Size(w, h),
                      painter: _ThreeDEarthGlobePainter(
                        rotateAngle: rotateAngle,
                        sneakProgress: sneakProgress,
                        wavyProgress: wavyProgress,
                        globeCenterX: globeCenterX,
                        globeCenterY: globeCenterY,
                        globeRadius: globeRadius,
                        locAngle: smoothAngle,
                        locYOff: smoothY,
                      ),
                    ),

                    // TOP-LEFT CYBER HUD STATUS BADGE
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'SPATIAL NODE: ONLINE',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // DYNAMIC NOTIFICATION POP-UP BANNER (POPS UP RIGHT NEAR CHARACTER HAND & TARGET PIN)
                    Positioned(
                      left: (charX - 85).clamp(10.0, w - 190.0),
                      top: (charY - 46 - bubbleBob).clamp(10.0, h - 45.0),
                      child: Transform.scale(
                        scale: notifScale,
                        child: Opacity(
                          opacity: notifOpacity,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.30),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                                  blurRadius: 10,
                                ),
                              ],
                              border: Border.all(color: const Color(0xFF0284C7), width: 1.4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  activeLoc['icon']! as String,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  activeLoc['desc']! as String,
                                  style: const TextStyle(
                                    color: AppColors.primaryColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
// REAL 3D EARTH GLOBE & SNEAKING CHARACTER PAINTER (WITH SATURN RINGS & COMETS)
// ============================================================================
class _ThreeDEarthGlobePainter extends CustomPainter {
  final double rotateAngle;
  final double sneakProgress;
  final double wavyProgress;
  final double globeCenterX;
  final double globeCenterY;
  final double globeRadius;
  final double locAngle;
  final double locYOff;

  _ThreeDEarthGlobePainter({
    required this.rotateAngle,
    required this.sneakProgress,
    required this.wavyProgress,
    required this.globeCenterX,
    required this.globeCenterY,
    required this.globeRadius,
    required this.locAngle,
    required this.locYOff,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. SHOOTING STAR COMET STREAKS IN SPACE
    final cometProgress = (wavyProgress * 1.5) % 1.0;
    final cometX = (w * 0.1) + (cometProgress * w * 0.8);
    final cometY = (h * 0.1) + (cometProgress * h * 0.4);
    final cometPath = Path()
      ..moveTo(cometX - 25, cometY - 12)
      ..lineTo(cometX, cometY);
    canvas.drawPath(
      cometPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF38BDF8).withValues(alpha: 0.0),
            const Color(0xFF38BDF8).withValues(alpha: 0.7),
          ],
        ).createShader(Rect.fromLTWH(cometX - 25, cometY - 12, 25, 12))
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );

    // 2. TWINKLING STARFIELD BACKGROUND DOTS
    final random = math.Random(42);
    for (int i = 0; i < 35; i++) {
      final sx = random.nextDouble() * w;
      final sy = random.nextDouble() * h;
      final twinkleAlpha = (0.3 + 0.6 * math.sin((wavyProgress * 2 * math.pi) + (i * 0.5))).clamp(0.1, 0.9);
      final starPaint = Paint()..color = Colors.white.withValues(alpha: twinkleAlpha);
      canvas.drawCircle(Offset(sx, sy), random.nextDouble() * 1.6, starPaint);
    }

    // 3. ATMOSPHERE OUTER GLOW RING
    canvas.drawCircle(
      Offset(globeCenterX, globeCenterY),
      globeRadius + 14,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // 4. EARTH MARBLE BLUE OCEAN BASE
    final oceanPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 0.85,
        colors: const [
          Color(0xFF38BDF8), // Sunlight Cyan Glare
          Color(0xFF0284C7), // Deep Ocean Blue
          Color(0xFF1E3A8A), // Dark Shadow Side
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(globeCenterX, globeCenterY), radius: globeRadius));

    canvas.drawCircle(Offset(globeCenterX, globeCenterY), globeRadius, oceanPaint);

    // CLIP TO EARTH SPHERE
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(globeCenterX, globeCenterY), radius: globeRadius)));

    // 5. LATITUDE & LONGITUDE GRID LINES
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.15);

    for (int i = -2; i <= 2; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(globeCenterX, globeCenterY + (i * 15)),
          width: globeRadius * 2,
          height: 24,
        ),
        gridPaint,
      );
    }

    // 6. ROTATING EARTH CONTINENTS
    final landPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF22C55E), Color(0xFF15803D)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    for (int c = 0; c < 4; c++) {
      final continentOffset = rotateAngle + (c * math.pi / 2);
      final continentX = globeCenterX + (math.sin(continentOffset) * (globeRadius * 0.7));

      if (math.cos(continentOffset) > -0.2) {
        final scaleX = math.cos(continentOffset).clamp(0.1, 1.0);
        final opacity = math.cos(continentOffset).clamp(0.0, 1.0);

        canvas.save();
        canvas.translate(continentX, globeCenterY + ((c % 2 == 0 ? -1 : 1) * 10));
        canvas.scale(scaleX, 1.0);

        final landPath = Path()
          ..addOval(Rect.fromCenter(center: Offset.zero, width: 32, height: 24))
          ..addOval(Rect.fromCenter(center: const Offset(10, -8), width: 18, height: 14));

        canvas.drawPath(
          landPath,
          landPaint..color = landPaint.color.withValues(alpha: opacity),
        );
        canvas.restore();
      }
    }

    // 7. DYNAMIC 3D TILTED SATURN ORBITAL RINGS AROUND EARTH
    canvas.save();
    canvas.translate(globeCenterX, globeCenterY);
    canvas.rotate(-math.pi / 8);

    final saturnRingOval = Rect.fromCenter(center: Offset.zero, width: (globeRadius + 18) * 2, height: (globeRadius + 18) * 0.45);
    final saturnPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.50);
    canvas.drawOval(saturnRingOval, saturnPaint);

    final saturnInnerOval = Rect.fromCenter(center: Offset.zero, width: (globeRadius + 12) * 2, height: (globeRadius + 12) * 0.45);
    final saturnInnerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF34D399).withValues(alpha: 0.35);
    canvas.drawOval(saturnInnerOval, saturnInnerPaint);

    canvas.restore();

    // 6. DYNAMIC WAVY SINE WAVE ENERGY RINGS AROUND EARTH EQUATOR
    for (int ring = 0; ring < 3; ring++) {
      final waveOffset = (wavyProgress * 2 * math.pi) + (ring * math.pi / 1.5);
      final wavePath = Path();
      final rWidth = (globeRadius + 8 + (ring * 6));
      final startX = globeCenterX - rWidth;
      final endX = globeCenterX + rWidth;

      for (double x = startX; x <= endX; x += 2) {
        final normX = (x - startX) / (rWidth * 2);
        final waveY = globeCenterY + (ring * 12 - 12) + (math.sin((normX * 3 * math.pi) + waveOffset) * 5.0);
        if (x == startX) {
          wavePath.moveTo(x, waveY);
        } else {
          wavePath.lineTo(x, waveY);
        }
      }

      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (ring == 1 ? const Color(0xFF34D399) : const Color(0xFF38BDF8)).withValues(alpha: 0.45);
      canvas.drawPath(wavePath, wavePaint);
    }

    // 7. LOCATION-SPECIFIC TARGET PIN MARKER & ORBIT POSITION
    final targetRad = locAngle;
    final orbitRx = globeRadius + 20.0;
    final orbitRy = globeRadius * 0.50;
    final charX = globeCenterX + (math.cos(targetRad) * orbitRx);
    final charY = globeCenterY + (math.sin(targetRad) * orbitRy) + locYOff;

    final pinX = globeCenterX + (math.cos(targetRad) * (globeRadius * 0.65));
    final pinY = globeCenterY + (math.sin(targetRad) * (globeRadius * 0.35)) + (locYOff * 0.6);

    // HOLOGRAPHIC VERTICAL LIGHT BEAM SHOOTING UP FROM PIN INTO SPACE
    final beamPath = Path()
      ..moveTo(pinX - 5, pinY)
      ..lineTo(pinX + 5, pinY)
      ..lineTo(pinX + 12, pinY - 45)
      ..lineTo(pinX - 12, pinY - 45)
      ..close();
    canvas.drawPath(
      beamPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFF38BDF8).withValues(alpha: 0.5),
            const Color(0xFF38BDF8).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(pinX - 12, pinY - 45, 24, 45)),
    );

    // Glowing Target Radar Rings around Pin
    final radarRadius = 6.0 + (math.sin(wavyProgress * 2 * math.pi) * 3.0);
    canvas.drawCircle(
      Offset(pinX, pinY),
      radarRadius + 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFFE53E3E).withValues(alpha: 0.6),
    );

    canvas.drawCircle(
      Offset(pinX, pinY),
      8,
      Paint()
        ..color = const Color(0xFFE53E3E).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(Offset(pinX, pinY), 4, Paint()..color = const Color(0xFFE53E3E));
    canvas.drawCircle(Offset(pinX, pinY), 1.8, Paint()..color = Colors.white);

    // LASER BEAM FROM CHARACTER HAND TO LOCATION PIN
    canvas.drawLine(
      Offset(charX - 10, charY + 8),
      Offset(pinX, pinY),
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.6)
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    canvas.restore(); // END EARTH CLIP

    // ------------------------------------------------------------------------
    // 7. REALISTIC 3D BUSINESSMAN CHARACTER MODEL (SUIT, SPECS, STYLED HAIR)
    // ------------------------------------------------------------------------
    // Executive Suit Jacket Body (#0F172A Dark Navy / Charcoal Suit)
    final jacketPath = Path()
      ..moveTo(charX - 22, charY + 28)
      ..quadraticBezierTo(charX - 14, charY + 12, charX, charY + 10)
      ..quadraticBezierTo(charX + 14, charY + 12, charX + 22, charY + 28)
      ..close();
    canvas.drawPath(
      jacketPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ).createShader(Rect.fromLTWH(charX - 22, charY + 10, 44, 18)),
    );

    // Suit Lapels (#334155)
    final leftLapel = Path()
      ..moveTo(charX - 18, charY + 28)
      ..lineTo(charX - 6, charY + 10)
      ..lineTo(charX - 2, charY + 20)
      ..close();
    final rightLapel = Path()
      ..moveTo(charX + 18, charY + 28)
      ..lineTo(charX + 6, charY + 10)
      ..lineTo(charX + 2, charY + 20)
      ..close();
    canvas.drawPath(leftLapel, Paint()..color = const Color(0xFF334155));
    canvas.drawPath(rightLapel, Paint()..color = const Color(0xFF334155));

    // Crisp White Shirt V-Neck
    final shirtPath = Path()
      ..moveTo(charX - 6, charY + 10)
      ..lineTo(charX, charY + 22)
      ..lineTo(charX + 6, charY + 10)
      ..close();
    canvas.drawPath(shirtPath, Paint()..color = Colors.white);

    // Executive Red Necktie (#E53E3E)
    final tiePath = Path()
      ..moveTo(charX - 2.5, charY + 12)
      ..lineTo(charX + 2.5, charY + 12)
      ..lineTo(charX + 3.5, charY + 25)
      ..lineTo(charX, charY + 28)
      ..lineTo(charX - 3.5, charY + 25)
      ..close();
    canvas.drawPath(tiePath, Paint()..color = const Color(0xFFE53E3E));

    // Gold Tie Clip Line
    canvas.drawLine(
      Offset(charX - 3, charY + 18),
      Offset(charX + 3, charY + 18),
      Paint()..color = const Color(0xFFF59E0B)..strokeWidth = 1.2,
    );

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(charX - 4, charY + 6, 8, 7), const Radius.circular(3)),
      Paint()..color = const Color(0xFFFDBA74),
    );

    // 3D Head (Gradient Shading)
    final headPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.2, -0.2),
        colors: [Color(0xFFFFEDD5), Color(0xFFFDBA74), Color(0xFFE59E54)],
      ).createShader(Rect.fromCircle(center: Offset(charX, charY), radius: 14));
    canvas.drawCircle(Offset(charX, charY), 14, headPaint);

    // Styled Executive Hair (Dark Brown Pompadour / Side-Parted)
    final hairPath = Path()
      ..moveTo(charX - 14.5, charY - 2)
      ..quadraticBezierTo(charX - 16, charY - 14, charX - 4, charY - 17)
      ..quadraticBezierTo(charX + 8, charY - 18, charX + 15, charY - 12)
      ..quadraticBezierTo(charX + 15, charY - 4, charX + 14, charY)
      ..quadraticBezierTo(charX + 6, charY - 11, charX, charY - 10)
      ..quadraticBezierTo(charX - 8, charY - 10, charX - 14.5, charY - 2)
      ..close();
    canvas.drawPath(
      hairPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF3E2723), Color(0xFF291D18)],
        ).createShader(Rect.fromLTWH(charX - 16, charY - 18, 32, 18)),
    );

    // Eyebrows
    canvas.drawLine(Offset(charX - 8, charY - 5), Offset(charX - 2, charY - 4), Paint()..color = const Color(0xFF291D18)..strokeWidth = 1.6);
    canvas.drawLine(Offset(charX + 2, charY - 4), Offset(charX + 8, charY - 5), Paint()..color = const Color(0xFF291D18)..strokeWidth = 1.6);

    // Human Eyes
    void drawHumanEye(double ex, double ey) {
      canvas.drawOval(Rect.fromCenter(center: Offset(ex, ey), width: 5.5, height: 4.5), Paint()..color = Colors.white);
      canvas.drawCircle(Offset(ex - 0.5, ey), 1.6, Paint()..color = const Color(0xFF0F172A));
      canvas.drawCircle(Offset(ex - 1.0, ey - 0.8), 0.7, Paint()..color = Colors.white);
    }
    drawHumanEye(charX - 5, charY - 1);
    drawHumanEye(charX + 5, charY - 1);

    // Sleek Business Spectacles / Glasses (#0F172A Frame + Glare)
    final specsFramePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF0F172A);

    // Left Lens Frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(charX - 5, charY - 1), width: 9, height: 7.5), const Radius.circular(3)),
      specsFramePaint,
    );
    // Right Lens Frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(charX + 5, charY - 1), width: 9, height: 7.5), const Radius.circular(3)),
      specsFramePaint,
    );
    // Glasses Bridge Across Nose
    canvas.drawLine(Offset(charX - 1, charY - 2.5), Offset(charX + 1, charY - 2.5), specsFramePaint);
    // Lens Glare Highlights
    canvas.drawLine(
      Offset(charX - 7, charY - 3),
      Offset(charX - 4, charY + 1),
      Paint()..color = Colors.white.withValues(alpha: 0.5)..strokeWidth = 1.0,
    );
    canvas.drawLine(
      Offset(charX + 3, charY - 3),
      Offset(charX + 6, charY + 1),
      Paint()..color = Colors.white.withValues(alpha: 0.5)..strokeWidth = 1.0,
    );

    // Nose & Businessman Smile
    canvas.drawCircle(Offset(charX, charY + 2.5), 1.2, Paint()..color = const Color(0xFFE59E54));
    final smilePath = Path()
      ..moveTo(charX - 4, charY + 6)
      ..quadraticBezierTo(charX, charY + 9.5, charX + 4, charY + 6);
    canvas.drawPath(
      smilePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF9A3412),
    );

    // Suit Arm & Extended Tapping Index Finger 👆 onto Globe Pin (pinX, pinY)
    final armPath = Path()
      ..moveTo(charX - 10, charY + 14)
      ..quadraticBezierTo(
        (charX + pinX) * 0.5 - 10,
        (charY + pinY) * 0.5,
        pinX,
        pinY,
      );

    canvas.drawPath(
      armPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF1E293B) // Dark Suit Sleeve
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // Hand & Tapping Finger Pin
    canvas.drawCircle(Offset(pinX, pinY), 3.5, Paint()..color = const Color(0xFFFDBA74));
    canvas.drawCircle(Offset(pinX, pinY), 1.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ThreeDEarthGlobePainter oldDelegate) {
    return oldDelegate.rotateAngle != rotateAngle || oldDelegate.sneakProgress != sneakProgress;
  }
}

// ============================================================================
// COMPREHENSIVE LOCATION EXPORT MODAL DIALOG
// ============================================================================
class _LocationExportModalDialog extends StatefulWidget {
  final List<LocationMaster> locations;

  const _LocationExportModalDialog({required this.locations});

  @override
  State<_LocationExportModalDialog> createState() => _LocationExportModalDialogState();
}

class _LocationExportModalDialogState extends State<_LocationExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'

  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<int> _selectedLocationCodes;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedLocationCodes = widget.locations.map((l) => l.locCode).toSet();
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

  List<LocationMaster> get _filteredPreviewLocations {
    if (_modalSearchQuery.isEmpty) return widget.locations;
    return widget.locations.where((l) {
      final codeMatch = l.locCode.toString().contains(_modalSearchQuery);
      final nameMatch = l.locName.toLowerCase().contains(_modalSearchQuery);
      final prefixMatch = l.locPrefix.toLowerCase().contains(_modalSearchQuery);
      final seriesMatch = l.locSeries.toLowerCase().contains(_modalSearchQuery);
      final dateMatch = l.createdDate.toLowerCase().contains(_modalSearchQuery);
      return codeMatch || nameMatch || prefixMatch || seriesMatch || dateMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewLocations;
    if (preview.isEmpty) return false;
    return preview.every((l) => _selectedLocationCodes.contains(l.locCode));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewLocations;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final l in preview) {
          _selectedLocationCodes.remove(l.locCode);
        }
      } else {
        for (final l in preview) {
          _selectedLocationCodes.add(l.locCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedLocationCodes.isEmpty) {
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
      final selectedList = widget.locations
          .where((l) => _selectedLocationCodes.contains(l.locCode))
          .toList();

      Directory? downloadsDir;
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          downloadsDir = Directory('$userProfile\\Downloads');
        }
      }
      downloadsDir ??= await getDownloadsDirectory();
      downloadsDir ??= await getApplicationDocumentsDirectory();

      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'LocationMaster_Export_$timestamp.$extension';
      final filePath = '${downloadsDir.path}${Platform.pathSeparator}$fileName';

      final file = File(filePath);

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Location Master');
        final excel_pkg.Sheet sheet = excel['Location Master'];

        // Set Generous Column Widths (Prevents text clipping)
        sheet.setColumnWidth(0, 22.0); // LOCATION CODE
        sheet.setColumnWidth(1, 36.0); // LOCATION NAME
        sheet.setColumnWidth(2, 24.0); // PREFIX
        sheet.setColumnWidth(3, 24.0); // SERIES
        sheet.setColumnWidth(4, 28.0); // DATE CREATED

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
          excel_pkg.TextCellValue('LOCATION CODE'),
          excel_pkg.TextCellValue('LOCATION NAME'),
          excel_pkg.TextCellValue('PREFIX'),
          excel_pkg.TextCellValue('SERIES'),
          excel_pkg.TextCellValue('DATE CREATED'),
        ]);

        for (int col = 0; col < 5; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        // Append Data Rows with Heights & Styles
        for (int i = 0; i < selectedList.length; i++) {
          final l = selectedList[i];
          final style = (i % 2 == 0) ? evenStyle : oddStyle;
          final int rIdx = i + 1;

          sheet.setRowHeight(rIdx, 22.0);
          sheet.appendRow([
            excel_pkg.IntCellValue(l.locCode),
            excel_pkg.TextCellValue(l.locName),
            excel_pkg.TextCellValue(l.locPrefix.isNotEmpty ? l.locPrefix : '-'),
            excel_pkg.TextCellValue(l.locSeries.isNotEmpty ? l.locSeries : '-'),
            excel_pkg.TextCellValue(l.createdDate.isNotEmpty ? l.createdDate : '-'),
          ]);

          for (int col = 0; col < 5; col++) {
            sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
          }
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await file.writeAsBytes(fileBytes);
        }
      } else {
        final pdfDoc = pw.Document();
        final fontData = await rootBundle.load('assets/fonts/Inter-Regular.ttf').catchError((_) => ByteData(0));
        final ttf = fontData.lengthInBytes > 0 ? pw.Font.ttf(fontData) : null;

        final headers = ['Location Code', 'Location Name', 'Prefix', 'Series', 'Date Created'];
        final data = selectedList.map((l) => [
          '${l.locCode}',
          l.locName,
          l.locPrefix.isNotEmpty ? l.locPrefix : '-',
          l.locSeries.isNotEmpty ? l.locSeries : '-',
          l.createdDate.isNotEmpty ? l.createdDate : '-',
        ]).toList();

        pdfDoc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            maxPages: 1000,
            header: (pw.Context ctx) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Location Master Register Report',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF0C3B2E),
                    ),
                  ),
                  pw.Text(
                    'Total Records: ${selectedList.length}',
                    style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            footer: (pw.Context ctx) => pw.Container(
              margin: const pw.EdgeInsets.only(top: 12),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey600),
              ),
            ),
            build: (pw.Context ctx) => [
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(
                  font: ttf,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF0C3B2E),
                ),
                headerAlignment: pw.Alignment.center,
                cellAlignment: pw.Alignment.center,
                cellStyle: pw.TextStyle(font: ttf, fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF8FAFC),
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
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
    } catch (e) {
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
                              Text('Export Location Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              SizedBox(height: 2),
                              Text('Select format & download records to your PC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),

                      // Side-by-Side Format Cards
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
            '${_selectedLocationCodes.length} of ${widget.locations.length} selected',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
          ),
        ),
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final previewList = _filteredPreviewLocations;
    if (previewList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'No location records found',
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minTableWidth = 620.0;
            final effectiveWidth = math.max(constraints.maxWidth, minTableWidth);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: effectiveWidth,
                child: Column(
                  children: [
                    // RESPONSIVE TABLE HEADER BAR
                    Container(
                      height: 40,
                      color: const Color(0xFF0C3B2E),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 38,
                            child: Text(
                              'SEL',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                          SizedBox(
                            width: 65,
                            child: Text(
                              'CODE',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Text(
                                'LOCATION NAME',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                textAlign: TextAlign.left,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Text(
                                'PREFIX',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                textAlign: TextAlign.left,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              'SERIES',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                          SizedBox(
                            width: 105,
                            child: Text(
                              'DATE CREATED',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: previewList.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                        itemBuilder: (ctx, idx) {
                          final l = previewList[idx];
                          final isSelected = _selectedLocationCodes.contains(l.locCode);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedLocationCodes.remove(l.locCode);
                                } else {
                                  _selectedLocationCodes.add(l.locCode);
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
                                    width: 38,
                                    child: Checkbox(
                                      value: isSelected,
                                      activeColor: AppColors.secondaryColor,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedLocationCodes.add(l.locCode);
                                          } else {
                                            _selectedLocationCodes.remove(l.locCode);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 65,
                                    child: Text(
                                      '${l.locCode}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primaryColor),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        l.locName,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                                        textAlign: TextAlign.left,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        l.locPrefix,
                                        style: TextStyle(fontSize: 11, color: AppColors.neutralDark.withValues(alpha: 0.8)),
                                        textAlign: TextAlign.left,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      l.locSeries,
                                      style: TextStyle(fontSize: 11, color: AppColors.neutralDark.withValues(alpha: 0.8)),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 105,
                                    child: Text(
                                      l.createdDate,
                                      style: TextStyle(fontSize: 11, color: AppColors.neutralDark.withValues(alpha: 0.7)),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
          },
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
            const SizedBox(
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

// 100% IDENTICAL IMAGE 2 VECTOR ILLUSTRATION PAINTER
class _IdenticalDeleteDialogIllustrationPainter extends CustomPainter {
  const _IdenticalDeleteDialogIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Light Grey Interior Room Lines (Window, Picture Frame, Table)
    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Left Window Frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.26, h * 0.10, w * 0.24, h * 0.44), const Radius.circular(2)),
      linePaint,
    );
    canvas.drawLine(Offset(w * 0.38, h * 0.10), Offset(w * 0.38, h * 0.54), linePaint);
    canvas.drawLine(Offset(w * 0.26, h * 0.32), Offset(w * 0.50, h * 0.32), linePaint);

    // Right Picture Frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.58, h * 0.14, w * 0.20, h * 0.28), const Radius.circular(2)),
      linePaint,
    );

    // Right Side Table & Fruit Bowl
    canvas.drawLine(Offset(w * 0.54, h * 0.72), Offset(w * 0.86, h * 0.72), linePaint);
    final bowlPath = Path()
      ..addArc(Rect.fromLTWH(w * 0.64, h * 0.62, w * 0.14, h * 0.12), 0, math.pi);
    canvas.drawPath(bowlPath, linePaint);

    // 2. Ground Oval Shadow on Floor
    canvas.drawOval(
      Rect.fromLTWH(w * 0.22, h * 0.88, w * 0.62, h * 0.08),
      Paint()..color = const Color(0xFFF1F5F9)..style = PaintingStyle.fill,
    );

    // 3. Red Trash Container (Right Side)
    final trashRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.56, h * 0.58, w * 0.18, h * 0.32),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      trashRect,
      Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill,
    );
    // Vertical stripe grooves on trash bin
    final stripePaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(w * 0.60, h * 0.62), Offset(w * 0.60, h * 0.86), stripePaint);
    canvas.drawLine(Offset(w * 0.65, h * 0.62), Offset(w * 0.65, h * 0.86), stripePaint);
    canvas.drawLine(Offset(w * 0.70, h * 0.62), Offset(w * 0.70, h * 0.86), stripePaint);

    // Trash bin rim top
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.55, h * 0.55, w * 0.20, h * 0.06), const Radius.circular(3)),
      Paint()..color = const Color(0xFFDC2626)..style = PaintingStyle.fill,
    );

    // 4. Character Person (Standing Left Side)
    // Dark Navy Trousers
    final legLeft = Path()
      ..moveTo(w * 0.38, h * 0.56)
      ..lineTo(w * 0.36, h * 0.88)
      ..lineTo(w * 0.40, h * 0.88)
      ..lineTo(w * 0.42, h * 0.56)
      ..close();
    final legRight = Path()
      ..moveTo(w * 0.44, h * 0.56)
      ..lineTo(w * 0.47, h * 0.88)
      ..lineTo(w * 0.51, h * 0.88)
      ..lineTo(w * 0.46, h * 0.56)
      ..close();
    final pantsPaint = Paint()..color = const Color(0xFF1E293B)..style = PaintingStyle.fill;
    canvas.drawPath(legLeft, pantsPaint);
    canvas.drawPath(legRight, pantsPaint);

    // Red Shoes
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.33, h * 0.86, w * 0.08, h * 0.04), const Radius.circular(2)),
      Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.46, h * 0.86, w * 0.08, h * 0.04), const Radius.circular(2)),
      Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill,
    );

    // Coral Pink Top / Shirt
    final torsoPath = Path()
      ..moveTo(w * 0.39, h * 0.38)
      ..lineTo(w * 0.47, h * 0.38)
      ..lineTo(w * 0.45, h * 0.56)
      ..lineTo(w * 0.38, h * 0.56)
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = const Color(0xFFF87171)..style = PaintingStyle.fill);

    // Skin Tone Arms & Head
    final skinPaint = Paint()..color = const Color(0xFFFED7AA)..style = PaintingStyle.fill;
    // Head & Neck
    canvas.drawCircle(Offset(w * 0.43, h * 0.31), w * 0.05, skinPaint);
    // Dark Hair
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.43, h * 0.30), radius: w * 0.055), math.pi, math.pi, true, Paint()..color = const Color(0xFF0F172A));

    // Arms holding red folder
    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.40, w * 0.10, h * 0.08), Paint()..color = const Color(0xFFEF4444));

    // 5. Red Floating Envelopes / Files Falling into Trash
    final envPaint = Paint()..color = const Color(0xFFF87171)..style = PaintingStyle.fill;

    // Envelope 1 (Mid Air)
    canvas.save();
    canvas.translate(w * 0.54, h * 0.42);
    canvas.rotate(0.35);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 14, 9), const Radius.circular(1.5)), envPaint);
    canvas.restore();

    // Envelope 2 (Lower Air)
    canvas.save();
    canvas.translate(w * 0.58, h * 0.49);
    canvas.rotate(-0.25);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 14, 9), const Radius.circular(1.5)), envPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

// ============================================================================
// 100% IDENTICAL LOCATION PIN LOGO WIDGET (MATCHING IMAGE 2 IDENTICALLY)
// ============================================================================
class _IdenticalLocationPinLogoWidget extends StatelessWidget {
  final double size;
  const _IdenticalLocationPinLogoWidget({this.size = 26.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF389078).withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _IdenticalLocationPinLogoPainter(),
      ),
    );
  }
}

class _IdenticalLocationPinLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Outer 3D Mint Teal Squircle Frame (Gradient + Top Highlight)
    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.28),
    );
    final frameGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF54BBA2),
        Color(0xFF4CA58E),
        Color(0xFF389078),
      ],
    );
    final framePaint = Paint()
      ..shader = frameGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(frameRect, framePaint);

    // 2. Inner 3D Recessed Surface Cutout
    final innerMargin = w * 0.13;
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(innerMargin, innerMargin, w - (innerMargin * 2), h - (innerMargin * 2)),
      Radius.circular(w * 0.20),
    );
    final innerGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFF7FAF9),
        Color(0xFFEEF4F3),
        Color(0xFFE0EBE8),
      ],
    );
    final innerPaint = Paint()
      ..shader = innerGradient.createShader(Rect.fromLTWH(innerMargin, innerMargin, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(innerRect, innerPaint);

    // 3. 3D Ground Shadow Oval under Pin Tip
    final shadowPaint = Paint()
      ..color = const Color(0xFF2C7864).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromLTWH(w * 0.30, h * 0.70, w * 0.40, h * 0.14),
      shadowPaint,
    );

    // 4. 3D Coral Red Location Pin Marker (Radial Highlight Gradient)
    final centerX = w * 0.5;
    final headCenterY = h * 0.42;
    final headRadius = w * 0.22;

    final pinGradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 0.85,
      colors: const [
        Color(0xFFFF7A8A), // Top-left specular light highlight
        Color(0xFFE94D61), // Coral Red Base
        Color(0xFFC02A3E), // Bottom-right shadow
      ],
    );

    final pinPaint = Paint()
      ..shader = pinGradient.createShader(Rect.fromLTWH(w * 0.25, h * 0.18, w * 0.5, h * 0.6))
      ..style = PaintingStyle.fill;

    final pinPath = Path()
      ..moveTo(centerX - headRadius, headCenterY)
      ..arcTo(
        Rect.fromCircle(center: Offset(centerX, headCenterY), radius: headRadius),
        math.pi,
        math.pi,
        false,
      )
      ..quadraticBezierTo(
        centerX + headRadius * 0.85,
        headCenterY + headRadius * 0.9,
        centerX,
        h * 0.77,
      )
      ..quadraticBezierTo(
        centerX - headRadius * 0.85,
        headCenterY + headRadius * 0.9,
        centerX - headRadius,
        headCenterY,
      )
      ..close();

    canvas.drawPath(pinPath, pinPaint);

    // 5. White Inner Hole Cutout
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, headCenterY), headRadius * 0.44, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// IMAGE 1 VECTOR MAP LANDSCAPE LOGO EMBLEM WIDGET (MATCHING IMAGE 1 IDENTICALLY)
// ============================================================================
// ============================================================================
// 100% IDENTICAL IMAGE 2 FOLDED MAP & HOPPING RED PIN ANIMATED LOGO EMBLEM
// ============================================================================
class _FoldedMapPinLogoWidget extends StatefulWidget {
  final double size;
  const _FoldedMapPinLogoWidget({this.size = 48.0});

  @override
  State<_FoldedMapPinLogoWidget> createState() => _FoldedMapPinLogoWidgetState();
}

class _FoldedMapPinLogoWidgetState extends State<_FoldedMapPinLogoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _hopController;

  @override
  void initState() {
    super.initState();
    _hopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _hopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _hopController,
      builder: (context, child) {
        return SizedBox(
          width: widget.size * 1.15,
          height: widget.size,
          child: CustomPaint(
            painter: _FoldedMapPinLogoPainter(
              hopProgress: _hopController.value,
            ),
          ),
        );
      },
    );
  }
}

class _FoldedMapPinLogoPainter extends CustomPainter {
  final double hopProgress;

  _FoldedMapPinLogoPainter({required this.hopProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Dark Navy contour paint
    final strokePaint = Paint()
      ..color = const Color(0xFF1D2D44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // ------------------------------------------------------------------------
    // 1. 3D PERSPECTIVE FOLDED MAP (4 VERTICAL ACCORDION SEGMENTS - IMAGE 2)
    // ------------------------------------------------------------------------
    // Segment 1 (Leftmost, folded inward)
    final seg1Path = Path()
      ..moveTo(w * 0.16, h * 0.46)
      ..lineTo(w * 0.35, h * 0.41)
      ..lineTo(w * 0.34, h * 0.88)
      ..lineTo(w * 0.06, h * 0.82)
      ..close();
    canvas.drawPath(seg1Path, Paint()..color = const Color(0xFF74C69D)..style = PaintingStyle.fill);
    canvas.drawPath(seg1Path, strokePaint);

    // Blue section inside Segment 1
    final seg1Blue = Path()
      ..moveTo(w * 0.06, h * 0.82)
      ..lineTo(w * 0.34, h * 0.88)
      ..lineTo(w * 0.34, h * 0.72)
      ..lineTo(w * 0.10, h * 0.68)
      ..close();
    canvas.drawPath(seg1Blue, Paint()..color = const Color(0xFF4EA8DE)..style = PaintingStyle.fill);
    canvas.drawPath(seg1Blue, strokePaint);

    // Segment 2 (Middle-Left, folded outward)
    final seg2Path = Path()
      ..moveTo(w * 0.35, h * 0.41)
      ..lineTo(w * 0.55, h * 0.48)
      ..lineTo(w * 0.54, h * 0.94)
      ..lineTo(w * 0.34, h * 0.88)
      ..close();
    canvas.drawPath(seg2Path, Paint()..color = const Color(0xFF95D5B2)..style = PaintingStyle.fill);
    canvas.drawPath(seg2Path, strokePaint);

    // Segment 3 (Middle-Right, folded inward)
    final seg3Path = Path()
      ..moveTo(w * 0.55, h * 0.48)
      ..lineTo(w * 0.78, h * 0.43)
      ..lineTo(w * 0.77, h * 0.87)
      ..lineTo(w * 0.54, h * 0.94)
      ..close();
    canvas.drawPath(seg3Path, Paint()..color = const Color(0xFF52B788)..style = PaintingStyle.fill);
    canvas.drawPath(seg3Path, strokePaint);

    // Segment 4 (Rightmost, folded outward)
    final seg4Path = Path()
      ..moveTo(w * 0.78, h * 0.43)
      ..lineTo(w * 0.94, h * 0.49)
      ..lineTo(w * 0.93, h * 0.80)
      ..lineTo(w * 0.77, h * 0.87)
      ..close();
    canvas.drawPath(seg4Path, Paint()..color = const Color(0xFFFFB703)..style = PaintingStyle.fill);
    canvas.drawPath(seg4Path, strokePaint);

    // 3D Road grid lines running across map
    final roadPath = Path()
      ..moveTo(w * 0.20, h * 0.60)
      ..lineTo(w * 0.35, h * 0.55)
      ..lineTo(w * 0.55, h * 0.65)
      ..lineTo(w * 0.78, h * 0.58)
      ..lineTo(w * 0.90, h * 0.64);
    canvas.drawPath(
      roadPath,
      Paint()
        ..color = const Color(0xFF1D2D44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      roadPath,
      Paint()
        ..color = const Color(0xFFF8F9FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // ------------------------------------------------------------------------
    // 2. SLOW MOTION HOPPING ANIMATION MATH & DYNAMIC RED DROP-LINE
    // ------------------------------------------------------------------------
    final hopSin = math.sin(hopProgress * math.pi);
    final hopY = -hopSin * (h * 0.16); // Gentle slow motion hop up/down
    final targetX = w * 0.50;
    final mapSpotY = h * 0.66; // Exact target spot on map surface

    final pinHeadCenterY = (h * 0.30) + hopY;
    final pinTipY = (h * 0.62) + hopY;

    // Dynamic Ground Shadow under Pin (shrinks when pin hops high)
    final shadowScale = (1.0 - (hopSin * 0.35)).clamp(0.65, 1.0);
    final shadowOpacity = (0.50 - (hopSin * 0.25)).clamp(0.20, 0.50);
    canvas.save();
    canvas.translate(targetX, mapSpotY);
    canvas.scale(shadowScale, shadowScale * 0.4);
    canvas.drawCircle(
      Offset.zero,
      w * 0.18,
      Paint()..color = const Color(0xFF1D2D44).withValues(alpha: shadowOpacity),
    );
    canvas.restore();

    // DYNAMIC RED DROP-LINE DRAWN FROM PIN TIP DOWN TO MAP SPOT EXACTLY
    if (hopSin > 0.02) {
      final lineOpacity = (hopSin * 1.2).clamp(0.0, 1.0);
      final redLinePaint = Paint()
        ..color = const Color(0xFFFF4D6D).withValues(alpha: lineOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      // Red line drawn exactly from pin tip down to map spot
      canvas.drawLine(Offset(targetX, pinTipY), Offset(targetX, mapSpotY), redLinePaint);

      // Target ripple dot on map
      canvas.drawCircle(
        Offset(targetX, mapSpotY),
        (3.0 + (hopSin * 4.0)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFFF4D6D).withValues(alpha: lineOpacity * 0.7),
      );
    }

    // ------------------------------------------------------------------------
    // 3. LARGE CORAL RED LOCATION PIN MARKER (100% MATCHING IMAGE 2)
    // ------------------------------------------------------------------------
    final headRadius = w * 0.23;

    final pinPath = Path()
      ..moveTo(targetX - headRadius, pinHeadCenterY)
      ..arcTo(
        Rect.fromCircle(center: Offset(targetX, pinHeadCenterY), radius: headRadius),
        math.pi,
        math.pi,
        false,
      )
      ..quadraticBezierTo(
        targetX + headRadius * 0.90,
        pinHeadCenterY + headRadius * 0.90,
        targetX,
        pinTipY,
      )
      ..quadraticBezierTo(
        targetX - headRadius * 0.90,
        pinHeadCenterY + headRadius * 0.90,
        targetX - headRadius,
        pinHeadCenterY,
      )
      ..close();

    // Coral Red Gradient Body
    final pinGradient = RadialGradient(
      center: const Alignment(-0.35, -0.40),
      radius: 0.95,
      colors: const [
        Color(0xFFFF758F), // Top-left specular red highlight
        Color(0xFFFF4D6D), // Image 2 Vibrant Coral Red
        Color(0xFFC9184A), // Dark Shadow Side
      ],
    );
    canvas.drawPath(
      pinPath,
      Paint()..shader = pinGradient.createShader(Rect.fromLTWH(targetX - headRadius, pinHeadCenterY - headRadius, headRadius * 2, headRadius * 2.6)),
    );
    canvas.drawPath(pinPath, strokePaint);

    // Round Inner Cutout Circle (Beige / Soft Cream #F8F9FA)
    final holeRadius = headRadius * 0.46;
    final holeCenter = Offset(targetX, pinHeadCenterY - 1.0);
    canvas.drawCircle(holeCenter, holeRadius, Paint()..color = const Color(0xFFF8F9FA)..style = PaintingStyle.fill);
    canvas.drawCircle(holeCenter, holeRadius, strokePaint);

    // Top-Left Specular White Glare Arc
    final glarePath = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(targetX, pinHeadCenterY), radius: headRadius * 0.78),
        math.pi * 1.15,
        math.pi * 0.40,
      );
    canvas.drawPath(
      glarePath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _FoldedMapPinLogoPainter oldDelegate) {
    return oldDelegate.hopProgress != hopProgress;
  }
}

// ============================================================================
// IMAGE 1 VECTOR MAP LANDSCAPE LOGO EMBLEM WIDGET (MATCHING IMAGE 1 IDENTICALLY)
// ============================================================================
class _LocationLandscapeLogoWidget extends StatelessWidget {
  final double size;
  const _LocationLandscapeLogoWidget({this.size = 54.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.35,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2BB6A3).withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _LocationLandscapeLogoPainter(),
      ),
    );
  }
}

class _LocationLandscapeLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final outlinePaint = Paint()
      ..color = const Color(0xFF1E293B) // Vector black line contour
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Sky Background Elements (Sun & Cloud)
    // Yellow Sun
    final sunCenter = Offset(w * 0.76, h * 0.18);
    final sunRadius = w * 0.08;
    canvas.drawCircle(sunCenter, sunRadius, Paint()..color = const Color(0xFFF5B041)..style = PaintingStyle.fill);
    canvas.drawCircle(sunCenter, sunRadius, outlinePaint);

    // Blue Cloud on Left
    final cloudPath = Path()
      ..moveTo(w * 0.14, h * 0.32)
      ..arcTo(Rect.fromCircle(center: Offset(w * 0.18, h * 0.28), radius: w * 0.08), math.pi, math.pi * 0.75, false)
      ..arcTo(Rect.fromCircle(center: Offset(w * 0.26, h * 0.22), radius: w * 0.10), math.pi * 1.25, math.pi * 0.8, false)
      ..arcTo(Rect.fromCircle(center: Offset(w * 0.34, h * 0.28), radius: w * 0.07), math.pi * 1.8, math.pi * 0.75, false)
      ..lineTo(w * 0.14, h * 0.32)
      ..close();
    canvas.drawPath(cloudPath, Paint()..color = const Color(0xFF5DADE2)..style = PaintingStyle.fill);
    canvas.drawPath(cloudPath, outlinePaint);

    // 2. Turquoise Map Landscape Ground Base Curve
    final groundPath = Path()
      ..moveTo(w * 0.18, h * 0.86)
      ..quadraticBezierTo(w * 0.45, h * 0.62, w * 0.92, h * 0.74)
      ..lineTo(w * 0.82, h * 0.92)
      ..quadraticBezierTo(w * 0.45, h * 0.98, w * 0.18, h * 0.86)
      ..close();
    canvas.drawPath(groundPath, Paint()..color = const Color(0xFF2BB6A3)..style = PaintingStyle.fill);
    canvas.drawPath(groundPath, outlinePaint);

    // 3. Gold/Yellow Circular Target Ring Ground Base under Pin
    final ringCenter = Offset(w * 0.50, h * 0.77);
    final ringOval = Rect.fromCenter(center: ringCenter, width: w * 0.36, height: h * 0.18);
    canvas.drawOval(ringOval, Paint()..color = const Color(0xFFF5B041)..style = PaintingStyle.fill);
    canvas.drawOval(ringOval, outlinePaint);

    // Inner green hole inside yellow ring
    final innerGreenOval = Rect.fromCenter(center: ringCenter, width: w * 0.22, height: h * 0.10);
    canvas.drawOval(innerGreenOval, Paint()..color = const Color(0xFF27AE60)..style = PaintingStyle.fill);
    canvas.drawOval(innerGreenOval, outlinePaint);

    // 4. Foliage Plant on Left (3 Green Leaves)
    final leafPaint = Paint()..color = const Color(0xFF27AE60)..style = PaintingStyle.fill;
    final plantPath = Path()
      ..moveTo(w * 0.26, h * 0.82)
      ..quadraticBezierTo(w * 0.08, h * 0.68, w * 0.14, h * 0.58)
      ..quadraticBezierTo(w * 0.24, h * 0.64, w * 0.26, h * 0.82);
    canvas.drawPath(plantPath, leafPaint);
    canvas.drawPath(plantPath, outlinePaint);

    final leafCenter = Path()
      ..moveTo(w * 0.26, h * 0.82)
      ..quadraticBezierTo(w * 0.18, h * 0.48, w * 0.22, h * 0.46)
      ..quadraticBezierTo(w * 0.30, h * 0.56, w * 0.26, h * 0.82);
    canvas.drawPath(leafCenter, leafPaint);
    canvas.drawPath(leafCenter, outlinePaint);

    // 5. Big Coral Red Location Pin Marker in Center
    final pinCenterX = w * 0.50;
    final pinHeadY = h * 0.42;
    final pinRadius = w * 0.18;

    final pinPath = Path()
      ..moveTo(pinCenterX - pinRadius, pinHeadY)
      ..arcTo(Rect.fromCircle(center: Offset(pinCenterX, pinHeadY), radius: pinRadius), math.pi, math.pi, false)
      ..quadraticBezierTo(pinCenterX + pinRadius * 0.85, pinHeadY + pinRadius * 0.95, pinCenterX, h * 0.77)
      ..quadraticBezierTo(pinCenterX - pinRadius * 0.85, pinHeadY + pinRadius * 0.95, pinCenterX - pinRadius, pinHeadY)
      ..close();

    canvas.drawPath(pinPath, Paint()..color = const Color(0xFFE84858)..style = PaintingStyle.fill);
    canvas.drawPath(pinPath, outlinePaint);

    // White Center Hole Cutout in Pin Head
    canvas.drawCircle(Offset(pinCenterX, pinHeadY), pinRadius * 0.46, Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(pinCenterX, pinHeadY), pinRadius * 0.46, outlinePaint);

    // 6. Small Red Target Ring Pole on Right
    final poleX = w * 0.78;
    final poleY = h * 0.50;
    canvas.drawLine(Offset(poleX, poleY), Offset(poleX, h * 0.68), outlinePaint..strokeWidth = w * 0.025);
    canvas.drawCircle(Offset(poleX, poleY), w * 0.07, Paint()..color = const Color(0xFFE84858)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(poleX, poleY), w * 0.07, outlinePaint);
    canvas.drawCircle(Offset(poleX, poleY), w * 0.035, Paint()..color = Colors.white..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
