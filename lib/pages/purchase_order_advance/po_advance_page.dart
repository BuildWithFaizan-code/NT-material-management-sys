import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/app_colors.dart';
import '../bom/bom_models.dart';
import '../bom/widgets/bom_animated_success_button.dart';
import '../bom/widgets/bom_modern_date_picker_dialog.dart';
import '../bom/widgets/bom_modern_dropdown.dart';
import 'po_advance_models.dart';
import 'po_advance_service.dart';
import 'widgets/po_advance_export_modal_dialog.dart';
import 'widgets/po_advance_history_modal.dart';
import 'widgets/po_advance_party_lookup_modal.dart';
import 'widgets/po_advance_party_summary_modal.dart';
import 'widgets/po_advance_record_lookup_modal.dart';

/// Purchase Order Based Advance Entry Module
/// Production-ready screen to manage financial advances paid to suppliers against approved POs.
/// Adheres strictly to NT-MMS tokens, Group Master show-record UX, and Project Master animations.
class PoAdvancePage extends StatefulWidget {
  final PoAdvanceService? service;

  const PoAdvancePage({super.key, this.service});

  @override
  State<PoAdvancePage> createState() => _PoAdvancePageState();
}

class _PoAdvancePageState extends State<PoAdvancePage> {
  late final PoAdvanceService _service;
  int? _selectedRecordId;

  // Parties & Selection
  List<PoAdvancePartyLookup> _parties = [];
  PoAdvancePartyLookup? _selectedParty;
  bool _isLoadingParties = true;

  // POs for selected party
  List<String> _partyPos = [];
  String? _selectedPoNo;
  bool _isLoadingPos = false;

  // Selected PO Details & Financials
  PoAdvanceHeaderDetails? _poDetails;
  bool _isLoadingPoDetails = false;

  // Dual Grids Data
  List<PoAdvanceHistoryRecord> _poHistoryRecords = [];
  bool _isLoadingHistory = false;

  List<PoAdvancePartySummary> _partySummaries = [];
  bool _isLoadingPartySummaries = false;

  // Form Input Controllers & Focus Nodes
  DateTime _appDate = DateTime.now();
  final TextEditingController _appAmtCtrl = TextEditingController();
  final TextEditingController _appLessCtrl = TextEditingController(text: '0.00');
  String _appEMode = 'Cheque';
  final TextEditingController _chequeNoCtrl = TextEditingController();
  DateTime? _appMDate = DateTime.now();
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _appRemarkCtrl = TextEditingController();

  final FocusNode _chequeNoFocusNode = FocusNode();
  final FocusNode _bankNameFocusNode = FocusNode();
  final FocusNode _appAmtFocusNode = FocusNode();
  final FocusNode _appLessFocusNode = FocusNode();
  final FocusNode _appRemarkFocusNode = FocusNode();

  // Validation & Micro-feedback
  ButtonStatus _saveButtonStatus = ButtonStatus.idle;
  String? _validationError;
  bool _isDateLocked = false;
  int? _glowingPoId;
  Timer? _glowTimer;

  static const List<String> _paymentModes = [
    'Cheque',
    'RTGS/NEFT',
    'Bank Transfer',
    'Cash',
    'Demand Draft',
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PoAdvanceService();
    _appAmtCtrl.addListener(_onAmountChanged);
    _appLessCtrl.addListener(_onAmountChanged);
    _loadParties();
    _checkLockForDate(_appDate);
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appAmtCtrl.removeListener(_onAmountChanged);
    _appLessCtrl.removeListener(_onAmountChanged);
    _appAmtCtrl.dispose();
    _appLessCtrl.dispose();
    _chequeNoCtrl.dispose();
    _bankNameCtrl.dispose();
    _appRemarkCtrl.dispose();
    _chequeNoFocusNode.dispose();
    _bankNameFocusNode.dispose();
    _appAmtFocusNode.dispose();
    _appLessFocusNode.dispose();
    _appRemarkFocusNode.dispose();
    _glowTimer?.cancel();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // DYNAMIC FINANCIAL CALCULATIONS
  // --------------------------------------------------------------------------

  double get _currentAppAmt {
    return double.tryParse(_appAmtCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
  }

  double get _currentAppLess {
    return double.tryParse(_appLessCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
  }

  /// Net bank disbursement to party: Payment Amount minus Deductions
  double get _netPayout => _currentAppAmt - _currentAppLess;

  /// Total advance credited against the PO liability: Payment Amount + Deductions
  double get _totalAdvanceSettled => _currentAppAmt + _currentAppLess;

  /// Remaining balance of the PO after applying this advance entry
  double get _remainingBalanceAfterAdvance {
    final pending = _poDetails?.pendingAmt ?? 0.0;
    return pending - _totalAdvanceSettled;
  }

  // --------------------------------------------------------------------------
  // DATA FETCHING & SYNC
  // --------------------------------------------------------------------------

  Future<void> _loadParties() async {
    setState(() => _isLoadingParties = true);
    try {
      final list = await _service.fetchParties();
      if (mounted) {
        setState(() {
          _parties = list;
          _isLoadingParties = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingParties = false);
      }
    }
  }

  Future<void> _checkLockForDate(DateTime date) async {
    final locked = await _service.checkDateLock(date);
    if (mounted) {
      setState(() => _isDateLocked = locked);
    }
  }

  void _onPartySelected(PoAdvancePartyLookup party) async {
    setState(() {
      _selectedParty = party;
      _selectedPoNo = null;
      _poDetails = null;
      _partyPos = [];
      _poHistoryRecords = [];
      _partySummaries = [];
      _validationError = null;
      _isLoadingPos = true;
      _isLoadingPartySummaries = true;
    });

    try {
      final posFuture = _service.fetchPosForParty(party.pCode);
      final summariesFuture = _service.fetchPartyAdvanceSummaries(party.pCode);

      final results = await Future.wait([posFuture, summariesFuture]);
      final pos = results[0] as List<String>;
      final summaries = results[1] as List<PoAdvancePartySummary>;

      if (mounted) {
        setState(() {
          _partyPos = pos;
          _partySummaries = summaries;
          _isLoadingPos = false;
          _isLoadingPartySummaries = false;
          if (pos.length == 1) {
            _onPoSelected(pos.first);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPos = false;
          _isLoadingPartySummaries = false;
        });
      }
    }
  }

  void _onPoSelected(String poNo) async {
    setState(() {
      _selectedPoNo = poNo;
      _isLoadingPoDetails = true;
      _isLoadingHistory = true;
      _validationError = null;
    });

    try {
      final detailsFuture = _service.fetchPoDetails(poNo, _appDate);
      final historyFuture = _service.fetchPoAdvanceHistory(poNo);

      final results = await Future.wait([detailsFuture, historyFuture]);
      final details = results[0] as PoAdvanceHeaderDetails?;
      final history = results[1] as List<PoAdvanceHistoryRecord>;

      if (mounted) {
        setState(() {
          _poDetails = details;
          _poHistoryRecords = history;
          _isLoadingPoDetails = false;
          _isLoadingHistory = false;

          if (details != null) {
            // 1. Auto-fill Payment Amount with remaining pending balance
            if (details.pendingAmt > 0) {
              _appAmtCtrl.text = details.pendingAmt.toStringAsFixed(2);
            } else {
              _appAmtCtrl.text = '0.00';
            }
            _appLessCtrl.text = '0.00';

            // 2. Auto-fill Supplier Reference into Cheque/Ref if present
            if (details.suppRef.trim().isNotEmpty) {
              _chequeNoCtrl.text = details.suppRef.trim();
            }

            // 3. Keep Instrument Date synchronized with Voucher Date
            _appMDate = _appDate;

            // 4. Auto-detect Payment Mode from PO terms or PO mode
            final hint = '${details.pTerms} ${details.poMode}'.toUpperCase();
            if (hint.contains('RTGS') || hint.contains('NEFT') || hint.contains('IMPS')) {
              _appEMode = 'RTGS/NEFT';
            } else if (hint.contains('TRANSFER') || hint.contains('ONLINE') || hint.contains('NET')) {
              _appEMode = 'Bank Transfer';
            } else if (hint.contains('CASH')) {
              _appEMode = 'Cash';
            } else if (hint.contains('DD') || hint.contains('DEMAND DRAFT')) {
              _appEMode = 'Demand Draft';
            } else {
              _appEMode = 'Cheque';
            }

            // 5. Contextual Narration from PO details & terms
            final termsPart = details.pTerms.trim().isNotEmpty ? ' (${details.pTerms.trim()})' : '';
            final remarkPart = details.remark.trim().isNotEmpty ? ' - ${details.remark.trim()}' : '';
            _appRemarkCtrl.text = 'Advance against PO $poNo$termsPart$remarkPart';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPoDetails = false;
          _isLoadingHistory = false;
        });
      }
    }
  }

  void _openPartyLookupModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PoAdvancePartyLookupModal(
        parties: _parties,
        onSelect: _onPartySelected,
      ),
    );
  }

  Future<void> _openExportModal() async {
    List<PoAdvanceHistoryRecord> exportRecords = _poHistoryRecords;
    if (exportRecords.isEmpty) {
      try {
        exportRecords = await _service.fetchAllAdvances();
      } catch (_) {}
    }

    if (exportRecords.isEmpty) {
      _showTransientValidation('No advance history records available to export.');
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PoAdvanceExportModalDialog(
        records: exportRecords,
        poNo: _selectedPoNo ?? 'ALL_POS',
        partyName: _selectedParty?.pName ?? 'All Suppliers',
      ),
    );
  }

  Future<void> _openShowRecordModal() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    List<PoAdvanceHistoryRecord> allRecords = [];
    try {
      allRecords = await _service.fetchAllAdvances();
    } catch (e) {
      debugPrint('Error fetching master advance records: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading dialog

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PoAdvanceRecordLookupModal(
        records: allRecords,
        service: _service,
        recentlySavedId: _glowingPoId,
        glowingPoId: _glowingPoId,
        onSelect: _loadRecordFromShowRecord,
        onRefreshNeeded: () async {
          if (_selectedPoNo != null) {
            await _fetchPoHistory(_selectedPoNo!);
          }
          if (_selectedParty != null) {
            await _fetchPartySummaries(_selectedParty!.pCode);
          }
        },
      ),
    );
  }

  Future<void> _openPoHistoryModal() async {
    if (_selectedPoNo == null || _selectedPoNo!.isEmpty) {
      _showTransientValidation('Please select a Purchase Order first to check its advance payment history.');
      return;
    }

    // Refresh history in background
    await _fetchPoHistory(_selectedPoNo!);
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PoAdvanceHistoryModal(
        poNo: _selectedPoNo!,
        partyName: _selectedParty?.pName ?? '',
        records: _poHistoryRecords,
        isLoading: _isLoadingHistory,
        netAmt: _poDetails?.netAmt ?? 0.0,
        totGiv: _poDetails?.totGiv ?? 0.0,
        pendingAmt: _poDetails?.pendingAmt ?? 0.0,
        selectedRecordId: _selectedRecordId,
        onSelectRecord: (record) => _loadRecordFromShowRecord(record),
        onDeleteRecord: (record) async {
          await _handleDeleteAdvance(record);
        },
      ),
    );
  }

  Future<void> _openPartySummaryModal() async {
    if (_selectedParty == null) {
      _showTransientValidation('Please select an Approved Supplier / Party first to view total advances.');
      return;
    }

    // Refresh party summaries in background
    await _fetchPartySummaries(_selectedParty!.pCode);
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PoAdvancePartySummaryModal(
        partyCode: _selectedParty!.pCode,
        partyName: _selectedParty!.pName,
        summaries: _partySummaries,
        isLoading: _isLoadingPartySummaries,
        currentSelectedPoNo: _selectedPoNo,
        onSelectPo: (poNo) {
          _onPoSelected(poNo);
        },
      ),
    );
  }

  Future<void> _loadRecordFromShowRecord(PoAdvanceHistoryRecord record) async {
    // 1. Locate or create party
    PoAdvancePartyLookup? party;
    final found = _parties.where((p) => p.pCode == record.partyId).toList();
    if (found.isNotEmpty) {
      party = found.first;
    } else {
      party = PoAdvancePartyLookup(pCode: record.partyId, pName: record.partyName);
    }

    setState(() {
      _selectedParty = party;
      _isLoadingPos = true;
    });

    // 2. Fetch approved POs for this party
    final pos = await _service.fetchPosForParty(party.pCode);
    final mutablePos = List<String>.from(pos);
    if (!mutablePos.contains(record.poNo)) {
      mutablePos.add(record.poNo);
    }

    setState(() {
      _partyPos = mutablePos;
      _selectedPoNo = record.poNo;
      _isLoadingPos = false;
      _isLoadingPoDetails = true;
    });

    // 3. Fetch PO header metrics & balance
    final appDate = record.appDt ?? DateTime.now();
    final det = await _service.fetchPoDetails(record.poNo, appDate);

    if (!mounted) return;

    setState(() {
      _selectedRecordId = record.poId;
      _poDetails = det;
      _isLoadingPoDetails = false;
      _appDate = appDate;
      if (record.appEMode.isNotEmpty) {
        _appEMode = record.appEMode;
      }
      _chequeNoCtrl.text = record.chequeNo;
      _appMDate = record.appMDate;
      _appAmtCtrl.text = record.appAmt.toStringAsFixed(2);
      _appLessCtrl.text = record.appLess.toStringAsFixed(2);
      _appRemarkCtrl.text = record.appRemark;
      _validationError = null;
      _glowingPoId = record.poId;
    });

    _triggerGlow(record.poId);
    await _fetchPoHistory(record.poNo);
    await _fetchPartySummaries(party.pCode);
  }

  Future<void> _fetchPoHistory(String poNo) async {
    try {
      final history = await _service.fetchPoAdvanceHistory(poNo);
      if (mounted) {
        setState(() => _poHistoryRecords = history);
      }
    } catch (_) {}
  }

  Future<void> _fetchPartySummaries(int partyCode) async {
    try {
      final summaries = await _service.fetchPartyAdvanceSummaries(partyCode);
      if (mounted) {
        setState(() => _partySummaries = summaries);
      }
    } catch (_) {}
  }

  void _resetForm({bool resetParty = true}) {
    setState(() {
      _selectedRecordId = null;
      if (resetParty) {
        _selectedParty = null;
        _partyPos = [];
        _partySummaries = [];
      }
      _selectedPoNo = null;
      _poDetails = null;
      _poHistoryRecords = [];
      _appDate = DateTime.now();
      _appAmtCtrl.clear();
      _appLessCtrl.text = '0.00';
      _appEMode = 'Cheque';
      _chequeNoCtrl.clear();
      _appMDate = DateTime.now();
      _bankNameCtrl.clear();
      _appRemarkCtrl.clear();
      _validationError = null;
      _saveButtonStatus = ButtonStatus.idle;
      _isDateLocked = false;
    });
    _checkLockForDate(_appDate);
  }

  void _triggerGlow(int poId) {
    _glowTimer?.cancel();
    setState(() => _glowingPoId = poId);
    _glowTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() => _glowingPoId = null);
      }
    });
  }

  void _showTransientValidation(String message) {
    setState(() => _validationError = message);
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted && _validationError == message) {
        setState(() => _validationError = null);
      }
    });
  }

  // --------------------------------------------------------------------------
  // SAVE TRANSACTION WORKFLOW
  // --------------------------------------------------------------------------

  Future<void> _handleSaveAdvance() async {
    if (_saveButtonStatus == ButtonStatus.loading) return;

    if (_selectedParty == null) {
      _showTransientValidation('Please select an Approved Supplier / Party first.');
      return;
    }
    if (_selectedPoNo == null || _selectedPoNo!.trim().isEmpty) {
      _showTransientValidation('Please select a Purchase Order (PO No.).');
      return;
    }

    final double amt = double.tryParse(_appAmtCtrl.text.trim()) ?? 0.0;
    if (amt <= 0) {
      _showTransientValidation('Please enter a valid Payment Amount greater than 0.');
      return;
    }

    final double less = double.tryParse(_appLessCtrl.text.trim()) ?? 0.0;

    if (_isDateLocked) {
      _showTransientValidation('Cannot save: Transaction date is locked in LOCKDATAMST.');
      return;
    }

    // Verify lock once more synchronously before committing
    final locked = await _service.checkDateLock(_appDate);
    if (locked) {
      setState(() => _isDateLocked = true);
      _showTransientValidation('Transaction date is locked in LOCKDATAMST.');
      return;
    }

    setState(() {
      _saveButtonStatus = ButtonStatus.loading;
      _validationError = null;
    });

    try {
      final payload = PoAdvanceCreatePayload(
        poNo: _selectedPoNo!,
        partyId: _selectedParty!.pCode,
        appDt: _appDate,
        appAmt: amt,
        appLess: less,
        appEMode: _appEMode,
        chequeNo: _chequeNoCtrl.text.trim(),
        bankName: _bankNameCtrl.text.trim(),
        appRemark: _appRemarkCtrl.text.trim(),
        appMDate: _appMDate,
      );

      final newId = await _service.createAdvance(payload);

      if (mounted) {
        setState(() {
          _selectedRecordId = newId;
          _saveButtonStatus = ButtonStatus.success;
          _appAmtCtrl.clear();
          _appLessCtrl.text = '0.00';
          _chequeNoCtrl.clear();
          _bankNameCtrl.clear();
          _appRemarkCtrl.clear();
        });

        _triggerGlow(newId);

        // Refresh PO details & history grids immediately
        _onPoSelected(_selectedPoNo!);
        if (_selectedParty != null) {
          final summaries = await _service.fetchPartyAdvanceSummaries(_selectedParty!.pCode);
          if (mounted) setState(() => _partySummaries = summaries);
        }

        // Return button to idle after success burst
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) setState(() => _saveButtonStatus = ButtonStatus.idle);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saveButtonStatus = ButtonStatus.error);
        _showTransientValidation(e.toString().replaceAll('Exception:', '').trim());
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) setState(() => _saveButtonStatus = ButtonStatus.idle);
        });
      }
    }
  }

  // --------------------------------------------------------------------------
  // DELETE ADVANCE WORKFLOW
  // --------------------------------------------------------------------------

  Future<void> _handleDeleteAdvance(PoAdvanceHistoryRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Void Advance Payment',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete advance entry #${record.poId} of ₹${record.appAmt.toStringAsFixed(2)} for PO ${record.poNo}?',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Text(
                'This will reverse the advance disbursement and update the pending balance.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteAdvance(record.poId);
        if (_selectedPoNo != null) _onPoSelected(_selectedPoNo!);
        if (_selectedParty != null) {
          final summaries = await _service.fetchPartyAdvanceSummaries(_selectedParty!.pCode);
          if (mounted) setState(() => _partySummaries = summaries);
        }
      } catch (e) {
        if (mounted) {
          _showTransientValidation('Failed to delete advance: $e');
        }
      }
    }
  }

  // --------------------------------------------------------------------------
  // BUILD METHOD (SINGLE VIEWPORT PAGE)
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.f1): _handleSaveAdvance,
        const SingleActivator(LogicalKeyboardKey.escape): () => _resetForm(resetParty: false),
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    // 1. TOP HEADER TOOLBAR
                    _buildScreenHeader(),
                    const SizedBox(height: 10),

                    // 2. ERROR / VALIDATION BANNER (IF ANY)
                    if (_validationError != null) ...[
                      _buildValidationBanner(),
                      const SizedBox(height: 8),
                    ],

                    // 3. MAIN WORKSPACE: SELECTION & PAYMENT ENTRY FORM (SCROLLABLE & OVERFLOW-FREE)
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildEntryCard(),
                      ),
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

  // --------------------------------------------------------------------------
  // 1. SCREEN HEADER TOOLBAR
  // --------------------------------------------------------------------------

  Widget _buildScreenHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1220;
        final isVeryCompact = constraints.maxWidth < 1000;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Isometric 3D Logo / Icon Container
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0C3B2E), Color(0xFF1D5A46)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0C3B2E).withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Subtitle (Expanded to prevent horizontal row overflow)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Purchase Order Based Advance Entry',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Text(
                            'FINANCIAL ADVANCE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF047857),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Record financial advance disbursements against approved POs with real-time ledger tracking',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Date Lock Indicator Pill
              if (_isDateLocked)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 12, color: Color(0xFFDC2626)),
                      SizedBox(width: 4),
                      Text(
                        'Date Locked',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),

              // PO ADVANCE HISTORY CHECK & SELECT BUTTON
              _HeaderPoHistoryButton(
                onTap: _openPoHistoryModal,
                count: _poHistoryRecords.length,
                isEnabled: _selectedPoNo != null,
              ),
              const SizedBox(width: 6),

              // PARTY TOTAL ADVANCES CHECK & SELECT BUTTON
              _HeaderPartySummaryButton(
                onTap: _openPartySummaryModal,
                count: _partySummaries.length,
                isEnabled: _selectedParty != null,
              ),
              const SizedBox(width: 6),

              // SHOW RECORD LOOKUP BUTTON (Group Master Mirror)
              _AnimatedShowRecordButton(onTap: _openShowRecordModal),
              const SizedBox(width: 6),

              // Reset / New Entry Button
              OutlinedButton.icon(
                onPressed: () => _resetForm(resetParty: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 34),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('New Entry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
              ),
              const SizedBox(width: 6),

              // Animated Export Button
              _HeaderExportButton(onPressed: _openExportModal),

              // Keyboard Helper Pill / Tooltip
              if (!isVeryCompact) ...[
                const SizedBox(width: 6),
                if (!isCompact)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.keyboard_outlined, size: 13, color: Color(0xFF64748B)),
                        SizedBox(width: 4),
                        Text(
                          'F1 Save | Esc Reset',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                else
                  Tooltip(
                    message: 'F1: Save (F1)  |  Esc: Reset',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard_outlined, size: 13, color: Color(0xFF64748B)),
                          SizedBox(width: 3),
                          Text('F1', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // 2. VALIDATION BANNER
  // --------------------------------------------------------------------------

  Widget _buildValidationBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _validationError!,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _validationError = null),
            child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFB91C1C)),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 3. UPPER CARD: SELECTION, FINANCIAL BANNER & PAYMENT ENTRY
  // --------------------------------------------------------------------------

  Widget _buildEntryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ROW 1 (Image 2 Parity): DATE :, ID :, PARTY NAME :
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Date : (Voucher Date)
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Date :', isRequired: true),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showModernDatePicker(
                          context: context,
                          initialDate: _appDate,
                        );
                        if (picked != null) {
                          setState(() => _appDate = picked);
                          _checkLockForDate(picked);
                          if (_selectedPoNo != null) {
                            final det = await _service.fetchPoDetails(_selectedPoNo!, picked);
                            if (mounted) setState(() => _poDetails = det);
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isDateLocked ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isDateLocked ? Icons.lock_clock_rounded : Icons.calendar_today_rounded,
                              size: 14,
                              color: _isDateLocked ? const Color(0xFFDC2626) : AppColors.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_appDate.day.toString().padLeft(2, '0')}/${_appDate.month.toString().padLeft(2, '0')}/${_appDate.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isDateLocked ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // ID : (Advance ID - e.g. 4 or Auto)
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('ID :'),
                    const SizedBox(height: 4),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedRecordId != null ? Icons.tag_rounded : Icons.fiber_new_rounded,
                            size: 14,
                            color: _selectedRecordId != null ? AppColors.primaryColor : const Color(0xFF047857),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _selectedRecordId != null ? '$_selectedRecordId' : 'Auto',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _selectedRecordId != null ? const Color(0xFF0F172A) : const Color(0xFF047857),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Party Name : (Supplier Search Lookup)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Party Name :', isRequired: true),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _openPartyLookupModal,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedParty != null ? AppColors.secondaryColor : const Color(0xFFCBD5E1),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.business_rounded, size: 16, color: AppColors.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isLoadingParties
                                    ? 'Loading approved suppliers...'
                                    : (_selectedParty != null
                                        ? '[${_selectedParty!.pCode}] ${_selectedParty!.pName}'
                                        : 'Click or press Enter to search approved suppliers...'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedParty != null ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedParty != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedParty != null) ...[
                              InkWell(
                                onTap: () => _resetForm(resetParty: true),
                                borderRadius: BorderRadius.circular(10),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('SEARCH', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ROW 2 (Image 2 Parity): PO NO., PO DATE, AMOUNT :, PYMT.AMT :, PENDING :
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // PO No.:
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel(
                      'PO No.:',
                      isRequired: true,
                      trailing: _selectedParty != null
                          ? InkWell(
                              onTap: _openPartySummaryModal,
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFA5B4FC), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.summarize_rounded, size: 9, color: Color(0xFF4338CA)),
                                    const SizedBox(width: 3),
                                    Text(
                                      'ALL POS (${_partySummaries.length})',
                                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF4338CA)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    _isLoadingPos
                        ? Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text('Loading POs...', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          )
                        : BomModernDropdown<String>(
                            value: _selectedPoNo,
                            hintText: _selectedParty == null
                                ? 'Select supplier first'
                                : (_partyPos.isEmpty ? 'No unreceived POs found' : 'Select PO No.'),
                            dropdownTitle: 'Select Approved PO',
                            items: _partyPos.map((po) {
                              return BomDropdownItem<String>(
                                value: po,
                                label: po,
                                icon: Icons.receipt_long_rounded,
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) _onPoSelected(val);
                            },
                            height: 36,
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // PO Date :
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('PO Date :'),
                    const SizedBox(height: 4),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: _isLoadingPoDetails
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                          : Row(
                              children: [
                                const Icon(Icons.date_range_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _poDetails?.poDate != null
                                        ? '${_poDetails!.poDate!.day.toString().padLeft(2, '0')}/${_poDetails!.poDate!.month.toString().padLeft(2, '0')}/${_poDetails!.poDate!.year}'
                                        : '-',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Amount : (PO Total Net Amount)
              _buildLegacyMetricBox(
                label: 'Amount :',
                value: _poDetails?.netAmt ?? 0.0,
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                flex: 3,
              ),
              const SizedBox(width: 8),

              // Pymt.Amt : (Total Prior Advances Given - with history modal trigger)
              _buildLegacyMetricBox(
                label: 'Pymt.Amt :',
                value: _poDetails?.totGiv ?? 0.0,
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
                flex: 3,
                trailing: _selectedPoNo != null
                    ? InkWell(
                        onTap: _openPoHistoryModal,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.history_edu_rounded, size: 9, color: Color(0xFFB45309)),
                              const SizedBox(width: 2),
                              Text(
                                'CHECK (${_poHistoryRecords.length})',
                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : null,
                onTap: _selectedPoNo != null ? _openPoHistoryModal : null,
                tooltip: _selectedPoNo != null ? 'Click to inspect advance payment history for $_selectedPoNo' : null,
              ),
              const SizedBox(width: 8),

              // Pending : (Pending PO Balance)
              _buildLegacyMetricBox(
                label: 'Pending :',
                value: _poDetails?.pendingAmt ?? 0.0,
                color: (_poDetails?.pendingAmt ?? 0.0) >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                bgColor: (_poDetails?.pendingAmt ?? 0.0) >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                flex: 3,
              ),
            ],
          ),

          // PO TERMS / BADGES STRIP (IF PRESENT)
          if (_selectedPoNo != null && _poDetails != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF475569)),
                    const SizedBox(width: 6),
                    const Text('PO Details:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    const SizedBox(width: 6),
                    _buildPoBadge('Payment Terms', _poDetails!.pTerms.isNotEmpty ? _poDetails!.pTerms : 'Standard'),
                    const SizedBox(width: 6),
                    _buildPoBadge('Delivery Terms', _poDetails!.dTerms.isNotEmpty ? _poDetails!.dTerms : 'Standard'),
                    const SizedBox(width: 6),
                    _buildPoBadge('Mode', _poDetails!.poMode.isNotEmpty ? _poDetails!.poMode : 'Direct'),
                    if (_poDetails!.suppRef.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildPoBadge('Supp Ref', _poDetails!.suppRef),
                    ],
                    if (_poDetails!.remark.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Note: ${_poDetails!.remark}',
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // GROUP BOX: ADVANCE DETAILS (IMAGE 2 PARITY)
          _buildAdvanceDetailsGroupBox(),

          const SizedBox(height: 10),

          // ROW 4: REMARK : & ACTION BUTTONS
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Remark :
              Expanded(
                flex: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Remark :'),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _appRemarkCtrl,
                        focusNode: _appRemarkFocusNode,
                        mouseCursor: SystemMouseCursors.text,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Enter advance remarks / payment narration...',
                          hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Clear Button
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _appAmtCtrl.clear();
                    _appLessCtrl.text = '0.00';
                    _chequeNoCtrl.clear();
                    _bankNameCtrl.clear();
                    _appRemarkCtrl.clear();
                    _validationError = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
              ),
              const SizedBox(width: 8),

              // Save (F1) Button
              SizedBox(
                height: 36,
                child: BomAnimatedSuccessButton(
                  status: _saveButtonStatus,
                  onPressed: _handleSaveAdvance,
                  idleText: 'Save (F1)',
                  loadingText: 'Saving...',
                  successText: 'Saved!',
                  errorText: 'Failed',
                  idleIcon: Icons.save_rounded,
                  height: 36,
                  idleBackgroundColor: AppColors.primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // REAL-TIME FINANCIAL SETTLEMENT SUMMARY STRIP
          _buildSettlementStrip(),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // GROUP BOX: ADVANCE DETAILS (Styled exactly matching Image 2)
  // --------------------------------------------------------------------------

  Widget _buildAdvanceDetailsGroupBox() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge for Group Box
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.payment_rounded, size: 12, color: AppColors.primaryColor),
                    SizedBox(width: 4),
                    Text(
                      'Advance Details',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // SUB-ROW 1: CHEQUE NO., DATE, AMOUNT., LESS / DEDUCT
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Cheque No.:
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Cheque No.:'),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _chequeNoCtrl,
                        focusNode: _chequeNoFocusNode,
                        mouseCursor: SystemMouseCursors.text,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Enter Cheque / UTR / Ref No',
                          hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Date : (Cheque / Instrument Date)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Date :'),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showModernDatePicker(
                          context: context,
                          initialDate: _appMDate ?? DateTime.now(),
                        );
                        if (picked != null) setState(() => _appMDate = picked);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_note_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _appMDate != null
                                    ? '${_appMDate!.day.toString().padLeft(2, '0')}/${_appMDate!.month.toString().padLeft(2, '0')}/${_appMDate!.year}'
                                    : 'Select Date',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Amount.: (Payment Amount)
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel(
                      'Amount.:',
                      isRequired: true,
                      trailing: _poDetails != null && (_poDetails!.pendingAmt > 0)
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildQuickFillChip('100%', _poDetails!.pendingAmt),
                                const SizedBox(width: 3),
                                _buildQuickFillChip('50%', _poDetails!.pendingAmt * 0.5),
                              ],
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _appAmtCtrl,
                        focusNode: _appAmtFocusNode,
                        mouseCursor: SystemMouseCursors.text,
                        textAlignVertical: TextAlignVertical.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: '₹ ',
                          isDense: true,
                          prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857), fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Less / Deduct (₹):
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Less / Deduct (₹):'),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _appLessCtrl,
                        focusNode: _appLessFocusNode,
                        mouseCursor: SystemMouseCursors.text,
                        textAlignVertical: TextAlignVertical.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: '₹ ',
                          isDense: true,
                          prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // SUB-ROW 2: BANK : AND PAYMENT MODE :
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Bank :
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Bank :'),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _bankNameCtrl,
                        focusNode: _bankNameFocusNode,
                        mouseCursor: SystemMouseCursors.text,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Enter Bank / Branch Name (e.g. HDFC / SBI Bank)',
                          hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Payment Mode :
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Payment Mode:'),
                    const SizedBox(height: 4),
                    BomModernDropdown<String>(
                      value: _appEMode,
                      hintText: 'Payment Mode',
                      dropdownTitle: 'Select Payment Mode',
                      items: _paymentModes.map((mode) {
                        return BomDropdownItem<String>(
                          value: mode,
                          label: mode,
                          icon: mode == 'Cash' ? Icons.money_rounded : Icons.credit_card_rounded,
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _appEMode = val);
                      },
                      height: 36,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // LEGACY METRIC BOX (Amount :, Pymt.Amt :, Pending : matching Image 2)
  // --------------------------------------------------------------------------

  Widget _buildLegacyMetricBox({
    required String label,
    required double value,
    required Color color,
    required Color bgColor,
    int flex = 3,
    Widget? trailing,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final boxContent = Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '₹${value.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label, trailing: trailing),
          const SizedBox(height: 4),
          if (onTap != null)
            Tooltip(
              message: tooltip ?? '',
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: boxContent,
              ),
            )
          else
            boxContent,
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // REAL-TIME SETTLEMENT SUMMARY STRIP
  // --------------------------------------------------------------------------

  Widget _buildSettlementStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _remainingBalanceAfterAdvance < -0.01
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calculate_outlined, size: 15, color: AppColors.primaryColor),
                      const SizedBox(width: 6),
                      const Text(
                        'REAL-TIME SETTLEMENT:',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF334155), letterSpacing: 0.3),
                      ),
                      const SizedBox(width: 10),
                      _buildSettlementStat('PO Net Total', '₹${(_poDetails?.netAmt ?? 0.0).toStringAsFixed(2)}', const Color(0xFF2563EB)),
                      _buildSettlementDivider(),
                      _buildSettlementStat('Gross Advance', '₹${_currentAppAmt.toStringAsFixed(2)}', const Color(0xFF0F172A)),
                      _buildSettlementDivider(),
                      _buildSettlementStat('Less/Deduct', '-₹${_currentAppLess.toStringAsFixed(2)}', const Color(0xFF64748B)),
                      _buildSettlementDivider(),
                      _buildSettlementStat('Net Disbursed', '₹${_netPayout.toStringAsFixed(2)}', const Color(0xFF047857), isBold: true),
                      _buildSettlementDivider(),
                      _buildSettlementStat(
                        'Remaining Balance',
                        '₹${_remainingBalanceAfterAdvance.toStringAsFixed(2)}',
                        _remainingBalanceAfterAdvance < -0.01
                            ? const Color(0xFFDC2626)
                            : (_remainingBalanceAfterAdvance.abs() <= 0.01 ? const Color(0xFF047857) : const Color(0xFFD97706)),
                        isBold: true,
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quick Trigger: PO Advance History Modal
                      InkWell(
                        onTap: _openPoHistoryModal,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _selectedPoNo != null ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _selectedPoNo != null ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history_edu_rounded,
                                size: 12,
                                color: _selectedPoNo != null ? const Color(0xFF047857) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'PO History (${_poHistoryRecords.length})',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedPoNo != null ? const Color(0xFF047857) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Quick Trigger: Party Advance Summary Modal
                      InkWell(
                        onTap: _openPartySummaryModal,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _selectedParty != null ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _selectedParty != null ? const Color(0xFFBFDBFE) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.summarize_rounded,
                                size: 12,
                                color: _selectedParty != null ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Party Summary (${_partySummaries.length})',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedParty != null ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Real-time Settlement Status Badge
                      _buildSettlementStatusBadge(),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // HELPER WIDGETS: FIELD LABELS & BADGES
  // --------------------------------------------------------------------------

  Widget _buildFieldLabel(String label, {bool isRequired = false, Widget? trailing}) {
    return Row(
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 2),
                const Text('*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: trailing,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickFillChip(String label, double amount) {
    return InkWell(
      onTap: () {
        setState(() {
          _appAmtCtrl.text = amount.toStringAsFixed(2);
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.25), width: 0.8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
        ),
      ),
    );
  }

  Widget _buildPoBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
      ),
    );
  }

  Widget _buildSettlementStat(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSettlementDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(width: 1, height: 12, color: const Color(0xFFCBD5E1)),
    );
  }

  Widget _buildSettlementStatusBadge() {
    if (_selectedPoNo == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('Select PO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
      );
    }

    if (_currentAppAmt <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Text('Enter Advance Amount', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
      );
    }

    if (_remainingBalanceAfterAdvance < -0.01) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 11, color: Color(0xFFDC2626)),
            const SizedBox(width: 4),
            Text(
              'Overpayment by ₹${(-_remainingBalanceAfterAdvance).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
            ),
          ],
        ),
      );
    }

    if (_remainingBalanceAfterAdvance.abs() <= 0.01) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF047857)),
            SizedBox(width: 4),
            Text('100% Full PO Settlement', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF047857))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timelapse_rounded, size: 11, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 4),
          Text(
            'Partial: ₹${_remainingBalanceAfterAdvance.toStringAsFixed(2)} Remaining',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HEADER ANIMATED EXPORT BUTTON (Matching Project Master Orbit Aesthetic)
// ============================================================================

class _HeaderExportButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _HeaderExportButton({required this.onPressed});

  @override
  State<_HeaderExportButton> createState() => _HeaderExportButtonState();
}

class _HeaderExportButtonState extends State<_HeaderExportButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ElevatedButton.icon(
        onPressed: widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0C3B2E),
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          elevation: _isHovered ? 3 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.download_rounded, size: 14, color: Colors.white),
        label: const Text(
          'Export',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED "SHOW RECORD" BUTTON (GROUP MASTER MIRROR)
// ============================================================================

class _AnimatedShowRecordButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedShowRecordButton({required this.onTap});

  @override
  State<_AnimatedShowRecordButton> createState() => _AnimatedShowRecordButtonState();
}

class _AnimatedShowRecordButtonState extends State<_AnimatedShowRecordButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _magnifySwingAnim;
  late Animation<double> _magnifyScaleAnim;
  late Animation<double> _pulseGlowAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _magnifySwingAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -0.22).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: -0.22, end: 0.22).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.22, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 25),
    ]).animate(_animController);

    _magnifyScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 70),
    ]).animate(_animController);

    _pulseGlowAnim = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onEnter(_) {
    setState(() => _isHovered = true);
    _animController.repeat(reverse: true);
  }

  void _onExit(_) {
    setState(() => _isHovered = false);
    _animController.stop();
    _animController.animateTo(0.0, duration: const Duration(milliseconds: 200));
  }

  void _handleTap() {
    _animController.forward(from: 0.0).then((_) {
      if (mounted && !_isHovered) {
        _animController.animateTo(0.0);
      }
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return AnimatedScale(
              scale: _isHovered ? 1.04 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: _isHovered ? const Color(0xFFDBEAFE) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isHovered ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
                    width: _isHovered ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: _isHovered ? 0.25 : 0.08),
                      blurRadius: _isHovered ? _pulseGlowAnim.value : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: _magnifyScaleAnim.value,
                      child: Transform.rotate(
                        angle: _magnifySwingAnim.value,
                        child: Icon(
                          Icons.manage_search_rounded,
                          size: 16,
                          color: _isHovered ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Show Record',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _isHovered ? const Color(0xFF1E40AF) : const Color(0xFF1D4ED8),
                        letterSpacing: 0.1,
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
// HEADER PO ADVANCE HISTORY BUTTON
// ============================================================================

class _HeaderPoHistoryButton extends StatefulWidget {
  final VoidCallback onTap;
  final int count;
  final bool isEnabled;

  const _HeaderPoHistoryButton({
    required this.onTap,
    required this.count,
    required this.isEnabled,
  });

  @override
  State<_HeaderPoHistoryButton> createState() => _HeaderPoHistoryButtonState();
}

class _HeaderPoHistoryButtonState extends State<_HeaderPoHistoryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.isEnabled;
    final bgColor = !enabled
        ? const Color(0xFFF8FAFC)
        : (_isHovered ? const Color(0xFFD1FAE5) : const Color(0xFFECFDF5));
    final borderColor = !enabled
        ? const Color(0xFFE2E8F0)
        : (_isHovered ? const Color(0xFF10B981) : const Color(0xFFA7F3D0));
    final textColor = !enabled
        ? const Color(0xFF94A3B8)
        : (_isHovered ? const Color(0xFF065F46) : const Color(0xFF047857));

    return Tooltip(
      message: enabled
          ? 'Check advance history records for selected PO (${widget.count} entries)'
          : 'Select a Purchase Order to check advance history',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? widget.onTap : null,
          child: AnimatedScale(
            scale: _isHovered && enabled ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: _isHovered && enabled ? 1.4 : 1.0),
                boxShadow: enabled && _isHovered
                    ? [
                        BoxShadow(
                          color: const Color(0xFF059669).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_edu_rounded,
                    size: 15,
                    color: textColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'PO History',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: enabled ? textColor.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER PARTY ADVANCE SUMMARY BUTTON
// ============================================================================

class _HeaderPartySummaryButton extends StatefulWidget {
  final VoidCallback onTap;
  final int count;
  final bool isEnabled;

  const _HeaderPartySummaryButton({
    required this.onTap,
    required this.count,
    required this.isEnabled,
  });

  @override
  State<_HeaderPartySummaryButton> createState() => _HeaderPartySummaryButtonState();
}

class _HeaderPartySummaryButtonState extends State<_HeaderPartySummaryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.isEnabled;
    final bgColor = !enabled
        ? const Color(0xFFF8FAFC)
        : (_isHovered ? const Color(0xFFE0E7FF) : const Color(0xFFEEF2FF));
    final borderColor = !enabled
        ? const Color(0xFFE2E8F0)
        : (_isHovered ? const Color(0xFF6366F1) : const Color(0xFFC7D2FE));
    final textColor = !enabled
        ? const Color(0xFF94A3B8)
        : (_isHovered ? const Color(0xFF3730A3) : const Color(0xFF4338CA));

    return Tooltip(
      message: enabled
          ? 'Check all PO advance summaries for selected supplier (${widget.count} POs)'
          : 'Select an approved supplier to view total advances',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? widget.onTap : null,
          child: AnimatedScale(
            scale: _isHovered && enabled ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: _isHovered && enabled ? 1.4 : 1.0),
                boxShadow: enabled && _isHovered
                    ? [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.summarize_rounded,
                    size: 15,
                    color: textColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Party POs',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: enabled ? textColor.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

