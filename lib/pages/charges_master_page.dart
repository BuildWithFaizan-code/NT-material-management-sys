import '../utils/file_export_helper.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/charges_master_service.dart';

enum ButtonStatus { idle, loading, success, error }

class ChargesMasterPage extends StatefulWidget {
  final VoidCallback? onNewTaxAdd;

  const ChargesMasterPage({
    super.key,
    this.onNewTaxAdd,
  });

  @override
  State<ChargesMasterPage> createState() => _ChargesMasterPageState();
}

class _ChargesMasterPageState extends State<ChargesMasterPage>
    with SingleTickerProviderStateMixin {
  final ChargesMasterService _service = ChargesMasterService();

  // Filter State
  String _selectedModule = 'PURCHASE ORDER';
  String _selectedMode = 'LOCAL';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Data State
  List<ChargesMasterItem> _allCharges = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Button Micro-Animations State
  ButtonStatus _saveStatus = ButtonStatus.idle;
  ButtonStatus _exportStatus = ButtonStatus.idle;
  ButtonStatus _cancelStatus = ButtonStatus.idle;
  String? _buttonNotificationMsg;
  bool _isNotificationError = true;

  // Keyboard focus node
  final FocusNode _focusNode = FocusNode();

  final List<String> _moduleOptions = [
    'ALL',
    'PURCHASE ORDER',
    'GOODS RECEIVE NOTE',
    'WORK ORDER',
    'QUOTATION',
  ];

  final List<String> _modeOptions = [
    'ALL',
    'LOCAL',
    'IMPORTED',
  ];

  @override
  void initState() {
    super.initState();
    _loadCharges();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCharges() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _service.getChargesList(
        module: _selectedModule,
        mode: _selectedMode,
      );

      if (!mounted) return;
      setState(() {
        _allCharges = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load Charges Master records: $e';
      });
    }
  }

  void _showButtonNotification(String msg, {bool isError = true}) {
    setState(() {
      _buttonNotificationMsg = msg;
      _isNotificationError = isError;
    });
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted && _buttonValidationMsg == msg) {
        setState(() => _buttonNotificationMsg = null);
      }
    });
  }

  String? get _buttonValidationMsg => _buttonNotificationMsg;

  List<ChargesMasterItem> get _filteredCharges {
    if (_searchQuery.isEmpty) return _allCharges;
    final q = _searchQuery.toLowerCase();
    return _allCharges.where((item) {
      return item.chgId.toString().contains(q) ||
          item.chgName.toLowerCase().contains(q) ||
          item.formula.toLowerCase().contains(q) ||
          item.addLess.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _saveAllChanges() async {
    if (_saveStatus == ButtonStatus.loading) return;

    setState(() => _saveStatus = ButtonStatus.loading);

    try {
      final ok = await _service.saveChargesList(_allCharges);
      if (!mounted) return;

      if (ok) {
        setState(() => _saveStatus = ButtonStatus.success);
        _showButtonNotification('Charges Master records saved successfully!', isError: false);
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _saveStatus = ButtonStatus.idle);
        });
      } else {
        setState(() => _saveStatus = ButtonStatus.error);
        _showButtonNotification('Failed to save Charges Master to SQL Server!', isError: true);
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (mounted) setState(() => _saveStatus = ButtonStatus.idle);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveStatus = ButtonStatus.error);
      _showButtonNotification('Error saving records: $e', isError: true);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _saveStatus = ButtonStatus.idle);
      });
    }
  }

  Future<void> _exportToExcel() async {
    if (_exportStatus == ButtonStatus.loading) return;

    if (_filteredCharges.isEmpty) {
      _showButtonNotification('No rows available to export!', isError: true);
      return;
    }

    setState(() => _exportStatus = ButtonStatus.loading);

    try {
      final excel = excel_pkg.Excel.createExcel();
      final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'Charges Master');
      final excel_pkg.Sheet sheet = excel['Charges Master'];

      // Header Styling
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

      // Set Column Widths
      sheet.setColumnWidth(0, 10.0);  // SrNo
      sheet.setColumnWidth(1, 12.0);  // ChgId
      sheet.setColumnWidth(2, 28.0);  // Charges Name
      sheet.setColumnWidth(3, 12.0);  // Disc
      sheet.setColumnWidth(4, 14.0);  // Amount
      sheet.setColumnWidth(5, 12.0);  // AddLess
      sheet.setColumnWidth(6, 10.0);  // IIND
      sheet.setColumnWidth(7, 10.0);  // IST
      sheet.setColumnWidth(8, 38.0);  // Formula
      sheet.setColumnWidth(9, 10.0);  // LOC
      sheet.setColumnWidth(10, 10.0); // IMP
      sheet.setColumnWidth(11, 12.0); // Priority
      sheet.setColumnWidth(12, 10.0); // PO
      sheet.setColumnWidth(13, 10.0); // GRN
      sheet.setColumnWidth(14, 10.0); // WO
      sheet.setColumnWidth(15, 10.0); // Rt

      sheet.setRowHeight(0, 26.0);
      sheet.appendRow([
        excel_pkg.TextCellValue('SrNo'),
        excel_pkg.TextCellValue('ChgId'),
        excel_pkg.TextCellValue('Charges Name'),
        excel_pkg.TextCellValue('Disc'),
        excel_pkg.TextCellValue('Amount'),
        excel_pkg.TextCellValue('AddLess'),
        excel_pkg.TextCellValue('IIND'),
        excel_pkg.TextCellValue('IST'),
        excel_pkg.TextCellValue('Formula'),
        excel_pkg.TextCellValue('LOC'),
        excel_pkg.TextCellValue('IMP'),
        excel_pkg.TextCellValue('Priority'),
        excel_pkg.TextCellValue('PO'),
        excel_pkg.TextCellValue('GRN'),
        excel_pkg.TextCellValue('WO'),
        excel_pkg.TextCellValue('Rt'),
      ]);

      for (int col = 0; col < 16; col++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
      }

      final records = _filteredCharges;
      for (int i = 0; i < records.length; i++) {
        final item = records[i];
        final style = (i % 2 == 0) ? evenStyle : oddStyle;
        final int rIdx = i + 1;

        sheet.setRowHeight(rIdx, 22.0);
        sheet.appendRow([
          excel_pkg.IntCellValue(i + 1),
          excel_pkg.IntCellValue(item.chgId),
          excel_pkg.TextCellValue(item.chgName),
          excel_pkg.DoubleCellValue(item.disc),
          excel_pkg.DoubleCellValue(item.amount),
          excel_pkg.TextCellValue(item.addLess),
          excel_pkg.IntCellValue(item.iind),
          excel_pkg.IntCellValue(item.ist),
          excel_pkg.TextCellValue(item.formula),
          excel_pkg.IntCellValue(item.loc),
          excel_pkg.IntCellValue(item.imp),
          excel_pkg.IntCellValue(item.priority),
          excel_pkg.IntCellValue(item.chgPO),
          excel_pkg.IntCellValue(item.chgGRN),
          excel_pkg.IntCellValue(item.chgWO),
          excel_pkg.DoubleCellValue(item.rt),
        ]);

        for (int col = 0; col < 16; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
        }
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
        final String fileName = 'Charges_Master_Export_$timeStamp.xlsx';
        await FileExportHelper.saveAndLaunchFile(bytes: fileBytes, fileName: fileName);

        if (!mounted) return;
        setState(() => _exportStatus = ButtonStatus.success);
        _showButtonNotification('Excel export completed successfully!', isError: false);

        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _exportStatus = ButtonStatus.idle);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _exportStatus = ButtonStatus.error);
      _showButtonNotification('Export failed: $e', isError: true);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _exportStatus = ButtonStatus.idle);
      });
    }
  }

  void _handleCancel() {
    setState(() {
      _cancelStatus = ButtonStatus.loading;
      _searchQuery = '';
      _searchCtrl.clear();
      _selectedModule = 'PURCHASE ORDER';
      _selectedMode = 'LOCAL';
    });

    _loadCharges().then((_) {
      if (mounted) {
        setState(() => _cancelStatus = ButtonStatus.success);
        _showButtonNotification('Filters reset to default!', isError: false);
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) setState(() => _cancelStatus = ButtonStatus.idle);
        });
      }
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f1) {
      _saveAllChanges();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredCharges;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                // ── A. TOP FILTER BAR ─────────────────────────────────────────
                _buildTopFilterBar(),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // ── B. HIGH-DENSITY DATA GRID (16 COLUMNS) ─────────────────────
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF0C3B2E),
                          ),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : list.isEmpty
                              ? _buildEmptyState()
                              : _buildFullWidthDataGrid(list),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // ── C. BOTTOM ACTION BAR ──────────────────────────────────────
                _buildBottomActionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // ── A. TOP FILTER BAR
  // ============================================================================
  Widget _buildTopFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          // Header Badge / Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payments_rounded, color: Color(0xFF0C3B2E), size: 20),
          ),
          const SizedBox(width: 12),

          // Title
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Charges Master Register',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                'Configure priority, formulas, and transaction applicability rules',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),

          const Spacer(),

          // Module Name Dropdown
          _buildDropdownFilter(
            label: 'Module Name',
            icon: Icons.view_module_rounded,
            iconColor: const Color(0xFF2563EB),
            value: _selectedModule,
            items: _moduleOptions,
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedModule = val);
                _loadCharges();
              }
            },
          ),
          const SizedBox(width: 12),

          // Mode Dropdown
          _buildDropdownFilter(
            label: 'Mode',
            icon: Icons.tune_rounded,
            iconColor: const Color(0xFFD97706),
            value: _selectedMode,
            items: _modeOptions,
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedMode = val);
                _loadCharges();
              }
            },
          ),
          const SizedBox(width: 12),

          // Search Control (🔍)
          SizedBox(
            width: 220,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search charges...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchCtrl.clear();
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required IconData icon,
    required Color iconColor,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          onChanged: onChanged,
          items: items.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: iconColor),
                  const SizedBox(width: 6),
                  Text(opt),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ============================================================================
  // ── B. FULL-WIDTH DATA GRID (16 COLUMNS WITH DISTINCT ICON HEADERS)
  // ============================================================================
  Widget _buildFullWidthDataGrid(List<ChargesMasterItem> list) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 42,
                horizontalMargin: 12,
                columnSpacing: 14,
                headingRowColor: WidgetStateProperty.all(const Color(0xFF0C3B2E)),
                border: const TableBorder(
                  horizontalInside: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
                  bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                ),
                columns: [
                  _buildHeaderColumn('SrNo', Icons.format_list_numbered_rounded, const Color(0xFF64748B)),
                  _buildHeaderColumn('ChgId', Icons.label_rounded, const Color(0xFF06B6D4)),
                  _buildHeaderColumn('Charges Name', Icons.description_rounded, const Color(0xFF10B981)),
                  _buildHeaderColumn('Disc', Icons.trending_down_rounded, const Color(0xFF0D9488)),
                  _buildHeaderColumn('Amount', Icons.attach_money_rounded, const Color(0xFFF59E0B)),
                  _buildHeaderColumn('AddLess', Icons.balance_rounded, const Color(0xFF8B5CF6)),
                  _buildHeaderColumn('IIND', Icons.language_rounded, const Color(0xFF6366F1)),
                  _buildHeaderColumn('IST', Icons.account_balance_rounded, const Color(0xFF2563EB)),
                  _buildHeaderColumn('Formula', Icons.functions_rounded, const Color(0xFF4338CA)),
                  _buildHeaderColumn('LOC', Icons.location_on_rounded, const Color(0xFFEF4444)),
                  _buildHeaderColumn('IMP', Icons.flight_land_rounded, const Color(0xFFF97316)),
                  _buildHeaderColumn('Priority', Icons.flag_rounded, const Color(0xFFF43F5E)),
                  _buildHeaderColumn('PO', Icons.inventory_2_rounded, const Color(0xFF16A34A)),
                  _buildHeaderColumn('GRN', Icons.local_shipping_rounded, const Color(0xFFD97706)),
                  _buildHeaderColumn('WO', Icons.construction_rounded, const Color(0xFF475569)),
                  _buildHeaderColumn('Rt', Icons.bar_chart_rounded, const Color(0xFF7C3AED)),
                ],
                rows: List.generate(list.length, (idx) {
                  final item = list[idx];
                  final bool isEven = idx % 2 == 0;
                  final Color rowBg = isEven ? Colors.white : const Color(0xFFF8FAFC);

                  return DataRow(
                    color: WidgetStateProperty.all(rowBg),
                    cells: [
                      // 1. SrNo
                      DataCell(
                        Text('${idx + 1}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ),
                      // 2. ChgId
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('#${item.chgId}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                        ),
                      ),
                      // 3. Charges Name
                      DataCell(
                        Text(item.chgName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ),
                      // 4. Disc
                      DataCell(
                        Text(item.disc > 0 ? '${item.disc}%' : '-', style: TextStyle(fontSize: 11.5, color: item.disc > 0 ? const Color(0xFF0D9488) : const Color(0xFF94A3B8))),
                      ),
                      // 5. Amount
                      DataCell(
                        Text(item.amount > 0 ? 'Rs. ${item.amount.toStringAsFixed(2)}' : '-', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: item.amount > 0 ? const Color(0xFFD97706) : const Color(0xFF94A3B8))),
                      ),
                      // 6. AddLess
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.addLess == '+' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.addLess,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: item.addLess == '+' ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ),
                      // 7. IIND
                      DataCell(_buildStatusBadge(item.iind, const Color(0xFF6366F1))),
                      // 8. IST
                      DataCell(_buildStatusBadge(item.ist, const Color(0xFF2563EB))),
                      // 9. Formula (Exp)
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            item.formula.isEmpty ? '-' : item.formula,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                        ),
                      ),
                      // 10. LOC
                      DataCell(_buildStatusBadge(item.loc, const Color(0xFFEF4444))),
                      // 11. IMP
                      DataCell(_buildStatusBadge(item.imp, const Color(0xFFF97316))),
                      // 12. Priority
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Text('P${item.priority}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE11D48))),
                        ),
                      ),
                      // 13. PO
                      DataCell(_buildStatusBadge(item.chgPO, const Color(0xFF16A34A))),
                      // 14. GRN
                      DataCell(_buildStatusBadge(item.chgGRN, const Color(0xFFD97706))),
                      // 15. WO
                      DataCell(_buildStatusBadge(item.chgWO, const Color(0xFF475569))),
                      // 16. Rt
                      DataCell(_buildStatusBadge(item.rt.toInt(), const Color(0xFF7C3AED))),
                    ],
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  DataColumn _buildHeaderColumn(String label, IconData icon, Color iconColor) {
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 13, color: iconColor),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(int val, Color accentColor) {
    final bool isActive = val == -1 || val > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? accentColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isActive ? accentColor.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
      ),
      child: Text(
        '$val',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isActive ? accentColor : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payments_outlined, size: 36, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          const Text('No Charges Master records found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(height: 4),
          const Text('Try adjusting your module, mode, or search filter', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  // ============================================================================
  // ── C. BOTTOM ACTION BAR (NEW TAX ADD + EXPORT, SAVE, CANCEL PANEL)
  // ============================================================================
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFFF8FAFC),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // In-Button Floating Notification Banner if any validation/error occurs
          if (_buttonValidationMsg != null) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _isNotificationError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: (_isNotificationError ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _isNotificationError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _buttonValidationMsg!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            children: [
              // Bottom-Left: New Tax Add Action Button (Triggers Screen 2)
              ElevatedButton.icon(
                onPressed: () {
                  if (widget.onNewTaxAdd != null) {
                    widget.onNewTaxAdd!();
                  } else {
                    _showButtonNotification('New Tax Add clicked (Triggers Screen 2)', isError: false);
                  }
                },
                icon: const Icon(Icons.add_circle_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'New Tax Add',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // Emerald Green
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const Spacer(),

              // Bottom-Right: Master Action Panel (Export, Save F1, Cancel)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Export Button
                  SizedBox(
                    width: 110,
                    child: AnimatedSuccessButton(
                      status: _exportStatus,
                      onPressed: _exportToExcel,
                      idleText: 'Export',
                      loadingText: 'Exporting...',
                      successText: 'Exported!',
                      errorText: 'Failed',
                      idleIcon: Icons.file_download_rounded,
                      idleBackgroundColor: const Color(0xFF0D9488), // Teal
                      successBackgroundColor: const Color(0xFF10B981),
                      height: 38,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Cancel / Reset Button
                  SizedBox(
                    width: 100,
                    child: AnimatedSuccessButton(
                      status: _cancelStatus,
                      onPressed: _handleCancel,
                      idleText: 'Cancel',
                      loadingText: 'Resetting...',
                      successText: 'Reset!',
                      errorText: 'Failed',
                      idleIcon: Icons.restart_alt_rounded,
                      idleBackgroundColor: const Color(0xFF64748B), // Slate Grey
                      successBackgroundColor: const Color(0xFF10B981),
                      height: 38,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Save (F1) Button
                  SizedBox(
                    width: 130,
                    child: AnimatedSuccessButton(
                      status: _saveStatus,
                      onPressed: _saveAllChanges,
                      idleText: 'Save (F1)',
                      loadingText: 'Saving...',
                      successText: 'Saved!',
                      errorText: 'Failed',
                      idleIcon: Icons.save_rounded,
                      idleBackgroundColor: const Color(0xFF0C3B2E), // Dark Green
                      successBackgroundColor: const Color(0xFF10B981),
                      height: 38,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ── IN-BUTTON FEEDBACK ANIMATED SUCCESS BUTTON WITH INTEGRATED LOADING/SUCCESS/SHAKE
// ============================================================================
class AnimatedSuccessButton extends StatefulWidget {
  final ButtonStatus status;
  final VoidCallback onPressed;
  final String idleText;
  final String loadingText;
  final String successText;
  final String errorText;
  final IconData idleIcon;
  final Color idleBackgroundColor;
  final Color successBackgroundColor;
  final double height;

  const AnimatedSuccessButton({
    super.key,
    required this.status,
    required this.onPressed,
    required this.idleText,
    required this.loadingText,
    required this.successText,
    this.errorText = 'Error',
    required this.idleIcon,
    required this.idleBackgroundColor,
    required this.successBackgroundColor,
    this.height = 36,
  });

  @override
  State<AnimatedSuccessButton> createState() => _AnimatedSuccessButtonState();
}

class _AnimatedSuccessButtonState extends State<AnimatedSuccessButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void didUpdateWidget(AnimatedSuccessButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == ButtonStatus.error && oldWidget.status != ButtonStatus.error) {
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = widget.status == ButtonStatus.loading;
    final bool isSuccess = widget.status == ButtonStatus.success;
    final bool isError = widget.status == ButtonStatus.error;

    final Color bgColor = isSuccess
        ? widget.successBackgroundColor
        : (isError
            ? const Color(0xFFEF4444)
            : (isLoading ? widget.idleBackgroundColor.withValues(alpha: 0.85) : widget.idleBackgroundColor));

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: InkWell(
            onTap: isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: widget.height,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isError ? const Color(0xFFDC2626) : Colors.transparent,
                  width: isError ? 1.5 : 0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else if (isSuccess)
                      const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white)
                    else if (isError)
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.white)
                    else
                      Icon(widget.idleIcon, size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      isLoading
                          ? widget.loadingText
                          : (isSuccess
                              ? widget.successText
                              : (isError ? widget.errorText : widget.idleText)),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
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
