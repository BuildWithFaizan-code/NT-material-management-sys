import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bom_models.dart';
import 'bom_followup_models.dart';
import 'bom_followup_service.dart';
import 'widgets/bom_animated_success_button.dart';
import 'widgets/bom_export_modal_dialog.dart';
import 'widgets/bom_followup_export_modal_dialog.dart';
import 'widgets/bom_modern_date_picker_dialog.dart';
import 'widgets/bom_modern_dropdown.dart';
import '../../design/app_colors.dart';

/// BOM Follow Up / Bill of Material Close Screen
/// Master verified enterprise page for batch review and closure of open BOM records.
/// Adheres 100% to Department Master table styling, zero column collision,
/// glassmorphism search, animated success button, and batch audit log.
class BomFollowupPage extends StatefulWidget {
  final BomFollowupService? service;

  const BomFollowupPage({super.key, this.service});

  @override
  State<BomFollowupPage> createState() => _BomFollowupPageState();
}

class _BomFollowupPageState extends State<BomFollowupPage> {
  late final BomFollowupService _service;

  // Filters State
  DateTime _asOnDate = DateTime.now();
  int _selectedDeptCode = 0; // 0 = ALL
  int _selectedDivCode = 0; // 0 = ALL
  String _selectedOrderType = 'ALL'; // ALL, JOB, REGULAR

  // Dropdown items cache
  List<BomFollowupDepartment> _departments = [];
  List<BomFollowupDivision> _divisions = [];
  List<BomFollowupOrderType> _orderTypes = [];

  // Data & Table State
  List<BomFollowupRecord> _records = [];
  final Set<String> _selectedBomIds = {};
  bool _isLoading = false;
  ButtonStatus _saveButtonStatus = ButtonStatus.idle;

  // Button Action & Micro-Feedback States (Zero External Banners)
  String? _buttonValidationMsg;
  Timer? _buttonValidationTimer;
  Timer? _validationClearTimer;

  // Search & Focus
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  final ScrollController _horizontalScrollCtrl = ScrollController();
  final ScrollController _verticalScrollCtrl = ScrollController();

  // Column View Mode: 0: All Columns, 1: Overview, 2: Inventory & Rates, 3: Audit & Timestamps
  int _columnViewMode = 0;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? BomFollowupService();
    _loadInitialData();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
    _horizontalScrollCtrl.addListener(_updateScrollButtons);
  }

  void _updateScrollButtons() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final maxScroll = _horizontalScrollCtrl.position.maxScrollExtent;
    final offset = _horizontalScrollCtrl.offset;
    final canLeft = offset > 10;
    final canRight = offset < maxScroll - 10;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollLeft() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final newOffset = (_horizontalScrollCtrl.offset - 350.0).clamp(
      0.0,
      _horizontalScrollCtrl.position.maxScrollExtent,
    );
    _horizontalScrollCtrl.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollRight() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final newOffset = (_horizontalScrollCtrl.offset + 350.0).clamp(
      0.0,
      _horizontalScrollCtrl.position.maxScrollExtent,
    );
    _horizontalScrollCtrl.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _previousViewMode() {
    setState(() {
      _columnViewMode = (_columnViewMode - 1 + 4) % 4;
      if (_horizontalScrollCtrl.hasClients) {
        _horizontalScrollCtrl.jumpTo(0.0);
      }
    });
  }

  void _nextViewMode() {
    setState(() {
      _columnViewMode = (_columnViewMode + 1) % 4;
      if (_horizontalScrollCtrl.hasClients) {
        _horizontalScrollCtrl.jumpTo(0.0);
      }
    });
  }

  @override
  void dispose() {
    _buttonValidationTimer?.cancel();
    _validationClearTimer?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    _horizontalScrollCtrl.removeListener(_updateScrollButtons);
    _horizontalScrollCtrl.dispose();
    _verticalScrollCtrl.dispose();
    super.dispose();
  }

  void _showButtonValidation(String msg) {
    setState(() {
      _buttonValidationMsg = msg;
      _saveButtonStatus = ButtonStatus.error;
    });
    _buttonValidationTimer?.cancel();
    _buttonValidationTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && _saveButtonStatus == ButtonStatus.error) {
        setState(() => _saveButtonStatus = ButtonStatus.idle);
      }
    });
    _validationClearTimer?.cancel();
    _validationClearTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _buttonValidationMsg == msg) {
        setState(() => _buttonValidationMsg = null);
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final deptsFuture = _service.fetchDepartments();
      final divsFuture = _service.fetchDivisions();
      final typesFuture = _service.fetchOrderTypes();

      final results = await Future.wait([deptsFuture, divsFuture, typesFuture]);
      _departments = results[0] as List<BomFollowupDepartment>;
      _divisions = results[1] as List<BomFollowupDivision>;
      _orderTypes = results[2] as List<BomFollowupOrderType>;

      await _fetchGridRecords();
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        _showSnack('Failed to load filter data: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchGridRecords() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.fetchRecords(
        asOnDate: _asOnDate,
        departmentCode: _selectedDeptCode > 0 ? _selectedDeptCode : null,
        divisionCode: _selectedDivCode > 0 ? _selectedDivCode : null,
        orderType: _selectedOrderType != 'ALL' ? _selectedOrderType : null,
      );
      if (mounted) {
        setState(() {
          _records = list;
          // Retain only selected IDs that still exist in active records
          _selectedBomIds.removeWhere((id) => !_records.any((r) => r.bomId == id));
        });
      }
    } catch (e) {
      debugPrint('Error fetching BOM followup records: $e');
      if (mounted) {
        _showSnack('Failed to load BOM records: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<BomFollowupRecord> get _filteredRecords {
    if (_searchQuery.isEmpty) return _records;
    return _records.where((r) {
      final idMatch = r.bomId.toLowerCase().contains(_searchQuery);
      final nameMatch = r.materialName.toLowerCase().contains(_searchQuery);
      final codeMatch = r.materialCode.toLowerCase().contains(_searchQuery);
      final depMatch = r.department.toLowerCase().contains(_searchQuery);
      final branchMatch = r.branch.toLowerCase().contains(_searchQuery);
      final divMatch = r.division.toLowerCase().contains(_searchQuery);
      final userMatch = r.user.toLowerCase().contains(_searchQuery);
      return idMatch || nameMatch || codeMatch || depMatch || branchMatch || divMatch || userMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final list = _filteredRecords;
    if (list.isEmpty) return false;
    return list.every((r) => _selectedBomIds.contains(r.bomId));
  }

  void _toggleSelectAllFiltered() {
    final list = _filteredRecords;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final r in list) {
          _selectedBomIds.remove(r.bomId);
        }
      } else {
        for (final r in list) {
          _selectedBomIds.add(r.bomId);
        }
      }
    });
  }

  void _toggleRecordSelection(String bomId) {
    setState(() {
      if (_selectedBomIds.contains(bomId)) {
        _selectedBomIds.remove(bomId);
      } else {
        _selectedBomIds.add(bomId);
      }
    });
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatDateTime(DateTime? d) {
    if (d == null) return '-';
    final date = _formatDate(d);
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  Future<void> _handleSaveClose() async {
    if (_saveButtonStatus == ButtonStatus.loading) return;

    if (_selectedBomIds.isEmpty) {
      _showButtonValidation('Select at least 1 record');
      _showSnack('Please select at least one open BOM record to close.', isError: true);
      return;
    }

    setState(() {
      _buttonValidationMsg = null;
      _saveButtonStatus = ButtonStatus.loading;
    });

    try {
      // 1. Pre-save Lock Verification (LOCKDATAMST)
      final isLocked = await _service.checkLockDate(_asOnDate);
      if (isLocked) {
        setState(() => _saveButtonStatus = ButtonStatus.idle);
        _showLockWarningDialog();
        return;
      }

      // 2. Perform Batch Closure
      final result = await _service.closeBomRecords(
        bomIds: _selectedBomIds.toList(),
        asOnDate: _asOnDate,
        username: 'ADMIN',
        companyName: 'NEW TECH INFOSOL',
      );

      if (result.success) {
        final closedIds = _selectedBomIds.toSet();
        setState(() {
          _saveButtonStatus = ButtonStatus.success;
          // Closed items immediately vanish from the active table list
          _records.removeWhere((r) => closedIds.contains(r.bomId));
          _selectedBomIds.clear();
        });

        // Zero external banner notifications: Button animation itself is the success notification!

        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) {
          setState(() => _saveButtonStatus = ButtonStatus.idle);
          // Query 8: Re-query the database to verify active state
          await _fetchGridRecords();
        }
      } else {
        setState(() => _saveButtonStatus = ButtonStatus.idle);
        _showSnack(result.message, isError: true);
      }
    } catch (e) {
      debugPrint('Save close failed: $e');
      setState(() => _saveButtonStatus = ButtonStatus.idle);
      _showSnack('Closure failed: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted || !isError) return; // Zero external banner notifications on success
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isError ? 'Notice' : 'Success',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0C3B2E),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError ? const Color(0xFFF87171) : const Color(0xFF34D399),
            width: 1.2,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLockWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock_outlined, color: Color(0xFFDC2626), size: 26),
            SizedBox(width: 10),
            Text('Date Locked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Transactions for date ${_formatDate(_asOnDate)} are locked in LOCKDATAMST. Bill of Material records cannot be closed on this date.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C3B2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openExportModal() {
    final list = _filteredRecords;
    if (list.isEmpty) {
      _showSnack('No records available to export.', isError: true);
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => BomFollowupExportModalDialog(records: list),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;

    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f1) {
          _handleSaveClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          child: Column(
            children: [
              // 1. TOP HEADER & EXPORT BAR
              _buildTopHeader(),

              // 2. MAIN TABLE CONTAINER (Department Master parity)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 3.1 Table Subheader with Left/Right navigation & Carousel presets
                          _buildTableSubHeader(filtered.length),

                          // 3.2 Table column headers & clean body
                          Expanded(
                            child: _buildTableContent(filtered),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP HEADER
  // ---------------------------------------------------------------------------
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Logo & Title
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Direct on plain white screen - no background box, border or shadow
                Image.asset(
                  'assets/images/bom_close_screen_logo.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                  errorBuilder: (ctx, err, stack) => const Icon(
                    Icons.assignment_turned_in_rounded,
                    color: Color(0xFF0C3B2E),
                    size: 40,
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Bill Of Material Close Screen',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Review and approve active bills of material',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(),

            // Right: Action buttons (Export + Approve right down to it)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BomAnimatedExportButton(onPressed: _openExportModal),
                const SizedBox(height: 8),
                if (_buttonValidationMsg != null) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _buttonValidationMsg!,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                BomAnimatedSuccessButton(
                  status: _saveButtonStatus,
                  onPressed: _handleSaveClose,
                  idleText: 'Approve (F1)',
                  loadingText: 'Approving...',
                  successText: 'Approved!',
                  errorText: 'Select Records',
                  idleIcon: Icons.check_circle_outline_rounded,
                  idleBackgroundColor: AppColors.secondaryColor, // Exact Sage Green #6D9773 from Project Master
                  successBackgroundColor: const Color(0xFF10B981),
                  height: 36,
                  width: 140,
                  borderRadius: BorderRadius.circular(18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. FILTER DIALOG (Encapsulated modern filter popup)
  // ---------------------------------------------------------------------------
  void _openFilterDialog() {
    DateTime tempDate = _asOnDate;
    int tempDeptCode = _selectedDeptCode;
    int tempDivCode = _selectedDivCode;
    String tempOrderType = _selectedOrderType;
    String localSearchQuery = '';

    final orderTypeOptions = _orderTypes.isNotEmpty
        ? _orderTypes.map((t) => t.bomType.trim().toUpperCase()).where((t) => t.isNotEmpty).toSet().toList()
        : ['JOB', 'REGULAR'];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        ButtonStatus filterBtnStatus = ButtonStatus.idle;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final now = DateTime.now();
            final isToday = tempDate.year == now.year &&
                tempDate.month == now.month &&
                tempDate.day == now.day;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                width: 460,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 36,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header (Image 2 style: Icon + Filter title + Close icon in black)
                    Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Filter',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Search Pill Input (Image 2 style)
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, size: 17, color: Colors.black),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Search department, division, type...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.normal,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                setDialogState(() => localSearchQuery = val.trim().toLowerCase());
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Quick Tag Chips (Image 2 style: horizontal pill tags)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterTagChip(
                            label: 'ALL TYPES',
                            isSelected: tempOrderType == 'ALL',
                            onTap: () => setDialogState(() => tempOrderType = 'ALL'),
                          ),
                          ...orderTypeOptions.map((type) {
                            final label = type == 'JOB' ? 'JOB ORDER' : type;
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _buildFilterTagChip(
                                label: label,
                                isSelected: tempOrderType == type,
                                onTap: () => setDialogState(() => tempOrderType = type),
                              ),
                            );
                          }),
                          const SizedBox(width: 6),
                          _buildFilterTagChip(
                            label: 'TODAY',
                            isSelected: isToday,
                            onTap: () => setDialogState(() => tempDate = DateTime(now.year, now.month, now.day)),
                          ),
                          const SizedBox(width: 6),
                          _buildFilterTagChip(
                            label: 'YESTERDAY',
                            isSelected: _isSameDay(tempDate, now.subtract(const Duration(days: 1))),
                            onTap: () => setDialogState(() => tempDate = now.subtract(const Duration(days: 1))),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Section 1: AS ON DATE (Everything black)
                    _buildFilterSectionTitle('AS ON DATE'),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () async {
                        final picked = await showModernDatePicker(
                          context: ctx,
                          initialDate: tempDate,
                        );
                        if (picked != null) {
                          setDialogState(() => tempDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.black),
                            const SizedBox(width: 10),
                            Text(
                              _formatDate(tempDate),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                color: Colors.black,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down_rounded, size: 22, color: Colors.black),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Section 2: DEPARTMENT (Everything black)
                    _buildFilterSectionTitle('DEPARTMENT'),
                    const SizedBox(height: 5),
                    BomModernDropdown<int>(
                      value: tempDeptCode,
                      hintText: 'Select Department',
                      dropdownTitle: 'DEPARTMENT LIST',
                      items: [
                        const BomDropdownItem<int>(
                          value: 0,
                          label: 'ALL DEPARTMENTS',
                          subtitle: 'Show all open departments',
                          icon: Icons.apartment_rounded,
                        ),
                        ..._departments
                            .where((d) => localSearchQuery.isEmpty || d.labName.toLowerCase().contains(localSearchQuery))
                            .map(
                              (d) => BomDropdownItem<int>(
                                value: d.labCode,
                                label: d.labName,
                                subtitle: 'Code: ${d.labCode}',
                                icon: Icons.apartment_rounded,
                              ),
                            ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => tempDeptCode = val);
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // Section 3: DIVISION (Everything black)
                    _buildFilterSectionTitle('DIVISION'),
                    const SizedBox(height: 5),
                    BomModernDropdown<int>(
                      value: tempDivCode,
                      hintText: 'Select Division',
                      dropdownTitle: 'DIVISION LIST',
                      items: [
                        const BomDropdownItem<int>(
                          value: 0,
                          label: 'ALL DIVISIONS',
                          subtitle: 'Show all open divisions',
                          icon: Icons.category_rounded,
                        ),
                        ..._divisions
                            .where((d) => localSearchQuery.isEmpty || d.khName.toLowerCase().contains(localSearchQuery))
                            .map(
                              (d) => BomDropdownItem<int>(
                                value: d.khCode,
                                label: d.khName,
                                subtitle: 'Code: ${d.khCode}',
                                icon: Icons.category_rounded,
                              ),
                            ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => tempDivCode = val);
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // Section 4: ORDER TYPE (Radio style like Image 2 GENDER)
                    _buildFilterSectionTitle('ORDER TYPE'),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _buildRadioPill(
                          label: 'ALL TYPES',
                          isSelected: tempOrderType == 'ALL',
                          onTap: () => setDialogState(() => tempOrderType = 'ALL'),
                        ),
                        for (final type in orderTypeOptions) ...[
                          const SizedBox(width: 8),
                          _buildRadioPill(
                            label: type == 'JOB' ? 'JOB ORDER' : type,
                            isSelected: tempOrderType == type,
                            onTap: () => setDialogState(() => tempOrderType = type),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Dialog Actions Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              tempDate = DateTime.now();
                              tempDeptCode = 0;
                              tempDivCode = 0;
                              tempOrderType = 'ALL';
                              localSearchQuery = '';
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.black),
                          label: const Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            BomAnimatedSuccessButton(
                              status: filterBtnStatus,
                              onPressed: () async {
                                setDialogState(() => filterBtnStatus = ButtonStatus.loading);
                                await Future.delayed(const Duration(milliseconds: 300));
                                if (!ctx.mounted) return;
                                setDialogState(() => filterBtnStatus = ButtonStatus.success);
                                await Future.delayed(const Duration(milliseconds: 550));
                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop();
                                setState(() {
                                  _asOnDate = tempDate;
                                  _selectedDeptCode = tempDeptCode;
                                  _selectedDivCode = tempDivCode;
                                  _selectedOrderType = tempOrderType;
                                });
                                await _fetchGridRecords();
                              },
                              idleText: 'Apply Filters',
                              loadingText: 'Applying...',
                              successText: 'Filters Applied!',
                              idleIcon: Icons.check_rounded,
                              idleBackgroundColor: AppColors.secondaryColor, // Exact Sage Green #6D9773 from Project Master
                              successBackgroundColor: const Color(0xFF10B981),
                              height: 36,
                              width: 140,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Colors.black,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFilterTagChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildRadioPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.black : const Color(0xFFCBD5E1),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black : const Color(0xFF94A3B8),
                    width: 1.5,
                  ),
                  color: isSelected ? Colors.black : Colors.transparent,
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.circle, size: 5, color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ---------------------------------------------------------------------------
  // 3. MAIN TABLE & CAROUSEL NAVIGATION (Modern Compact Layout)
  // ---------------------------------------------------------------------------
  static const double _colWidthCheckbox = 48.0;
  static const double _colWidthBomId = 155.0;
  static const double _colWidthDate = 110.0;
  static const double _colWidthDept = 160.0;
  static const double _colWidthBranch = 145.0;
  static const double _colWidthDiv = 145.0;
  static const double _colWidthName = 250.0;
  static const double _colWidthCode = 170.0;
  static const double _colWidthQty = 105.0;
  static const double _colWidthStatus = 95.0;
  static const double _colWidthDtTime = 140.0;
  static const double _colWidthUser = 105.0;
  static const double _colWidthRate = 90.0;
  static const double _colWidthUqc = 75.0;

  static const double _totalTableWidth = _colWidthCheckbox +
      _colWidthBomId +
      _colWidthDate +
      _colWidthDept +
      _colWidthBranch +
      _colWidthDiv +
      _colWidthName +
      _colWidthCode +
      _colWidthQty +
      _colWidthStatus +
      _colWidthDtTime +
      _colWidthUser +
      _colWidthRate +
      _colWidthUqc;

  double get _currentTableWidth {
    switch (_columnViewMode) {
      case 1:
        // Overview (zero-scroll compact)
        return _colWidthCheckbox + _colWidthBomId + _colWidthDate + 170.0 + 160.0 + 320.0 + 115.0 + 95.0;
      case 2:
        // Inventory & Rates
        return _colWidthCheckbox + _colWidthBomId + 280.0 + 180.0 + 155.0 + 110.0 + 110.0 + 95.0 + 75.0;
      case 3:
        // Audit & Tracking
        return _colWidthCheckbox + _colWidthBomId + 280.0 + 170.0 + 130.0 + 95.0 + 160.0;
      case 0:
      default:
        // All Columns
        return _totalTableWidth;
    }
  }

  /// 3.1 Subheader with Left/Right arrow controls and View Carousel
  Widget _buildTableSubHeader(int count) {
    return Container(
      padding: const EdgeInsets.only(left: 18, right: 28, top: 12, bottom: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
      ),
      child: Row(
        children: [
          // Left: Count & Selection info
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.table_chart_outlined, size: 13, color: Color(0xFF0C3B2E)),
                      const SizedBox(width: 5),
                      Text(
                        '$count OPEN RECORDS',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _selectedBomIds.isEmpty
                        ? 'Select target records to batch close'
                        : '${_selectedBomIds.length} record(s) selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: _selectedBomIds.isEmpty ? FontWeight.normal : FontWeight.bold,
                      color: _selectedBomIds.isEmpty ? const Color(0xFF64748B) : const Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Middle-Right: Filter Button (Image 2)
          _buildFilterButton(),

          const SizedBox(width: 8),

          // Middle-Right: Compact Glassmorphic Search Bar (Image 1)
          _buildCompactGlassmorphicSearchBar(),

          // Push Stepper to the Right
          const Spacer(),

          // Right: Stepper Progress Bar Navigation Cluster (Image 2 Parity)
          _buildStepperProgressNavigationCluster(),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    final hasActiveFilters = _selectedDeptCode != 0 ||
        _selectedDivCode != 0 ||
        _selectedOrderType != 'ALL';
    final activeCount = (_selectedDeptCode != 0 ? 1 : 0) +
        (_selectedDivCode != 0 ? 1 : 0) +
        (_selectedOrderType != 'ALL' ? 1 : 0);

    return Tooltip(
      message: 'Filter records by Date, Department, Division, Order Type',
      child: InkWell(
        onTap: _openFilterDialog,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: hasActiveFilters ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasActiveFilters ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
              width: 1.1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 15,
                color: hasActiveFilters ? const Color(0xFF065F46) : const Color(0xFF334155),
              ),
              const SizedBox(width: 6),
              Text(
                'Filter',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: hasActiveFilters ? const Color(0xFF065F46) : const Color(0xFF334155),
                ),
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactGlassmorphicSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 210,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _searchQuery.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Quick search BOM, Material...',
              hintStyle: const TextStyle(fontSize: 11.0, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF0C3B2E)),
              prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 34),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF64748B)),
                      onPressed: () => _searchCtrl.clear(),
                      splashRadius: 12,
                      padding: EdgeInsets.zero,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 34),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              isDense: true,
            ),
          ),
        ),
      ),
    );
  }

  static const List<_ViewModeStep> _stepperSteps = [
    _ViewModeStep(
      index: 0,
      label: 'All Columns',
      color: Color(0xFF059669), // 1. Emerald Green
      glowColor: Color(0xFF10B981),
      activeBorderTint: Color(0xFFA7F3D0),
      inactiveBarColor: Color(0xFFA7F3D0),
    ),
    _ViewModeStep(
      index: 1,
      label: 'Overview',
      color: Color(0xFF0091FF), // 2. Vivid Electric Blue (100% Image 2 reference)
      glowColor: Color(0xFF00A3FF),
      activeBorderTint: Color(0xFFBAE6FD),
      inactiveBarColor: Color(0xFFBAE6FD),
    ),
    _ViewModeStep(
      index: 2,
      label: 'Inventory',
      color: Color(0xFF7C3AED), // 3. Royal Violet / Indigo
      glowColor: Color(0xFF8B5CF6),
      activeBorderTint: Color(0xFFDDD6FE),
      inactiveBarColor: Color(0xFFDDD6FE),
    ),
    _ViewModeStep(
      index: 3,
      label: 'Audit Log',
      color: Color(0xFFEA580C), // 4. Warm Flame Orange / Amber
      glowColor: Color(0xFFF97316),
      activeBorderTint: Color(0xFFFFEDD5),
      inactiveBarColor: Color(0xFFFFEDD5),
    ),
  ];

  Widget _buildStepperProgressNavigationCluster() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Previous / Left Arrow Button (Aligned with 22x22 circle track)
        _buildStepperArrowButton(
          icon: Icons.chevron_left_rounded,
          onTap: _previousViewMode,
          tooltip: 'Previous View Mode',
        ),
        const SizedBox(width: 12),

        // Stepper Nodes & Connecting Progress Lines (100% Image 2 Parity)
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepNode(_stepperSteps[0], isActive: _columnViewMode == 0),
            _buildConnectorLine(precedingIndex: 0),
            _buildStepNode(_stepperSteps[1], isActive: _columnViewMode == 1),
            _buildConnectorLine(precedingIndex: 1),
            _buildStepNode(_stepperSteps[2], isActive: _columnViewMode == 2),
            _buildConnectorLine(precedingIndex: 2),
            _buildStepNode(_stepperSteps[3], isActive: _columnViewMode == 3),
          ],
        ),

        const SizedBox(width: 12),

        // Next / Right Arrow Button (Aligned with 22x22 circle track)
        _buildStepperArrowButton(
          icon: Icons.chevron_right_rounded,
          onTap: _nextViewMode,
          tooltip: 'Next View Mode',
        ),
      ],
    );
  }

  Widget _buildStepperArrowButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 15,
              color: const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepNode(_ViewModeStep step, {required bool isActive}) {
    final Color barColor = isActive ? step.color : step.inactiveBarColor;

    return Tooltip(
      message: 'Switch to ${step.label}',
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            setState(() => _columnViewMode = step.index);
            if (_horizontalScrollCtrl.hasClients) {
              _horizontalScrollCtrl.jumpTo(0.0);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circle Node (Exact Image 2 Size: 22x22)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? step.color : Colors.white,
                  border: isActive
                      ? Border.all(
                          color: step.activeBorderTint.withValues(alpha: 0.9),
                          width: 1.3,
                        )
                      : Border.all(
                          color: step.color,
                          width: 1.6,
                        ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: step.glowColor.withValues(alpha: 0.50),
                            blurRadius: 8,
                            spreadRadius: 2.5,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${step.index + 1}',
                  style: TextStyle(
                    color: isActive ? Colors.white : step.color,
                    fontSize: 10.5,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),

              const SizedBox(height: 3.5),

              // Dual Horizontal Pill Indicator Bars (Exact Image 2 style)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 18,
                height: 2.6,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 1.8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 12,
                height: 2.6,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),

              const SizedBox(height: 3.5),

              // Text Label
              Text(
                step.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? step.color : const Color(0xFF64748B),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectorLine({required int precedingIndex}) {
    final bool isPassed = _columnViewMode > precedingIndex;
    final step = _stepperSteps[precedingIndex];

    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 5, right: 5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 2.0,
        decoration: BoxDecoration(
          color: isPassed ? step.color : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildFloatingArrowButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: const Color(0xFF0C3B2E)),
          ),
        ),
      ),
    );
  }

  Widget _buildTableContent(List<BomFollowupRecord> filtered) {
    if (_isLoading && _records.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0C3B2E)),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Open BOM Records Found',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Adjust the filter date or search query to find open records.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double baseWidth = _currentTableWidth;
        final double availableWidth = math.max(constraints.maxWidth, baseWidth);
        final double extraWidth = math.max(0.0, constraints.maxWidth - baseWidth);
        final bool needsHorizontalScroll = baseWidth > constraints.maxWidth;

        return Stack(
          children: [
            // Horizontal container with suppressed scrollbar
            ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: SingleChildScrollView(
                controller: _horizontalScrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: needsHorizontalScroll
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: availableWidth,
                  child: Column(
                    children: [
                      // TABLE HEADER BAR
                      _buildTableHeader(extraWidth),

                      // TABLE BODY ROWS
                      Expanded(
                        child: Scrollbar(
                          controller: _verticalScrollCtrl,
                          thumbVisibility: true,
                          child: ListView.separated(
                            controller: _verticalScrollCtrl,
                            itemCount: filtered.length,
                            separatorBuilder: (ctx, idx) =>
                                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (ctx, idx) {
                              final item = filtered[idx];
                              final isSelected = _selectedBomIds.contains(item.bomId);
                              final isEven = idx % 2 == 0;
                              return _buildTableRow(item, isSelected, isEven, extraWidth);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Left Floating Navigation Arrow (when scrolled right)
            if (needsHorizontalScroll && _canScrollLeft)
              Positioned(
                left: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildFloatingArrowButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: _scrollLeft,
                    tooltip: 'Scroll Left',
                  ),
                ),
              ),

            // Right Floating Navigation Arrow (when scrollable right)
            if (needsHorizontalScroll && _canScrollRight)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildFloatingArrowButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: _scrollRight,
                    tooltip: 'Scroll Right',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTableHeader([double extraWidth = 0.0]) {
    return Container(
      height: 42,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
      ),
      child: Row(
        children: [
          // Select All Checkbox
          SizedBox(
            width: _colWidthCheckbox,
            child: Center(
              child: Checkbox(
                value: _isAllFilteredSelected,
                activeColor: const Color(0xFF0C3B2E),
                onChanged: (_) => _toggleSelectAllFiltered(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),

          // Header columns based on selected view mode
          ..._buildHeaderCellsForMode(extraWidth),
        ],
      ),
    );
  }

  List<Widget> _buildHeaderCellsForMode([double extraWidth = 0.0]) {
    switch (_columnViewMode) {
      case 1:
        // Overview (zero-scroll compact)
        final matWidth = 320.0 + (extraWidth * 0.65);
        final deptWidth = 170.0 + (extraWidth * 0.35);
        return [
          _buildHeaderCell(_colWidthBomId, 'BOM ID', Icons.tag_rounded, const Color(0xFF6366F1)),
          _buildHeaderCell(_colWidthDate, 'DATE', Icons.calendar_today_rounded, const Color(0xFFF59E0B)),
          _buildHeaderCell(deptWidth, 'DEPARTMENT', Icons.apartment_rounded, const Color(0xFF10B981)),
          _buildHeaderCell(160.0, 'DIVISION', Icons.category_rounded, const Color(0xFF8B5CF6)),
          _buildHeaderCell(matWidth, 'MATERIAL NAME', Icons.inventory_2_outlined, const Color(0xFFEC4899)),
          _buildHeaderCell(115.0, 'QTY', Icons.calculate_outlined, const Color(0xFFF97316), alignRight: true),
          _buildHeaderCell(95.0, 'STATUS', Icons.verified_rounded, const Color(0xFF10B981), center: true),
        ];
      case 2:
        // Inventory & Rates
        final matWidth = 280.0 + (extraWidth * 0.70);
        final branchWidth = 155.0 + (extraWidth * 0.30);
        return [
          _buildHeaderCell(_colWidthBomId, 'BOM ID', Icons.tag_rounded, const Color(0xFF6366F1)),
          _buildHeaderCell(matWidth, 'MATERIAL NAME', Icons.inventory_2_outlined, const Color(0xFFEC4899)),
          _buildHeaderCell(180.0, 'MATERIAL CODE', Icons.qr_code_rounded, const Color(0xFF64748B)),
          _buildHeaderCell(branchWidth, 'BRANCH', Icons.store_mall_directory_rounded, const Color(0xFF06B6D4)),
          _buildHeaderCell(110.0, 'QTY', Icons.calculate_outlined, const Color(0xFFF97316), alignRight: true),
          _buildHeaderCell(110.0, 'RATE', Icons.currency_rupee_rounded, const Color(0xFF0C3B2E), alignRight: true),
          _buildHeaderCell(95.0, 'STATUS', Icons.verified_rounded, const Color(0xFF10B981), center: true),
          _buildHeaderCell(75.0, 'UQC', Icons.straighten_rounded, const Color(0xFF64748B), center: true),
        ];
      case 3:
        // Audit & Tracking
        final matWidth = 280.0 + (extraWidth * 0.65);
        final deptWidth = 170.0 + (extraWidth * 0.35);
        return [
          _buildHeaderCell(_colWidthBomId, 'BOM ID', Icons.tag_rounded, const Color(0xFF6366F1)),
          _buildHeaderCell(matWidth, 'MATERIAL NAME', Icons.inventory_2_outlined, const Color(0xFFEC4899)),
          _buildHeaderCell(deptWidth, 'DEPARTMENT', Icons.apartment_rounded, const Color(0xFF10B981)),
          _buildHeaderCell(130.0, 'USER', Icons.person_outline_rounded, const Color(0xFF6366F1)),
          _buildHeaderCell(95.0, 'STATUS', Icons.verified_rounded, const Color(0xFF10B981), center: true),
          _buildHeaderCell(160.0, 'DT & TIME', Icons.access_time_rounded, const Color(0xFF64748B)),
        ];
      case 0:
      default:
        // All Columns
        final matWidth = _colWidthName + extraWidth;
        return [
          _buildHeaderCell(_colWidthBomId, 'BOM ID', Icons.tag_rounded, const Color(0xFF6366F1)),
          _buildHeaderCell(_colWidthDate, 'DATE', Icons.calendar_today_rounded, const Color(0xFFF59E0B)),
          _buildHeaderCell(_colWidthDept, 'DEPARTMENT', Icons.apartment_rounded, const Color(0xFF10B981)),
          _buildHeaderCell(_colWidthBranch, 'BRANCH', Icons.store_mall_directory_rounded, const Color(0xFF06B6D4)),
          _buildHeaderCell(_colWidthDiv, 'DIVISION', Icons.category_rounded, const Color(0xFF8B5CF6)),
          _buildHeaderCell(matWidth, 'MATERIAL NAME', Icons.inventory_2_outlined, const Color(0xFFEC4899)),
          _buildHeaderCell(_colWidthCode, 'MATERIAL CODE', Icons.qr_code_rounded, const Color(0xFF64748B)),
          _buildHeaderCell(_colWidthQty, 'QTY', Icons.calculate_outlined, const Color(0xFFF97316), alignRight: true),
          _buildHeaderCell(_colWidthStatus, 'STATUS', Icons.verified_rounded, const Color(0xFF10B981), center: true),
          _buildHeaderCell(_colWidthDtTime, 'DT & TIME', Icons.access_time_rounded, const Color(0xFF64748B)),
          _buildHeaderCell(_colWidthUser, 'USER', Icons.person_outline_rounded, const Color(0xFF6366F1)),
          _buildHeaderCell(_colWidthRate, 'RATE', Icons.currency_rupee_rounded, const Color(0xFF0C3B2E), alignRight: true),
          _buildHeaderCell(_colWidthUqc, 'UQC', Icons.straighten_rounded, const Color(0xFF64748B), center: true),
        ];
    }
  }

  Widget _buildHeaderCell(
    double width,
    String label,
    IconData icon,
    Color iconColor, {
    bool alignRight = false,
    bool center = false,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: center
              ? MainAxisAlignment.center
              : (alignRight ? MainAxisAlignment.end : MainAxisAlignment.start),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.5, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(BomFollowupRecord item, bool isSelected, bool isEven, [double extraWidth = 0.0]) {
    return InkWell(
      onTap: () => _toggleRecordSelection(item.bomId),
      hoverColor: const Color(0xFFF1F5F9),
      child: Container(
        height: 44,
        color: isSelected
            ? const Color(0xFFF0FDF4)
            : (isEven ? Colors.white : const Color(0xFFF8FAFC)),
        child: Row(
          children: [
            // Row Checkbox
            SizedBox(
              width: _colWidthCheckbox,
              child: Center(
                child: Checkbox(
                  value: isSelected,
                  activeColor: const Color(0xFF0C3B2E),
                  onChanged: (_) => _toggleRecordSelection(item.bomId),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),

            // Mode cells
            ..._buildRowCellsForMode(item, extraWidth),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRowCellsForMode(BomFollowupRecord item, [double extraWidth = 0.0]) {
    switch (_columnViewMode) {
      case 1:
        // Overview
        final matWidth = 320.0 + (extraWidth * 0.65);
        final deptWidth = 170.0 + (extraWidth * 0.35);
        return [
          _buildBomIdCell(item.bomId, _colWidthBomId),
          _buildDateCell(item.bomDate, _colWidthDate),
          _buildTextCell(item.department, deptWidth),
          _buildTextCell(item.division, 160.0),
          _buildTextCell(item.materialName, matWidth, isBold: true, color: Colors.black),
          _buildQtyCell(item.qty, 115.0),
          _buildStatusCell(item.status, 95.0),
        ];
      case 2:
        // Inventory & Rates
        final matWidth = 280.0 + (extraWidth * 0.70);
        final branchWidth = 155.0 + (extraWidth * 0.30);
        return [
          _buildBomIdCell(item.bomId, _colWidthBomId),
          _buildTextCell(item.materialName, matWidth, isBold: true, color: Colors.black),
          _buildTextCell(item.materialCode, 180.0, isMonospace: true, color: Colors.black),
          _buildTextCell(item.branch, branchWidth),
          _buildQtyCell(item.qty, 110.0),
          _buildRateCell(item.rate, 110.0),
          _buildStatusCell(item.status, 95.0),
          _buildUqcCell(item.uqc, 75.0),
        ];
      case 3:
        // Audit & Tracking
        final matWidth = 280.0 + (extraWidth * 0.65);
        final deptWidth = 170.0 + (extraWidth * 0.35);
        return [
          _buildBomIdCell(item.bomId, _colWidthBomId),
          _buildTextCell(item.materialName, matWidth, isBold: true, color: Colors.black),
          _buildTextCell(item.department, deptWidth),
          _buildTextCell(item.user, 130.0, isBold: true, color: Colors.black),
          _buildStatusCell(item.status, 95.0),
          _buildDtTimeCell(item.dtAndTime, 160.0),
        ];
      case 0:
      default:
        // All Columns
        final matWidth = _colWidthName + extraWidth;
        return [
          _buildBomIdCell(item.bomId, _colWidthBomId),
          _buildDateCell(item.bomDate, _colWidthDate),
          _buildTextCell(item.department, _colWidthDept),
          _buildTextCell(item.branch, _colWidthBranch),
          _buildTextCell(item.division, _colWidthDiv),
          _buildTextCell(item.materialName, matWidth, isBold: true, color: Colors.black),
          _buildTextCell(item.materialCode, _colWidthCode, isMonospace: true, color: Colors.black),
          _buildQtyCell(item.qty, _colWidthQty),
          _buildStatusCell(item.status, _colWidthStatus),
          _buildDtTimeCell(item.dtAndTime, _colWidthDtTime),
          _buildTextCell(item.user, _colWidthUser, isBold: true, color: Colors.black),
          _buildRateCell(item.rate, _colWidthRate),
          _buildUqcCell(item.uqc, _colWidthUqc),
        ];
    }
  }

  Widget _buildBomIdCell(String bomId, [double width = _colWidthBomId]) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          bomId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
            color: Colors.black,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildDateCell(DateTime date, [double width = _colWidthDate]) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          _formatDate(date),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildTextCell(
    String text,
    double width, {
    bool isBold = false,
    bool isMonospace = false,
    Color? color,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: isMonospace ? 'monospace' : null,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            fontSize: isMonospace ? 11.0 : 11.5,
            color: color ?? Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildQtyCell(double qty, [double width = _colWidthQty]) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            qty.toStringAsFixed(3),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCell(String status, [double width = _colWidthStatus]) {
    return SizedBox(
      width: width,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5.5,
                height: 5.5,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                status,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF065F46),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDtTimeCell(DateTime? dt, [double width = _colWidthDtTime]) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          _formatDateTime(dt),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10.5,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildRateCell(double rate, [double width = _colWidthRate]) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            rate.toStringAsFixed(2),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUqcCell(String uqc, [double width = _colWidthUqc]) {
    return SizedBox(
      width: width,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            uqc,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

}

class _ViewModeStep {
  final int index;
  final String label;
  final Color color;
  final Color glowColor;
  final Color activeBorderTint;
  final Color inactiveBarColor;

  const _ViewModeStep({
    required this.index,
    required this.label,
    required this.color,
    required this.glowColor,
    required this.activeBorderTint,
    required this.inactiveBarColor,
  });
}

