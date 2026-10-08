import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bom_models.dart';

/// STEP ENUM FOR FULL DETAIL VIEW
enum FullDetailColumnStep {
  specs('1', 'SPECIFICATIONS & ITEM CODE'),
  quantities('2', 'QUANTITY & TOLERANCE'),
  financials('3', 'RATES, AMOUNTS & REMARKS');

  final String stepNumber;
  final String title;
  const FullDetailColumnStep(this.stepNumber, this.title);
}

/// ULTRA-MODERN FULL DETAIL ZOOM MODAL FOR BOM SUB-ITEMS
/// Displays segmented column views with Image-2 step progress bar navigation,
/// left/right arrow step controls, and live search filtering.
class BomFullDetailModal extends StatefulWidget {
  final List<BomSubItemData> subItems;
  final String bomId;
  final String parentItemCode;
  final String parentItemDescription;
  final bool isApproved;
  final double totalConsumption;
  final double totalToleranceQty;
  final double totalNetQty;
  final Future<void> Function({BomSubItemData? existingItem, int? editIndex}) onEditRow;
  final Future<bool?> Function(int index) onDeleteRow;

  const BomFullDetailModal({
    super.key,
    required this.subItems,
    required this.bomId,
    required this.parentItemCode,
    required this.parentItemDescription,
    required this.isApproved,
    required this.totalConsumption,
    required this.totalToleranceQty,
    required this.totalNetQty,
    required this.onEditRow,
    required this.onDeleteRow,
  });

  @override
  State<BomFullDetailModal> createState() => _BomFullDetailModalState();
}

class _BomFullDetailModalState extends State<BomFullDetailModal> {
  final ScrollController _vertScrollCtrl = ScrollController();
  final ScrollController _horizScrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();

  FullDetailColumnStep _activeStep = FullDetailColumnStep.specs;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchFilter = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _vertScrollCtrl.dispose();
    _horizScrollCtrl.dispose();
    _searchCtrl.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _previousStep() {
    if (_activeStep.index > 0) {
      setState(() {
        _activeStep = FullDetailColumnStep.values[_activeStep.index - 1];
      });
    }
  }

  void _nextStep() {
    if (_activeStep.index < FullDetailColumnStep.values.length - 1) {
      setState(() {
        _activeStep = FullDetailColumnStep.values[_activeStep.index + 1];
      });
    }
  }

  List<BomSubItemData> get _filteredItems {
    if (_searchFilter.isEmpty) return widget.subItems;
    return widget.subItems.where((item) {
      return item.bomsCode.toLowerCase().contains(_searchFilter) ||
          item.iCode.toLowerCase().contains(_searchFilter) ||
          item.description.toLowerCase().contains(_searchFilter) ||
          item.materialType.toLowerCase().contains(_searchFilter) ||
          item.unitName.toLowerCase().contains(_searchFilter) ||
          item.bomRemarks.toLowerCase().contains(_searchFilter);
    }).toList();
  }

  double get _totalEstimatedAmount =>
      widget.subItems.fold(0.0, (acc, item) => acc + item.bomAmount);

  Color _getMaterialTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'FINISH':
        return const Color(0xFF059669);
      case 'SEMI-FINISH':
        return const Color(0xFF2563EB);
      case 'RAW':
        return const Color(0xFFD97706);
      case 'PACKING':
        return const Color(0xFF7C3AED);
      case 'CONSUMABLE':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF475569);
    }
  }

  Color _getMaterialTypeBg(String type) {
    return _getMaterialTypeColor(type).withValues(alpha: 0.10);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final modalWidth = math.min(1560.0, screenSize.width * 0.96);
    final modalHeight = math.min(840.0, screenSize.height * 0.92);

    final canGoLeft = _activeStep.index > 0;
    final canGoRight = _activeStep.index < FullDetailColumnStep.values.length - 1;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _previousStep();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nextStep();
          }
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Container(
          width: modalWidth,
          height: modalHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: const Color(0xFF0091FF).withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [
                _buildModalHeader(),
                _buildStepperToolbar(canGoLeft, canGoRight),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildTableView(),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                _buildModalFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TOP HEADER: BRAND ICON + TITLE + BADGES + SEARCH + CLOSE
  // --------------------------------------------------------------------------
  Widget _buildModalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 100% IDENTICAL IMAGE 2 BILL & CARDS LOGO DIRECT ON PLAIN WHITE SCREEN (NO BOXES, NO BORDERS)
          Image.asset(
            'assets/images/bom_sub_items_detail_bill_logo.png',
            width: 52,
            height: 52,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          ),
          const SizedBox(width: 16),

          // Titles & Badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BOM SUB-ITEMS & COMPONENTS — FULL DETAIL VIEW',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildHeaderBadge(
                      label: 'BOM ID',
                      value: widget.bomId.isNotEmpty ? widget.bomId : 'N/A',
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                    ),
                    _buildHeaderBadge(
                      label: 'FINISHED GOOD',
                      value: widget.parentItemCode.isNotEmpty ? widget.parentItemCode : 'N/A',
                      color: const Color(0xFF059669),
                      bgColor: const Color(0xFFECFDF5),
                    ),
                    if (widget.parentItemDescription.isNotEmpty)
                      Tooltip(
                        message: widget.parentItemDescription,
                        child: Text(
                          widget.parentItemDescription,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Glassmorphic Search Field
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: 230,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.92),
                      const Color(0xFFF8FAFC).withValues(alpha: 0.72),
                      const Color(0xFFF1F5F9).withValues(alpha: 0.52),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1).withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.95),
                      blurRadius: 2,
                      offset: const Offset(-1, -1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Center(
                        child: Icon(Icons.search_rounded, size: 14, color: Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          hintText: 'Filter components...',
                          hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    if (_searchFilter.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF64748B)),
                        onPressed: () => _searchCtrl.clear(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Total Items Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Text(
              '${widget.subItems.length} Sub-Items Loaded',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
            ),
          ),
          const SizedBox(width: 10),

          // Close 'X' Button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            tooltip: 'Close (Esc)',
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.75)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // STEPPER TOOLBAR: EXACT IMAGE-2 STEP PROGRESS BAR ARCHITECTURE
  // --------------------------------------------------------------------------
  Widget _buildStepperToolbar(bool canGoLeft, bool canGoRight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          // THE 3-STEP PROGRESS BAR (EXACT PARITY TO IMAGE 2)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // STEP 1: SPECIFICATIONS & ITEM CODE
                _buildStepNode(
                  step: FullDetailColumnStep.specs,
                  isActive: _activeStep == FullDetailColumnStep.specs,
                  onTap: () => setState(() => _activeStep = FullDetailColumnStep.specs),
                ),

                // CONNECTOR 1 -> 2
                _buildConnectorLine(isActive: _activeStep.index >= 1),

                // STEP 2: QUANTITY & TOLERANCE
                _buildStepNode(
                  step: FullDetailColumnStep.quantities,
                  isActive: _activeStep == FullDetailColumnStep.quantities,
                  onTap: () => setState(() => _activeStep = FullDetailColumnStep.quantities),
                ),

                // CONNECTOR 2 -> 3
                _buildConnectorLine(isActive: _activeStep.index >= 2),

                // STEP 3: RATES, AMOUNTS & REMARKS
                _buildStepNode(
                  step: FullDetailColumnStep.financials,
                  isActive: _activeStep == FullDetailColumnStep.financials,
                  onTap: () => setState(() => _activeStep = FullDetailColumnStep.financials),
                ),
              ],
            ),
          ),

          // ARROW STEP NAVIGATOR CONTROLS (IMAGE 2 LEFT / RIGHT NAVIGATION)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildArrowNavButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: 'Previous Columns (Left Arrow Key)',
                  enabled: canGoLeft,
                  onTap: _previousStep,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_activeStep.index + 1} / 3',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0091FF),
                  ),
                ),
                const SizedBox(width: 6),
                _buildArrowNavButton(
                  icon: Icons.arrow_forward_ios_rounded,
                  tooltip: 'Next Columns (Right Arrow Key)',
                  enabled: canGoRight,
                  onTap: _nextStep,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required FullDetailColumnStep step,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final Color barColor = isActive ? const Color(0xFF0091FF) : const Color(0xFFBAE6FD);

    return Tooltip(
      message: 'View ${step.title}',
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circle Node (24x24 matching Image 2 with cyan halo glow)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? const Color(0xFF0091FF) : Colors.white,
                  border: isActive
                      ? Border.all(
                          color: const Color(0xFFBAE6FD).withValues(alpha: 0.9),
                          width: 1.3,
                        )
                      : Border.all(
                          color: const Color(0xFF0091FF),
                          width: 1.6,
                        ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00A3FF).withValues(alpha: 0.55),
                            blurRadius: 9,
                            spreadRadius: 2.8,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  step.stepNumber,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF0091FF),
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),

              const SizedBox(height: 3.5),

              // Dual Horizontal Pill Indicator Bars (Image 2 style)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 2.6,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 1.5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 14,
                height: 2.2,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 4),

              // Step Title Text
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                  color: isActive ? const Color(0xFF0091FF) : const Color(0xFF64748B),
                  letterSpacing: 0.4,
                ),
                child: Text(step.title),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectorLine({required bool isActive}) {
    return Padding(
      padding: const EdgeInsets.only(top: 11, left: 10, right: 10, bottom: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 2.0,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0091FF) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildArrowNavButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: enabled ? Colors.white : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: enabled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Icon(
              icon,
              size: 13,
              color: enabled ? const Color(0xFF0091FF) : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TABLE VIEW: SEGMENTED VIEW (ONLY SELECTED STEP COLUMNS ARE RENDERED)
  // --------------------------------------------------------------------------
  Widget _buildTableView() {
    final items = _filteredItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_off_rounded, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(
              _searchFilter.isNotEmpty ? 'No sub-items match "$_searchFilter"' : 'No components found',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
            if (_searchFilter.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _searchCtrl.clear(),
                child: const Text('Clear search filter'),
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double minWidth = _activeStep == FullDetailColumnStep.specs ? 900.0 : 1000.0;
        final double contentWidth = math.max(constraints.maxWidth, minWidth);

        return Scrollbar(
          controller: _horizScrollCtrl,
          thumbVisibility: constraints.maxWidth < minWidth,
          child: SingleChildScrollView(
            controller: _horizScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              child: Column(
                children: [
                  // 1. COLUMN HEADER ROW
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: _buildHeaderRowForStep(_activeStep),
                  ),

                  // 2. SCROLLABLE ROWS
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.builder(
                        controller: _vertScrollCtrl,
                        itemCount: items.length,
                        itemBuilder: (ctx, idx) {
                          final row = items[idx];
                          return _buildBodyRowForStep(row, idx);
                        },
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

  // --------------------------------------------------------------------------
  // HEADER ROW BUILDER PER STEP
  // --------------------------------------------------------------------------
  Widget _buildHeaderRowForStep(FullDetailColumnStep step) {
    switch (step) {
      case FullDetailColumnStep.specs:
        return const Row(
          children: [
            SizedBox(width: 48, child: Text('SR', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 140, child: Text('MATERIAL TYPE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 200, child: Text('MATERIAL CODE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            Expanded(child: Text('MATERIAL DESCRIPTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 90, child: Text('SQM', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 220, child: Text('REMARKS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 90, child: Text('ACTION', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
          ],
        );

      case FullDetailColumnStep.quantities:
        return const Row(
          children: [
            SizedBox(width: 48, child: Text('SR', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 170, child: Text('MATERIAL CODE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            Expanded(child: Text('MATERIAL DESCRIPTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 100, child: Text('CONS.', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 110, child: Text('TOL (+/- %)', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 110, child: Text('TOL QTY', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 120, child: Text('TOTAL QTY', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 80, child: Text('UOM', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 90, child: Text('CONV', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 90, child: Text('ACTION', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
          ],
        );

      case FullDetailColumnStep.financials:
        return const Row(
          children: [
            SizedBox(width: 48, child: Text('SR', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 170, child: Text('MATERIAL CODE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            Expanded(child: Text('MATERIAL DESCRIPTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 110, child: Text('TOTAL QTY', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 80, child: Text('UOM', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 110, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 130, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 220, child: Text('REMARKS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
            SizedBox(width: 90, child: Text('ACTION', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
          ],
        );
    }
  }

  // --------------------------------------------------------------------------
  // BODY ROW BUILDER PER STEP
  // --------------------------------------------------------------------------
  Widget _buildBodyRowForStep(BomSubItemData row, int idx) {
    return _SegmentedRowContainer(
      index: idx,
      child: () {
        switch (_activeStep) {
          case FullDetailColumnStep.specs:
            return Row(
              children: [
                SizedBox(width: 48, child: Text(row.bomsCode, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                SizedBox(
                  width: 140,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _getMaterialTypeBg(row.materialType),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: _getMaterialTypeColor(row.materialType).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        row.materialType.isNotEmpty ? row.materialType : 'GENERAL',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _getMaterialTypeColor(row.materialType)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 200, child: Text(row.iCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                Expanded(child: Tooltip(message: row.description, child: Text(row.description, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))),
                SizedBox(width: 90, child: Text(row.sqm > 0 ? row.sqm.toStringAsFixed(2) : '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600))),
                SizedBox(width: 220, child: Tooltip(message: row.bomRemarks.isNotEmpty ? row.bomRemarks : '-', child: Text(row.bomRemarks.isNotEmpty ? row.bomRemarks : '-', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis))),
                SizedBox(width: 90, child: Center(child: _buildActionButtons(row, idx))),
              ],
            );

          case FullDetailColumnStep.quantities:
            return Row(
              children: [
                SizedBox(width: 48, child: Text(row.bomsCode, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                SizedBox(width: 170, child: Text(row.iCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                Expanded(child: Tooltip(message: row.description, child: Text(row.description, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))),
                SizedBox(width: 100, child: Text(row.bomCons.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                SizedBox(width: 110, child: Text('${row.bomExtra.toStringAsFixed(1)}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600))),
                SizedBox(width: 110, child: Text(row.bomTolQty.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                SizedBox(width: 120, child: Text(row.qty.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0C3B2E)))),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(row.unitName, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                    ),
                  ),
                ),
                SizedBox(width: 90, child: Text(row.convQty.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600))),
                SizedBox(width: 90, child: Center(child: _buildActionButtons(row, idx))),
              ],
            );

          case FullDetailColumnStep.financials:
            return Row(
              children: [
                SizedBox(width: 48, child: Text(row.bomsCode, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                SizedBox(width: 170, child: Text(row.iCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
                Expanded(child: Tooltip(message: row.description, child: Text(row.description, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))),
                SizedBox(width: 110, child: Text(row.qty.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(row.unitName, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                    ),
                  ),
                ),
                SizedBox(width: 110, child: Text('₹${row.bomRate.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600))),
                SizedBox(width: 130, child: Text('₹${row.bomAmount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                SizedBox(width: 220, child: Tooltip(message: row.bomRemarks.isNotEmpty ? row.bomRemarks : '-', child: Text(row.bomRemarks.isNotEmpty ? row.bomRemarks : '-', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis))),
                SizedBox(width: 90, child: Center(child: _buildActionButtons(row, idx))),
              ],
            );
        }
      }(),
    );
  }

  Widget _buildActionButtons(BomSubItemData row, int idx) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniActionIconButton(
          icon: Icons.edit_outlined,
          color: const Color(0xFF059669),
          hoverBg: const Color(0xFFECFDF5),
          tooltip: 'Edit Component',
          onPressed: widget.isApproved
              ? null
              : () async {
                  final originalIndex = widget.subItems.indexOf(row);
                  await widget.onEditRow(
                    existingItem: row,
                    editIndex: originalIndex >= 0 ? originalIndex : idx,
                  );
                  if (mounted) setState(() {});
                },
        ),
        const SizedBox(width: 4),
        _MiniActionIconButton(
          icon: Icons.delete_outline_rounded,
          color: const Color(0xFFEF4444),
          hoverBg: const Color(0xFFFEF2F2),
          tooltip: 'Delete Component',
          onPressed: widget.isApproved
              ? null
              : () async {
                  final originalIndex = widget.subItems.indexOf(row);
                  final deleted = await widget.onDeleteRow(
                    originalIndex >= 0 ? originalIndex : idx,
                  );
                  if (deleted == true && mounted) {
                    setState(() {});
                  }
                },
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // FOOTER: SUMMARY METRICS & CLOSE VIEW BUTTON
  // --------------------------------------------------------------------------
  Widget _buildModalFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
      ),
      child: Row(
        children: [
          // Total items count
          const Icon(Icons.format_list_numbered_rounded, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            '${widget.subItems.length} Total Sub-Items',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
          ),

          const Spacer(),

          // Summary Pills
          _buildSummaryPill(
            label: 'TOTAL CONS',
            value: widget.totalConsumption.toStringAsFixed(2),
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
          const SizedBox(width: 8),
          _buildSummaryPill(
            label: 'TOTAL TOL',
            value: widget.totalToleranceQty.toStringAsFixed(2),
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFEF3C7),
          ),
          const SizedBox(width: 8),
          _buildSummaryPill(
            label: 'NET QTY',
            value: widget.totalNetQty.toStringAsFixed(2),
            color: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
          ),
          const SizedBox(width: 8),
          _buildSummaryPill(
            label: 'EST. AMOUNT',
            value: '₹${_totalEstimatedAmount.toStringAsFixed(2)}',
            color: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
          ),

          const SizedBox(width: 16),

          // Close View Button
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check_circle_rounded, size: 15, color: Colors.white),
            label: const Text('Close View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.8)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// ROW CONTAINER WITH HOVER EFFECT
// ----------------------------------------------------------------------------
class _SegmentedRowContainer extends StatefulWidget {
  final int index;
  final Widget child;

  const _SegmentedRowContainer({
    required this.index,
    required this.child,
  });

  @override
  State<_SegmentedRowContainer> createState() => _SegmentedRowContainerState();
}

class _SegmentedRowContainerState extends State<_SegmentedRowContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF0FDF4) : (widget.index.isEven ? Colors.white : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.4 : 1.0,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: const Color(0xFF0091FF).withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// MINI ACTION ICON BUTTON (ZERO OVERFLOW, COMPACT INKWELL)
// ----------------------------------------------------------------------------
class _MiniActionIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color hoverBg;
  final String tooltip;
  final VoidCallback? onPressed;

  const _MiniActionIconButton({
    required this.icon,
    required this.color,
    required this.hoverBg,
    required this.tooltip,
    this.onPressed,
  });

  @override
  State<_MiniActionIconButton> createState() => _MiniActionIconButtonState();
}

class _MiniActionIconButtonState extends State<_MiniActionIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null;
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
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: (_isHovered && isEnabled) ? widget.hoverBg : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 15,
              color: isEnabled ? widget.color : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }
}
