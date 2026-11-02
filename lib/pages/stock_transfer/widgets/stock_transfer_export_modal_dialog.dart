import 'dart:async';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../design/app_colors.dart';
import '../../../utils/file_export_helper.dart';
import '../stock_transfer_models.dart';

String _formatDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _formatTimestamp() {
  final now = DateTime.now();
  final y = now.year.toString();
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  final h = now.hour.toString().padLeft(2, '0');
  final min = now.minute.toString().padLeft(2, '0');
  return '$y$m${d}_$h$min';
}

class StockTransferExportModalDialog extends StatefulWidget {
  final List<StockTransferGridRecord> records;

  const StockTransferExportModalDialog({super.key, required this.records});

  @override
  State<StockTransferExportModalDialog> createState() => _StockTransferExportModalDialogState();
}

class _StockTransferExportModalDialogState extends State<StockTransferExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  late Set<String> _selectedCodes;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _selectedCodes = widget.records.map((r) => r.issueCode).toSet();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<StockTransferGridRecord> get _filteredRecords {
    if (_searchQuery.isEmpty) return widget.records;
    final q = _searchQuery.toLowerCase();
    return widget.records.where((r) {
      return r.issueCode.toLowerCase().contains(q) ||
          r.sourceStoreName.toLowerCase().contains(q) ||
          r.sourceDeptName.toLowerCase().contains(q) ||
          r.plantName.toLowerCase().contains(q) ||
          r.remark.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _handleDownload() async {
    final selectedList = widget.records.where((r) => _selectedCodes.contains(r.issueCode)).toList();
    if (selectedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one record to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final stamp = _formatTimestamp();

      if (_selectedFormat == 'XLSX') {
        final fileName = 'STOCK_TRANSFER_$stamp.xlsx';
        final excel = excel_pkg.Excel.createExcel();
        final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
        final sheet = excel[sheetName];

        final headers = [
          '#',
          'ISSUE CODE',
          'DATE',
          'MODE',
          'FROM STORE',
          'FROM DEPT',
          'PLANT',
          'ITEMS',
          'TOTAL PCS',
          'TOTAL QTY',
          'REMARK',
          'CREATED BY',
        ];

        sheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());

        for (int i = 0; i < selectedList.length; i++) {
          final r = selectedList[i];
          sheet.appendRow([
            excel_pkg.IntCellValue(i + 1),
            excel_pkg.TextCellValue(r.issueCode),
            excel_pkg.TextCellValue(_formatDate(r.issueDate)),
            excel_pkg.TextCellValue(r.issueMode),
            excel_pkg.TextCellValue(r.sourceStoreName),
            excel_pkg.TextCellValue(r.sourceDeptName),
            excel_pkg.TextCellValue(r.plantName),
            excel_pkg.IntCellValue(r.totItm),
            excel_pkg.DoubleCellValue(r.totPcs),
            excel_pkg.DoubleCellValue(r.totQty),
            excel_pkg.TextCellValue(r.remark),
            excel_pkg.TextCellValue(r.createdBy),
          ]);
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: fileBytes, fileName: fileName);
        }
      } else {
        // PDF Export
        final fileName = 'STOCK_TRANSFER_$stamp.pdf';
        final pdf = pw.Document();

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(20),
            header: (ctx) => pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('NEWTECH INFOSOL - STOCK TRANSFER REGISTER',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                      pw.Text('Total Exported Records: ${selectedList.length}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text('Generated: ${_formatDate(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            build: (ctx) => [
              pw.TableHelper.fromTextArray(
                headers: ['#', 'CODE', 'DATE', 'STORE', 'DEPARTMENT', 'PLANT', 'ITM', 'PCS', 'QTY', 'REMARK'],
                data: selectedList.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final r = entry.value;
                  return [
                    '$idx',
                    r.issueCode,
                    _formatDate(r.issueDate),
                    r.sourceStoreName,
                    r.sourceDeptName,
                    r.plantName,
                    '${r.totItm}',
                    r.totPcs.toStringAsFixed(0),
                    r.totQty.toStringAsFixed(2),
                    r.remark,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F172A')),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              ),
            ],
          ),
        );

        final pdfBytes = await pdf.save();
        await FileExportHelper.saveAndLaunchFile(bytes: pdfBytes, fileName: fileName);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildFormatCard(String format, String label, IconData icon, Color color) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      onTap: () => setState(() => _selectedFormat = format),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;
    final allSelected = filtered.isNotEmpty && filtered.every((r) => _selectedCodes.contains(r.issueCode));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 780,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.download, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  const Text('Export Stock Transfers',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // Format Selection
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Export Format',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFormatCard('XLSX', 'Excel (.xlsx)', Icons.table_chart, const Color(0xFF107C41)),
                      const SizedBox(width: 16),
                      _buildFormatCard('PDF', 'PDF Document', Icons.picture_as_pdf, const Color(0xFFE11D48)),
                    ],
                  ),
                ],
              ),
            ),

            // Filter & Select All Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedCodes.addAll(filtered.map((r) => r.issueCode));
                        } else {
                          for (final r in filtered) {
                            _selectedCodes.remove(r.issueCode);
                          }
                        }
                      });
                    },
                  ),
                  Text('Select All (${_selectedCodes.length}/${widget.records.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v.trim()),
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Filter records...',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.search, size: 16),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Records List Preview
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (ctx, idx) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = filtered[i];
                  final isChecked = _selectedCodes.contains(r.issueCode);

                  return CheckboxListTile(
                    value: isChecked,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedCodes.add(r.issueCode);
                        } else {
                          _selectedCodes.remove(r.issueCode);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        Text(r.issueCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(width: 12),
                        Text(_formatDate(r.issueDate), style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                        const SizedBox(width: 16),
                        Text(r.sourceStoreName, style: const TextStyle(fontSize: 11.5)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 8),
                        Text(r.sourceDeptName, style: const TextStyle(fontSize: 11.5)),
                      ],
                    ),
                    subtitle: Text('Items: ${r.totItm} | Total Qty: ${r.totQty.toStringAsFixed(2)} | Pcs: ${r.totPcs.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  );
                },
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : _handleDownload,
                    icon: _isExporting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download, size: 16),
                    label: Text(_isExporting ? 'Exporting...' : 'Download $_selectedFormat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
