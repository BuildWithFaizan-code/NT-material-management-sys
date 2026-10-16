import 'dart:async';
import 'package:flutter/material.dart';

import '../../design/app_colors.dart';
import 'sales_order_models.dart';
import 'sales_order_service.dart';
import 'widgets/add_so_row_dialog.dart';
import 'widgets/customer_lookup_dialog.dart';
import 'widgets/so_animated_success_button.dart';
import 'widgets/so_charges_modal_dialog.dart';
import 'widgets/so_export_modal_dialog.dart';
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
  int _selectedCostCenter = 0;
  final TextEditingController _searchCtrl = TextEditingController();
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
          final targetOffset = (idx * 44.0) - 80.0;
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

      await Future.delayed(const Duration(milliseconds: 600));

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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopToolbar(),
                const SizedBox(height: 16),
                _buildMetricsBanner(),
                const SizedBox(height: 16),
                Expanded(child: _buildMainTable()),
                const SizedBox(height: 12),
                _buildPaginationFooter(),
              ],
            ),
          ),
          if (_isWizardOpen) _buildWizardModalOverlay(),
        ],
      ),
    );
  }

  // ==========================================================================
  // TOP TOOLBAR & CONTROLS
  // ==========================================================================
  Widget _buildTopToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate Sales Order',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Text(
                'Transaction → Sales Order → Generate Sales Order',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          // Search box
          SizedBox(
            width: 240,
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search SO No, Customer...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Export button
          SoAnimatedExportButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => SoExportModalDialog(orders: _filteredOrders),
              );
            },
          ),
          const SizedBox(width: 12),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _loadInitialData,
            tooltip: 'Refresh Orders',
          ),
          const SizedBox(width: 12),
          // New Entry Button (Project Master style)
          ElevatedButton.icon(
            onPressed: _openNewEntryWizard,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Entry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // METRICS BANNER
  // ==========================================================================
  Widget _buildMetricsBanner() {
    double totalVal = 0.0;
    int totalItems = 0;
    double totalQty = 0.0;
    for (final o in _filteredOrders) {
      totalVal += o.netAmt;
      totalItems += o.totItm;
      totalQty += o.totQty;
    }

    return Row(
      children: [
        _buildMetricCard('Total Sales Orders', _totalCount.toString(), Icons.receipt_long_rounded, AppColors.primaryColor),
        const SizedBox(width: 14),
        _buildMetricCard('Total Items', totalItems.toString(), Icons.category_rounded, AppColors.secondaryColor),
        const SizedBox(width: 14),
        _buildMetricCard('Total Quantity', totalQty.toStringAsFixed(1), Icons.scale_rounded, const Color(0xFFE65100)),
        const SizedBox(width: 14),
        _buildMetricCard('Total Net Value', '₹ ${totalVal.toStringAsFixed(2)}', Icons.account_balance_wallet_rounded, const Color(0xFF2E7D32)),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // MAIN DASHBOARD TABLE (DEPARTMENT MASTER STYLE)
  // ==========================================================================
  Widget _buildMainTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 10),
            const Text('No sales orders found', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // Table Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.sidebarBackground.withOpacity(0.4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.5))),
            ),
            child: const Row(
              children: [
                SizedBox(width: 140, child: Text('SO No', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                SizedBox(width: 100, child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                Expanded(flex: 3, child: Text('Customer / Party Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                Expanded(flex: 2, child: Text('Division', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                SizedBox(width: 60, child: Text('Items', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                SizedBox(width: 80, child: Text('Total Qty', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                SizedBox(width: 110, child: Text('Net Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                SizedBox(width: 100, child: Center(child: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)))),
                SizedBox(width: 90, child: Center(child: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)))),
              ],
            ),
          ),
          // Table Body List
          Expanded(
            child: ListView.separated(
              controller: _tableScrollCtrl,
              itemCount: _filteredOrders.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider.withOpacity(0.3)),
              itemBuilder: (context, index) {
                final order = _filteredOrders[index];
                final isGlowing = _highlightedSoNo == order.soNo;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  color: isGlowing
                      ? (_isHighlightedEdit
                          ? const Color(0xFFFFF9C4)
                          : const Color(0xFFE8F5E9))
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          order.soNo,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          order.soDate.toIso8601String().split('T').first,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.partyName,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            if (order.gstin.isNotEmpty)
                              Text('GSTIN: ${order.gstin}', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary.withOpacity(0.8))),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          order.costCenterName.isNotEmpty ? order.costCenterName : '—',
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          order.totItm.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          order.totQty.toStringAsFixed(1),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                          '₹ ${order.netAmt.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: order.isRec
                                  ? AppColors.primaryColor.withOpacity(0.12)
                                  : (order.approved ? AppColors.success.withOpacity(0.12) : const Color(0xFFFFF3E0)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              order.isRec ? 'Delivered' : (order.approved ? 'Approved' : 'Pending'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: order.isRec
                                    ? AppColors.primaryColor
                                    : (order.approved ? AppColors.success : const Color(0xFFE65100)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.primaryColor),
                              onPressed: () => _openEditWizard(order),
                              tooltip: 'Edit Order',
                              splashRadius: 16,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.error),
                              onPressed: () => _confirmDelete(order),
                              tooltip: 'Delete Order',
                              splashRadius: 16,
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
    );
  }

  Widget _buildPaginationFooter() {
    final totalPages = (_totalCount / _pageSize).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Total Records: $_totalCount (Showing page $_currentPage of ${totalPages == 0 ? 1 : totalPages})',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
  // WIZARD OVERLAY MODAL (3-STEP WIZARD)
  // ==========================================================================
  Widget _buildWizardModalOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: 980,
          height: 680,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWizardHeader(),
              _buildWizardStepIndicator(),
              if (_wizardError != null) _buildWizardErrorBanner(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildCurrentStepContent(),
                ),
              ),
              _buildWizardFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWizardHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.sidebarBackground.withOpacity(0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isEditing ? Icons.edit_note_rounded : Icons.post_add_rounded,
              color: AppColors.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Edit Sales Order (${_soNoCtrl.text})' : 'Generate New Sales Order',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Text(
                'Complete metadata, add line items, configure duties and save to database',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.85)),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
            onPressed: _closeWizard,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildWizardStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          _buildStepItem(1, 'Header & Customer', 'Order info & customer', _currentStep == 1, _currentStep > 1),
          const Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
          _buildStepItem(2, 'Line Items Grid', 'Add catalog items (${_lineItems.length})', _currentStep == 2, _currentStep > 2),
          const Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
          _buildStepItem(3, 'Review & Charges', 'Totals & commercial terms', _currentStep == 3, false),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String title, String subtitle, bool isActive, bool isDone) {
    return InkWell(
      onTap: () => setState(() => _currentStep = step),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? AppColors.success
                    : (isActive ? AppColors.primaryColor : AppColors.surface),
                border: Border.all(
                  color: isDone
                      ? AppColors.success
                      : (isActive ? AppColors.primaryColor : AppColors.divider),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : Text(
                        step.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? AppColors.primaryColor : AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWizardErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: AppColors.error.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _wizardError!,
              style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
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
  // STEP 1: HEADER METADATA
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
                    const Text('SO Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_soDate.toIso8601String().split('T').first, style: const TextStyle(fontSize: 12.5)),
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
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
          // Customer / Debtor Lookup Card
          _buildCustomerSelectionCard(),
          const SizedBox(height: 16),
          // Row 3: Order Mode, Store Mode, Division
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Order Mode',
                  value: _soMode,
                  items: const ['Direct', 'Against Quo', 'Indent'],
                  onChanged: (val) => setState(() => _soMode = val ?? 'Direct'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildLookupDropdown(
                  label: 'Store Mode (CapCons)',
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
          // Row 4: Credit Days, Delivery Days, Sales Person, Supp Ref
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
                child: _buildTextField('Customer Order Ref (Supp Ref)', _suppRefCtrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSelectionCard() {
    final hasParty = _pCode > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: hasParty ? AppColors.primaryColor.withOpacity(0.3) : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_pin_rounded, color: AppColors.primaryColor, size: 18),
                  SizedBox(width: 8),
                  Text('Customer / Debtor *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                      _gstin = selected.gstin;
                      _stateCode = selected.stateCode;
                      _address = selected.address;
                      _wizardError = null;
                    });
                  }
                },
                icon: const Icon(Icons.search_rounded, size: 15),
                label: Text(hasParty ? 'Change Customer' : 'Select Customer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
          if (hasParty) ...[
            const SizedBox(height: 10),
            Text(
              _partyName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('GSTIN: ${_gstin.isNotEmpty ? _gstin : 'Unregistered'}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                const SizedBox(width: 16),
                Text('State Code: ${_stateCode.isNotEmpty ? _stateCode : 'N/A'}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
            if (_address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Address: $_address', style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.8))),
            ],
          ] else ...[
            const SizedBox(height: 8),
            const Text('No customer selected yet. Click "Select Customer" to search debtors from PARTYMST.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // STEP 2: LINE ITEMS GRID
  // ==========================================================================
  Widget _buildStep2LineItemsGrid() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('Line Items (${_lineItems.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(width: 14),
                Text('Total Qty: ${_totalQty.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(width: 14),
                Text('Gross Amount: ₹ ${_grossAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
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
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Line Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                      Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textSecondary.withOpacity(0.4)),
                      const SizedBox(height: 10),
                      const Text('No line items added yet. Click "Add Line Item" above.', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: ListView.separated(
                    itemCount: _lineItems.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider.withOpacity(0.3)),
                    itemBuilder: (context, index) {
                      final it = _lineItems[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Text(it.srNo.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.itemName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  Text('Code: ${it.iCode} • Division: ${it.divisionName.isNotEmpty ? it.divisionName : 'N/A'}', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary.withOpacity(0.8))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Text('${it.qty} ${it.unitName}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Text('₹ ${it.rate.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Text('₹ ${it.disc.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Text('₹ ${it.amount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primaryColor),
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
                              splashRadius: 16,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                              onPressed: () {
                                setState(() {
                                  _lineItems.removeAt(index);
                                  for (int i = 0; i < _lineItems.length; i++) {
                                    _lineItems[i] = _lineItems[i].copyWith(srNo: i + 1);
                                  }
                                });
                              },
                              splashRadius: 16,
                            ),
                          ],
                        ),
                      );
                    },
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                _buildTotalRow('Items Gross Amount', '₹ ${_grossAmount.toStringAsFixed(2)}', isBold: false),
                const SizedBox(height: 6),
                _buildTotalRow('Total Line Discounts (−)', '₹ ${_totalItemDiscounts.toStringAsFixed(2)}', isBold: false, color: AppColors.error),
                const SizedBox(height: 6),
                _buildTotalRow('Duties & Additional Charges (Net)', '${_chargesNetEffect >= 0 ? '+' : ''} ₹ ${_chargesNetEffect.toStringAsFixed(2)}', isBold: false, color: _chargesNetEffect >= 0 ? AppColors.success : AppColors.error),
                const Divider(height: 16, color: AppColors.divider),
                _buildTotalRow('Final Order Net Amount', '₹ ${_finalNetAmount.toStringAsFixed(2)}', isBold: true, color: AppColors.primaryColor, fontSize: 16),
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
                  icon: const Icon(Icons.calculate_rounded, size: 18),
                  label: Text('Duties & Additional Charges (${_charges.length})'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  icon: const Icon(Icons.gavel_rounded, size: 18),
                  label: Text('Terms & Conditions (${_conditions.length})'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Remarks Field & Autocomplete Chips
          const Text('Order Remarks / Special Notes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          TextField(
            controller: _remarkCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter general order remarks, internal remarks, or special instructions...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
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
        Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: AppColors.textPrimary)),
        Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? AppColors.textPrimary)),
      ],
    );
  }

  // ==========================================================================
  // WIZARD FOOTER NAVIGATION
  // ==========================================================================
  Widget _buildWizardFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
        border: Border(top: BorderSide(color: AppColors.divider.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: _closeWizard,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Next Step'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 12.5, color: readOnly ? AppColors.textSecondary : AppColors.textPrimary),
          decoration: InputDecoration(
            filled: readOnly,
            fillColor: readOnly ? AppColors.surface : AppColors.cardBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
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
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
              isExpanded: true,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
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
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: items.any((e) => e.code == value) ? value : (items.isNotEmpty ? items.first.code : null),
              isExpanded: true,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
              items: items.map((e) => DropdownMenuItem(value: e.code, child: Text(e.name))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
