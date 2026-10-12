import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/app_colors.dart';
import '../../design/app_dimensions.dart';
import 'purchase_order_models.dart';
import 'purchase_order_service.dart';
import 'widgets/add_po_row_dialog.dart';
import 'widgets/party_lookup_dialog.dart';
import 'widgets/po_animated_success_button.dart';
import 'widgets/po_charges_modal_dialog.dart';
import 'widgets/po_export_modal_dialog.dart';
import 'widgets/po_terms_modal_dialog.dart';

// ============================================================================
// MAIN PURCHASE ORDER GENERATION PAGE
// ============================================================================
class PurchaseOrderPage extends StatefulWidget {
  const PurchaseOrderPage({super.key});

  @override
  State<PurchaseOrderPage> createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
  final PurchaseOrderService _service = PurchaseOrderService();

  // Audit list state
  List<PurchaseOrderHeader> _orders = [];
  List<PurchaseOrderHeader> _filteredOrders = [];
  PurchaseOrderLookupsData _lookups = const PurchaseOrderLookupsData();
  bool _isLoading = true;
  String? _errorMessage;

  // Search & Filter
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int _selectedFilterStore = 0;

  // Glow Effect state (Project Master style)
  String? _highlightedPoNo;
  bool _isHighlightedEdit = false;
  Timer? _highlightTimer;

  // Table Scroll Controller
  final ScrollController _tableScrollCtrl = ScrollController();

  // ==========================================================================
  // WIZARD MODAL STATE (3-STEP MODAL)
  // ==========================================================================
  bool _isWizardOpen = false;
  int _currentStep = 1; // 1, 2, 3
  bool _isEditing = false;
  ButtonStatus _saveButtonStatus = ButtonStatus.idle;
  String? _wizardError;

  // Step 1: Header Metadata
  final TextEditingController _poNoCtrl = TextEditingController();
  DateTime _poDate = DateTime.now();
  int _pCode = 0;
  final TextEditingController _partyNameCtrl = TextEditingController();
  String _gstin = '';
  String _stateCode = '';
  String _address = '';
  int _poCrDays = 0;
  int _pomDelDays = 7;
  int _pomBrCode = 1;
  final TextEditingController _poCrDaysCtrl = TextEditingController(text: '0');
  final TextEditingController _pomDelDaysCtrl = TextEditingController(text: '7');
  String _agent = '';
  int _poDelCd = 0;
  String _delPartyName = '';
  int _selectedStore = 0;
  String _selectedStoreName = '';
  String _selectedOrderMode = 'Direct';
  String _selectedCurrency = 'INR';
  int _selectedCapMode = 0;
  final TextEditingController _suppRefCtrl = TextEditingController();
  bool _isImp = false;

  // Step 2: Line Items
  List<PurchaseOrderItem> _lineItems = [];

  // Step 3: Auxiliary Modals Data & Calculations
  List<PurchaseOrderCharge> _charges = [];
  List<PurchaseOrderCondition> _conditions = [];
  String _dTerms = '';
  String _pTerms = '';
  String _dispIns = '';
  String _spNote = '';
  String _headerRemark = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _tableScrollCtrl.dispose();

    _poNoCtrl.dispose();
    _partyNameCtrl.dispose();
    _suppRefCtrl.dispose();
    _poCrDaysCtrl.dispose();
    _pomDelDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final lookupsFuture = _service.fetchLookups();
      final ordersFuture = _service.fetchPurchaseOrders(page: 1, pageSize: 100);

      final lookups = await lookupsFuture;
      final ordersPaged = await ordersFuture;

      if (mounted) {
        setState(() {
          _lookups = lookups;
          _orders = ordersPaged.items;
          _filteredOrders = ordersPaged.items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredOrders = _orders.where((o) {
        final matchesQuery = query.isEmpty ||
            o.poNo.toLowerCase().contains(query) ||
            o.partyName.toLowerCase().contains(query) ||
            o.storeName.toLowerCase().contains(query) ||
            o.gstin.toLowerCase().contains(query);

        final matchesStore = _selectedFilterStore == 0 || o.pStrCode == _selectedFilterStore;
        return matchesQuery && matchesStore;
      }).toList();
    });
  }

  void _triggerGlow(String poNo, bool isEdit) {
    _highlightTimer?.cancel();
    setState(() {
      _highlightedPoNo = poNo;
      _isHighlightedEdit = isEdit;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tableScrollCtrl.hasClients) {
        final idx = _filteredOrders.indexWhere((o) => o.poNo == poNo);
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
        setState(() => _highlightedPoNo = null);
      }
    });
  }

  // ==========================================================================
  // WIZARD WORKFLOW METHODS
  // ==========================================================================
  void _openNewEntryModal() {
    _resetWizardForm();
    setState(() {
      _isEditing = false;
      _saveButtonStatus = ButtonStatus.idle;
      _wizardError = null;
      _poNoCtrl.text = _lookups.nextPoNo.isNotEmpty ? _lookups.nextPoNo : 'PRCH/000001/27';
      _poDate = DateTime.now();
      _isWizardOpen = true;
      _currentStep = 1;
    });
  }

  Future<void> _openEditModal(String poNo) async {
    setState(() => _isLoading = true);
    try {
      final po = await _service.fetchPurchaseOrderByNo(poNo);
      if (po == null) {
        setState(() {
          _errorMessage = 'Purchase order $poNo not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _isEditing = true;
        _saveButtonStatus = ButtonStatus.idle;
        _wizardError = null;
        _poNoCtrl.text = po.poNo;
        _poDate = po.poDate;
        _pCode = po.pCode;
        _partyNameCtrl.text = po.partyName;
        _gstin = po.gstin;
        _stateCode = po.stateCode;
        _address = po.address;
        _poCrDays = po.poCrDays;
        _poCrDaysCtrl.text = po.poCrDays.toString();
        _pomDelDays = po.pomDelDays;
        _pomDelDaysCtrl.text = po.pomDelDays.toString();
        _agent = po.brokerName;
        _pomBrCode = po.pomBrCode > 0 ? po.pomBrCode : 1;
        _poDelCd = po.poDelCd;
        _delPartyName = po.delPartyName;
        _selectedStore = po.pStrCode;
        _selectedStoreName = po.storeName;
        _selectedOrderMode = po.poMode;
        _selectedCurrency = po.curr.isNotEmpty ? po.curr : 'INR';
        _selectedCapMode = po.pomCapMode;
        _suppRefCtrl.text = po.suppRef;
        _isImp = po.isImp;

        _lineItems = List.from(po.items);
        _charges = List.from(po.charges);
        _conditions = List.from(po.conditions);
        _dTerms = po.dTerms;
        _pTerms = po.pTerms;
        _dispIns = po.dispIns;
        _spNote = po.spNote;
        _headerRemark = po.remark;

        _isWizardOpen = true;
        _currentStep = 1;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load PO details: $e';
      });
    }
  }

  void _resetWizardForm() {
    _poNoCtrl.clear();
    _poDate = DateTime.now();
    _pCode = 0;
    _partyNameCtrl.clear();
    _gstin = '';
    _stateCode = '';
    _address = '';
    _poCrDays = 0;
    _poCrDaysCtrl.text = '0';
    _pomDelDays = 7;
    _pomDelDaysCtrl.text = '7';
    _agent = '';
    _pomBrCode = 1;
    _poDelCd = 0;
    _delPartyName = '';
    _selectedStore = _lookups.stores.isNotEmpty ? _lookups.stores.first.strCode : 0;
    _selectedStoreName = _lookups.stores.isNotEmpty ? _lookups.stores.first.strName : '';
    _selectedOrderMode = 'Direct';
    _selectedCurrency = _lookups.currencies.isNotEmpty ? _lookups.currencies.first : 'INR';
    _selectedCapMode = _lookups.capModes.isNotEmpty ? _lookups.capModes.first.locCode : 0;
    _suppRefCtrl.clear();
    _isImp = false;

    _lineItems = [];
    _charges = [];
    _conditions = [];
    _dTerms = '';
    _pTerms = '';
    _dispIns = '';
    _spNote = '';
    _headerRemark = '';
    _wizardError = null;
    _saveButtonStatus = ButtonStatus.idle;
  }

  void _closeWizardModal() {
    setState(() {
      _isWizardOpen = false;
      _saveButtonStatus = ButtonStatus.idle;
      _wizardError = null;
    });
  }

  Future<void> _openPartyLookup() async {
    final selected = await showDialog<SupplierLookupItem>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PartyLookupDialog(service: _service),
    );

    if (selected != null && mounted) {
      setState(() {
        _pCode = selected.pCode;
        _partyNameCtrl.text = selected.pName;
        _gstin = selected.gstin;
        _stateCode = selected.stateCode;
        _address = selected.address;
        _poCrDays = selected.creditDays;
        _poCrDaysCtrl.text = selected.creditDays.toString();
        _pomDelDays = 7;
        _pomDelDaysCtrl.text = '7';
        _agent = selected.agent;
        _pomBrCode = selected.brkCode > 0 ? selected.brkCode : 1;
        _poDelCd = selected.pCode;
        _delPartyName = selected.pName;
        _wizardError = null;
      });
    }
  }

  Future<void> _addNewLineRow() async {
    final nextSrNo = _lineItems.length + 1;
    final row = await showDialog<PurchaseOrderItem>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AddPoRowDialog(
        srNo: nextSrNo,
        supplierStateCode: _stateCode,
        companyStateCode: _lookups.companyStateCode,
        departments: _lookups.departments,
        divisions: _lookups.divisions,
        service: _service,
      ),
    );

    if (row != null && mounted) {
      setState(() {
        _lineItems.add(row);
        _wizardError = null;
      });
    }
  }

  Future<void> _editLineRow(int index) async {
    final existing = _lineItems[index];
    final row = await showDialog<PurchaseOrderItem>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AddPoRowDialog(
        srNo: existing.srNo,
        supplierStateCode: _stateCode,
        companyStateCode: _lookups.companyStateCode,
        departments: _lookups.departments,
        divisions: _lookups.divisions,
        service: _service,
        existingItem: existing,
      ),
    );

    if (row != null && mounted) {
      setState(() {
        _lineItems[index] = row;
        _wizardError = null;
      });
    }
  }

  void _removeLineRow(int index) {
    setState(() {
      _lineItems.removeAt(index);
      for (int i = 0; i < _lineItems.length; i++) {
        final cur = _lineItems[i];
        _lineItems[i] = PurchaseOrderItem(
          pId: cur.pId,
          poNo: cur.poNo,
          srNo: i + 1,
          iCode: cur.iCode,
          itemName: cur.itemName,
          hsn: cur.hsn,
          uom: cur.uom,
          unitName: cur.unitName,
          qty: cur.qty,
          accQty: cur.accQty,
          rate: cur.rate,
          disc: cur.disc,
          amount: cur.amount,
          khCode: cur.khCode,
          divisionName: cur.divisionName,
          depCode: cur.depCode,
          deptName: cur.deptName,
          mrgNo: cur.mrgNo,
          shade: cur.shade,
          specification: cur.specification,
          pRemark: cur.pRemark,
          freight: cur.freight,
          podIsFreight: cur.podIsFreight,
          cgPer: cur.cgPer,
          cgAmt: cur.cgAmt,
          sgPer: cur.sgPer,
          sgAmt: cur.sgAmt,
          igPer: cur.igPer,
          igAmt: cur.igAmt,
          netAmt: cur.netAmt,
          podStock: cur.podStock,
          podLastRate: cur.podLastRate,
          podMakeId: cur.podMakeId,
          makerName: cur.makerName,
          podConvUom: cur.podConvUom,
          convUnitName: cur.convUnitName,
          podConvQty: cur.podConvQty,
          closePO: cur.closePO,
        );
      }
    });
  }

  Future<void> _openChargesModal() async {
    final updated = await showDialog<List<PurchaseOrderCharge>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PoChargesModalDialog(
        orderGrossAmount: _totalItemsAmount,
        currentCharges: _charges,
        defaultChargesMaster: _lookups.defaultCharges,
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _charges = updated;
      });
    }
  }

  Future<void> _openTermsModal() async {
    final result = await showDialog<PoTermsResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PoTermsModalDialog(
        initialDTerms: _dTerms,
        initialPTerms: _pTerms,
        initialDispIns: _dispIns,
        initialSpNote: _spNote,
        initialRemark: _headerRemark,
        initialConditions: _conditions,
        lookups: _lookups,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _dTerms = result.dTerms;
        _pTerms = result.pTerms;
        _dispIns = result.dispIns;
        _spNote = result.spNote;
        _headerRemark = result.remark;
        _conditions = result.conditions;
      });
    }
  }

  // ==========================================================================
  // REAL-TIME FINANCIAL CALCULATIONS
  // ==========================================================================
  double get _totalItemsQty => _lineItems.fold(0.0, (s, i) => s + i.qty);
  double get _totalItemsGross => _lineItems.fold(0.0, (s, i) => s + (i.qty * i.rate));
  double get _totalItemsDisc => _lineItems.fold(0.0, (s, i) => s + ((i.qty * i.rate) * (i.disc / 100.0)));
  double get _totalItemsAmount => _lineItems.fold(0.0, (s, i) => s + i.amount);
  double get _totalItemsFreight => _lineItems.fold(0.0, (s, i) => s + i.freight);
  double get _totalCgAmt => _lineItems.fold(0.0, (s, i) => s + i.cgAmt);
  double get _totalSgAmt => _lineItems.fold(0.0, (s, i) => s + i.sgAmt);
  double get _totalIgAmt => _lineItems.fold(0.0, (s, i) => s + i.igAmt);

  double get _totalChargesNetImpact {
    return _charges.fold(0.0, (s, c) => s + (c.amt * (c.addLess != 0 ? c.addLess : 1)));
  }

  double get _calculatedNetTotal {
    final linesNet = _lineItems.fold(0.0, (s, i) => s + i.netAmt);
    return (linesNet + _totalChargesNetImpact).clamp(0.0, double.infinity);
  }

  String _convertNumberToWords(double amount) {
    if (amount <= 0) return 'Rupees Zero Only';
    final int whole = amount.floor();
    final int paise = ((amount - whole) * 100).round();

    final words = _numToWordsIndian(whole);
    if (paise > 0) {
      return 'Rupees $words and $paise/100 Paise Only';
    }
    return 'Rupees $words Only';
  }

  String _numToWordsIndian(int n) {
    if (n == 0) return 'Zero';
    final ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String helper(int num) {
      if (num < 20) return ones[num];
      if (num < 100) return '${tens[num ~/ 10]} ${ones[num % 10]}'.trim();
      if (num < 1000) return '${ones[num ~/ 100]} Hundred ${helper(num % 100)}'.trim();
      if (num < 100000) return '${helper(num ~/ 1000)} Thousand ${helper(num % 1000)}'.trim();
      if (num < 10000000) return '${helper(num ~/ 100000)} Lakh ${helper(num % 100000)}'.trim();
      return '${helper(num ~/ 10000000)} Crore ${helper(num % 10000000)}'.trim();
    }

    return helper(n);
  }

  // ==========================================================================
  // SAVE & VALIDATE
  // ==========================================================================
  Future<void> _savePurchaseOrder() async {
    if (_pCode == 0 || _partyNameCtrl.text.trim().isEmpty) {
      setState(() {
        _wizardError = 'Please select a supplier party in Step 1';
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

    setState(() {
      _wizardError = null;
      _saveButtonStatus = ButtonStatus.loading;
    });

    try {
      final isLocked = await _service.checkDateLock(_poDate);
      if (isLocked) {
        setState(() {
          _saveButtonStatus = ButtonStatus.error;
          _wizardError = 'Selected date is locked by management in LOCKDATAMST';
        });
        return;
      }

      final crDays = int.tryParse(_poCrDaysCtrl.text.trim()) ?? _poCrDays;
      final delDays = int.tryParse(_pomDelDaysCtrl.text.trim()) ?? _pomDelDays;

      final payload = {
        'poNo': _isEditing ? _poNoCtrl.text.trim() : '',
        'poDate': _poDate.toIso8601String(),
        'pCode': _pCode,
        'poDelCd': _poDelCd > 0 ? _poDelCd : _pCode,
        'pStrCode': _selectedStore > 0 ? _selectedStore : 1,
        'deptCode': _lineItems.isNotEmpty ? _lineItems.first.depCode : 1,
        'poMode': _selectedOrderMode,
        'totItm': _lineItems.length,
        'totQty': _totalItemsQty,
        'totDisc': _totalItemsDisc,
        'totAmt': _totalItemsAmount,
        'pfChg': (_calculatedNetTotal - _totalItemsAmount).clamp(0.0, double.infinity),
        'freight': _totalItemsFreight,
        'netAmt': _calculatedNetTotal,
        'dTerms': _dTerms,
        'pTerms': _pTerms,
        'dispIns': _dispIns,
        'spNote': _spNote,
        'remark': _headerRemark,
        'isImp': _isImp,
        'curr': _selectedCurrency,
        'words': _convertNumberToWords(_calculatedNetTotal),
        'suppRef': _suppRefCtrl.text.trim(),
        'poCrDays': crDays,
        'pomDelDays': delDays,
        'pomCapMode': _selectedCapMode,
        'cgPer': _lineItems.isNotEmpty ? _lineItems.first.cgPer : 0.0,
        'cgAmt': _totalCgAmt,
        'sgPer': _lineItems.isNotEmpty ? _lineItems.first.sgPer : 0.0,
        'sgAmt': _totalSgAmt,
        'igPer': _lineItems.isNotEmpty ? _lineItems.first.igPer : 0.0,
        'igAmt': _totalIgAmt,
        'pomBrCode': _pomBrCode > 0 ? _pomBrCode : 1,
        'pomIsFreight': _totalItemsFreight > 0 ? 1 : 0,
        'items': _lineItems.map((i) => i.toSaveJson()).toList(),
        'charges': _charges.map((c) => c.toSaveJson()).toList(),
        'conditions': _conditions.map((c) => c.toSaveJson()).toList(),
      };

      final savedPoNo = await _service.savePurchaseOrder(payload);

      setState(() => _saveButtonStatus = ButtonStatus.success);

      Future.delayed(const Duration(milliseconds: 600), () async {
        if (!mounted) return;
        _closeWizardModal();
        await _loadInitialData();
        _triggerGlow(savedPoNo, _isEditing);
      });

      Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _saveButtonStatus == ButtonStatus.success) {
          setState(() => _saveButtonStatus = ButtonStatus.idle);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveButtonStatus = ButtonStatus.error;
          _wizardError = e.toString();
        });
        Timer(const Duration(seconds: 3), () {
          if (mounted && _saveButtonStatus == ButtonStatus.error) {
            setState(() => _saveButtonStatus = ButtonStatus.idle);
          }
        });
      }
    }
  }

  Future<void> _deletePurchaseOrder(String poNo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase Order'),
        content: Text('Are you sure you want to permanently delete purchase order $poNo? This will reverse audit records and stock commitments.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete PO', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _service.deletePurchaseOrder(poNo);
        await _loadInitialData();
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to delete PO: $e';
        });
      }
    }
  }

  void _openComprehensiveExport() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PoExportModalDialog(orders: _filteredOrders),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f1 && _isWizardOpen) {
            _savePurchaseOrder();
          } else if (event.logicalKey == LogicalKeyboardKey.escape && _isWizardOpen) {
            _closeWizardModal();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderAndKpiCards(),
                  const SizedBox(height: 12),
                  _buildSearchAndActionsBar(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildMasterDataTable()),
                ],
              ),
            ),
            if (_isWizardOpen) _buildWizardModal(),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // MASTER AUDIT SCREEN BUILDERS (DEPARTMENT MASTER HIGH-DENSITY TABLE)
  // ==========================================================================
  Widget _buildHeaderAndKpiCards() {
    final totalCount = _orders.length;
    final totalNetVal = _orders.fold(0.0, (s, o) => s + o.netAmt);
    final directCount = _orders.where((o) => o.poMode.toLowerCase() == 'direct').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tableBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryColor, size: 26),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchase Order Generation',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.surfaceDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage active purchase orders, vendor contracts, line items & statutory GST charges',
                    style: TextStyle(fontSize: 11, color: AppColors.slateMuted),
                  ),
                ],
              ),
            ],
          ),

          Row(
            children: [
              _buildKpiCard(
                label: 'TOTAL POS',
                value: '$totalCount',
                icon: Icons.list_alt_rounded,
                color: AppColors.brandBlue,
              ),
              const SizedBox(width: 10),
              _buildKpiCard(
                label: 'TOTAL VALUE',
                value: '₹ ${(totalNetVal / 100000).toStringAsFixed(2)} L',
                icon: Icons.currency_rupee_rounded,
                color: AppColors.glowGold,
              ),
              const SizedBox(width: 10),
              _buildKpiCard(
                label: 'DIRECT POS',
                value: '$directCount',
                icon: Icons.flash_on_rounded,
                color: AppColors.glowPink,
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
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 1),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.surfaceDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndActionsBar() {
    return Row(
      children: [
        // Search Input
        SizedBox(
          width: 280,
          height: 38,
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
            decoration: InputDecoration(
              hintText: 'Search PO No, Party, Store...',
              hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.primaryColor),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear_rounded, size: 14), onPressed: () => _searchCtrl.clear())
                  : null,
              filled: true,
              fillColor: AppColors.surfaceColor,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.tableBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.tableBorder)),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Store Filter Dropdown
        if (_lookups.stores.isNotEmpty)
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.tableBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedFilterStore,
                items: [
                  const DropdownMenuItem<int>(value: 0, child: Text('All Stores', style: TextStyle(fontSize: 11.5))),
                  ..._lookups.stores.map((s) => DropdownMenuItem<int>(value: s.strCode, child: Text(s.strName, style: const TextStyle(fontSize: 11.5)))),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedFilterStore = val ?? 0;
                    _onSearchChanged();
                  });
                },
              ),
            ),
          ),

        const Spacer(),

        // Animated Export Button (Circulating Light Edge Orbit)
        PoAnimatedExportButton(onPressed: _openComprehensiveExport),

        const SizedBox(width: 10),

        // "+ New Entry" Button
        ElevatedButton.icon(
          onPressed: _openNewEntryModal,
          icon: const Icon(Icons.add_rounded, size: 17, color: Colors.white),
          label: const Text('New Entry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            elevation: 2,
            shadowColor: AppColors.secondaryColor.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ],
    );
  }

  Widget _buildMasterDataTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 38, color: AppColors.error),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.errorDark)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadInitialData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final list = _filteredOrders;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tableBorder),
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
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded, size: 18, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Purchase Orders Directory Sheet',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppColors.surfaceDark),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${list.length} Records Found',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.secondaryColor),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Table Header + Rows
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 36, color: AppColors.slateMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 6),
                        const Text('No purchase order records match current criteria', style: TextStyle(fontSize: 12, color: AppColors.slateMuted)),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth = math.max(constraints.maxWidth, 1100.0);

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
                                  color: AppColors.tableHeaderBg,
                                  border: Border(bottom: BorderSide(color: AppColors.tableBorder)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: const Row(
                                  children: [
                                    SizedBox(width: 140, child: Text('PO NUMBER', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.w800, fontSize: 10.5))),
                                    SizedBox(width: 90, child: Text('DATE', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.w800, fontSize: 10.5))),
                                    Expanded(flex: 3, child: Text('SUPPLIER NAME', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.w800, fontSize: 10.5))),
                                    SizedBox(width: 120, child: Text('GSTIN', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.w800, fontSize: 10.5))),
                                    SizedBox(width: 90, child: Text('STORE', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.w800, fontSize: 10.5))),
                                    SizedBox(width: 80, child: Text('MODE', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.w800, fontSize: 10.5))),
                                    SizedBox(width: 70, child: Text('QTY', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.w800, fontSize: 10.5))),
                                    SizedBox(width: 110, child: Text('NET AMOUNT', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.w800, fontSize: 10.5))),
                                    SizedBox(width: 80, child: Text('STATUS', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.w800, fontSize: 10.5))),
                                    SizedBox(width: 90, child: Center(child: Text('ACTIONS', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.w800, fontSize: 10.5)))),
                                  ],
                                ),
                              ),

                              // Data Rows List
                              Expanded(
                                child: ListView.separated(
                                  controller: _tableScrollCtrl,
                                  itemCount: list.length,
                                  separatorBuilder: (ctx, idx) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                                  itemBuilder: (ctx, idx) {
                                    final o = list[idx];
                                    final isGlowing = _highlightedPoNo == o.poNo;

                                    return _buildOrderRow(o, isGlowing);
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
        ],
      ),
    );
  }

  Widget _buildOrderRow(PurchaseOrderHeader o, bool isGlowing) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isGlowing
            ? (_isHighlightedEdit
                ? AppColors.glowGold.withValues(alpha: 0.15)
                : AppColors.success.withValues(alpha: 0.15))
            : Colors.transparent,
        border: isGlowing
            ? Border.all(
                color: _isHighlightedEdit ? AppColors.glowGold : AppColors.success,
                width: 1.5,
              )
            : null,
      ),
      child: Row(
        children: [
          // PO Number
          SizedBox(
            width: 140,
            child: Text(
              o.poNo,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
            ),
          ),

          // Date
          SizedBox(
            width: 90,
            child: Text(
              o.poDate.toIso8601String().split('T')[0],
              style: const TextStyle(fontSize: 11, color: AppColors.neutralDark),
            ),
          ),

          // Supplier Name
          Expanded(
            flex: 3,
            child: Text(
              o.partyName,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.surfaceDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // GSTIN
          SizedBox(
            width: 120,
            child: Text(
              o.gstin.isNotEmpty ? o.gstin : '-',
              style: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
            ),
          ),

          // Store
          SizedBox(
            width: 90,
            child: Text(
              o.storeName,
              style: const TextStyle(fontSize: 11, color: AppColors.neutralDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Order Mode
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.tableHeaderBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                o.poMode,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.neutralDark),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Total Qty
          SizedBox(
            width: 70,
            child: Text(
              o.totQty.toStringAsFixed(1),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
            ),
          ),

          // Net Amount
          SizedBox(
            width: 110,
            child: Text(
              '₹ ${o.netAmt.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primaryColor),
            ),
          ),

          // Status Badge
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: o.approved ? AppColors.successLight : AppColors.warningLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                o.approved ? 'Approved' : 'Open',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: o.approved ? AppColors.successDark : AppColors.warningDark,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primaryColor),
                  tooltip: 'Edit PO',
                  onPressed: () => _openEditModal(o.poNo),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                  tooltip: 'Delete PO',
                  onPressed: () => _deletePurchaseOrder(o.poNo),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 3-STEP WIZARD MODAL IMPLEMENTATION
  // ==========================================================================
  Widget _buildWizardModal() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: Container(
        width: 1120,
        height: 720,
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _buildWizardStepHeader(),
              if (_wizardError != null) _buildWizardErrorBanner(),
              Expanded(
                child: _currentStep == 1
                    ? _buildWizardStep1HeaderMetadata()
                    : (_currentStep == 2
                        ? _buildWizardStep2LineItemsGrid()
                        : _buildWizardStep3ReviewAndTerms()),
              ),
              _buildWizardFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWizardStepHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.tableHeaderBg,
        border: Border(bottom: BorderSide(color: AppColors.tableBorder)),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.post_add_rounded, color: AppColors.primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                _isEditing ? 'Edit Purchase Order (${_poNoCtrl.text})' : 'Create Purchase Order (New Entry)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.surfaceDark),
              ),
            ],
          ),

          const Spacer(),

          // Progress Steps (1, 2, 3)
          Row(
            children: [
              _buildStepIndicator(
                stepIndex: 1,
                title: 'Header & Supplier',
                isActive: _currentStep == 1,
                isCompleted: _currentStep > 1,
              ),
              Container(width: 32, height: 2, color: _currentStep > 1 ? AppColors.secondaryColor : AppColors.divider),
              _buildStepIndicator(
                stepIndex: 2,
                title: 'Line Items Grid',
                isActive: _currentStep == 2,
                isCompleted: _currentStep > 2,
              ),
              Container(width: 32, height: 2, color: _currentStep > 2 ? AppColors.secondaryColor : AppColors.divider),
              _buildStepIndicator(
                stepIndex: 3,
                title: 'Review & Terms',
                isActive: _currentStep == 3,
                isCompleted: false,
              ),
            ],
          ),

          const SizedBox(width: 24),

          IconButton(
            onPressed: _closeWizardModal,
            icon: const Icon(Icons.close_rounded, color: AppColors.neutralDark, size: 18),
            tooltip: 'Cancel & Close (Esc)',
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator({
    required int stepIndex,
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    final Color badgeColor = isCompleted
        ? AppColors.secondaryColor
        : (isActive ? AppColors.primaryColor : AppColors.slateMuted);

    return InkWell(
      onTap: () {
        setState(() => _currentStep = stepIndex);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
              child: isCompleted
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : Text('$stepIndex', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                color: isActive ? AppColors.primaryColor : AppColors.slateMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWizardErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: AppColors.errorLight,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(_wizardError!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.errorDark))),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
            onPressed: () => setState(() => _wizardError = null),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STEP 1: HEADER & SUPPLIER METADATA
  // ==========================================================================
  Widget _buildWizardStep1HeaderMetadata() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID & Date Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Purchase Order No. *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _poNoCtrl,
                        readOnly: true,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primaryColor),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.tableRowHover,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('P.O. Date *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _poDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _poDate = picked);
                        }
                      },
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.tableBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.primaryColor),
                            const SizedBox(width: 8),
                            Text(_poDate.toIso8601String().split('T')[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Mode *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      isDense: true,
                      initialValue: _selectedOrderMode,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Direct', child: Text('Direct (Immediate)', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Indent', child: Text('Indent Based', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Quotation', child: Text('Quotation Based', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                      onChanged: (val) => setState(() => _selectedOrderMode = val ?? 'Direct'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Store *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      isDense: true,
                      initialValue: _lookups.stores.any((s) => s.strCode == _selectedStore)
                          ? _selectedStore
                          : (_lookups.stores.isNotEmpty ? _lookups.stores.first.strCode : null),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                      ),
                      items: _lookups.stores.map((s) {
                        return DropdownMenuItem<int>(
                          value: s.strCode,
                          child: Text(s.strName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final match = _lookups.stores.firstWhere((s) => s.strCode == val);
                          setState(() {
                            _selectedStore = val;
                            _selectedStoreName = match.strName;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Supplier Lookup Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.tableRowHover,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.tableBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 18, color: AppColors.primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'SUPPLIER / PARTY DETAILS (PARTYMST)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _openPartyLookup,
                      icon: const Icon(Icons.search_rounded, size: 15),
                      label: const Text('Open Supplier Lookup (Enter)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Supplier Name *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _partyNameCtrl,
                              readOnly: true,
                              onTap: _openPartyLookup,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
                              decoration: InputDecoration(
                                hintText: 'Press Enter or click here to search supplier...',
                                hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                                prefixIcon: const Icon(Icons.person_search_rounded, size: 16, color: AppColors.primaryColor),
                                filled: true,
                                fillColor: AppColors.surfaceColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GSTIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          Container(
                            height: 38,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.tableBorder),
                            ),
                            child: Text(_gstin.isNotEmpty ? _gstin : '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('State Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          Container(
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.tableBorder),
                            ),
                            child: Text(_stateCode.isNotEmpty ? _stateCode : '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Address', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          Container(
                            height: 38,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.tableBorder),
                            ),
                            child: Text(_address.isNotEmpty ? _address : '-', style: const TextStyle(fontSize: 11.5, color: AppColors.slateMuted), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cr. Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _poCrDaysCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.surfaceColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Del. Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _pomDelDaysCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.surfaceColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Broker / Agent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          Container(
                            height: 38,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.tableBorder),
                            ),
                            child: Text(_agent.isNotEmpty ? _agent : 'DIRECT', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_delPartyName.isNotEmpty || _selectedStoreName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 14, color: AppColors.secondaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Delivery Consignee: ${_delPartyName.isNotEmpty ? _delPartyName : _partyNameCtrl.text}  •  Destination Store: ${_selectedStoreName.isNotEmpty ? _selectedStoreName : "Main Plant"}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Auxiliary Metadata Row (Currency, Reference, Import Toggle)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Currency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<String>(
                      key: ValueKey('curr_$_selectedCurrency'),
                      isExpanded: true,
                      isDense: true,
                      initialValue: _selectedCurrency,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                      ),
                      items: [
                        if (!_lookups.currencies.contains(_selectedCurrency))
                          DropdownMenuItem(value: _selectedCurrency, child: Text(_selectedCurrency, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1)),
                        ..._lookups.currencies.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1))),
                      ],
                      onChanged: (val) => setState(() => _selectedCurrency = val ?? 'INR'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Location Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<int>(
                      key: ValueKey('cap_$_selectedCapMode'),
                      isExpanded: true,
                      isDense: true,
                      initialValue: _lookups.capModes.any((c) => c.locCode == _selectedCapMode)
                          ? _selectedCapMode
                          : 0,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                      ),
                      items: [
                        if (!_lookups.capModes.any((c) => c.locCode == 0))
                          const DropdownMenuItem(value: 0, child: Text('Standard / Default', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1)),
                        ..._lookups.capModes.map((m) => DropdownMenuItem(value: m.locCode, child: Text(m.location, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1))),
                      ],
                      onChanged: (val) => setState(() => _selectedCapMode = val ?? 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Supplier Reference / Quotation No.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _suppRefCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'e.g. QUOT-2026-8841',
                          hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                          filled: true,
                          fillColor: AppColors.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                margin: const EdgeInsets.only(top: 18),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.tableBorder),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isImp,
                      onChanged: (val) => setState(() => _isImp = val == true),
                    ),
                    const Text('Import Purchase Order', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STEP 2: LINE-ITEM CATALOG GRID (ALL 24 COLUMNS)
  // ==========================================================================
  Widget _buildWizardStep2LineItemsGrid() {
    return Column(
      children: [
        // Grid Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.tableRowHover,
            border: Border(bottom: BorderSide(color: AppColors.tableBorder)),
          ),
          child: Row(
            children: [
              const Icon(Icons.format_list_bulleted_rounded, size: 18, color: AppColors.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Line Items Catalog Grid (24 Exact Columns)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.neutralDark),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addNewLineRow,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Row', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // Line-item 24-Column Data Table
        Expanded(
          child: _lineItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.playlist_add_rounded, size: 42, color: AppColors.slateMuted),
                      const SizedBox(height: 8),
                      const Text('No line items added yet.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                      const SizedBox(height: 4),
                      const Text('Click "+ Add Row" above to select catalog items and quantities.', style: TextStyle(fontSize: 11.5, color: AppColors.slateMuted)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _addNewLineRow,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
                        child: const Text('Add First Line Item', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 2400, // accommodate all 24 columns nicely
                    child: Column(
                      children: [
                        // Column Headers
                        Container(
                          height: 36,
                          color: AppColors.tableHeaderBg,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: const Row(
                            children: [
                              SizedBox(width: 45, child: Text('SR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 120, child: Text('ITEM CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 200, child: Text('DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 110, child: Text('MERGE / STYLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 90, child: Text('SHADE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 140, child: Text('REMARK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 110, child: Text('DEPARTMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 110, child: Text('COST CENTER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 65, child: Text('UQC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 75, child: Text('PEND QTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 75, child: Text('GRN QTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 80, child: Text('QTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 80, child: Text('CONV UNIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 80, child: Text('CONV QTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 80, child: Text('RATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 65, child: Text('DISC %', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 95, child: Text('AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 75, child: Text('FREIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 60, child: Text('CG %', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 75, child: Text('CG AMT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 60, child: Text('SG %', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 75, child: Text('SG AMT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 60, child: Text('IG %', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 75, child: Text('IG AMT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 105, child: Text('NET AMT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                              SizedBox(width: 80, child: Center(child: Text('ACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
                            ],
                          ),
                        ),

                        // Line Rows
                        Expanded(
                          child: ListView.separated(
                            itemCount: _lineItems.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                            itemBuilder: (ctx, i) {
                              final item = _lineItems[i];
                              return Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    SizedBox(width: 45, child: Text('${item.srNo}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    SizedBox(width: 120, child: Text(item.iCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryColor))),
                                    SizedBox(width: 200, child: Text(item.itemName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                    SizedBox(width: 110, child: Text(item.mrgNo, style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 90, child: Text(item.shade, style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 140, child: Text(item.pRemark, style: const TextStyle(fontSize: 10.5, color: AppColors.slateMuted), overflow: TextOverflow.ellipsis)),
                                    SizedBox(width: 110, child: Text(item.deptName, style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 110, child: Text(item.divisionName, style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 65, child: Text(item.unitName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    const SizedBox(width: 75, child: Text('0.00', style: TextStyle(fontSize: 11, color: AppColors.slateMuted))),
                                    SizedBox(width: 75, child: Text(item.accQty.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 80, child: Text(item.qty.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    SizedBox(width: 80, child: Text(item.convUnitName, style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 80, child: Text(item.podConvQty.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 80, child: Text(item.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 65, child: Text('${item.disc.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 95, child: Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                    SizedBox(width: 75, child: Text(item.freight.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 60, child: Text('${item.cgPer.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 75, child: Text(item.cgAmt.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 60, child: Text('${item.sgPer.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 75, child: Text(item.sgAmt.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 60, child: Text('${item.igPer.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 75, child: Text(item.igAmt.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                                    SizedBox(width: 105, child: Text(item.netAmt.toStringAsFixed(2), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppColors.primaryColor))),
                                    SizedBox(
                                      width: 80,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded, size: 15, color: AppColors.primaryColor),
                                            onPressed: () => _editLineRow(i),
                                            tooltip: 'Edit Row',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.error),
                                            onPressed: () => _removeLineRow(i),
                                            tooltip: 'Remove Row',
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

        // Grid Bottom Summary Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.tableHeaderBg,
            border: Border(top: BorderSide(color: AppColors.tableBorder)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Line Items: ${_lineItems.length}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
              Text('Total Quantity: ${_totalItemsQty.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
              Text('Taxable Amount: ₹ ${_totalItemsAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
              Text('Net Items Amount: ₹ ${_lineItems.fold(0.0, (s, i) => s + i.netAmt).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primaryColor)),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // STEP 3: REVIEW, DUTIES & TERMS MODAL SECTION
  // ==========================================================================
  Widget _buildWizardStep3ReviewAndTerms() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Auxiliary Modal Launchers
          Row(
            children: [
              // Duties & Charges Launcher Card
              Expanded(
                child: InkWell(
                  onTap: _openChargesModal,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune_rounded, color: AppColors.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Additional Duties & Charges', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.surfaceDark)),
                              const SizedBox(height: 2),
                              Text(
                                '${_charges.length} active charges (Impact: ₹ ${_totalChargesNetImpact.toStringAsFixed(2)})',
                                style: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primaryColor),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Terms & Conditions Launcher Card
              Expanded(
                child: InkWell(
                  onTap: _openTermsModal,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.secondaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.gavel_rounded, color: AppColors.secondaryColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Terms, Conditions & Clauses', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.surfaceDark)),
                              const SizedBox(height: 2),
                              Text(
                                '${_conditions.length} contractual conditions configured',
                                style: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.secondaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Real-time Calculation Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.tableBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.primaryColor),
                    SizedBox(width: 8),
                    Text('FINANCIAL & TAX BREAKDOWN', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.surfaceDark)),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    _buildSummaryItem('Gross Line Total', '₹ ${_totalItemsGross.toStringAsFixed(2)}'),
                    _buildSummaryItem('Total Discounts', '- ₹ ${_totalItemsDisc.toStringAsFixed(2)}', isNegative: true),
                    _buildSummaryItem('Total Freight', '₹ ${_totalItemsFreight.toStringAsFixed(2)}'),
                    _buildSummaryItem('Duties / AddLess', '${_totalChargesNetImpact >= 0 ? "+" : ""} ₹ ${_totalChargesNetImpact.toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildSummaryItem('CGST Total', '₹ ${_totalCgAmt.toStringAsFixed(2)}'),
                    _buildSummaryItem('SGST Total', '₹ ${_totalSgAmt.toStringAsFixed(2)}'),
                    _buildSummaryItem('IGST Total', '₹ ${_totalIgAmt.toStringAsFixed(2)}'),
                    _buildSummaryItem('Final Net Amount', '₹ ${_calculatedNetTotal.toStringAsFixed(2)}', isBold: true),
                  ],
                ),

                const Divider(height: 28, color: AppColors.tableBorder),

                // Amount in Words
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Amount in Words: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.slateMuted)),
                    Expanded(
                      child: Text(
                        _convertNumberToWords(_calculatedNetTotal),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isNegative = false, bool isBold = false}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isBold ? AppColors.primaryColor.withValues(alpha: 0.08) : AppColors.tableRowHover,
          borderRadius: BorderRadius.circular(10),
          border: isBold ? Border.all(color: AppColors.primaryColor) : Border.all(color: AppColors.tableBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.slateMuted)),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: isBold ? 14 : 12,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                color: isNegative ? AppColors.error : (isBold ? AppColors.primaryColor : AppColors.surfaceDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // WIZARD FOOTER TOOLBAR
  // ==========================================================================
  Widget _buildWizardFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.tableHeaderBg,
        border: Border(top: BorderSide(color: AppColors.tableBorder)),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: _closeWizardModal,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: AppColors.tableBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.bold, fontSize: 12)),
          ),

          const Spacer(),

          if (_currentStep > 1) ...[
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                side: const BorderSide(color: AppColors.tableBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
          ],

          if (_currentStep < 3) ...[
            ElevatedButton.icon(
              onPressed: () {
                if (_currentStep == 1 && _pCode == 0) {
                  setState(() => _wizardError = 'Please select a supplier party first');
                  return;
                }
                setState(() {
                  _wizardError = null;
                  _currentStep++;
                });
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Next Step', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ] else ...[
            PoAnimatedSuccessButton(
              status: _saveButtonStatus,
              onPressed: _savePurchaseOrder,
              idleText: _isEditing ? 'Update Order (F1)' : 'Save Order (F1)',
              loadingText: 'Saving PO...',
              successText: _isEditing ? 'Order Updated!' : 'Order Saved!',
              idleIcon: Icons.save_rounded,
              height: 42,
              fontSize: 12.5,
              borderRadius: BorderRadius.circular(10),
            ),
          ],
        ],
      ),
    );
  }
}
