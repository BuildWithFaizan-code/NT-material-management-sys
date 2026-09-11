import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import '../design/app_colors.dart';
import '../services/store_service.dart';

// ============================================================================
// DATA MODELS: StoreMaster & LocationLookupDto
// ============================================================================
class StoreMaster {
  final int strCode;
  final String strName;
  final int locCode;
  final String locationName;
  final String strSeries;
  final String strFixChar;

  StoreMaster({
    required this.strCode,
    required this.strName,
    required this.locCode,
    String? locationName,
    String? strSeries,
    String? strFixChar,
  })  : locationName = locationName ?? 'AARYA ENTERPRISE',
        strSeries = strSeries ?? '',
        strFixChar = strFixChar ?? '';

  factory StoreMaster.fromJson(Map<String, dynamic> json) {
    return StoreMaster(
      strCode: json['strCode'] is int
          ? json['strCode']
          : (json['StrCode'] is int
              ? json['StrCode']
              : int.tryParse(json['strCode']?.toString() ?? json['StrCode']?.toString() ?? '0') ?? 0),
      strName: json['strName'] as String? ?? json['StrName'] as String? ?? '',
      locCode: json['locCode'] is int
          ? json['locCode']
          : (json['LocCode'] is int
              ? json['LocCode']
              : int.tryParse(json['locCode']?.toString() ?? json['LocCode']?.toString() ?? '0') ?? 0),
      locationName: json['locationName'] as String? ?? json['LocationName'] as String? ?? 'AARYA ENTERPRISE',
      strSeries: json['strSeries'] as String? ?? json['StrSeries'] as String? ?? '',
      strFixChar: json['strFixChar'] as String? ?? json['StrFixChar'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'strCode': strCode,
        'strName': strName,
        'locCode': locCode,
        'locationName': locationName,
        'strSeries': strSeries,
        'strFixChar': strFixChar,
      };

  StoreMaster copyWith({
    int? strCode,
    String? strName,
    int? locCode,
    String? locationName,
    String? strSeries,
    String? strFixChar,
  }) {
    return StoreMaster(
      strCode: strCode ?? this.strCode,
      strName: strName ?? this.strName,
      locCode: locCode ?? this.locCode,
      locationName: locationName ?? this.locationName,
      strSeries: strSeries ?? this.strSeries,
      strFixChar: strFixChar ?? this.strFixChar,
    );
  }
}

class LocationLookupDto {
  final int locCode;
  final String locationName;

  LocationLookupDto({
    required this.locCode,
    required this.locationName,
  });

  factory LocationLookupDto.fromJson(Map<String, dynamic> json) {
    return LocationLookupDto(
      locCode: json['locCode'] is int
          ? json['locCode']
          : (json['LocCode'] is int
              ? json['LocCode']
              : int.tryParse(json['locCode']?.toString() ?? json['LocCode']?.toString() ?? '0') ?? 0),
      locationName: json['locationName'] as String? ?? json['LocationName'] as String? ?? json['location'] as String? ?? '',
    );
  }
}

// ============================================================================
// MAIN PAGE: StoreMasterPage (Interactive Bento Grid Cards Concept)
// ============================================================================
class StoreMasterPage extends StatefulWidget {
  final StoreService? storeService;
  const StoreMasterPage({super.key, this.storeService});

  @override
  State<StoreMasterPage> createState() => _StoreMasterPageState();
}

class _StoreMasterPageState extends State<StoreMasterPage> {
  late final StoreService _storeService;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<StoreMaster> _stores = [];
  List<LocationLookupDto> _locationsLookup = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filter & Sort State variables
  String _searchQuery = '';
  String _selectedLocationFilter = 'ALL';
  String _sortOrder = 'CODE_ASC'; // 'CODE_ASC', 'CODE_DESC', 'NAME_ASC', 'NAME_DESC', 'LOCATION_ASC'
  String? _activeOpenDropdownId;

  // Entry Glow Strategy (New = Emerald, Updated = Amber)
  int? _recentlySavedCode;    // newly added -> emerald glow
  int? _recentlyUpdatedCode;  // recently updated -> amber glow
  Timer? _glowTimer;

  void _highlightStoreCard(int code, {bool isEdit = false}) {
    _glowTimer?.cancel();
    setState(() {
      if (isEdit) {
        _recentlyUpdatedCode = code;
        _recentlySavedCode = null;
      } else {
        _recentlySavedCode = code;
        _recentlyUpdatedCode = null;
      }
    });
    _glowTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _recentlySavedCode = null;
          _recentlyUpdatedCode = null;
        });
      }
    });
  }

  /// Refresh data silently WITHOUT showing shimmer loading state
  Future<void> _refreshDataSilently() async {
    try {
      final storesData = await _storeService.fetchStores();
      final locsData = await _storeService.fetchLocationsLookup();
      if (mounted) {
        setState(() {
          _stores = storesData;
          _locationsLookup = locsData;
        });
      }
    } catch (_) {}
  }

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _storeService = widget.storeService ?? StoreService();
    _fetchData();
    _searchCtrl.addListener(() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() {
            _searchQuery = _searchCtrl.text.trim().toLowerCase();
          });
          _updateFilteredStores();
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _glowTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Live End-to-End API Fetch
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storesData = await _storeService.fetchStores();
      final locsData = await _storeService.fetchLocationsLookup();
      if (mounted) {
        setState(() {
          _stores = storesData;
          _locationsLookup = locsData;
          _isLoading = false;
        });
        _updateFilteredStores();
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

  /// Active Filter Counter
  int get _activeFilterCount {
    int count = 0;
    if (_searchQuery.isNotEmpty) count++;
    if (_selectedLocationFilter != 'ALL') count++;
    if (_sortOrder != 'CODE_ASC') count++;
    return count;
  }

  /// Clear/Reset All Filters
  void _resetAllFilters() {
    setState(() {
      _searchCtrl.clear();
      _searchQuery = '';
      _selectedLocationFilter = 'ALL';
      _sortOrder = 'CODE_ASC';
    });
    _updateFilteredStores();
  }

  List<StoreMaster> _cachedFilteredStores = [];

  void _updateFilteredStores() {
    final list = _stores.where((s) {
      // 1. Location Filter
      if (_selectedLocationFilter != 'ALL' &&
          s.locationName.toLowerCase() != _selectedLocationFilter.toLowerCase()) {
        return false;
      }
      // 2. Multi-Field Real-Time Search Match
      if (_searchQuery.isEmpty) return true;
      final codeMatch = s.strCode.toString().contains(_searchQuery);
      final nameMatch = s.strName.toLowerCase().contains(_searchQuery);
      final locMatch = s.locationName.toLowerCase().contains(_searchQuery);
      final seriesMatch = s.strSeries.toLowerCase().contains(_searchQuery);
      final fixCharMatch = s.strFixChar.toLowerCase().contains(_searchQuery);
      return codeMatch || nameMatch || locMatch || seriesMatch || fixCharMatch;
    }).toList();

    // Sorting Options
    list.sort((a, b) {
      switch (_sortOrder) {
        case 'CODE_DESC':
          return b.strCode.compareTo(a.strCode);
        case 'NAME_ASC':
          return a.strName.toLowerCase().compareTo(b.strName.toLowerCase());
        case 'NAME_DESC':
          return b.strName.toLowerCase().compareTo(a.strName.toLowerCase());
        case 'LOCATION_ASC':
          return a.locationName.toLowerCase().compareTo(b.locationName.toLowerCase());
        case 'CODE_ASC':
        default:
          return a.strCode.compareTo(b.strCode);
      }
    });

    _cachedFilteredStores = list;
  }

  List<StoreMaster> get _filteredStores => _cachedFilteredStores;

  int get _activeLinkedLocationsCount {
    return _stores.map((e) => e.locCode).toSet().length;
  }

  List<String> get _uniqueLocations {
    final allLocationNames = {
      ..._locationsLookup.map((e) => e.locationName.trim()).where((e) => e.isNotEmpty),
      ..._stores.map((e) => e.locationName.trim()).where((e) => e.isNotEmpty),
    }.toList()..sort();

    return ['ALL', ...allLocationNames];
  }

  void _showStoreFormSquareModal({StoreMaster? storeToEdit}) async {
    int nextCode = 1;
    if (storeToEdit == null) {
      nextCode = await _storeService.fetchNextCode();
    }

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _SquareStoreFormModal(
              store: storeToEdit,
              nextCode: nextCode,
              locationsLookup: _locationsLookup,
              storeService: _storeService,
              onSuccess: (savedStore, isEdit) async {
                _highlightStoreCard(savedStore.strCode, isEdit: isEdit);
                await _refreshDataSilently();
              },
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  Future<void> _confirmDelete(StoreMaster store) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () => _storeService.deleteStore(store.strCode),
      ),
    );

    if (deleted == true) {
      await _fetchData();
    }
  }

  void _showComprehensiveExportModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _StoreExportModalDialog(stores: _filteredStores),
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
                          _buildMetricsAndToolbar(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _isLoading
                          ? _buildShimmerGridLoading()
                          : (_errorMessage != null
                              ? _buildErrorState()
                              : (_filteredStores.isEmpty
                                  ? _buildEmptyState()
                                  : _buildBentoCardGrid())),
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

  Widget _buildHeader() {
    final uniqueLocations = _uniqueLocations;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 100% Identical Store Master Header Logo (Direct on plain screen, no box/borders, high-res)
        Image.asset(
          'assets/images/store_master_header_logo.png',
          width: 68,
          height: 68,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Store Master',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Storage hubs, series codes & inventory directory',
                style: TextStyle(
                  color: AppColors.neutralDark.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Right-side 2x2 Box: 2 KPI Cards Up, 2 Dropdowns Down
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // UP (TOP ROW): 2 KPI Cards (Image 2 Style - Coral & Amber Gradients with Sparkline Graphs)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // KPI 1: Total Stores (Coral-Red Gradient with Connected-Node Sparkline)
                _SparklineKpiCard(
                  label: 'Total Stores',
                  value: '${_stores.length}',
                  width: 190,
                  height: 48,
                  gradientColors: const [
                    Color(0xFFFF6B6B),
                    Color(0xFFEE5253),
                  ],
                  points: const [
                    Offset(0.0, 0.75),
                    Offset(0.35, 0.35),
                    Offset(0.65, 0.55),
                    Offset(1.0, 0.15),
                  ],
                ),
                const SizedBox(width: 10),

                // KPI 2: Active Locations (Warm Amber-Gold Gradient with Connected-Node Sparkline)
                _SparklineKpiCard(
                  label: 'Active Locations',
                  value: '$_activeLinkedLocationsCount',
                  width: 190,
                  height: 48,
                  gradientColors: const [
                    Color(0xFFFBBF24),
                    Color(0xFFF59E0B),
                  ],
                  points: const [
                    Offset(0.0, 0.70),
                    Offset(0.33, 0.30),
                    Offset(0.66, 0.48),
                    Offset(1.0, 0.15),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // DOWN (BOTTOM ROW): 2 Filter Dropdowns
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dropdown 1: Sort Order Dropdown
                _SwitchableDropdownButton<String>(
                  id: 'SORT',
                  width: 190,
                  alignRight: false,
                  headerTitle: 'SORT ORDER',
                  value: _sortOrder,
                  activeOpenId: _activeOpenDropdownId,
                  onToggleOpen: (id) => setState(() => _activeOpenDropdownId = id),
                  leadingIcon: Icons.sort_rounded,
                  accentColor: const Color(0xFF6366F1),
                  onChanged: (val) {
                    setState(() => _sortOrder = val);
                    _updateFilteredStores();
                  },
                  items: const [
                    _DropdownItemData(
                      value: 'CODE_ASC',
                      label: 'Code: Low to High',
                      icon: Icons.format_list_numbered_rounded,
                    ),
                    _DropdownItemData(
                      value: 'CODE_DESC',
                      label: 'Code: High to Low',
                      icon: Icons.format_list_numbered_rtl_rounded,
                    ),
                    _DropdownItemData(
                      value: 'NAME_ASC',
                      label: 'Name: A to Z',
                      icon: Icons.sort_by_alpha_rounded,
                    ),
                    _DropdownItemData(
                      value: 'NAME_DESC',
                      label: 'Name: Z to A',
                      icon: Icons.sort_by_alpha_rounded,
                    ),
                    _DropdownItemData(
                      value: 'LOCATION_ASC',
                      label: 'Location: A to Z',
                      icon: Icons.place_outlined,
                    ),
                  ],
                ),
                const SizedBox(width: 10),

                // Dropdown 2: Location Filter Dropdown (alignRight: true to align perfectly with button & container)
                _SwitchableDropdownButton<String>(
                  id: 'LOCATION',
                  width: 190,
                  alignRight: true,
                  headerTitle: 'FILTER BY LOCATION',
                  value: _selectedLocationFilter,
                  activeOpenId: _activeOpenDropdownId,
                  onToggleOpen: (id) => setState(() => _activeOpenDropdownId = id),
                  leadingIcon: Icons.location_on_rounded,
                  accentColor: const Color(0xFF0D9488),
                  onChanged: (val) {
                    setState(() => _selectedLocationFilter = val);
                    _updateFilteredStores();
                  },
                  items: uniqueLocations.map((loc) {
                    return _DropdownItemData<String>(
                      value: loc,
                      label: loc == 'ALL' ? 'All Locations' : loc,
                      icon: loc == 'ALL' ? Icons.travel_explore_rounded : Icons.place_rounded,
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsAndToolbar() {
    return Row(
      children: [
        // Active Filters Badge & Quick Clear Button
        if (_activeFilterCount > 0) ...[
          InkWell(
            onTap: _resetAllFilters,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_alt_rounded, size: 14, color: Color(0xFFB45309)),
                  const SizedBox(width: 5),
                  Text(
                    'Filters Active ($_activeFilterCount)',
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.close_rounded, size: 14, color: Color(0xFFB45309)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],

        // Search Input Bar (Expanded)
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(18),
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
              style: const TextStyle(color: AppColors.neutralDark, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search store code, name, series or location...',
                hintStyle: TextStyle(
                  color: AppColors.neutralDark.withValues(alpha: 0.4),
                  fontSize: 12.5,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.secondaryColor,
                  size: 18,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => _searchCtrl.clear(),
                      ),
                    // Visual [Ctrl+K] Chip Badge
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundColor,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Text(
                        'Ctrl+K',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutralDark,
                        ),
                      ),
                    ),
                  ],
                ),
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

        // Export Button
        _AnimatedExportButton(onPressed: _showComprehensiveExportModal),
        const SizedBox(width: 10),

        // Add New Store Button
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
          onPressed: () => _showStoreFormSquareModal(),
          icon: const Icon(Icons.add_business_rounded, size: 18),
          label: const Text(
            'Add New Store',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  // Dynamic Responsive Bento Grid (4 to 5 cards per row on wide screens)
  Widget _buildBentoCardGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        int crossAxisCount = 3;
        if (w >= 1650) {
          crossAxisCount = 5;
        } else if (w >= 1300) {
          crossAxisCount = 4;
        } else if (w >= 950) {
          crossAxisCount = 3;
        } else if (w >= 600) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        return RefreshIndicator(
          onRefresh: _fetchData,
          child: GridView.builder(
            itemCount: _filteredStores.length,
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: 148,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (ctx, index) {
              final store = _filteredStores[index];
              final isNewGlow = store.strCode == _recentlySavedCode;
              final isUpdateGlow = store.strCode == _recentlyUpdatedCode;
              return _BentoStoreCard(
                store: store,
                isNewGlow: isNewGlow,
                isUpdateGlow: isUpdateGlow,
                onEdit: () => _showStoreFormSquareModal(storeToEdit: store),
                onDelete: () => _confirmDelete(store),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildShimmerGridLoading() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        int count = w >= 1650 ? 5 : (w >= 1300 ? 4 : (w >= 950 ? 3 : 2));
        return GridView.builder(
          itemCount: count * 2,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisExtent: 168,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (ctx, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.secondaryColor.withValues(alpha: 0.5),
                    strokeWidth: 2,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Clean Empty State View with Reset Filters Action
  Widget _buildEmptyState() {
    return Center(
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
              Icons.search_off_rounded,
              size: 44,
              color: AppColors.secondaryColor,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No store records match your search criteria',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: AppColors.neutralDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _activeFilterCount > 0
                ? 'Try adjusting or clearing your active filters to see all store registers.'
                : 'Click "+ Add New Store" above to create your first inventory store register.',
            style: TextStyle(fontSize: 12.5, color: AppColors.neutralDark.withValues(alpha: 0.6)),
          ),
          if (_activeFilterCount > 0) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: _resetAllFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Reset Filters', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFE53E3E), size: 36),
            const SizedBox(height: 10),
            const Text(
              'Backend API Connection Error',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unable to connect to Store Master API',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }
}



// ============================================================================
// SLEEK SPARKLINE KPI CARD WIDGET (REFERENCE IMAGE 2 STYLE)
// ============================================================================
class _SparklineKpiCard extends StatefulWidget {
  final String label;
  final String value;
  final List<Color> gradientColors;
  final List<Offset> points;
  final double width;
  final double height;

  const _SparklineKpiCard({
    required this.label,
    required this.value,
    required this.gradientColors,
    required this.points,
    this.width = 180,
    this.height = 48,
  });

  @override
  State<_SparklineKpiCard> createState() => _SparklineKpiCardState();
}

class _SparklineKpiCardState extends State<_SparklineKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.gradientColors.last;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: widget.width,
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: _isHovered ? 0.38 : 0.24),
              blurRadius: _isHovered ? 12 : 7,
              offset: Offset(0, _isHovered ? 3.5 : 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
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
                        fontSize: 18.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        height: 1.05,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 24,
              child: CustomPaint(
                painter: _SparklinePainter(points: widget.points),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<Offset> points;

  const _SparklinePainter({
    required this.points,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    const pad = 3.5;
    final usableW = size.width - pad * 2;
    final usableH = size.height - pad * 2;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final nodeStrokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final nodeFillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final pixelPoints = points.map((p) {
      return Offset(pad + p.dx * usableW, pad + p.dy * usableH);
    }).toList();

    final path = Path();
    path.moveTo(pixelPoints.first.dx, pixelPoints.first.dy);
    for (int i = 1; i < pixelPoints.length; i++) {
      path.lineTo(pixelPoints[i].dx, pixelPoints[i].dy);
    }

    // Draw sparkline connecting path
    canvas.drawPath(path, linePaint);

    // Draw circular ring nodes (Image 2 style)
    for (final pt in pixelPoints) {
      canvas.drawCircle(pt, 2.7, nodeFillPaint);
      canvas.drawCircle(pt, 2.7, nodeStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => false;
}

class _DropdownItemData<T> {
  final T value;
  final String label;
  final IconData? icon;

  const _DropdownItemData({
    required this.value,
    required this.label,
    this.icon,
  });
}

class _SwitchableDropdownButton<T> extends StatefulWidget {
  final T value;
  final String id;
  final String? activeOpenId;
  final String? headerTitle;
  final double width;
  final bool alignRight;
  final ValueChanged<String?> onToggleOpen;
  final IconData leadingIcon;
  final Color accentColor;
  final List<_DropdownItemData<T>> items;
  final ValueChanged<T> onChanged;

  const _SwitchableDropdownButton({
    required this.value,
    required this.id,
    required this.activeOpenId,
    this.headerTitle,
    this.width = 190,
    this.alignRight = false,
    required this.onToggleOpen,
    required this.leadingIcon,
    required this.accentColor,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_SwitchableDropdownButton<T>> createState() => _SwitchableDropdownButtonState<T>();
}

class _SwitchableDropdownButtonState<T> extends State<_SwitchableDropdownButton<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    if (widget.activeOpenId == widget.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.activeOpenId == widget.id) {
          _showOverlay();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _SwitchableDropdownButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeOpenId == widget.id && _overlayEntry == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.activeOpenId == widget.id) {
          _showOverlay();
        }
      });
    } else if (widget.activeOpenId != widget.id && _overlayEntry != null) {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    _hideOverlay();

    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size(widget.width, 38);
    // Menu width perfectly matches the button width for seamless flush alignment
    final overlayWidth = size.width;
    final double xOffset = widget.alignRight ? (size.width - overlayWidth) : 0.0;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Hit-test transparent barrier
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (_) {
                  widget.onToggleOpen(null);
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              width: overlayWidth,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(xOffset, size.height + 6),
                child: Material(
                  elevation: 16,
                  shadowColor: Colors.black.withValues(alpha: 0.16),
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.headerTitle != null) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  widget.headerTitle!,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${widget.items.length}',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        ],
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: RawScrollbar(
                            thumbColor: widget.accentColor.withValues(alpha: 0.35),
                            radius: const Radius.circular(4),
                            thickness: 3.5,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: widget.items.map((item) {
                                  final isSelected = item.value == widget.value;
                                  return _DropdownOptionTile<T>(
                                    item: item,
                                    isSelected: isSelected,
                                    accentColor: widget.accentColor,
                                    onTap: () {
                                      widget.onChanged(item.value);
                                      widget.onToggleOpen(null);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
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

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = widget.activeOpenId == widget.id;
    final selectedItem = widget.items.firstWhere(
      (e) => e.value == widget.value,
      orElse: () => widget.items.first,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: () {
          if (isOpen) {
            widget.onToggleOpen(null);
          } else {
            widget.onToggleOpen(widget.id);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOpen
                  ? widget.accentColor
                  : const Color(0xFFE2E8F0),
              width: isOpen ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isOpen
                    ? widget.accentColor.withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: isOpen ? 8 : 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(widget.leadingIcon, size: 13, color: widget.accentColor),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  selectedItem.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isOpen ? widget.accentColor : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownOptionTile<T> extends StatefulWidget {
  final _DropdownItemData<T> item;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _DropdownOptionTile({
    required this.item,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_DropdownOptionTile<T>> createState() => _DropdownOptionTileState<T>();
}

class _DropdownOptionTileState<T> extends State<_DropdownOptionTile<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: _isHovered ? 12 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.accentColor.withValues(alpha: 0.12)
                : (_isHovered ? const Color(0xFFF1F5F9) : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? widget.accentColor.withValues(alpha: 0.35)
                  : (_isHovered ? const Color(0xFFCBD5E1) : Colors.transparent),
              width: 1,
            ),
            boxShadow: _isHovered && !widget.isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (widget.item.icon != null) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? widget.accentColor.withValues(alpha: 0.18)
                        : (_isHovered ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    widget.item.icon,
                    size: 12.5,
                    color: widget.isSelected
                        ? widget.accentColor
                        : (_isHovered ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 140),
                  style: TextStyle(
                    color: widget.isSelected
                        ? widget.accentColor
                        : (_isHovered ? const Color(0xFF0F172A) : const Color(0xFF1E293B)),
                    fontSize: 12,
                    fontWeight: widget.isSelected
                        ? FontWeight.w800
                        : (_isHovered ? FontWeight.w700 : FontWeight.w600),
                  ),
                  child: Text(widget.item.label),
                ),
              ),
              if (widget.isSelected) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: widget.accentColor,
                ),
              ] else if (_isHovered) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Animated Export Button
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
// SLEEK ACTION BUTTON WITH HOVER STATE ANIMATION (PROJECT MASTER IDENTICAL)
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
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: _isHovered ? widget.hoverBg : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 13.5,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 1. RESPONSIVE CARD GRID COMPONENT (_BentoStoreCard) - 100% PROJECT MASTER UI
// ============================================================================
class _BentoStoreCard extends StatefulWidget {
  final StoreMaster store;
  final bool isNewGlow;
  final bool isUpdateGlow;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BentoStoreCard({
    required this.store,
    this.isNewGlow = false,
    this.isUpdateGlow = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_BentoStoreCard> createState() => _BentoStoreCardState();
}

class _BentoStoreCardState extends State<_BentoStoreCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  AnimationController? _glowController;
  late Animation<double> _glowAnimation;

  bool get _isGlowing => widget.isNewGlow || widget.isUpdateGlow;

  @override
  void initState() {
    super.initState();
    if (_isGlowing) {
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
      _glowAnimation = Tween<double>(begin: 0.25, end: 0.65).animate(
        CurvedAnimation(parent: _glowController!, curve: Curves.easeInOut),
      );
    }
    _glowController!.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _BentoStoreCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasGlowing = oldWidget.isNewGlow || oldWidget.isUpdateGlow;
    if (_isGlowing != wasGlowing) {
      if (_isGlowing) {
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

  Widget _buildUniqueStoreEmblem(int strCode) {
    IconData iconData;
    List<Color> gradientColors;
    Color shadowColor;

    switch (strCode % 5) {
      case 1:
        // Project Master Style Emblem #1: Royal Sapphire Storefront
        iconData = Icons.storefront_rounded;
        gradientColors = const [Color(0xFF2563EB), Color(0xFF3B82F6), Color(0xFF06B6D4)];
        shadowColor = const Color(0xFF2563EB);
        break;
      case 2:
        // Project Master Style Emblem #2: Emerald Inventory Box
        iconData = Icons.inventory_2_rounded;
        gradientColors = const [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)];
        shadowColor = const Color(0xFF059669);
        break;
      case 3:
        // Project Master Style Emblem #3: Neon Violet Warehouse
        iconData = Icons.warehouse_rounded;
        gradientColors = const [Color(0xFF7C3AED), Color(0xFF9333EA), Color(0xFFD946EF)];
        shadowColor = const Color(0xFF7C3AED);
        break;
      case 4:
        // Project Master Style Emblem #4: Warm Amber Logistics
        iconData = Icons.local_shipping_rounded;
        gradientColors = const [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFBBF24)];
        shadowColor = const Color(0xFFD97706);
        break;
      default:
        // Project Master Style Emblem #5/0: Cyan Enterprise Domain
        iconData = Icons.domain_rounded;
        gradientColors = const [Color(0xFF0891B2), Color(0xFF06B6D4), Color(0xFF38BDF8)];
        shadowColor = const Color(0xFF0891B2);
        break;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          iconData,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final codeFormatted = '#${s.strCode.toString().padLeft(2, '0')}';
    final isNewGlow = widget.isNewGlow;
    final isUpdateGlow = widget.isUpdateGlow;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowAlpha = _isGlowing ? _glowAnimation.value : 0.0;

        return GestureDetector(
          onDoubleTap: widget.onEdit, // Double-Click Grid Card to open edit modal!
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _isHovered ? -3.0 : 0.0, 0),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: isNewGlow
                    ? const Color(0xFFF0FDF4)
                    : (isUpdateGlow
                        ? const Color(0xFFFFFBEB)
                        : (_isHovered ? Colors.white : const Color(0xFFFAFAFC))),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isNewGlow
                      ? const Color(0xFF10B981)
                      : (isUpdateGlow
                          ? const Color(0xFFF59E0B)
                          : (_isHovered ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0))),
                  width: (isNewGlow || isUpdateGlow) ? 1.8 : (_isHovered ? 1.4 : 1.0),
                ),
                boxShadow: isNewGlow
                    ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: glowAlpha),
                          blurRadius: 14,
                          spreadRadius: 1.5,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : (isUpdateGlow
                        ? [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: glowAlpha),
                              blurRadius: 14,
                              spreadRadius: 1.5,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : (_isHovered
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.025),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1.5),
                                ),
                              ])),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Top Enhanced Holographic Gradient Accent Line (Project Master Signature)
                  Positioned(
                    top: -11,
                    left: 10,
                    right: 10,
                    child: Container(
                      height: 3.2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isNewGlow
                              ? const [Color(0xFF10B981), Color(0xFF34D399), Color(0xFF6EE7B7)]
                              : (isUpdateGlow
                                  ? const [Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFFDE68A)]
                                  : (_isHovered
                                      ? const [Color(0xFF2563EB), Color(0xFF4F46E5), Color(0xFF06B6D4), Color(0xFFD946EF)]
                                      : const [Color(0xFF818CF8), Color(0xFFC7D2FE), Color(0xFF93C5FD)])),
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: (isNewGlow || isUpdateGlow || _isHovered)
                            ? [
                                BoxShadow(
                                  color: isNewGlow
                                      ? const Color(0xFF10B981).withValues(alpha: 0.6)
                                      : (isUpdateGlow
                                          ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                                          : const Color(0xFF2563EB).withValues(alpha: 0.6)),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                    ),
                  ),

                  // Main Card Contents Column
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Row: Code Pill + New/Update Glow Badge + Action Capsule
                        Row(
                          children: [
                            // Holographic Code Chip (Clean single # without duplicate icon)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: const Color(0xFFC7D2FE), width: 1.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                codeFormatted,
                                style: const TextStyle(
                                  color: Color(0xFF4F46E5),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            if (isNewGlow) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                      blurRadius: 5,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.stars_rounded, size: 10, color: Colors.white),
                                    SizedBox(width: 2.5),
                                    Text(
                                      'NEW',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isUpdateGlow) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                      blurRadius: 5,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt_rounded, size: 10, color: Colors.white),
                                    SizedBox(width: 2.5),
                                    Text(
                                      'UPDATED',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Spacer(),

                            // Sleek Action Capsule Container
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
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
                                    color: const Color(0xFF2563EB),
                                    hoverBg: const Color(0xFFEFF6FF),
                                    tooltip: 'Edit Store',
                                    onPressed: widget.onEdit,
                                  ),
                                  const SizedBox(width: 2),
                                  _ActionIconButton(
                                    icon: Icons.delete_outline_rounded,
                                    color: const Color(0xFFEF4444),
                                    hoverBg: const Color(0xFFFEF2F2),
                                    tooltip: 'Delete Store',
                                    onPressed: widget.onDelete,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Center Body: Dynamic 3D Unique Emblem + Store Name & Location
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              _buildUniqueStoreEmblem(s.strCode),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      s.strName.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        height: 1.2,
                                        letterSpacing: -0.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2.5),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          size: 10.5,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 2.5),
                                        Expanded(
                                          child: Text(
                                            s.locationName.toUpperCase(),
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 10,
                                              letterSpacing: 0.15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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

                        // Subtle Card Divider Line
                        Container(
                          height: 1,
                          color: const Color(0xFFF1F5F9),
                        ),

                        // Bottom Footer: Tag Chips & Registered Badge
                        Row(
                          children: [
                            if (s.strSeries.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.label_rounded,
                                      color: Color(0xFF0284C7),
                                      size: 9.5,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      s.strSeries,
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (s.strFixChar.isNotEmpty) ...[
                              if (s.strSeries.isNotEmpty) const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.tag_rounded,
                                      color: Color(0xFFD97706),
                                      size: 9.5,
                                    ),
                                    const SizedBox(width: 2.5),
                                    Text(
                                      s.strFixChar,
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (s.strSeries.isEmpty && s.strFixChar.isEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.store_rounded,
                                      color: Color(0xFF64748B),
                                      size: 9.5,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'STORE',
                                      style: TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 4.5,
                                    height: 4.5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 3.5),
                                  const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: Color(0xFF047857),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
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
// SQUARE SHAPE MODAL SCREEN: _SquareStoreFormModal
// ============================================================================
class _SquareStoreFormModal extends StatefulWidget {
  final StoreMaster? store;
  final int nextCode;
  final List<LocationLookupDto> locationsLookup;
  final StoreService storeService;
  final Function(StoreMaster store, bool isEdit) onSuccess;

  const _SquareStoreFormModal({
    required this.store,
    required this.nextCode,
    required this.locationsLookup,
    required this.storeService,
    required this.onSuccess,
  });

  @override
  State<_SquareStoreFormModal> createState() => _SquareStoreFormModalState();
}

class _ModernFashionLocationDropdown extends StatefulWidget {
  final int? selectedLocCode;
  final List<LocationLookupDto> locationsLookup;
  final ValueChanged<int> onChanged;
  final FormFieldValidator<int>? validator;

  const _ModernFashionLocationDropdown({
    required this.selectedLocCode,
    required this.locationsLookup,
    required this.onChanged,
    this.validator,
  });

  @override
  State<_ModernFashionLocationDropdown> createState() => _ModernFashionLocationDropdownState();
}

class _ModernFashionLocationDropdownState extends State<_ModernFashionLocationDropdown>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _isHovered = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );
    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Curves.easeOutBack,
      ),
    );
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    if (widget.locationsLookup.isEmpty) return;
    _closeMenu();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;
    final spaceBelow = screenSize.height - (offset.dy + size.height);

    const double maxMenuHeight = 186.0;
    final double calculatedHeight = math.min<double>(widget.locationsLookup.length * 40.0 + 42.0, maxMenuHeight);
    final bool openUpwards = spaceBelow < (calculatedHeight + 10);
    final double offsetY = openUpwards ? -(calculatedHeight + 4) : (size.height + 4);

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            // Barrier to dismiss when clicking outside
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (_) => _closeMenu(),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Positioned Dropdown Menu with entrance animation
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, offsetY),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    alignment: openUpwards ? Alignment.bottomCenter : Alignment.topCenter,
                    child: Material(
                      elevation: 16,
                      shadowColor: Colors.black.withValues(alpha: 0.18),
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: const Color(0xFFE11D48).withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(maxHeight: maxMenuHeight),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE4E6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFE11D48)),
                                  ),
                                  const SizedBox(width: 7),
                                  const Text(
                                    'STORE LOCATIONS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${widget.locationsLookup.length} Options',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Scrollable List with Smooth Responsive Animated Scrolling & Interactive Scrollbar
                            Flexible(
                              child: RawScrollbar(
                                controller: _scrollController,
                                thumbVisibility: true,
                                interactive: true,
                                thickness: 5,
                                radius: const Radius.circular(5),
                                thumbColor: const Color(0xFF94A3B8),
                                trackVisibility: true,
                                trackColor: const Color(0xFFF1F5F9),
                                trackRadius: const Radius.circular(5),
                                trackBorderColor: Colors.transparent,
                                padding: const EdgeInsets.only(right: 3, top: 4, bottom: 4),
                                minThumbLength: 32,
                                pressDuration: Duration.zero,
                                child: Listener(
                                  onPointerSignal: (pointerSignal) {
                                    if (pointerSignal is PointerScrollEvent && _scrollController.hasClients) {
                                      GestureBinding.instance.pointerSignalResolver.register(pointerSignal, (event) {
                                        final scrollEvent = event as PointerScrollEvent;
                                        final currentOffset = _scrollController.offset;
                                        final maxOffset = _scrollController.position.maxScrollExtent;
                                        final targetOffset = (currentOffset + scrollEvent.scrollDelta.dy * 0.75).clamp(0.0, maxOffset);
                                        _scrollController.animateTo(
                                          targetOffset,
                                          duration: const Duration(milliseconds: 140),
                                          curve: Curves.easeOutCubic,
                                        );
                                      });
                                    }
                                  },
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    physics: const ClampingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: widget.locationsLookup.map((loc) {
                                        final isSelected = loc.locCode == widget.selectedLocCode;
                                        return _LocationDropdownOptionTile(
                                          key: ValueKey(loc.locCode),
                                          loc: loc,
                                          isSelected: isSelected,
                                          onTap: () {
                                            _closeMenu();
                                            widget.onChanged(loc.locCode);
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
    _animCtrl.forward(from: 0.0);

    // Smooth, responsive auto-scroll animation to selected item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 60), () {
        if (!_scrollController.hasClients) return;
        final selectedIndex = widget.locationsLookup.indexWhere(
          (l) => l.locCode == widget.selectedLocCode,
        );
        if (selectedIndex > 0) {
          // Start from top, then smoothly glide down to the selected location
          _scrollController.jumpTo(0.0);
          final double itemHeight = 39.0;
          final double targetOffset = (selectedIndex * itemHeight - 20.0).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          );
          if (targetOffset > 0) {
            _scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 440),
              curve: Curves.easeOutQuart,
            );
          }
        } else if (_scrollController.position.maxScrollExtent > 0) {
          // Responsive scroll bounce preview indicating scrollability
          _scrollController.animateTo(
            28.0,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutQuad,
          ).then((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInQuad,
              );
            }
          });
        }
      });
    });
  }

  void _closeMenu() {
    if (!_isOpen) return;
    _isOpen = false;
    if (mounted) setState(() {});
    _animCtrl.reverse().then((_) {
      if (_overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ModernFashionLocationDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isOpen && _overlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isOpen && _overlayEntry != null && mounted) {
          _overlayEntry!.markNeedsBuild();
        }
      });
    }
  }

  @override
  void dispose() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isOpen = false;
    }
    _animCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedLoc = widget.locationsLookup.firstWhere(
      (l) => l.locCode == widget.selectedLocCode,
      orElse: () => widget.locationsLookup.isNotEmpty
          ? widget.locationsLookup.first
          : LocationLookupDto(locCode: 1, locationName: 'Default Location'),
    );

    return FormField<int>(
      key: ValueKey(widget.selectedLocCode),
      initialValue: widget.selectedLocCode,
      validator: widget.validator,
      builder: (fieldState) {
        final hasError = fieldState.hasError;
        return CompositedTransformTarget(
          link: _layerLink,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: InkWell(
              onTap: _toggleMenu,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasError
                        ? const Color(0xFFEF4444)
                        : (_isOpen || _isHovered ? const Color(0xFFE11D48) : const Color(0xFFCBD5E1)),
                    width: _isOpen ? 1.5 : 1.0,
                  ),
                  boxShadow: _isOpen
                      ? [
                          BoxShadow(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.10),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      size: 15,
                      color: Color(0xFFE11D48),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedLoc.locationName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '#${selectedLoc.locCode}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LocationDropdownOptionTile extends StatefulWidget {
  final LocationLookupDto loc;
  final bool isSelected;
  final VoidCallback onTap;

  const _LocationDropdownOptionTile({
    super.key,
    required this.loc,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LocationDropdownOptionTile> createState() => _LocationDropdownOptionTileState();
}

class _LocationDropdownOptionTileState extends State<_LocationDropdownOptionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final loc = widget.loc;

    final Color bgColor;
    if (isSelected) {
      bgColor = const Color(0xFFFFF1F2);
    } else if (_isHovered) {
      bgColor = const Color(0xFFF1F5F9);
    } else {
      bgColor = Colors.transparent;
    }

    final Color borderColor;
    if (isSelected) {
      borderColor = const Color(0xFFFECDD3);
    } else if (_isHovered) {
      borderColor = const Color(0xFFCBD5E1);
    } else {
      borderColor = Colors.transparent;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          padding: EdgeInsets.symmetric(
            horizontal: _isHovered ? 12 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: _isHovered && !isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFFE4E6)
                      : (_isHovered ? const Color(0xFFE2E8F0) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  Icons.place_rounded,
                  size: 13,
                  color: isSelected
                      ? const Color(0xFFE11D48)
                      : (_isHovered ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 140),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w800
                        : (_isHovered ? FontWeight.w700 : FontWeight.w600),
                    color: isSelected
                        ? const Color(0xFFE11D48)
                        : (_isHovered ? const Color(0xFF0F172A) : const Color(0xFF1E293B)),
                  ),
                  overflow: TextOverflow.ellipsis,
                  child: Text(loc.locationName),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE11D48).withValues(alpha: 0.12)
                      : (_isHovered ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${loc.locCode}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? const Color(0xFFE11D48)
                        : (_isHovered ? const Color(0xFF1E293B) : const Color(0xFF64748B)),
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFFE11D48)),
              ] else if (_isHovered) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareStoreFormModalState extends State<_SquareStoreFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _seriesCtrl;
  late TextEditingController _fixCharCtrl;

  int? _selectedLocCode;
  bool _isSaving = false;
  bool _isSaveSuccess = false;
  String? _errorMsg;

  String? _seriesWarning;
  String? _fixCharWarning;
  Timer? _seriesTimer;
  Timer? _fixCharTimer;

  @override
  void initState() {
    super.initState();
    final isEdit = widget.store != null;
    _codeCtrl = TextEditingController(
      text: isEdit ? widget.store!.strCode.toString() : widget.nextCode.toString(),
    );
    _nameCtrl = TextEditingController(
      text: isEdit ? widget.store!.strName : '',
    );
    _seriesCtrl = TextEditingController(
      text: isEdit ? widget.store!.strSeries : '',
    );
    _fixCharCtrl = TextEditingController(
      text: isEdit ? widget.store!.strFixChar : '',
    );

    if (isEdit) {
      _selectedLocCode = widget.store!.locCode;
    } else if (widget.locationsLookup.isNotEmpty) {
      _selectedLocCode = widget.locationsLookup.first.locCode;
    }
  }

  @override
  void dispose() {
    _seriesTimer?.cancel();
    _fixCharTimer?.cancel();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _seriesCtrl.dispose();
    _fixCharCtrl.dispose();
    super.dispose();
  }

  void _triggerSeriesLimitWarning() {
    _seriesTimer?.cancel();
    setState(() {
      _seriesWarning = 'Max 8 chars limit reached!';
    });
    _seriesTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _seriesWarning = null);
    });
  }

  void _triggerFixCharLimitWarning() {
    _fixCharTimer?.cancel();
    setState(() {
      _fixCharWarning = 'Max 3 chars limit reached!';
    });
    _fixCharTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _fixCharWarning = null);
    });
  }

  Widget _buildFormFieldCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, size: 12, color: iconColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
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
    final locCode = _selectedLocCode ?? 1;
    final series = _seriesCtrl.text.trim();
    final fixChar = _fixCharCtrl.text.trim();
    final isEdit = widget.store != null;

    final matchedLoc = widget.locationsLookup.firstWhere(
      (l) => l.locCode == locCode,
      orElse: () => LocationLookupDto(locCode: locCode, locationName: 'Location #$locCode'),
    );

    try {
      bool success = false;
      if (isEdit) {
        success = await widget.storeService.updateStore(code, name, locCode, series: series, fixChar: fixChar);
      } else {
        success = await widget.storeService.createStore(code, name, locCode, series: series, fixChar: fixChar);
      }

      if (mounted) {
        if (success) {
          setState(() {
            _isSaving = false;
            _isSaveSuccess = true;
          });
          final saved = StoreMaster(
            strCode: code,
            strName: name,
            locCode: locCode,
            locationName: matchedLoc.locationName,
            strSeries: series,
            strFixChar: fixChar,
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
    final isEdit = widget.store != null;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 760,
        height: 620,
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 36,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 18, 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.8)),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/create_store_master_logo.png',
                        width: 68,
                        height: 68,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Edit Store Master' : 'Create Store Master',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            isEdit ? 'Update details for #${widget.store!.strCode}' : 'Add a new inventory store register',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.neutralDark.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                if (_errorMsg != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBF0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFEB2B2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFE53E3E), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: const TextStyle(color: Color(0xFF9B2C2C), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT COLUMN: STORE CODE, STORE NAME, LOCATION
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // FIELD 1: STORE CODE (BLUE #2563EB)
                              _buildFormFieldCard(
                                title: 'STORE CODE',
                                icon: Icons.qr_code_rounded,
                                iconColor: const Color(0xFF2563EB),
                                bgColor: const Color(0xFFEFF6FF),
                                borderColor: const Color(0xFFBFDBFE),
                                child: SizedBox(
                                  height: 38,
                                  child: TextField(
                                    controller: _codeCtrl,
                                    readOnly: true,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: isEdit ? const Color(0xFF475569) : const Color(0xFF0F172A),
                                      letterSpacing: 0.2,
                                    ),
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        isEdit ? Icons.lock_outline_rounded : Icons.numbers_rounded,
                                        size: 15,
                                        color: isEdit ? const Color(0xFF94A3B8) : const Color(0xFF2563EB),
                                      ),
                                      suffixIcon: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        alignment: Alignment.centerRight,
                                        width: 52,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: isEdit ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: isEdit ? const Color(0xFFCBD5E1) : const Color(0xFFBFDBFE),
                                            ),
                                          ),
                                          child: Text(
                                            isEdit ? 'Lock' : 'Auto',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: isEdit ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      hintText: 'Auto Code',
                                      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      filled: true,
                                      fillColor: isEdit ? const Color(0xFFF8FAFC) : const Color(0xFFF0F7FF),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: isEdit ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: isEdit ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE)),
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // FIELD 2: STORE NAME (EMERALD GREEN #059669)
                              _buildFormFieldCard(
                                title: 'STORE NAME *',
                                icon: Icons.storefront_rounded,
                                iconColor: const Color(0xFF059669),
                                bgColor: const Color(0xFFD1FAE5),
                                borderColor: const Color(0xFFA7F3D0),
                                child: TextFormField(
                                  controller: _nameCtrl,
                                  autofocus: true,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Store name is required';
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'e.g. MAIN STORE, RAW MATERIAL STORE',
                                    hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF059669)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // FIELD 3: LOCATION (ROSE #E11D48)
                              _buildFormFieldCard(
                                title: 'LOCATION *',
                                icon: Icons.location_on_rounded,
                                iconColor: const Color(0xFFE11D48),
                                bgColor: const Color(0xFFFFE4E6),
                                borderColor: const Color(0xFFFDA4AF),
                                child: _ModernFashionLocationDropdown(
                                  selectedLocCode: _selectedLocCode,
                                  locationsLookup: widget.locationsLookup,
                                  validator: (val) {
                                    if (val == null || val <= 0) {
                                      return 'Please select a location';
                                    }
                                    return null;
                                  },
                                  onChanged: (val) {
                                    setState(() => _selectedLocCode = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 22),

                        // RIGHT COLUMN: TOP ROW (PREFIX SERIES & FIX CHARACTER), BOTTOM 3D MODEL
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // FIELD 4: PREFIX SERIES (INDIGO #4F46E5)
                                  Expanded(
                                    child: _buildFormFieldCard(
                                      title: 'PREFIX SERIES',
                                      icon: Icons.local_offer_rounded,
                                      iconColor: const Color(0xFF4F46E5),
                                      bgColor: const Color(0xFFEEF2FF),
                                      borderColor: const Color(0xFFC7D2FE),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextFormField(
                                            controller: _seriesCtrl,
                                            inputFormatters: [
                                              _MaxCharLimitFormatter(
                                                8,
                                                _triggerSeriesLimitWarning,
                                              ),
                                            ],
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                            validator: (val) {
                                              if (val != null && val.trim().length > 8) {
                                                return 'Max 8 characters allowed';
                                              }
                                              return null;
                                            },
                                            decoration: InputDecoration(
                                              hintText: 'e.g. STR01',
                                              counterText: '',
                                              prefixIcon: const Icon(Icons.tag_rounded, size: 15, color: Color(0xFF4F46E5)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                                              ),
                                            ),
                                          ),
                                          if (_seriesWarning != null) ...[
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF2F2),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFFECACA)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFDC2626)),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      _seriesWarning!,
                                                      style: const TextStyle(
                                                        color: Color(0xFFDC2626),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // FIELD 5: FIX CHARACTER (AMBER #D97706)
                                  Expanded(
                                    child: _buildFormFieldCard(
                                      title: 'FIX CHARACTER',
                                      icon: Icons.subtitles_rounded,
                                      iconColor: const Color(0xFFD97706),
                                      bgColor: const Color(0xFFFEF3C7),
                                      borderColor: const Color(0xFFFDE68A),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextFormField(
                                            controller: _fixCharCtrl,
                                            inputFormatters: [
                                              _MaxCharLimitFormatter(
                                                3,
                                                _triggerFixCharLimitWarning,
                                              ),
                                            ],
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                            validator: (val) {
                                              if (val != null && val.trim().length > 3) {
                                                return 'Max 3 characters allowed';
                                              }
                                              return null;
                                            },
                                            decoration: InputDecoration(
                                              hintText: 'e.g. RAW',
                                              counterText: '',
                                              prefixIcon: const Icon(Icons.short_text_rounded, size: 16, color: Color(0xFFD97706)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                                              ),
                                            ),
                                          ),
                                          if (_fixCharWarning != null) ...[
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF2F2),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFFECACA)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFDC2626)),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      _fixCharWarning!,
                                                      style: const TextStyle(
                                                        color: Color(0xFFDC2626),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // 3D MODEL WIDGET (UNTOUCHED AND UNALTERED)
                              Expanded(
                                child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const _ThreeDIntegratedNatureWidget(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.divider, width: 0.8)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            side: const BorderSide(color: AppColors.divider, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.neutralDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AnimatedSuccessButton(
                          status: _isSaveSuccess
                              ? ButtonStatus.success
                              : (_isSaving ? ButtonStatus.loading : ButtonStatus.idle),
                          onPressed: _submit,
                          idleText: isEdit ? 'Update Store' : 'Save Store',
                          loadingText: 'Saving...',
                          successText: 'Saved!',
                          idleIcon: isEdit ? Icons.check_rounded : Icons.save_rounded,
                          idleBackgroundColor: AppColors.secondaryColor,
                          successBackgroundColor: const Color(0xFF10B981),
                          height: 46,
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
// INTEGRATED 3D NATURE, STORE & DELIVERY LOGISTICS SCENE (White-Space Native)
// ============================================================================
class _ThreeDIntegratedNatureWidget extends StatefulWidget {
  const _ThreeDIntegratedNatureWidget();

  @override
  State<_ThreeDIntegratedNatureWidget> createState() =>
      _ThreeDIntegratedNatureWidgetState();
}

class _ThreeDIntegratedNatureWidgetState
    extends State<_ThreeDIntegratedNatureWidget>
    with TickerProviderStateMixin {
  late AnimationController _truckMoveCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _cloudFloatCtrl;

  @override
  void initState() {
    super.initState();
    _truckMoveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _cloudFloatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _truckMoveCtrl.dispose();
    _waveCtrl.dispose();
    _cloudFloatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_truckMoveCtrl, _waveCtrl, _cloudFloatCtrl]),
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ThreeDIntegratedNaturePainter(
            truckProgress: _truckMoveCtrl.value,
            waveProgress: _waveCtrl.value,
            cloudProgress: _cloudFloatCtrl.value,
          ),
        );
      },
    );
  }
}

class _ThreeDIntegratedNaturePainter extends CustomPainter {
  final double truckProgress;
  final double waveProgress;
  final double cloudProgress;

  _ThreeDIntegratedNaturePainter({
    required this.truckProgress,
    required this.waveProgress,
    required this.cloudProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ========================================================================
    // 1. ATMOSPHERIC SKY & CELESTIAL GLOW
    // ========================================================================
    final skyRect = Rect.fromLTWH(0, 0, w, h);
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFFBAE6FD), // Sky 200
        Color(0xFFE0F2FE), // Sky 100
        Color(0xFFF0FDF4), // Soft Mint / White Horizon
      ],
      stops: const [0.0, 0.45, 1.0],
    );
    canvas.drawRect(skyRect, Paint()..shader = skyGradient.createShader(skyRect));

    // Radiant Sun with Atmospheric Coronal Glow
    final sunCenter = Offset(w * 0.82, h * 0.15 + (cloudProgress * 3));

    // Outer warm corona
    canvas.drawCircle(
      sunCenter,
      36,
      Paint()
        ..color = const Color(0xFFFDE68A).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Middle flare ring
    canvas.drawCircle(
      sunCenter,
      25,
      Paint()
        ..color = const Color(0xFFFBBF24).withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Sun core with bright radial glow
    final sunShader = ui.Gradient.radial(
      sunCenter,
      17,
      const [
        Color(0xFFFFFBEB),
        Color(0xFFFDE047),
        Color(0xFFF59E0B),
      ],
      const [0.0, 0.55, 1.0],
    );
    canvas.drawCircle(sunCenter, 17, Paint()..shader = sunShader);

    // Subtle sunbeams
    final beamPaint = Paint()
      ..color = const Color(0xFFFEF08A).withValues(alpha: 0.12)
      ..strokeWidth = 1.6;
    for (int b = 0; b < 8; b++) {
      final bAngle = (b * math.pi / 4) + (cloudProgress * 0.1);
      canvas.drawLine(
        Offset(sunCenter.dx + math.cos(bAngle) * 22, sunCenter.dy + math.sin(bAngle) * 22),
        Offset(sunCenter.dx + math.cos(bAngle) * 38, sunCenter.dy + math.sin(bAngle) * 38),
        beamPaint,
      );
    }

    // Volumetric 3D Fluffy Cumulus Clouds
    void drawDetailedCloud(double cx, double cy, double scale, double opacity) {
      final cloudBase = Paint()..color = const Color(0xFFCBD5E1).withValues(alpha: opacity * 0.7);
      final cloudHighlight = Paint()..color = Colors.white.withValues(alpha: opacity);

      // Shadowed underbelly
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + (5 * scale)), width: 56 * scale, height: 16 * scale),
        cloudBase,
      );
      // Sunlit puffy lobes
      canvas.drawCircle(Offset(cx - 15 * scale, cy + 2 * scale), 12 * scale, cloudHighlight);
      canvas.drawCircle(Offset(cx, cy - 4 * scale), 16 * scale, cloudHighlight);
      canvas.drawCircle(Offset(cx + 16 * scale, cy + 1 * scale), 13 * scale, cloudHighlight);
      canvas.drawCircle(Offset(cx + 28 * scale, cy + 4 * scale), 9 * scale, cloudHighlight);
    }

    final cloudShift = cloudProgress * 10;
    drawDetailedCloud(w * 0.14 + cloudShift, h * 0.12, 0.95, 0.92);
    drawDetailedCloud(w * 0.52 - cloudShift, h * 0.10, 1.10, 0.95);
    drawDetailedCloud(w * 0.94 - (cloudShift * 0.5), h * 0.08, 0.75, 0.70);

    // Distant soaring birds (V-formation)
    void drawBird(double bx, double by, double bScale) {
      final birdPath = Path()
        ..moveTo(bx - 5 * bScale, by + 2 * bScale)
        ..quadraticBezierTo(bx - 2 * bScale, by - 3 * bScale, bx, by)
        ..quadraticBezierTo(bx + 2 * bScale, by - 3 * bScale, bx + 5 * bScale, by + 2 * bScale);
      canvas.drawPath(
        birdPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1 * bScale
          ..color = const Color(0xFF475569).withValues(alpha: 0.75)
          ..strokeCap = StrokeCap.round,
      );
    }

    drawBird(w * 0.38, h * 0.16, 0.85);
    drawBird(w * 0.42, h * 0.14, 0.70);
    drawBird(w * 0.45, h * 0.17, 0.60);

    // ========================================================================
    // 2. MULTI-LAYER REALISTIC LUSH ROLLING HILLS
    // ========================================================================
    final roadHeight = 24.0;
    final roadTopY = h - roadHeight;

    // Layer A: Distant Misty Hill (Atmospheric Depth)
    final distantHill = Path()
      ..moveTo(-30, h * 0.46)
      ..quadraticBezierTo(w * 0.25, h * 0.32, w * 0.55, h * 0.39)
      ..quadraticBezierTo(w * 0.80, h * 0.45, w + 30, h * 0.37)
      ..lineTo(w + 30, roadTopY)
      ..lineTo(-30, roadTopY)
      ..close();

    final distantHillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFFA7F3D0), // Soft Mint Green
        Color(0xFF34D399), // Emerald 400
        Color(0xFF059669), // Emerald 600
      ],
    );
    canvas.drawPath(
      distantHill,
      Paint()..shader = distantHillGradient.createShader(Rect.fromLTWH(0, h * 0.30, w, h * 0.70)),
    );

    // Layer B: Sunlit Midground Rolling Hill
    final midHill = Path()
      ..moveTo(-30, h * 0.40)
      ..quadraticBezierTo(w * 0.28, h * 0.26, w * 0.62, h * 0.43)
      ..quadraticBezierTo(w * 0.86, h * 0.54, w + 30, h * 0.46)
      ..lineTo(w + 30, roadTopY)
      ..lineTo(-30, roadTopY)
      ..close();

    final midHillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF6EE7B7), // Emerald 300
        Color(0xFF10B981), // Emerald 500
        Color(0xFF047857), // Emerald 700
      ],
    );
    canvas.drawPath(
      midHill,
      Paint()..shader = midHillGradient.createShader(Rect.fromLTWH(0, h * 0.25, w, h * 0.75)),
    );

    // Layer C: Rich Foreground Meadow Hill
    final foreHill = Path()
      ..moveTo(-30, h * 0.52)
      ..quadraticBezierTo(w * 0.35, h * 0.48, w * 0.68, h * 0.58)
      ..quadraticBezierTo(w * 0.88, h * 0.62, w + 30, h * 0.55)
      ..lineTo(w + 30, roadTopY)
      ..lineTo(-30, roadTopY)
      ..close();

    final foreHillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF059669),
        Color(0xFF047857),
        Color(0xFF064E3B),
      ],
    );
    canvas.drawPath(
      foreHill,
      Paint()..shader = foreHillGradient.createShader(Rect.fromLTWH(0, h * 0.45, w, h * 0.55)),
    );

    // Organic Meadow Details (Wildflower dots along slope)
    final flowerPaint = Paint();
    final flowerSpots = [
      Offset(w * 0.12, h * 0.62),
      Offset(w * 0.18, h * 0.68),
      Offset(w * 0.26, h * 0.72),
      Offset(w * 0.44, h * 0.76),
      Offset(w * 0.64, h * 0.74),
      Offset(w * 0.82, h * 0.70),
      Offset(w * 0.90, h * 0.65),
    ];
    for (int f = 0; f < flowerSpots.length; f++) {
      flowerPaint.color = (f % 2 == 0 ? const Color(0xFFFDE047) : Colors.white).withValues(alpha: 0.65);
      canvas.drawCircle(flowerSpots[f], 1.4, flowerPaint);
    }

    // ========================================================================
    // 3. ULTRA-REALISTIC 3D ISO SHIPPING CONTAINERS
    // ========================================================================
    void drawRealistic3DContainer({
      required double x,
      required double y,
      required double width,
      required double height,
      required double depth,
      required Color baseColor,
      required Color darkColor,
      required Color lightColor,
      required String title,
      required String isoCode,
      required String specLine,
    }) {
      // Ambient Ground Contact Shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 3, y + height - 2, width + depth + 6, 8),
          const Radius.circular(5),
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // FRONT FACE
      final frontRect = Rect.fromLTWH(x, y, width, height);
      final frontGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lightColor, baseColor, darkColor],
      );
      canvas.drawRect(frontRect, Paint()..shader = frontGradient.createShader(frontRect));

      // Realistic Corrugated Vertical Steel Ribs
      final ribWidth = 5.2;
      for (double rx = x + 4; rx < x + width - 4; rx += ribWidth) {
        // Shadow groove
        canvas.drawLine(
          Offset(rx, y + 1),
          Offset(rx, y + height - 1),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.28)
            ..strokeWidth = 1.0,
        );
        // Highlight crest
        canvas.drawLine(
          Offset(rx + 1.2, y + 1),
          Offset(rx + 1.2, y + height - 1),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.25)
            ..strokeWidth = 1.0,
        );
      }

      // Front Perimeter Frame
      canvas.drawRect(
        frontRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF0F172A),
      );

      // Door locking vertical steel rods & handle
      canvas.drawLine(
        Offset(x + width * 0.32, y + 1),
        Offset(x + width * 0.32, y + height - 1),
        Paint()..color = const Color(0xFF0F172A)..strokeWidth = 1.0,
      );
      canvas.drawLine(
        Offset(x + width * 0.68, y + 1),
        Offset(x + width * 0.68, y + height - 1),
        Paint()..color = const Color(0xFF0F172A)..strokeWidth = 1.0,
      );
      // Rod handles
      canvas.drawRect(
        Rect.fromLTWH(x + width * 0.29, y + height * 0.48, 5, 2.5),
        Paint()..color = const Color(0xFFE2E8F0),
      );
      canvas.drawRect(
        Rect.fromLTWH(x + width * 0.65, y + height * 0.48, 5, 2.5),
        Paint()..color = const Color(0xFFE2E8F0),
      );

      // Steel Corner Casting Blocks (All 4 front corners)
      final cornerPaint = Paint()..color = const Color(0xFF0F172A);
      final socketPaint = Paint()..color = const Color(0xFF94A3B8);
      void drawCornerCasting(double cx, double cy) {
        canvas.drawRect(Rect.fromLTWH(cx, cy, 3.8, 3.8), cornerPaint);
        canvas.drawCircle(Offset(cx + 1.9, cy + 1.9), 0.9, socketPaint);
      }

      drawCornerCasting(x, y);
      drawCornerCasting(x + width - 3.8, y);
      drawCornerCasting(x, y + height - 3.8);
      drawCornerCasting(x + width - 3.8, y + height - 3.8);

      // SIDE FACE (Isometric Perspective)
      final sidePath = Path()
        ..moveTo(x + width, y)
        ..lineTo(x + width + depth, y - (depth * 0.45))
        ..lineTo(x + width + depth, y + height - (depth * 0.45))
        ..lineTo(x + width, y + height)
        ..close();

      final sideGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [darkColor, const Color(0xFF0F172A).withValues(alpha: 0.85)],
      );
      canvas.drawPath(sidePath, Paint()..shader = sideGradient.createShader(sidePath.getBounds()));
      canvas.drawPath(
        sidePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF0F172A),
      );

      // Side Corrugation Grooves
      for (double sf = 0.25; sf <= 0.75; sf += 0.25) {
        final sx1 = x + width + (depth * sf);
        final sy1 = y - (depth * 0.45 * sf);
        final sy2 = sy1 + height;
        canvas.drawLine(
          Offset(sx1, sy1),
          Offset(sx1, sy2),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.3)
            ..strokeWidth = 1.0,
        );
      }

      // TOP ROOF (Isometric Perspective)
      final topPath = Path()
        ..moveTo(x, y)
        ..lineTo(x + depth, y - (depth * 0.45))
        ..lineTo(x + width + depth, y - (depth * 0.45))
        ..lineTo(x + width, y)
        ..close();

      final topGradient = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [lightColor, lightColor.withValues(alpha: 0.8)],
      );
      canvas.drawPath(topPath, Paint()..shader = topGradient.createShader(topPath.getBounds()));
      canvas.drawPath(
        topPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF0F172A),
      );

      // Top Casting Blocks
      drawCornerCasting(x + depth - 3.8, y - (depth * 0.45));
      drawCornerCasting(x + width + depth - 3.8, y - (depth * 0.45));

      // Industrial Stencil Markings (Dynamically sized and centered to prevent collision)
      final titlePainter = TextPainter(
        text: TextSpan(
          text: title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 5.2,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final badgePadH = 3.5;
      final badgePadV = 1.8;
      final badgeW = (titlePainter.width + badgePadH * 2).clamp(18.0, width - 4.0);
      final badgeH = titlePainter.height + badgePadV * 2;
      final badgeX = x + (width - badgeW) * 0.5;
      final badgeY = y + 3.8;

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(badgeX, badgeY, badgeW, badgeH), const Radius.circular(2.5)),
        Paint()..color = Colors.white.withValues(alpha: 0.94),
      );
      titlePainter.paint(canvas, Offset(badgeX + (badgeW - titlePainter.width) * 0.5, badgeY + badgePadV));

      // ISO code compact stencil (Centered cleanly within container width)
      if (isoCode.isNotEmpty) {
        final isoText = specLine.isNotEmpty ? '$isoCode • $specLine' : isoCode;
        final isoPainter = TextPainter(
          text: TextSpan(
            text: isoText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 4.1,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final isoX = x + (width - isoPainter.width) * 0.5;
        final isoY = y + height - 7.5;
        if (isoX >= x + 2) {
          isoPainter.paint(canvas, Offset(isoX, isoY));
        }
      }
    }

    // Top Container: Evergreen Emerald
    drawRealistic3DContainer(
      x: w * 0.18,
      y: h * 0.32,
      width: 52,
      height: 25,
      depth: 10,
      baseColor: const Color(0xFF059669),
      darkColor: const Color(0xFF064E3B),
      lightColor: const Color(0xFF34D399),
      title: 'STORE BAY A',
      isoCode: 'EMCU 4920',
      specLine: 'MAX 30T',
    );

    // Bottom Left Container: Maersk Ocean Blue
    drawRealistic3DContainer(
      x: w * 0.17,
      y: h * 0.45,
      width: 52,
      height: 25,
      depth: 10,
      baseColor: const Color(0xFF0284C7),
      darkColor: const Color(0xFF0369A1),
      lightColor: const Color(0xFF38BDF8),
      title: 'RAW MAT',
      isoCode: 'MSKU 8103',
      specLine: 'TARE 2T',
    );

    // Bottom Right Container: Hapag Industrial Golden Amber
    drawRealistic3DContainer(
      x: w * 0.32,
      y: h * 0.47,
      width: 52,
      height: 25,
      depth: 10,
      baseColor: const Color(0xFFD97706),
      darkColor: const Color(0xFF92400E),
      lightColor: const Color(0xFFFBBF24),
      title: 'DISPATCH #03',
      isoCode: 'HLXU 3319',
      specLine: '28T',
    );

    // ========================================================================
    // 4. MODERN ARCHITECTURAL ECO-FULFILLMENT WAREHOUSE
    // ========================================================================
    final storeX = w * 0.50;
    final storeY = h * 0.34;
    final bldgW = 96.0;
    final bldgH = 62.0;
    final sideDepth = 14.0;

    // Ground Ambient Occlusion Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(storeX - 10, storeY + bldgH - 4, bldgW + sideDepth + 18, 18),
        const Radius.circular(12),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Concrete Plinth Foundation
    final plinthRect = Rect.fromLTWH(storeX - 2, storeY + bldgH - 6, bldgW + 4, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plinthRect, const Radius.circular(2)),
      Paint()..color = const Color(0xFF94A3B8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plinthRect, const Radius.circular(2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF64748B),
    );

    // Front Facade: Insulated Architectural Sandwich Paneling
    final facadeRect = Rect.fromLTWH(storeX, storeY, bldgW, bldgH);
    final facadeGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFFFFFFFF),
        Color(0xFFF8FAFC),
        Color(0xFFF1F5F9),
      ],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(facadeRect, const Radius.circular(8)),
      Paint()..shader = facadeGradient.createShader(facadeRect),
    );

    // Horizontal Architectural Panel Grooves
    final panelLinePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8;
    for (double py = storeY + 12; py < storeY + bldgH - 8; py += 10) {
      canvas.drawLine(Offset(storeX + 2, py), Offset(storeX + bldgW - 2, py), panelLinePaint);
    }

    // Facade Perimeter Stroke
    canvas.drawRRect(
      RRect.fromRectAndRadius(facadeRect, const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF0F172A),
    );

    // 3D Isometric Side Wall
    final sideWallPath = Path()
      ..moveTo(storeX + bldgW, storeY)
      ..lineTo(storeX + bldgW + sideDepth, storeY - (sideDepth * 0.7))
      ..lineTo(storeX + bldgW + sideDepth, storeY + bldgH - (sideDepth * 0.7))
      ..lineTo(storeX + bldgW, storeY + bldgH)
      ..close();

    final sideWallGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFF0284C7),
        Color(0xFF0369A1),
        Color(0xFF075985),
      ],
    );
    canvas.drawPath(sideWallPath, Paint()..shader = sideWallGradient.createShader(sideWallPath.getBounds()));
    canvas.drawPath(
      sideWallPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF0F172A),
    );

    // Side Wall Expansion Ribs
    for (double sf = 0.33; sf <= 0.67; sf += 0.34) {
      final sx = storeX + bldgW + (sideDepth * sf);
      final sy1 = storeY - (sideDepth * 0.7 * sf);
      final sy2 = sy1 + bldgH;
      canvas.drawLine(
        Offset(sx, sy1),
        Offset(sx, sy2),
        Paint()
          ..color = const Color(0xFF0C4A6E)
          ..strokeWidth = 1.0,
      );
    }

    // Industrial Recessed Loading Dock Bay (Center)
    final dockX = storeX + 38;
    final dockY = storeY + 28;
    final dockW = 20.0;
    final dockH = 34.0;
    final dockRect = Rect.fromLTWH(dockX, dockY, dockW, dockH);

    // Dark recessed bay interior
    canvas.drawRRect(
      RRect.fromRectAndRadius(dockRect, const Radius.circular(4)),
      Paint()..color = const Color(0xFF064E3B),
    );

    // Roll-up Sectional Shutter Door Slats
    final slatPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.35)
      ..strokeWidth = 1.0;
    for (double sy = dockY + 4; sy < dockY + dockH - 4; sy += 3.5) {
      canvas.drawLine(Offset(dockX + 2, sy), Offset(dockX + dockW - 2, sy), slatPaint);
    }

    // Dock Door Outline Frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(dockRect, const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF0F172A),
    );

    // Safety Hazard Chevron Stripes on Loading Bumpers (Left & Right)
    void drawDockBumper(double bx, double by) {
      final bumperRect = Rect.fromLTWH(bx, by, 3.5, 12);
      canvas.drawRect(bumperRect, Paint()..color = const Color(0xFFF59E0B));
      final stripePaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 1.0;
      for (double step = by + 2; step < by + 12; step += 3) {
        canvas.drawLine(Offset(bx, step), Offset(bx + 3.5, step - 2), stripePaint);
      }
      canvas.drawRect(
        bumperRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFF0F172A),
      );
    }

    drawDockBumper(dockX - 4.5, dockY + dockH - 14);
    drawDockBumper(dockX + dockW + 1.0, dockY + dockH - 14);

    // Overhead Industrial LED Loading Dock Canopy & Floodlight
    final dockCanopy = Rect.fromLTWH(dockX - 3, dockY - 3, dockW + 6, 3);
    canvas.drawRect(dockCanopy, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(Offset(dockX + (dockW * 0.5), dockY - 1.5), 2.0, Paint()..color = const Color(0xFFFDE047));
    // Soft Downward Light Cone
    final dockLightPath = Path()
      ..moveTo(dockX + (dockW * 0.5) - 2, dockY)
      ..lineTo(dockX - 2, dockY + 16)
      ..lineTo(dockX + dockW + 2, dockY + 16)
      ..lineTo(dockX + (dockW * 0.5) + 2, dockY)
      ..close();
    canvas.drawPath(
      dockLightPath,
      Paint()
        ..color = const Color(0xFFFEF08A).withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Architectural Double-Glazed Office Windows (Left & Right)
    void drawArchitecturalWindow(double wx, double wy, double ww, double wh) {
      final winRect = Rect.fromLTWH(wx, wy, ww, wh);

      // Window Glass Shader
      final glassGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFFE0F2FE),
          Color(0xFFBAE6FD),
          Color(0xFF7DD3FC),
        ],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(winRect, const Radius.circular(4)),
        Paint()..shader = glassGradient.createShader(winRect),
      );

      // Specular Reflection Highlight Streak (45 Degree Angle)
      final glarePath = Path()
        ..moveTo(wx + 3, wy + wh)
        ..lineTo(wx + ww * 0.45, wy)
        ..lineTo(wx + ww * 0.65, wy)
        ..lineTo(wx + 7, wy + wh)
        ..close();
      canvas.drawPath(glarePath, Paint()..color = Colors.white.withValues(alpha: 0.45));

      // Window Frame & Mullions
      canvas.drawRRect(
        RRect.fromRectAndRadius(winRect, const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF0F172A),
      );
      // Center Mullion
      canvas.drawLine(
        Offset(wx + (ww * 0.5), wy),
        Offset(wx + (ww * 0.5), wy + wh),
        Paint()..color = const Color(0xFF0F172A)..strokeWidth = 1.0,
      );
      canvas.drawLine(
        Offset(wx, wy + (wh * 0.5)),
        Offset(wx + ww, wy + (wh * 0.5)),
        Paint()..color = const Color(0xFF0F172A)..strokeWidth = 1.0,
      );
    }

    drawArchitecturalWindow(storeX + 10, storeY + 16, 22, 22);
    drawArchitecturalWindow(storeX + 64, storeY + 16, 22, 22);

    // Photovoltaic Solar Canopy Roof
    final roofPeakX = storeX + (bldgW * 0.5);
    final roofPeakY = storeY - 26;
    final roofOverhang = 8.0;

    final roofFrontPath = Path()
      ..moveTo(storeX - roofOverhang, storeY)
      ..lineTo(roofPeakX, roofPeakY)
      ..lineTo(storeX + bldgW + roofOverhang, storeY)
      ..lineTo(storeX + bldgW + roofOverhang + sideDepth, storeY - (sideDepth * 0.7))
      ..lineTo(roofPeakX + sideDepth, roofPeakY - (sideDepth * 0.7))
      ..lineTo(storeX - roofOverhang, storeY)
      ..close();

    // Dark Monocrystalline Solar Base
    final roofGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFF0F172A), // Dark Slate
        Color(0xFF0C4A6E), // Deep Sapphire
        Color(0xFF0369A1), // Solar Cell Navy
      ],
    );
    canvas.drawPath(roofFrontPath, Paint()..shader = roofGradient.createShader(roofFrontPath.getBounds()));
    canvas.drawPath(
      roofFrontPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF38BDF8),
    );

    // Solar Cell Metallic Busbars & Division Grids
    final solarGridPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.75)
      ..strokeWidth = 1.1;

    // Horizontal busbars
    for (double step = 0.28; step <= 0.75; step += 0.24) {
      final leftPt = Offset.lerp(Offset(storeX - roofOverhang, storeY), Offset(roofPeakX, roofPeakY), step)!;
      final rightPt = Offset.lerp(Offset(storeX + bldgW + roofOverhang, storeY), Offset(roofPeakX, roofPeakY), step)!;
      canvas.drawLine(leftPt, rightPt, solarGridPaint);
    }

    // Angled cell ribs
    canvas.drawLine(Offset(storeX + 16, storeY - 7), Offset(roofPeakX - 10, roofPeakY + 7), solarGridPaint);
    canvas.drawLine(Offset(storeX + 32, storeY - 14), Offset(roofPeakX - 5, roofPeakY + 12), solarGridPaint);
    canvas.drawLine(Offset(storeX + bldgW - 16, storeY - 7), Offset(roofPeakX + 10, roofPeakY + 7), solarGridPaint);
    canvas.drawLine(Offset(storeX + bldgW - 32, storeY - 14), Offset(roofPeakX + 5, roofPeakY + 12), solarGridPaint);

    // Solar Panel Glass Specular Sheen Sweep
    final solarGlarePath = Path()
      ..moveTo(storeX + 6, storeY - 2)
      ..lineTo(roofPeakX - 12, roofPeakY + 4)
      ..lineTo(roofPeakX - 4, roofPeakY + 4)
      ..lineTo(storeX + 18, storeY - 2)
      ..close();
    canvas.drawPath(solarGlarePath, Paint()..color = Colors.white.withValues(alpha: 0.28));

    // Floating Glassmorphic "⚡ 100% GREEN ENERGY HUB" Status HUD
    // Floating Glassmorphic "⚡ 100% GREEN ENERGY HUB" Status HUD
    // Positioned cleanly ABOVE the roofline without colliding or clipping!
    final hubTextPainter = TextPainter(
      text: const TextSpan(
        text: '100% GREEN ENERGY HUB',
        style: TextStyle(
          color: Colors.white,
          fontSize: 6.4,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.35,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final hudW = hubTextPainter.width + 38.0; // Ample room for bolt (14px) + text + gap + LED (14px)
    final hudH = 16.0;
    final hudX = (storeX + (bldgW - hudW) * 0.5).clamp(8.0, w - hudW - 8.0);
    final hudY = roofPeakY - (sideDepth * 0.7) - 18;
    final hudRect = Rect.fromLTWH(hudX, hudY, hudW, hudH);

    // Glassmorphic Backdrop
    canvas.drawRRect(
      RRect.fromRectAndRadius(hudRect, const Radius.circular(8)),
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.90),
    );
    // Neon Emerald Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(hudRect, const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF10B981),
    );

    // Energy Bolt Icon badge
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(hudX + 3.5, hudY + 2.5, 11, 11), const Radius.circular(4)),
      Paint()..color = const Color(0xFF064E3B),
    );
    final boltPainter = TextPainter(
      text: const TextSpan(
        text: '⚡',
        style: TextStyle(fontSize: 7.2, color: Color(0xFFFDE047)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    boltPainter.paint(canvas, Offset(hudX + 5.0, hudY + 3.2));

    // Clean Typography positioned after bolt with clear spacing
    hubTextPainter.paint(canvas, Offset(hudX + 18.0, hudY + 4.5));

    // Pulsing live green LED status indicator safely on right margin
    final ledX = hudX + hudW - 8.0;
    final ledY = hudY + 8.0;
    final ledPulseAlpha = (0.5 + (waveProgress * 0.5)).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(ledX, ledY),
      3.2,
      Paint()..color = const Color(0xFF34D399).withValues(alpha: ledPulseAlpha * 0.5),
    );
    canvas.drawCircle(
      Offset(ledX, ledY),
      1.8,
      Paint()..color = const Color(0xFF10B981),
    );

    // ========================================================================
    // 5. HIGH-TECH AERODYNAMIC 3D WIND TURBINE
    // ========================================================================
    final windAngle = truckProgress * 14 * math.pi;

    void drawHighTechTurbine(double tx, double ty, double scale) {
      // Pedestal Ground Shadow
      canvas.drawOval(
        Rect.fromCenter(center: Offset(tx, ty + (48 * scale)), width: 28 * scale, height: 7 * scale),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Octagonal Concrete Foundation Collar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(tx, ty + (46 * scale)), width: 18 * scale, height: 4.5 * scale),
          Radius.circular(2 * scale),
        ),
        Paint()..color = const Color(0xFFCBD5E1),
      );

      // Tapered Tubular Aerodynamic Steel Tower
      final towerPath = Path()
        ..moveTo(tx - (2.2 * scale), ty)
        ..lineTo(tx - (4.0 * scale), ty + (45 * scale))
        ..lineTo(tx + (4.0 * scale), ty + (45 * scale))
        ..lineTo(tx + (2.2 * scale), ty)
        ..close();

      final towerGradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0xFF64748B), // Slate 500 shadow
          Color(0xFFF8FAFC), // White specular highlight
          Color(0xFFCBD5E1), // Slate 300 base
          Color(0xFF475569), // Dark edge
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      );
      canvas.drawPath(towerPath, Paint()..shader = towerGradient.createShader(towerPath.getBounds()));
      canvas.drawPath(
        towerPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFF0F172A),
      );

      // Streamlined Aerodynamic Nacelle (Generator Housing)
      final nacelleRect = Rect.fromCenter(center: Offset(tx + (2 * scale), ty), width: 14 * scale, height: 7 * scale);
      canvas.drawRRect(
        RRect.fromRectAndRadius(nacelleRect, Radius.circular(3 * scale)),
        Paint()..color = const Color(0xFFF8FAFC),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(nacelleRect, Radius.circular(3 * scale)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = const Color(0xFF0F172A),
      );

      // Flashing Red Aviation Obstacle Beacon on Nacelle Crown
      final beaconAlpha = ((math.sin(truckProgress * 18 * math.pi) + 1.0) * 0.5).clamp(0.2, 1.0);
      canvas.drawCircle(
        Offset(tx + (2 * scale), ty - (4.5 * scale)),
        2.8 * scale,
        Paint()..color = const Color(0xFFEF4444).withValues(alpha: beaconAlpha * 0.5),
      );
      canvas.drawCircle(
        Offset(tx + (2 * scale), ty - (4.5 * scale)),
        1.3 * scale,
        Paint()..color = const Color(0xFFDC2626),
      );

      // Aerodynamic Rotor Hub & Spinner Nose Cone
      canvas.drawCircle(Offset(tx, ty), 5.2 * scale, Paint()..color = const Color(0xFF0F172A));
      canvas.drawCircle(Offset(tx, ty), 3.2 * scale, Paint()..color = const Color(0xFF38BDF8));

      // 3 Aerodynamic Twisted Composite Blades
      for (int i = 0; i < 3; i++) {
        final angle = windAngle + (i * (2 * math.pi / 3));
        final bladeLength = 36.0 * scale;

        // Realistic Airfoil Tapering Blade Path
        final bladePath = Path()
          ..moveTo(tx, ty)
          ..lineTo(tx + math.cos(angle - 0.16) * (bladeLength * 0.4), ty + math.sin(angle - 0.16) * (bladeLength * 0.4))
          ..lineTo(tx + math.cos(angle - 0.08) * (bladeLength * 0.85), ty + math.sin(angle - 0.08) * (bladeLength * 0.85))
          ..lineTo(tx + math.cos(angle) * bladeLength, ty + math.sin(angle) * bladeLength)
          ..lineTo(tx + math.cos(angle + 0.08) * (bladeLength * 0.85), ty + math.sin(angle + 0.08) * (bladeLength * 0.85))
          ..lineTo(tx + math.cos(angle + 0.16) * (bladeLength * 0.4), ty + math.sin(angle + 0.16) * (bladeLength * 0.4))
          ..close();

        // Drop shadow cast onto landscape
        final shadowOffset = const Offset(2.5, 3.0);
        canvas.drawPath(
          bladePath.shift(shadowOffset),
          Paint()..color = Colors.black.withValues(alpha: 0.15),
        );

        // Blade Outline
        canvas.drawPath(
          bladePath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0xFF0F172A),
        );

        // Blade Metallic Shading
        final bladeGradient = LinearGradient(
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFF1F5F9),
            Color(0xFFBAE6FD),
          ],
        );
        canvas.drawPath(
          bladePath,
          Paint()..shader = bladeGradient.createShader(Rect.fromCircle(center: Offset(tx, ty), radius: bladeLength)),
        );

        // Red Safety Warning Stripe near blade tip
        final tipX = tx + math.cos(angle) * (bladeLength * 0.90);
        final tipY = ty + math.sin(angle) * (bladeLength * 0.90);
        canvas.drawCircle(Offset(tipX, tipY), 1.8 * scale, Paint()..color = const Color(0xFFEF4444));
      }
    }

    drawHighTechTurbine(w * 0.89, h * 0.32, 0.95);

    // ========================================================================
    // 6. HIGH-CONTRAST HIGHWAY ROAD & PAVEMENT
    // ========================================================================
    // Asphalt surface
    final roadRect = Rect.fromLTWH(0, roadTopY, w, roadHeight);
    final asphaltGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF334155), // Slate 700
        Color(0xFF1E293B), // Slate 800
        Color(0xFF0F172A), // Slate 900
      ],
    );
    canvas.drawRect(roadRect, Paint()..shader = asphaltGradient.createShader(roadRect));

    // Solid White Edge Shoulder Lines (Top & Bottom)
    canvas.drawRect(Rect.fromLTWH(0, roadTopY, w, 1.8), Paint()..color = const Color(0xFFE2E8F0));
    canvas.drawRect(Rect.fromLTWH(0, h - 1.8, w, 1.8), Paint()..color = const Color(0xFFCBD5E1));

    // Glowing Reflective Amber Highway Center Divider Lines
    final dashPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (double dx = 0; dx < w; dx += 24) {
      canvas.drawLine(Offset(dx, roadTopY + 12), Offset(dx + 14, roadTopY + 12), dashPaint);
      // Small reflector stud in gap
      canvas.drawCircle(Offset(dx + 19, roadTopY + 12), 1.0, Paint()..color = const Color(0xFFFEF08A));
    }

    // ========================================================================
    // 7. 360° AIR TUMBLE SPIN CRATE DELIVERY ACTION
    // ========================================================================
    void drawDetailedWoodenCrate(Canvas c, double cx, double cy, double boxSize) {
      // Drop Shadow
      c.drawRect(
        Rect.fromLTWH(cx - 1, cy + boxSize - 1.5, boxSize + 2, 3),
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );

      final crateRect = Rect.fromLTWH(cx, cy, boxSize, boxSize);

      // Wood plank gradient
      final woodGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFFF59E0B),
          Color(0xFFD97706),
          Color(0xFFB45309),
        ],
      );
      c.drawRect(crateRect, Paint()..shader = woodGradient.createShader(crateRect));

      // Wood plank horizontal slat lines
      final plankLinePaint = Paint()
        ..color = const Color(0xFF78350F)
        ..strokeWidth = 0.8;
      c.drawLine(Offset(cx, cy + (boxSize * 0.33)), Offset(cx + boxSize, cy + (boxSize * 0.33)), plankLinePaint);
      c.drawLine(Offset(cx, cy + (boxSize * 0.67)), Offset(cx + boxSize, cy + (boxSize * 0.67)), plankLinePaint);

      // Diagonal structural brace with cross
      final bracePaint = Paint()
        ..color = const Color(0xFF92400E)
        ..strokeWidth = 1.2;
      c.drawLine(Offset(cx + 2, cy + 2), Offset(cx + boxSize - 2, cy + boxSize - 2), bracePaint);
      c.drawLine(Offset(cx + boxSize - 2, cy + 2), Offset(cx + 2, cy + boxSize - 2), bracePaint);

      // Outer frame
      c.drawRect(
        crateRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = const Color(0xFF451A03),
      );

      // Iron corner angle brackets with rivets
      final ironPaint = Paint()..color = const Color(0xFF1E293B);
      c.drawRect(Rect.fromLTWH(cx, cy, 2.5, 2.5), ironPaint);
      c.drawRect(Rect.fromLTWH(cx + boxSize - 2.5, cy, 2.5, 2.5), ironPaint);
      c.drawRect(Rect.fromLTWH(cx, cy + boxSize - 2.5, 2.5, 2.5), ironPaint);
      c.drawRect(Rect.fromLTWH(cx + boxSize - 2.5, cy + boxSize - 2.5, 2.5, 2.5), ironPaint);

      // Stenciled "UP" arrow mark in center
      final arrowPaint = Paint()..color = const Color(0xFF451A03)..strokeWidth = 0.9;
      final midX = cx + (boxSize * 0.5);
      final midY = cy + (boxSize * 0.5);
      c.drawLine(Offset(midX, midY + 2.5), Offset(midX, midY - 2.5), arrowPaint);
      c.drawLine(Offset(midX - 1.8, midY - 0.8), Offset(midX, midY - 2.5), arrowPaint);
      c.drawLine(Offset(midX + 1.8, midY - 0.8), Offset(midX, midY - 2.5), arrowPaint);
    }

    void draw3DCrateStackGroup(Canvas c, double dropPointX, double landedY, double fallProgress) {
      c.save();
      final startY = landedY - 26;
      final currentY = startY + (fallProgress * 26);
      final spinAngle = (1.0 - fallProgress) * 2 * math.pi;

      c.translate(dropPointX, currentY);
      if (fallProgress < 1.0) {
        c.rotate(spinAngle);
      }

      // Pyramidal stack of 3 realistic crates
      drawDetailedWoodenCrate(c, -11, -11, 10);
      drawDetailedWoodenCrate(c, 1, -11, 10);
      drawDetailedWoodenCrate(c, -5, -21, 10);

      c.restore();
    }

    final dropX1 = w * 0.35;
    final dropX2 = w * 0.72;
    final truckX = (truckProgress * (w + 140)) - 90;

    // Delivery Drop 1
    if (truckX > dropX1) {
      final fallP1 = ((truckX - dropX1) / 45.0).clamp(0.0, 1.0);
      draw3DCrateStackGroup(canvas, dropX1, roadTopY, fallP1);
    }

    // Delivery Drop 2
    if (truckX > dropX2) {
      final fallP2 = ((truckX - dropX2) / 45.0).clamp(0.0, 1.0);
      draw3DCrateStackGroup(canvas, dropX2, roadTopY, fallP2);
    }

    // Atmospheric Road Dust & Vapor Trail behind truck
    final exhaustX = truckX - 30;
    final exhaustY = roadTopY - 6;

    for (int i = 0; i < 6; i++) {
      final smokeProgress = (truckProgress * 12 + i * 0.35) % 1.0;
      final sx = exhaustX - (i * 9) - (smokeProgress * 16);
      final sy = exhaustY - (i * 2.0) - (math.sin(smokeProgress * math.pi) * 3);
      final radius = 3.5 + (i * 2.0);
      final alpha = (0.50 - (i * 0.08)).clamp(0.04, 0.55);

      canvas.drawCircle(
        Offset(sx, sy),
        radius,
        Paint()
          ..color = const Color(0xFF94A3B8).withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // ========================================================================
    // 8. REALISTIC ECO-LOGISTICS SEMI-TRUCK & DRIVER
    // ========================================================================
    final truckY = roadTopY - 22;

    canvas.save();
    canvas.translate(truckX, truckY);

    // Realistic Truck Ground Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-30, 19, 82, 6), const Radius.circular(4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Heavy-Duty Steel Flatbed Trailer
    final flatbedRect = const Rect.fromLTWH(-28, 5, 46, 15);
    final flatbedGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF92400E),
        Color(0xFF78350F),
        Color(0xFF451A03),
      ],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(flatbedRect, const Radius.circular(3)),
      Paint()..shader = flatbedGradient.createShader(flatbedRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(flatbedRect, const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0xFF1E293B),
    );

    // Flatbed Safety Side Rail
    canvas.drawLine(
      const Offset(-28, 8),
      const Offset(18, 8),
      Paint()..color = const Color(0xFFF59E0B)..strokeWidth = 1.0,
    );

    // Cargo on Flatbed
    drawDetailedWoodenCrate(canvas, -24, -7, 12);
    drawDetailedWoodenCrate(canvas, -10, -7, 12);
    if (truckProgress < 0.35 || truckProgress > 0.72) {
      drawDetailedWoodenCrate(canvas, -17, -19, 12); // Stacked Crate ready for drop
    }

    // Modern Aerodynamic Semi-Truck Cab (Forest Emerald)
    final cabinPath = Path()
      ..moveTo(18, 19)
      ..lineTo(18, -2)
      ..lineTo(28, -6)
      ..quadraticBezierTo(38, -6, 40, 2)
      ..lineTo(40, 19)
      ..close();

    final cabGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFF047857), // Emerald 700
        Color(0xFF064E3B), // Emerald 800
        Color(0xFF022C22), // Emerald 950
      ],
    );
    canvas.drawPath(cabinPath, Paint()..shader = cabGradient.createShader(cabinPath.getBounds()));
    canvas.drawPath(
      cabinPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF0F172A),
    );

    // Aerodynamic Curved Windshield Glass
    final windshieldPath = Path()
      ..moveTo(26, -1)
      ..lineTo(29, -4)
      ..quadraticBezierTo(37, -4, 38, 2)
      ..lineTo(38, 8)
      ..lineTo(26, 8)
      ..close();

    final windshieldGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFFE0F2FE),
        Color(0xFFBAE6FD),
        Color(0xFF7DD3FC),
      ],
    );
    canvas.drawPath(windshieldPath, Paint()..shader = windshieldGradient.createShader(windshieldPath.getBounds()));
    canvas.drawPath(
      windshieldPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF0F172A),
    );

    // Windshield Reflection Glare
    canvas.drawLine(
      const Offset(29, -1),
      const Offset(35, 6),
      Paint()..color = Colors.white.withValues(alpha: 0.5)..strokeWidth = 1.2,
    );

    // Driver Silhouette (holding steering wheel)
    canvas.drawCircle(const Offset(30, 3.5), 2.8, Paint()..color = const Color(0xFFFDBA74)); // Head
    canvas.drawRect(const Rect.fromLTWH(28, 6.5, 5, 2.5), Paint()..color = const Color(0xFF1E293B)); // Torso
    canvas.drawCircle(const Offset(35, 6.5), 1.5, Paint()..color = const Color(0xFF0F172A)); // Steering Wheel

    // Aerodynamic Side Mirror
    canvas.drawRect(const Rect.fromLTWH(23, 2, 2.5, 4.5), Paint()..color = const Color(0xFF0F172A));

    // High-Intensity LED Headlights with Volumetric Beam Cone
    final headlightPath = Path()
      ..moveTo(40, 9)
      ..lineTo(85, -2)
      ..lineTo(85, 23)
      ..lineTo(40, 15)
      ..close();

    final headlightBeamGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        const Color(0xFFFEF08A).withValues(alpha: 0.45),
        const Color(0xFFFDE047).withValues(alpha: 0.20),
        Colors.transparent,
      ],
    );
    canvas.drawPath(
      headlightPath,
      Paint()
        ..shader = headlightBeamGradient.createShader(headlightPath.getBounds())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // LED Lamp Housing
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(38, 9, 3, 5), const Radius.circular(1.5)),
      Paint()..color = const Color(0xFFFDE047),
    );

    // Heavy-Duty Truck Wheels with Realistic Tire Treads & Alloy Rims
    final wheelSpin = truckProgress * 22 * math.pi;
    void drawRealisticWheel(double wx, double wy) {
      // Black Rubber Tire
      canvas.drawCircle(Offset(wx, wy), 5.8, Paint()..color = const Color(0xFF0F172A));

      // Tire Tread Outer Ring
      canvas.drawCircle(
        Offset(wx, wy),
        5.8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFF334155),
      );

      // Steel Alloy Rim
      canvas.drawCircle(Offset(wx, wy), 3.4, Paint()..color = const Color(0xFF94A3B8));
      canvas.drawCircle(Offset(wx, wy), 2.2, Paint()..color = const Color(0xFFF59E0B));

      // Spinning Lug Nuts / Spokes
      final spokePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.0;
      for (int s = 0; s < 4; s++) {
        final spAngle = wheelSpin + (s * math.pi / 2);
        canvas.drawLine(
          Offset(wx, wy),
          Offset(wx + math.cos(spAngle) * 3.0, wy + math.sin(spAngle) * 3.0),
          spPaint(spokePaint),
        );
      }

      // Center Chrome Hub Cap
      canvas.drawCircle(Offset(wx, wy), 1.2, Paint()..color = const Color(0xFF0F172A));
    }

    drawRealisticWheel(-18, 20);
    drawRealisticWheel(5, 20);
    drawRealisticWheel(30, 20);

    canvas.restore();
  }

  Paint spPaint(Paint p) => p;

  @override
  bool shouldRepaint(covariant _ThreeDIntegratedNaturePainter oldDelegate) {
    return oldDelegate.truckProgress != truckProgress ||
        oldDelegate.waveProgress != waveProgress ||
        oldDelegate.cloudProgress != cloudProgress;
  }
}

class _MaxCharLimitFormatter extends TextInputFormatter {
  final int maxLen;
  final VoidCallback onLimitReached;

  _MaxCharLimitFormatter(this.maxLen, this.onLimitReached);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final uppercaseText = newValue.text.toUpperCase();
    if (uppercaseText.length > maxLen) {
      onLimitReached();
      final truncated = uppercaseText.substring(0, maxLen);
      return TextEditingValue(
        text: truncated,
        selection: TextSelection.collapsed(offset: truncated.length),
      );
    }
    return TextEditingValue(
      text: uppercaseText,
      selection: newValue.selection,
    );
  }
}

// ============================================================================
// COMPREHENSIVE EXPORT MODAL DIALOG (Glassmorphism & Authentic Brand Logos)
// ============================================================================
class _StoreExportModalDialog extends StatefulWidget {
  final List<StoreMaster> stores;

  const _StoreExportModalDialog({required this.stores});

  @override
  State<_StoreExportModalDialog> createState() => _StoreExportModalDialogState();
}

class _StoreExportModalDialogState extends State<_StoreExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'

  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<int> _selectedStoreCodes;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedStoreCodes = widget.stores.map((s) => s.strCode).toSet();
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

  List<StoreMaster> get _filteredPreviewStores {
    if (_modalSearchQuery.isEmpty) return widget.stores;
    return widget.stores.where((s) {
      final codeMatch = s.strCode.toString().contains(_modalSearchQuery);
      final nameMatch = s.strName.toLowerCase().contains(_modalSearchQuery);
      final seriesMatch = s.strSeries.toLowerCase().contains(_modalSearchQuery);
      final locMatch = s.locationName.toLowerCase().contains(_modalSearchQuery);
      return codeMatch || nameMatch || seriesMatch || locMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewStores;
    if (preview.isEmpty) return false;
    return preview.every((s) => _selectedStoreCodes.contains(s.strCode));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewStores;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final s in preview) {
          _selectedStoreCodes.remove(s.strCode);
        }
      } else {
        for (final s in preview) {
          _selectedStoreCodes.add(s.strCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedStoreCodes.isEmpty) {
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
      final selectedList = widget.stores.where((s) => _selectedStoreCodes.contains(s.strCode)).toList();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'StoreMaster_Export_$timestamp.$extension';

      final String userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
      final String downloadsPath = '$userProfile\\Downloads';
      final Directory dir = Directory(downloadsPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final filePath = '$downloadsPath\\$fileName';
      final file = File(filePath);

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Store Master');
        final excel_pkg.Sheet sheet = excel['Store Master'];

        // Set Generous Column Widths (Prevents text clipping)
        sheet.setColumnWidth(0, 20.0); // STORE CODE
        sheet.setColumnWidth(1, 36.0); // STORE NAME
        sheet.setColumnWidth(2, 24.0); // SERIES
        sheet.setColumnWidth(3, 24.0); // FIX CHAR
        sheet.setColumnWidth(4, 22.0); // LOCATION CODE
        sheet.setColumnWidth(5, 32.0); // LOCATION NAME

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
          excel_pkg.TextCellValue('STORE CODE'),
          excel_pkg.TextCellValue('STORE NAME'),
          excel_pkg.TextCellValue('SERIES'),
          excel_pkg.TextCellValue('FIX CHAR'),
          excel_pkg.TextCellValue('LOCATION CODE'),
          excel_pkg.TextCellValue('LOCATION NAME'),
        ]);

        for (int col = 0; col < 6; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        // Append Data Rows with Heights & Styles
        for (int i = 0; i < selectedList.length; i++) {
          final s = selectedList[i];
          final style = (i % 2 == 0) ? evenStyle : oddStyle;
          final int rIdx = i + 1;

          sheet.setRowHeight(rIdx, 22.0);
          sheet.appendRow([
            excel_pkg.IntCellValue(s.strCode),
            excel_pkg.TextCellValue(s.strName),
            excel_pkg.TextCellValue(s.strSeries.isNotEmpty ? s.strSeries : '-'),
            excel_pkg.TextCellValue(s.strFixChar.isNotEmpty ? s.strFixChar : '-'),
            excel_pkg.IntCellValue(s.locCode),
            excel_pkg.TextCellValue(s.locationName),
          ]);

          for (int col = 0; col < 6; col++) {
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
                      'STORE MASTER REGISTRATION REPORT',
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
                headers: ['SR NO', 'STORE CODE', 'STORE NAME', 'PREFIX SERIES', 'FIX CHARACTER', 'LOCATION NAME'],
                data: selectedList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final s = entry.value;
                  return [
                    '${idx + 1}',
                    '#${s.strCode}',
                    s.strName,
                    s.strSeries.isNotEmpty ? s.strSeries : '-',
                    s.strFixChar.isNotEmpty ? s.strFixChar : '-',
                    s.locationName,
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
                  4: pw.Alignment.center,
                  5: pw.Alignment.centerLeft,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(3.5),
                  3: const pw.FlexColumnWidth(1.8),
                  4: const pw.FlexColumnWidth(1.8),
                  5: const pw.FlexColumnWidth(3.0),
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

      // Save file & complete export process
      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        // Quick 650ms delay for user to see the animated checkmark directly on the button
        await Future.delayed(const Duration(milliseconds: 650));

        if (!mounted) return;
        Navigator.of(context).pop();

        // Reveal the downloaded file in Windows File Explorer
        await _openFileInSystemExplorer(filePath);
      }
    } catch (e, stack) {
      debugPrint('Export store master failed: $e\n$stack');
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
                // Dual Pane Split View Body
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
                              Text('Export Store Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                    // Right Column: Data Preview & Selection Table
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
                // Top Right Circular Close Button
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
            '${_selectedStoreCodes.length} of ${widget.stores.length} selected',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
          ),
        ),
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final previewList = _filteredPreviewStores;

    if (previewList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'No store records found',
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
                  SizedBox(width: 60, child: Text('CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(child: Text('STORE NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 110, child: Text('SERIES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 110, child: Text('LOCATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final s = previewList[idx];
                  final isSelected = _selectedStoreCodes.contains(s.strCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedStoreCodes.remove(s.strCode);
                        } else {
                          _selectedStoreCodes.add(s.strCode);
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
                                    _selectedStoreCodes.add(s.strCode);
                                  } else {
                                    _selectedStoreCodes.remove(s.strCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              '${s.strCode}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              s.strName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(
                              s.strSeries.isNotEmpty ? '${s.strSeries} (${s.strFixChar})' : '-',
                              style: TextStyle(
                                fontSize: 11,
                                color: s.strSeries.isNotEmpty ? const Color(0xFFB46617) : AppColors.neutralDark.withValues(alpha: 0.4),
                                fontWeight: s.strSeries.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(
                              s.locationName.isNotEmpty ? s.locationName : '-',
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

/// Pixel-Perfect 100% Identical 3D Glossy WhatsApp Sphere Logo (Matching User Screenshot 4)
class WhatsAppBrandLogoWidget extends StatelessWidget {
  final double size;
  const WhatsAppBrandLogoWidget({super.key, this.size = 38.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WhatsApp3DGlossyPainter(),
      ),
    );
  }
}

class _WhatsApp3DGlossyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // 1. 3D Spherical Radial Gradient (Matching Screenshot 4)
    final spherePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(w * 0.35, h * 0.3),
        radius * 1.15,
        [
          const Color(0xFF2BF47A),
          const Color(0xFF00E65B),
          const Color(0xFF00A83F),
        ],
        [0.0, 0.45, 1.0],
      );

    canvas.drawCircle(center, radius, spherePaint);

    // 2. Glossy Specular Top Highlight Curve
    final shinePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.5, 0),
        Offset(w * 0.5, h * 0.45),
        [
          Colors.white.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.0),
        ],
      );
    final shinePath = Path()
      ..addOval(Rect.fromCenter(center: Offset(w / 2, h * 0.22), width: w * 0.72, height: h * 0.34));
    canvas.drawPath(shinePath, shinePaint);

    // 3. Crisp White Speech Bubble + Phone Handset Icon
    final iconSize = size.width * 0.55;
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.chat_bubble_rounded.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.chat_bubble_rounded.fontFamily,
          package: Icons.chat_bubble_rounded.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((w - textPainter.width) / 2, (h - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pixel-Perfect 100% Identical Gmail 4-Color Official Logo (Matching User Screenshot 5)
class GmailBrandLogoWidget extends StatelessWidget {
  final double size;
  const GmailBrandLogoWidget({super.key, this.size = 38.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.62, size * 0.48),
          painter: _Gmail4ColorLogoPainter(),
        ),
      ),
    );
  }
}

class _Gmail4ColorLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokeWidth = w * 0.24;
    final r = strokeWidth / 2;

    // Blue Left Pillar
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Red Top Left Slope
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Yellow Top Right Peak
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Green Right Pillar
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 1. Left Blue Line
    canvas.drawLine(Offset(r, h - r), Offset(r, r + h * 0.15), bluePaint);

    // 2. Right Green Line
    canvas.drawLine(Offset(w - r, h - r), Offset(w - r, r + h * 0.15), greenPaint);

    // 3. Red Diagonal Left Fold
    canvas.drawLine(Offset(r, r), Offset(w / 2, h * 0.72), redPaint);

    // 4. Yellow Diagonal Right Fold
    canvas.drawLine(Offset(w - r, r), Offset(w / 2, h * 0.72), yellowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Authentic Google Drive 3-Color Vector Logo
class GoogleDriveBrandLogoWidget extends StatelessWidget {
  final double size;
  const GoogleDriveBrandLogoWidget({super.key, this.size = 34.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF4285F4).withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4285F4).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.add_to_drive_rounded, color: Color(0xFF4285F4), size: 18),
      ),
    );
  }
}

/// Authentic Windows System Share Vector Logo
class WindowsShareBrandLogoWidget extends StatelessWidget {
  final double size;
  const WindowsShareBrandLogoWidget({super.key, this.size = 34.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0078D4),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0078D4).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.folder_open_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Authentic Telegram Logo
class TelegramBrandLogoWidget extends StatelessWidget {
  final double size;
  const TelegramBrandLogoWidget({super.key, this.size = 34.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF229ED9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF229ED9).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.send_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Authentic Outlook Logo
class OutlookBrandLogoWidget extends StatelessWidget {
  final double size;
  const OutlookBrandLogoWidget({super.key, this.size = 34.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0078D4),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0078D4).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.mail_outline_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Authentic Slack Logo
class SlackBrandLogoWidget extends StatelessWidget {
  final double size;
  const SlackBrandLogoWidget({super.key, this.size = 34.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF4A154B),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A154B).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.tag_rounded, color: Colors.white, size: 18),
      ),
    );
  }
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

