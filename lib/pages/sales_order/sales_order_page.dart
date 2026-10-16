import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../design/app_colors.dart';
import 'sales_order_models.dart';
import 'sales_order_service.dart';
import 'widgets/add_so_row_dialog.dart';
import 'widgets/customer_lookup_dialog.dart';
import 'widgets/so_animated_success_button.dart';
import 'widgets/so_charges_modal_dialog.dart';
import 'widgets/so_export_modal_dialog.dart';
import 'widgets/so_step_progress_bar.dart';
import 'widgets/so_terms_modal_dialog.dart';

class SalesOrderPage extends StatefulWidget {
  final SalesOrderService? service;

  const SalesOrderPage({super.key, this.service});

  @override
  State<SalesOrderPage> createState() => _SalesOrderPageState();
}

class _SalesOrderPageState extends State<SalesOrderPage> {
  late final SalesOrderService _service;

  // Grid Data & Filter States
  List<SalesOrderHeader> _orders = [];
  List<SalesOrderHeader> _filteredOrders = [];
  bool _isLoading = true;
  String? _loadError;
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 50;

  DateTime? _fromDate;
  DateTime? _toDate;
  final int _selectedCostCenter = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _tableScrollCtrl = ScrollController();

  // Glow Effect state (Project Master style)
  String? _highlightedSoNo;
  bool _isHighlightedEdit = false;
  Timer? _highlightTimer;

  // Form Lookups Cache
  SalesOrderLookups? _lookups;

  // ==========================================================================
  // WIZARD MODAL STATE (3-STEP MODAL)
  // ==========================================================================
  bool _isWizardOpen = false;
  int _currentStep = 1; // 1, 2, 3
  bool _isEditing = false;
  ButtonStatus _saveButtonStatus = ButtonStatus.idle;
  String? _wizardError;

  // Step 1: Header Metadata
  final TextEditingController _soNoCtrl = TextEditingController();
  DateTime _soDate = DateTime.now();
  int _pCode = 0;
  String _partyName = '';
  String _gstin = '';
  String _stateCode = '';
  String _address = '';
  String _soMode = 'Direct';
  int _somCapMode = 0;
  int _costCd = 0;
  String _curr = 'INR';
  final TextEditingController _soCrDaysCtrl = TextEditingController(text: '0');
  final TextEditingController _somDelDaysCtrl = TextEditingController(text: '0');
  int _spCd = 0;
  final TextEditingController _suppRefCtrl = TextEditingController();

  // Step 2: Line Items
  List<SalesOrderItem> _lineItems = [];

  // Step 3: Auxiliary Modals Data & Calculations
  List<SalesOrderCharge> _charges = [];
  List<SalesOrderCondition> _conditions = [];
  final TextEditingController _remarkCtrl = TextEditingController();
  List<String> _remarkSuggestions = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SalesOrderService();
    _loadInitialData();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _tableScrollCtrl.dispose();

    _soNoCtrl.dispose();
    _soCrDaysCtrl.dispose();
    _somDelDaysCtrl.dispose();
    _suppRefCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final lookups = await _service.fetchLookups();
      final paged = await _service.fetchSalesOrders(
        fromDate: _fromDate,
        toDate: _toDate,
        costCd: _selectedCostCenter > 0 ? _selectedCostCenter : null,
        search: _searchCtrl.text.trim(),
        page: _currentPage,
        pageSize: _pageSize,
      );

      final remarks = await _service.fetchRemarksLookup('');

      if (mounted) {
        setState(() {
          _lookups = lookups;
          _orders = paged.items;
          _filteredOrders = List.from(paged.items);
          _totalCount = paged.totalCount;
          _remarkSuggestions = remarks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredOrders = List.from(_orders);
      } else {
        _filteredOrders = _orders.where((o) {
          final noMatch = o.soNo.toLowerCase().contains(q);
          final partyMatch = o.partyName.toLowerCase().contains(q);
          final gstinMatch = o.gstin.toLowerCase().contains(q);
          final ccMatch = o.costCenterName.toLowerCase().contains(q);
          return noMatch || partyMatch || gstinMatch || ccMatch;
        }).toList();
      }
    });
  }

  void _triggerGlow(String soNo, bool isEdit) {
    _highlightTimer?.cancel();
    setState(() {
      _highlightedSoNo = soNo;
      _isHighlightedEdit = isEdit;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tableScrollCtrl.hasClients) {
        final idx = _filteredOrders.indexWhere((o) => o.soNo == soNo);
        if (idx != -1) {
          final targetOffset = (idx * 40.0) - 80.0;
          _tableScrollCtrl.animateTo(
            targetOffset.clamp(0.0, _tableScrollCtrl.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });

    _highlightTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _highlightedSoNo = null);
      }
    });
  }

  // ==========================================================================
  // WIZARD OPEN / CLOSE / INITIALIZATION
  // ==========================================================================
  void _openNewEntryWizard() {
    _soNoCtrl.text = _lookups?.nextSoNo ?? 'SALO/000001/27';
    _soDate = DateTime.now();
    _pCode = 0;
    _partyName = '';
    _gstin = '';
    _stateCode = '';
    _address = '';
    _soMode = 'Direct';
    _somCapMode = (_lookups?.capModes.isNotEmpty == true) ? _lookups!.capModes.first.code : 0;
    _costCd = (_lookups?.costCenters.isNotEmpty == true) ? _lookups!.costCenters.first.code : 0;
    _curr = (_lookups?.currencies.isNotEmpty == true) ? _lookups!.currencies.first : 'INR';
    _soCrDaysCtrl.text = '0';
    _somDelDaysCtrl.text = '0';
    _spCd = (_lookups?.salesPersons.isNotEmpty == true) ? _lookups!.salesPersons.first.code : 0;
    _suppRefCtrl.text = '';

    _lineItems = [];
    _charges = List.from(_lookups?.defaultCharges ?? []);
    _conditions = [];
    _remarkCtrl.text = '';

    setState(() {
      _isEditing = false;
      _isWizardOpen = true;
      _currentStep = 1;
      _wizardError = null;
      _saveButtonStatus = ButtonStatus.idle;
    });
  }

  void _openEditWizard(SalesOrderHeader header) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fullOrder = await _service.fetchSalesOrderByNo(header.soNo);
      if (fullOrder != null && mounted) {
        _soNoCtrl.text = fullOrder.soNo;
        _soDate = fullOrder.soDate;
        _pCode = fullOrder.pCode;
        _partyName = fullOrder.partyName;
        _gstin = fullOrder.gstin;
        _stateCode = fullOrder.stateCode;
        _address = fullOrder.address;
        _soMode = fullOrder.soMode;
        _somCapMode = fullOrder.somCapMode;
        _costCd = fullOrder.costCd;
        _curr = fullOrder.curr;
        _soCrDaysCtrl.text = fullOrder.soCrDays.toString();
        _somDelDaysCtrl.text = fullOrder.somDelDays.toString();
        _spCd = fullOrder.spCd;
        _suppRefCtrl.text = fullOrder.suppRef;

        _lineItems = List.from(fullOrder.items);
        _charges = List.from(fullOrder.charges.isNotEmpty ? fullOrder.charges : (_lookups?.defaultCharges ?? []));
        _conditions = List.from(fullOrder.conditions);
        _remarkCtrl.text = fullOrder.remark;

        setState(() {
          _isEditing = true;
          _isWizardOpen = true;
          _currentStep = 1;
          _wizardError = null;
          _saveButtonStatus = ButtonStatus.idle;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('Could not load Sales Order details', e.toString());
      }
    }
  }

  void _closeWizard() {
    setState(() {
      _isWizardOpen = false;
      _saveButtonStatus = ButtonStatus.idle;
      _wizardError = null;
    });
  }

  // ==========================================================================
  // CALCULATIONS
  // ==========================================================================
  double get _grossAmount {
    double sum = 0.0;
    for (final it in _lineItems) {
      sum += (it.qty * it.rate);
    }
    return sum;
  }

  double get _totalItemDiscounts {
    double sum = 0.0;
    for (final it in _lineItems) {
      sum += it.disc;
    }
    return sum;
  }

  double get _totalQty {
    double sum = 0.0;
    for (final it in _lineItems) {
      sum += it.qty;
    }
    return sum;
  }

  double get _chargesNetEffect {
    double sum = 0.0;
    for (final c in _charges) {
      sum += (c.amt * c.addLess);
    }
    return sum;
  }

  double get _finalNetAmount {
    final itemsNet = _grossAmount - _totalItemDiscounts;
    final total = itemsNet + _chargesNetEffect;
    return total < 0 ? 0.0 : total;
  }

  // ==========================================================================
  // SAVE SALES ORDER ACTION
  // ==========================================================================
  Future<void> _saveSalesOrder() async {
    if (_pCode <= 0) {
      setState(() {
        _wizardError = 'Please select a Customer in Step 1';
        _currentStep = 1;
      });
      return;
    }

    if (_lineItems.isEmpty) {
      setState(() {
        _wizardError = 'Please add at least one line item in Step 2';
        _currentStep = 2;
      });
      return;
    }

    // Check date lock
    final isLocked = await _service.checkDateLock(_soDate);
    if (isLocked) {
      setState(() {
        _wizardError = 'The date ${_soDate.toIso8601String().split('T').first} is locked in financial data lock (LOCKDATAMST).';
      });
      return;
    }

    setState(() {
      _saveButtonStatus = ButtonStatus.loading;
      _wizardError = null;
    });

    final payload = {
      'isEdit': _isEditing,
      'soNo': _soNoCtrl.text.trim(),
      'soDate': _soDate.toIso8601String(),
      'pCode': _pCode,
      'deptCode': 0,
      'soMode': _soMode,
      'totItm': _lineItems.length,
      'totQty': _totalQty,
      'totDisc': _totalItemDiscounts,
      'totAmt': _grossAmount,
      'adv': 0.0,
      'pfChg': 0.0,
      'freight': 0.0,
      'others': _chargesNetEffect,
      'netAmt': _finalNetAmount,
      'remark': _remarkCtrl.text.trim(),
      'curr': _curr,
      'suppRef': _suppRefCtrl.text.trim(),
      'soCrDays': int.tryParse(_soCrDaysCtrl.text.trim()) ?? 0,
      'somLoc': 'LWHL26_SQL',
      'somEmode': _soMode,
      'somDelDays': int.tryParse(_somDelDaysCtrl.text.trim()) ?? 0,
      'somCapMode': _somCapMode,
      'costCd': _costCd,
      'spCd': _spCd,
      'items': _lineItems.map((e) => e.toJson()).toList(),
      'charges': _charges.map((e) => e.toJson()).toList(),
      'conditions': _conditions.map((e) => e.toJson()).toList(),
    };

    try {
      final savedSoNo = await _service.saveSalesOrder(payload);

      setState(() {
        _saveButtonStatus = ButtonStatus.success;
      });

      await Future.delayed(const Duration(milliseconds: 700));

      if (mounted) {
        _closeWizard();
        await _loadInitialData();
        _triggerGlow(savedSoNo, _isEditing);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveButtonStatus = ButtonStatus.error;
          _wizardError = e.toString();
        });
      }
    }
  }

  // ==========================================================================
  // DELETE SALES ORDER ACTION
  // ==========================================================================
  Future<void> _confirmDelete(SalesOrderHeader order) async {
    if (order.isRec) {
      _showErrorDialog('Cannot Delete', 'Sales Order ${order.soNo} has already been received/dispatched and cannot be deleted.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 10),
            Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Are you sure you want to permanently delete Sales Order ${order.soNo}?\n\nThis will remove the order header, line items, and audit this action in DAYBOOK.'),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteSalesOrder(order.soNo);
        await _loadInitialData();
      } catch (e) {
        _showErrorDialog('Delete Failed', e.toString());
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
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
                      // Glassmorphic Corporate Header & Metrics
                      _buildHeaderCard(),
                      const SizedBox(height: 14),

                      // Main Responsive Table Body
                      Expanded(child: _buildMainTableDesk()),
                      const SizedBox(height: 10),

                      // Pagination Footer
                      _buildPaginationFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3-Step Wizard Overlay Modal
          if (_isWizardOpen) _buildWizardModalOverlay(),
        ],
      ),
    );
  }

  // ==========================================================================
  // 1. CORPORATE HEADER CONTAINER WITH KPI GAUGES (DEPARTMENT MASTER STYLE)
  // ==========================================================================
  Widget _buildHeaderCard() {
    double totalVal = 0.0;
    int totalItems = 0;
    double totalQty = 0.0;
    for (final o in _filteredOrders) {
      totalVal += o.netAmt;
      totalItems += o.totItm;
      totalQty += o.totQty;
    }

    return Container(
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
          // Row 1: Title & KPI Gauges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Generate Sales Order',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Transaction → Sales Order → Generate Sales Order',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Modern Gauge KPI Cards
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildKpiCard(
                    label: 'TOTAL ORDERS',
                    value: _totalCount.toString(),
                    gradientColors: const [Color(0xFF2563EB), Color(0xFF06B6D4)],
                  ),
                  const SizedBox(width: 10),
                  _buildKpiCard(
                    label: 'TOTAL ITEMS',
                    value: totalItems.toString(),
                    gradientColors: const [Color(0xFFEC4899), Color(0xFFF43F5E)],
                  ),
                  const SizedBox(width: 10),
                  _buildKpiCard(
                    label: 'TOTAL QTY',
                    value: totalQty.toStringAsFixed(1),
                    gradientColors: const [Color(0xFFF59E0B), Color(0xFFEA580C)],
                  ),
                  const SizedBox(width: 10),
                  _buildKpiCard(
                    label: 'TOTAL NET VALUE',
                    value: '₹ ${totalVal.toStringAsFixed(2)}',
                    gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Search Bar + Orbit Export Button + New Entry Button (Project Master style)
          Row(
            children: [
              // Search Input Field
              Expanded(
                child: Container(
                  height: 38,
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
                    style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
                    decoration: InputDecoration(
                      hintText: 'Search SO No, Customer, GSTIN, Division...',
                      hintStyle: TextStyle(fontSize: 11.5, color: AppColors.neutralDark.withValues(alpha: 0.5)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.primaryColor),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 14),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: AppColors.secondaryColor, width: 1.4),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Animated Export Orbit Button (100% exact Project Master parity)
              SoAnimatedExportButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => SoExportModalDialog(orders: _filteredOrders),
                  );
                },
              ),

              const SizedBox(width: 10),

              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
                onPressed: _loadInitialData,
                tooltip: 'Refresh Orders',
              ),

              const SizedBox(width: 10),

              // + New Entry Button (Project Master style)
              ElevatedButton.icon(
                onPressed: _openNewEntryWizard,
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'New Entry',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  elevation: 2,
                  shadowColor: AppColors.secondaryColor.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.3),
          ),
          const SizedBox(height: 2),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              value,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2. MAIN DATA GRID DESK (DEPARTMENT MASTER TABLE PARITY)
  // ==========================================================================
  Widget _buildMainTableDesk() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            Text(_loadError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: _loadInitialData, child: const Text('Try Again')),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
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
          // Table Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Sales Order Directory Register',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_filteredOrders.length} Records',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.secondaryColor),
                  ),
                ),
              ],
            ),
          ),

          // Responsive Table Body Grid
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              child: _filteredOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('No sales order records match your criteria', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        const double minTableWidth = 1350.0;
                        final double tableWidth = math.max(constraints.maxWidth, minTableWidth);

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: Column(
                              children: [
                                // Column Header Bar with Vector Icons & Natural Color Accents
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
                                        width: 130,
                                        child: Row(
                                          children: [
                                            Icon(Icons.sell_outlined, size: 12, color: Color(0xFF2563EB)),
                                            SizedBox(width: 4),
                                            Text('SO NO', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 95,
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF0891B2)),
                                            SizedBox(width: 4),
                                            Text('DATE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            Icon(Icons.business_rounded, size: 12, color: Color(0xFF059669)),
                                            SizedBox(width: 4),
                                            Text('CUSTOMER NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 140,
                                        child: Row(
                                          children: [
                                            Icon(Icons.receipt_long_rounded, size: 12, color: Color(0xFFD97706)),
                                            SizedBox(width: 4),
                                            Text('GSTIN', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Icon(Icons.account_tree_rounded, size: 12, color: Color(0xFF8B5CF6)),
                                            SizedBox(width: 4),
                                            Text('DIVISION', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 60,
                                        child: Center(
                                          child: Text('ITEMS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text('QTY', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 95,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text('GROSS (₹)', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text('DISC (₹)', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 110,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text('NET AMT (₹)', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: Center(
                                          child: Text('STATUS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Center(
                                          child: Text('ACTIONS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ListView Rows with Project Master Glow Strategy
                                Expanded(
                                  child: ListView.separated(
                                    controller: _tableScrollCtrl,
                                    itemCount: _filteredOrders.length,
                                    separatorBuilder: (ctx, idx) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (context, index) {
                                      final order = _filteredOrders[index];
                                      final isGlowing = _highlightedSoNo == order.soNo;
                                      final isZebra = index % 2 == 1;

                                      Color rowBg = isZebra ? const Color(0xFFF8FAFC) : Colors.white;
                                      if (isGlowing) {
                                        rowBg = _isHighlightedEdit ? const Color(0xFFFFF9C4) : const Color(0xFFE8F5E9);
                                      }

                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 500),
                                        color: rowBg,
                                        height: 40,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        child: Row(
                                          children: [
                                            // SO No Badge
                                            SizedBox(
                                              width: 130,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEEF2FF),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFFC7D2FE)),
                                                  ),
                                                  child: Text(
                                                    order.soNo,
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Date
                                            SizedBox(
                                              width: 95,
                                              child: Text(
                                                order.soDate.toIso8601String().split('T').first,
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                              ),
                                            ),

                                            // Customer Name
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                order.partyName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                              ),
                                            ),

                                            // GSTIN
                                            SizedBox(
                                              width: 140,
                                              child: Text(
                                                order.gstin.isNotEmpty ? order.gstin : '—',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontFamily: order.gstin.isNotEmpty ? 'monospace' : null,
                                                  color: order.gstin.isNotEmpty ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ),

                                            // Division
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                order.costCenterName.isNotEmpty ? order.costCenterName : '—',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                              ),
                                            ),

                                            // Total Items
                                            SizedBox(
                                              width: 60,
                                              child: Center(
                                                child: Text(
                                                  order.totItm.toString(),
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                                ),
                                              ),
                                            ),

                                            // Qty
                                            SizedBox(
                                              width: 80,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                  order.totQty.toStringAsFixed(1),
                                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
                                                ),
                                              ),
                                            ),

                                            // Gross
                                            SizedBox(
                                              width: 95,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                  order.totAmt.toStringAsFixed(2),
                                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                                ),
                                              ),
                                            ),

                                            // Discount
                                            SizedBox(
                                              width: 80,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                  order.totDisc.toStringAsFixed(2),
                                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFFE11D48)),
                                                ),
                                              ),
                                            ),

                                            // Net Amount
                                            SizedBox(
                                              width: 110,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                  '₹ ${order.netAmt.toStringAsFixed(2)}',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                                ),
                                              ),
                                            ),

                                            // Status Badge
                                            SizedBox(
                                              width: 90,
                                              child: Center(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: order.isRec
                                                        ? const Color(0xFFDCFCE7)
                                                        : (order.approved ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7)),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    order.isRec ? 'Delivered' : (order.approved ? 'Approved' : 'Pending'),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: order.isRec
                                                          ? const Color(0xFF15803D)
                                                          : (order.approved ? const Color(0xFF1D4ED8) : const Color(0xFFB45309)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Actions (Edit & Delete)
                                            SizedBox(
                                              width: 80,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                                                    onPressed: () => _openEditWizard(order),
                                                    tooltip: 'Edit Sales Order',
                                                    splashRadius: 14,
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                                                    onPressed: () => _confirmDelete(order),
                                                    tooltip: 'Delete Sales Order',
                                                    splashRadius: 14,
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
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
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter() {
    final totalPages = (_totalCount / _pageSize).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Total Records: $_totalCount (Showing page $_currentPage of ${totalPages == 0 ? 1 : totalPages})',
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              onPressed: _currentPage > 1
                  ? () {
                      setState(() => _currentPage--);
                      _loadInitialData();
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              onPressed: _currentPage < totalPages
                  ? () {
                      setState(() => _currentPage++);
                      _loadInitialData();
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================================
  // 3. WIZARD OVERLAY MODAL (BOM-STYLE 3-STEP PROGRESS HEADER)
  // ==========================================================================
  Widget _buildWizardModalOverlay() {
    final size = MediaQuery.of(context).size;
    final modalWidth = (size.width * 0.88).clamp(900.0, 1150.0);
    final modalHeight = (size.height * 0.88).clamp(580.0, 740.0);

    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          width: modalWidth,
          height: modalHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWizardHeader(),

                // Dedicated BOM-style 3-Step Progress Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: SoStepProgressBar(
                    currentStep: _currentStep,
                    onStepSelected: (s) {
                      setState(() => _currentStep = s);
                    },
                  ),
                ),

                if (_wizardError != null) _buildWizardErrorBanner(),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: _buildCurrentStepContent(),
                  ),
                ),

                _buildWizardFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWizardHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isEditing ? Icons.edit_note_rounded : Icons.post_add_rounded,
              color: const Color(0xFF2563EB),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Edit Sales Order (${_soNoCtrl.text})' : 'Generate New Sales Order',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const Text(
                'Complete party info, populate line item details, configure duties & save',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
            onPressed: _closeWizard,
            splashRadius: 18,
            tooltip: 'Close Modal',
          ),
        ],
      ),
    );
  }

  Widget _buildWizardErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: const Color(0xFFFEF2F2),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _wizardError!,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
            onPressed: () => setState(() => _wizardError = null),
            splashRadius: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1HeaderMetadata();
      case 2:
        return _buildStep2LineItemsGrid();
      case 3:
      default:
        return _buildStep3ReviewAndCharges();
    }
  }

  // ==========================================================================
  // STEP 1: HEADER METADATA & PARTY
  // ==========================================================================
  Widget _buildStep1HeaderMetadata() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: SO No, Date, Currency
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField('Sales Order No *', _soNoCtrl, readOnly: true),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SO Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _soDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          final isLocked = await _service.checkDateLock(picked);
                          if (isLocked) {
                            setState(() => _wizardError = 'Date ${picked.toIso8601String().split('T').first} is locked in LOCKDATAMST');
                          } else {
                            setState(() {
                              _soDate = picked;
                              _wizardError = null;
                            });
                          }
                        }
                      },
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_soDate.toIso8601String().split('T').first, style: const TextStyle(fontSize: 12.5)),
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: _buildDropdown(
                  label: 'Currency',
                  value: _curr,
                  items: _lookups?.currencies ?? ['INR'],
                  onChanged: (val) => setState(() => _curr = val ?? 'INR'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Customer / Debtor Lookup Card (Triggers Group Master parity modal)
          _buildCustomerSelectionCard(),

          const SizedBox(height: 16),

          // Row 2: Mode, Cap Cons Store, Division
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Order Mode',
                  value: _soMode,
                  items: const ['Direct', 'Through Agent', 'Export', 'Tender'],
                  onChanged: (val) => setState(() => _soMode = val ?? 'Direct'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildLookupDropdown(
                  label: 'Cap Cons Store Location',
                  value: _somCapMode,
                  items: _lookups?.capModes ?? [],
                  onChanged: (val) => setState(() => _somCapMode = val ?? 0),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildLookupDropdown(
                  label: 'Division / Cost Center',
                  value: _costCd,
                  items: _lookups?.costCenters ?? [],
                  onChanged: (val) => setState(() => _costCd = val ?? 0),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Row 3: Credit Days, Delivery Days, Sales Person, Supp Ref
          Row(
            children: [
              Expanded(
                child: _buildTextField('Credit Days', _soCrDaysCtrl, keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildTextField('Delivery Days', _somDelDaysCtrl, keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildLookupDropdown(
                  label: 'Sales Person',
                  value: _spCd,
                  items: _lookups?.salesPersons ?? [],
                  onChanged: (val) => setState(() => _spCd = val ?? 0),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildTextField('Supplier Reference', _suppRefCtrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSelectionCard() {
    final hasParty = _pCode > 0 && _partyName.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasParty ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_pin_rounded, color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 8),
                  Text('Customer / Debtor Account *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final selected = await showDialog<CustomerLookup>(
                    context: context,
                    builder: (_) => CustomerLookupDialog(service: _service),
                  );
                  if (selected != null) {
                    setState(() {
                      _pCode = selected.pCode;
                      _partyName = selected.pName;
                      _gstin = selected.gstIn;
                      _stateCode = selected.state;
                      _address = selected.address;
                      _wizardError = null;
                    });
                  }
                },
                icon: const Icon(Icons.search_rounded, size: 15, color: Colors.white),
                label: Text(hasParty ? 'Change Customer' : 'Select Customer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          if (hasParty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('#$_pCode', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ),
                const SizedBox(width: 10),
                Text(
                  _partyName,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('GSTIN: ${_gstin.isNotEmpty ? _gstin : 'Unregistered'}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                const SizedBox(width: 16),
                Text('State: ${_stateCode.isNotEmpty ? _stateCode : 'N/A'}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              ],
            ),
            if (_address.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text('Address: $_address', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ] else ...[
            const SizedBox(height: 8),
            const Text('No customer selected yet. Click "Select Customer" to search debtors from PARTYMST.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // STEP 2: LINE ITEMS GRID (EXACT COLUMNS PARITY WITH ADD ROW DIALOG)
  // ==========================================================================
  Widget _buildStep2LineItemsGrid() {
    return Column(
      children: [
        // Grid Summary & Add Row Action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('Line Items (${_lineItems.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(width: 14),
                Text('Total Qty: ${_totalQty.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(width: 14),
                Text('Gross Amount: ₹ ${_grossAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await showDialog<SalesOrderItem>(
                  context: context,
                  builder: (_) => AddSoRowDialog(
                    service: _service,
                    costCenters: _lookups?.costCenters ?? [],
                    nextSrNo: _lineItems.length + 1,
                    onSave: (row) {
                      setState(() {
                        _lineItems.add(row);
                        _wizardError = null;
                      });
                    },
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: const Text('Add Line Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Expanded(
          child: _lineItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 44, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text('No line items added yet. Click "Add Line Item" above.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ],
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        // Column Headers matching Add Row Dialog exactly
                        Container(
                          height: 36,
                          color: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: const Row(
                            children: [
                              SizedBox(width: 35, child: Text('SR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                              SizedBox(width: 90, child: Text('ITEM CODE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                              Expanded(flex: 3, child: Text('ITEM DESCRIPTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                              SizedBox(width: 100, child: Text('DIVISION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                              SizedBox(width: 60, child: Text('UOM', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                              SizedBox(width: 70, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                              SizedBox(width: 80, child: Text('RATE (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                              SizedBox(width: 75, child: Text('DISC (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                              SizedBox(width: 95, child: Text('AMOUNT (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)))),
                              SizedBox(width: 80, child: Center(child: Text('ACTIONS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))))),
                            ],
                          ),
                        ),

                        const Divider(height: 1, color: Color(0xFFE2E8F0)),

                        // Line Items Rows
                        Expanded(
                          child: ListView.separated(
                            itemCount: _lineItems.length,
                            separatorBuilder: (ctx, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final it = _lineItems[index];

                              return Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 35,
                                      child: Text(it.srNo.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: Text(it.iCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        it.itemName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(it.divisionName.isNotEmpty ? it.divisionName : '—', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: Text(it.unitName.isNotEmpty ? it.unitName : '—', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                                    ),
                                    SizedBox(
                                      width: 70,
                                      child: Text(it.qty.toStringAsFixed(1), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A))),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Text('₹ ${it.rate.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A))),
                                    ),
                                    SizedBox(
                                      width: 75,
                                      child: Text('₹ ${it.disc.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: Color(0xFFE11D48))),
                                    ),
                                    SizedBox(
                                      width: 95,
                                      child: Text('₹ ${it.amount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                            onPressed: () async {
                                              await showDialog<SalesOrderItem>(
                                                context: context,
                                                builder: (_) => AddSoRowDialog(
                                                  service: _service,
                                                  costCenters: _lookups?.costCenters ?? [],
                                                  initialItem: it,
                                                  nextSrNo: it.srNo,
                                                  onSave: (updated) {
                                                    setState(() {
                                                      _lineItems[index] = updated;
                                                    });
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFE11D48)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                            onPressed: () {
                                              setState(() {
                                                _lineItems.removeAt(index);
                                                // Re-index SrNo
                                                for (int i = 0; i < _lineItems.length; i++) {
                                                  _lineItems[i] = _lineItems[i].copyWith(srNo: i + 1);
                                                }
                                              });
                                            },
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
                ),
        ),
      ],
    );
  }

  // ==========================================================================
  // STEP 3: REVIEW, CHARGES & TERMS
  // ==========================================================================
  Widget _buildStep3ReviewAndCharges() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Totals Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildTotalRow('Items Gross Amount', '₹ ${_grossAmount.toStringAsFixed(2)}', isBold: false),
                const SizedBox(height: 6),
                _buildTotalRow('Total Line Discounts (−)', '₹ ${_totalItemDiscounts.toStringAsFixed(2)}', isBold: false, color: const Color(0xFFE11D48)),
                const SizedBox(height: 6),
                _buildTotalRow(
                  'Duties & Additional Charges (Net)',
                  '${_chargesNetEffect >= 0 ? '+' : ''} ₹ ${_chargesNetEffect.toStringAsFixed(2)}',
                  isBold: false,
                  color: _chargesNetEffect >= 0 ? const Color(0xFF059669) : const Color(0xFFE11D48),
                ),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildTotalRow(
                  'Final Order Net Amount',
                  '₹ ${_finalNetAmount.toStringAsFixed(2)}',
                  isBold: true,
                  color: const Color(0xFF059669),
                  fontSize: 16,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Auxiliary Action Buttons (Charges & Terms)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final res = await showDialog<List<SalesOrderCharge>>(
                      context: context,
                      builder: (_) => SoChargesModalDialog(
                        orderGrossAmount: _grossAmount - _totalItemDiscounts,
                        currentCharges: _charges,
                        defaultChargesMaster: _lookups?.defaultCharges ?? [],
                      ),
                    );
                    if (res != null) {
                      setState(() => _charges = res);
                    }
                  },
                  icon: const Icon(Icons.calculate_rounded, size: 18, color: Color(0xFF2563EB)),
                  label: Text('Duties & Additional Charges (${_charges.length})'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final res = await showDialog<List<SalesOrderCondition>>(
                      context: context,
                      builder: (_) => SoTermsModalDialog(initialConditions: _conditions),
                    );
                    if (res != null) {
                      setState(() => _conditions = res);
                    }
                  },
                  icon: const Icon(Icons.gavel_rounded, size: 18, color: Color(0xFF8B5CF6)),
                  label: Text('Terms & Conditions (${_conditions.length})'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Remarks Field & Autocomplete Chips
          const Text('Order Remarks / Special Notes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          TextField(
            controller: _remarkCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Enter general order remarks, internal remarks, or special instructions...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            ),
          ),
          if (_remarkSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _remarkSuggestions.take(6).map((rem) {
                return ActionChip(
                  label: Text(rem, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      if (_remarkCtrl.text.isEmpty) {
                        _remarkCtrl.text = rem;
                      } else {
                        _remarkCtrl.text += ' • $rem';
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false, Color? color, double fontSize = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: const Color(0xFF0F172A))),
        Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? const Color(0xFF0F172A))),
      ],
    );
  }

  // ==========================================================================
  // WIZARD FOOTER NAVIGATION
  // ==========================================================================
  Widget _buildWizardFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: _closeWizard,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel'),
          ),
          Row(
            children: [
              if (_currentStep > 1) ...[
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep--),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (_currentStep < 3)
                ElevatedButton.icon(
                  onPressed: () {
                    if (_currentStep == 1 && _pCode <= 0) {
                      setState(() => _wizardError = 'Please select a Customer before proceeding');
                      return;
                    }
                    if (_currentStep == 2 && _lineItems.isEmpty) {
                      setState(() => _wizardError = 'Please add at least one line item before proceeding');
                      return;
                    }
                    setState(() {
                      _wizardError = null;
                      _currentStep++;
                    });
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                  label: const Text('Next Step'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else
                SoAnimatedSuccessButton(
                  status: _saveButtonStatus,
                  onPressed: _saveSalesOrder,
                  idleText: _isEditing ? 'Update Sales Order' : 'Save Sales Order',
                  successText: 'Saved Successfully!',
                  idleIcon: Icons.save_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HELPER FORM FIELDS
  // ==========================================================================
  Widget _buildTextField(String label, TextEditingController ctrl, {bool readOnly = false, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 12.5, color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            filled: readOnly,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
              isExpanded: true,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLookupDropdown({
    required String label,
    required int value,
    required List<LookupCodeName> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: items.any((e) => e.code == value) ? value : (items.isNotEmpty ? items.first.code : null),
              isExpanded: true,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
              items: items.map((e) => DropdownMenuItem(value: e.code, child: Text(e.name))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
