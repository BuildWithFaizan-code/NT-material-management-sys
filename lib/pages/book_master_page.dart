import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../design/app_colors.dart';
import '../services/book_master_service.dart';
import '../utils/file_export_helper.dart';

enum ExportFormat { excel, pdf }
enum ButtonStatus { idle, loading, success }

// ============================================================================
// MAIN PAGE: BookMasterPage (Dual-Pane Category Allocation & Series Setup)
// ============================================================================
class BookMasterPage extends StatefulWidget {
  const BookMasterPage({super.key});

  @override
  State<BookMasterPage> createState() => _BookMasterPageState();
}

class _BookMasterPageState extends State<BookMasterPage> {
  final BookMasterService _service = BookMasterService();
  final FocusNode _pageKeyFocusNode = FocusNode();

  // Master State Data
  List<BookDetailItem> _allBooks = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Selected Active Book State
  bool _isEditing = false;
  int _formBookCode = 1;
  final TextEditingController _bookNameCtrl = TextEditingController();
  final TextEditingController _grnCtrl = TextEditingController();
  final TextEditingController _issueCtrl = TextEditingController();
  final TextEditingController _jobIssueCtrl = TextEditingController();
  final TextEditingController _jobReceiptCtrl = TextEditingController();

  final FocusNode _bookNameFocusNode = FocusNode();
  final FocusNode _grnFocusNode = FocusNode();
  final FocusNode _issueFocusNode = FocusNode();
  final FocusNode _jobIssueFocusNode = FocusNode();
  final FocusNode _jobReceiptFocusNode = FocusNode();

  // Category Transfer Lists
  List<CategoryItem> _availableCategories = [];
  List<CategoryItem> _assignedCategories = [];
  List<CategoryItem> _cachedAvailCats = [];
  List<CategoryItem> _cachedAssignCats = [];

  void _updateShuttleFilters() {
    _cachedAvailCats = _availableCategories.where((c) {
      if (_availQuery.isEmpty) return true;
      return c.catName.toLowerCase().contains(_availQuery.toLowerCase()) ||
          c.catCode.toString().contains(_availQuery);
    }).toList();
    _cachedAssignCats = _assignedCategories.where((c) {
      if (_assignQuery.isEmpty) return true;
      return c.catName.toLowerCase().contains(_assignQuery.toLowerCase()) ||
          c.catCode.toString().contains(_assignQuery);
    }).toList();
  }

  // Shuttle Transfer Multi-Selection Sets
  final Set<int> _selectedAvailableCodes = {};
  final Set<int> _selectedAssignedCodes = {};

  // Shuttle Search Controllers & Debounce
  final TextEditingController _searchAvailableCtrl = TextEditingController();
  final TextEditingController _searchAssignedCtrl = TextEditingController();
  String _availQuery = '';
  String _assignQuery = '';
  Timer? _availDebounce;
  Timer? _assignDebounce;

  // Button Action States
  bool _isSubmitting = false;
  bool _isSaveSuccess = false;
  String? _buttonValidationMsg;

  // Minimal Hover Success Toast State (Hovering on the left in header white space with rightward pointer arrow)
  String? _hoverSuccessMsg;
  Timer? _hoverMsgTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pageKeyFocusNode.dispose();
    _bookNameCtrl.dispose();
    _grnCtrl.dispose();
    _issueCtrl.dispose();
    _jobIssueCtrl.dispose();
    _jobReceiptCtrl.dispose();

    _bookNameFocusNode.dispose();
    _grnFocusNode.dispose();
    _issueFocusNode.dispose();
    _jobIssueFocusNode.dispose();
    _jobReceiptFocusNode.dispose();

    _searchAvailableCtrl.dispose();
    _searchAssignedCtrl.dispose();
    _availDebounce?.cancel();
    _assignDebounce?.cancel();
    _hoverMsgTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final books = await _service.getAllBooksWithDetails();
      final nextCode = await _service.getNextBookCode();

      if (!mounted) return;
      setState(() {
        _allBooks = books;
        _formBookCode = nextCode;
        _isLoading = false;
      });

      if (_allBooks.isNotEmpty) {
        _selectBookForEditing(_allBooks.first);
      } else {
        _prepareNewBook(nextCode);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to connect to Book Master API: $e';
      });
    }
  }

  Future<void> _prepareNewBook([int? code]) async {
    final nextCode = code ?? await _service.getNextBookCode();
    final availCats = await _service.getAvailableCategories(0);

    if (!mounted) return;
    setState(() {
      _isEditing = false;
      _formBookCode = nextCode;
      _bookNameCtrl.clear();
      _grnCtrl.clear();
      _issueCtrl.clear();
      _jobIssueCtrl.clear();
      _jobReceiptCtrl.clear();

      _availableCategories = availCats;
      _assignedCategories = [];
      _selectedAvailableCodes.clear();
      _selectedAssignedCodes.clear();
      _buttonValidationMsg = null;
    });
  }

  Future<void> _selectBookForEditing(BookDetailItem book) async {
    final availCats = await _service.getAvailableCategories(book.bookCode);

    if (!mounted) return;
    setState(() {
      _isEditing = true;
      _formBookCode = book.bookCode;
      _bookNameCtrl.text = book.bookName;
      _grnCtrl.text = book.grn;
      _issueCtrl.text = book.issue;
      _jobIssueCtrl.text = book.jobIssue;
      _jobReceiptCtrl.text = book.jobReceipt;

      _availableCategories = availCats;
      _assignedCategories = List.from(book.categories);
      _selectedAvailableCodes.clear();
      _selectedAssignedCodes.clear();
      _buttonValidationMsg = null;
    });
  }

  // --------------------------------------------------------------------------
  // SHUTTLE BOX TRANSFER OPERATIONS
  // --------------------------------------------------------------------------
  void _transferSelectedRight() {
    if (_selectedAvailableCodes.isEmpty) return;
    setState(() {
      final toMove = _availableCategories
          .where((c) => _selectedAvailableCodes.contains(c.catCode))
          .toList();
      _assignedCategories.addAll(toMove);
      _availableCategories.removeWhere((c) => _selectedAvailableCodes.contains(c.catCode));
      _selectedAvailableCodes.clear();
    });
  }

  void _transferSelectedLeft() {
    if (_selectedAssignedCodes.isEmpty) return;
    setState(() {
      final toMove = _assignedCategories
          .where((c) => _selectedAssignedCodes.contains(c.catCode))
          .toList();
      _availableCategories.addAll(toMove);
      _assignedCategories.removeWhere((c) => _selectedAssignedCodes.contains(c.catCode));
      _selectedAssignedCodes.clear();
    });
  }

  void _transferAllRight() {
    if (_availableCategories.isEmpty) return;
    setState(() {
      _assignedCategories.addAll(_availableCategories);
      _availableCategories.clear();
      _selectedAvailableCodes.clear();
    });
  }

  void _transferAllLeft() {
    if (_assignedCategories.isEmpty) return;
    setState(() {
      _availableCategories.addAll(_assignedCategories);
      _assignedCategories.clear();
      _selectedAssignedCodes.clear();
    });
  }

  // --------------------------------------------------------------------------
  // FORM SUBMISSION & DELETION WITH AUTOMATIC RESET
  // --------------------------------------------------------------------------
  void _showButtonValidation(String msg) {
    setState(() => _buttonValidationMsg = msg);
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && _buttonValidationMsg == msg) {
        setState(() => _buttonValidationMsg = null);
      }
    });
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    final name = _bookNameCtrl.text.trim();
    if (name.isEmpty) {
      _showButtonValidation('Please enter Book Name!');
      _bookNameFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _buttonValidationMsg = null;
    });

    final bool isCreatingNew = !_isEditing;
    final int savedCode = _formBookCode;

    final dto = BookSaveDto(
      bookCode: savedCode,
      bookName: name,
      grn: _grnCtrl.text.trim(),
      issue: _issueCtrl.text.trim(),
      jobIssue: _jobIssueCtrl.text.trim(),
      jobReceipt: _jobReceiptCtrl.text.trim(),
      selectedCatCodes: _assignedCategories.map((c) => c.catCode).toList(),
    );

    final success = await _service.saveBook(dto);

    if (mounted) {
      if (success) {
        setState(() {
          _isSubmitting = false;
          _isSaveSuccess = true;
          _hoverSuccessMsg = isCreatingNew ? 'Book Created!' : 'Book Updated!';
        });

        // Auto-dismiss hover message after 3.5 seconds
        _hoverMsgTimer?.cancel();
        _hoverMsgTimer = Timer(const Duration(milliseconds: 3500), () {
          if (mounted) {
            setState(() => _hoverSuccessMsg = null);
          }
        });

        // AUTOMATICALLY RESET FORM FIELDS & REFRESH DATA FOR NEXT ENTRY
        Future.delayed(const Duration(milliseconds: 800), () async {
          if (mounted) {
            setState(() => _isSaveSuccess = false);
            final updatedBooks = await _service.getAllBooksWithDetails();
            final nextCode = await _service.getNextBookCode();
            final availCats = await _service.getAvailableCategories(0);

            setState(() {
              _allBooks = updatedBooks;
              _isEditing = false;
              _formBookCode = nextCode;
              _bookNameCtrl.clear();
              _grnCtrl.clear();
              _issueCtrl.clear();
              _jobIssueCtrl.clear();
              _jobReceiptCtrl.clear();
              _availableCategories = availCats;
              _assignedCategories = [];
              _selectedAvailableCodes.clear();
              _selectedAssignedCodes.clear();
              _buttonValidationMsg = null;
            });
          }
        });
      } else {
        setState(() => _isSubmitting = false);
        _showButtonValidation('Failed to save Book record to SQL Server.');
      }
    }
  }

  Future<void> _deleteBook() async {
    if (!_isEditing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () async {
          final ok = await _service.deleteBook(_formBookCode);
          return ok;
        },
      ),
    );

    if (confirmed == true && mounted) {
      await _loadInitialData();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        _submitForm();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _prepareNewBook();
      }
    }
  }

  void _openExportModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _BookExportModalDialog(books: _allBooks),
    );
  }

  // --------------------------------------------------------------------------
  // BUILD METHOD
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _pageKeyFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF2FFFFFF),
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 1. SCREEN HEADER TOOLBAR
                    _buildScreenHeader(),
                    const SizedBox(height: 14),

                    // 2. MAIN WORKSPACE AREA
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                          : _errorMessage != null
                              ? _buildErrorState()
                              : Column(
                                  children: [
                                    // Top Book Name & Code Configuration Row
                                    _buildBookSetupCard(),
                                    const SizedBox(height: 12),

                                    // Dual-Pane Transfer Shuttle Box
                                    Expanded(child: _buildShuttleBoxSection()),
                                    const SizedBox(height: 12),

                                    // Bottom Series Setup Dashboard Strip & Action Row
                                    _buildSeriesSetupAndActionFooter(),
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

  // --------------------------------------------------------------------------
  // 1. SCREEN HEADER TOOLBAR (ROYAL SAPPHIRE, TOAST FLOATING ON LEFT WHITE SPACE)
  // --------------------------------------------------------------------------
  Widget _buildScreenHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          // 3D ANIMATED LOGO BADGE (SAPPHIRE BOOK EMBLEM)
          const _BookMasterHeaderLogoWidget(size: 46.0),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Book Master',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_allBooks.length} Books Configured',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── FLOATING MINT TOAST NOTIFICATION (HOVERING ON THE LEFT IN HEADER WHITE SPACE) ──
          if (_hoverSuccessMsg != null) ...[
            _MinimalHoverPointerToast(
              message: _hoverSuccessMsg!,
              onDismiss: () => setState(() => _hoverSuccessMsg = null),
            ),
            const SizedBox(width: 8),
          ],

          // ── MODERN GLASSMORPHIC "SELECT BOOK" DROPDOWN SELECTOR ──
          _ModernBookDropdownSelector(
            books: _allBooks,
            selectedBookCode: _formBookCode,
            onBookSelected: (selected) => _selectBookForEditing(selected),
            onNewBookTap: () => _prepareNewBook(),
          ),

          const SizedBox(width: 10),

          // ── "+ NEW BOOK" BUTTON (MATCHING PROJECT MASTER SECONDARY COLOR) ──
          _HoverTactileButton(
            onTap: _prepareNewBook,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.secondaryColor,
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondaryColor.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'New Book',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ANIMATED ORBIT EXPORT BUTTON (OPERATOR MASTER STYLE)
          _AnimatedExportButton(onPressed: _openExportModal),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 2. TOP BOOK SETUP CARD
  // --------------------------------------------------------------------------
  Widget _buildBookSetupCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Book Code Read-Only Badge
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.auto_stories_rounded, size: 14, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 8),
          const Text(
            'BOOK CODE:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB), letterSpacing: 0.5),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(
              '#$_formBookCode',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ),

          const SizedBox(width: 20),

          // Book Name Field
          const Text(
            'BOOK NAME:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: 0.5),
          ),
          const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),

          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _bookNameCtrl,
                focusNode: _bookNameFocusNode,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'e.g. STANDARD ISSUE BOOK',
                  hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                ),
              ),
            ),
          ),

          if (_isEditing) ...[
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Text(
                'EDITING #$_formBookCode',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 3. DUAL-PANE TRANSFER SHUTTLE BOX
  // --------------------------------------------------------------------------
  Widget _buildShuttleBoxSection() {
    return Row(
      children: [
        // Left Box: Unassigned Available Categories
        Expanded(
          child: _buildCategoryListBox(
            title: 'UNASSIGNED CATEGORIES',
            icon: Icons.grid_view_rounded,
            iconColor: const Color(0xFF64748B),
            badgeColor: const Color(0xFFF1F5F9),
            badgeTextColor: const Color(0xFF475569),
            badgeCount: _cachedAvailCats.length,
            searchCtrl: _searchAvailableCtrl,
            searchHint: 'Search available categories...',
            onSearchChanged: (val) => setState(() {
              _availQuery = val.trim();
              _updateShuttleFilters();
            }),
            categories: _cachedAvailCats,
            selectedCodes: _selectedAvailableCodes,
            onItemTap: (code) {
              setState(() {
                if (_selectedAvailableCodes.contains(code)) {
                  _selectedAvailableCodes.remove(code);
                } else {
                  _selectedAvailableCodes.add(code);
                }
              });
            },
            onItemDoubleTap: (item) {
              setState(() {
                _assignedCategories.add(item);
                _availableCategories.removeWhere((c) => c.catCode == item.catCode);
                _selectedAvailableCodes.remove(item.catCode);
                _updateShuttleFilters();
              });
            },
          ),
        ),

        // Center Shuttle Transfer Controls Column (Royal Blue Theme)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildShuttleActionButton(
                icon: Icons.keyboard_double_arrow_right_rounded,
                tooltip: 'Assign All',
                onTap: _transferAllRight,
              ),
              const SizedBox(height: 10),
              _buildShuttleActionButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Assign Selected',
                onTap: _transferSelectedRight,
              ),
              const SizedBox(height: 10),
              _buildShuttleActionButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Remove Selected',
                onTap: _transferSelectedLeft,
              ),
              const SizedBox(height: 10),
              _buildShuttleActionButton(
                icon: Icons.keyboard_double_arrow_left_rounded,
                tooltip: 'Remove All',
                onTap: _transferAllLeft,
              ),
            ],
          ),
        ),

        // Right Box: Assigned Categories for Active Book
        Expanded(
          child: _buildCategoryListBox(
            title: 'ASSIGNED BOOK CATEGORIES',
            icon: Icons.playlist_add_check_circle_rounded,
            iconColor: const Color(0xFF2563EB),
            badgeColor: const Color(0xFFEFF6FF),
            badgeTextColor: const Color(0xFF1D4ED8),
            badgeCount: _cachedAssignCats.length,
            searchCtrl: _searchAssignedCtrl,
            searchHint: 'Search assigned categories...',
            onSearchChanged: (val) => setState(() {
              _assignQuery = val.trim();
              _updateShuttleFilters();
            }),
            categories: _cachedAssignCats,
            selectedCodes: _selectedAssignedCodes,
            onItemTap: (code) {
              setState(() {
                if (_selectedAssignedCodes.contains(code)) {
                  _selectedAssignedCodes.remove(code);
                } else {
                  _selectedAssignedCodes.add(code);
                }
              });
            },
            onItemDoubleTap: (item) {
              setState(() {
                _availableCategories.add(item);
                _assignedCategories.removeWhere((c) => c.catCode == item.catCode);
                _selectedAssignedCodes.remove(item.catCode);
                _updateShuttleFilters();
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryListBox({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color badgeColor,
    required Color badgeTextColor,
    required int badgeCount,
    required TextEditingController searchCtrl,
    required String searchHint,
    required ValueChanged<String> onSearchChanged,
    required List<CategoryItem> categories,
    required Set<int> selectedCodes,
    required ValueChanged<int> onItemTap,
    required ValueChanged<CategoryItem> onItemDoubleTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // List Box Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$badgeCount items',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeTextColor),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar Input
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearchChanged,
                  style: const TextStyle(fontSize: 11.5),
                  decoration: InputDecoration(
                    hintText: searchHint,
                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 14, color: Color(0xFF64748B)),
                    suffixIcon: searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 12, color: Color(0xFF64748B)),
                            onPressed: () {
                              searchCtrl.clear();
                              onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: iconColor, width: 1.2)),
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Virtualized Category List
            Expanded(
              child: categories.isEmpty
                  ? Center(
                      child: Text(
                        'No categories found',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                      ),
                    )
                  : ListView.builder(
                      itemCount: categories.length,
                      itemExtent: 36.0,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemBuilder: (ctx, idx) {
                        final item = categories[idx];
                        final isSelected = selectedCodes.contains(item.catCode);

                        return InkWell(
                          onTap: () => onItemTap(item.catCode),
                          onDoubleTap: () => onItemDoubleTap(item),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? iconColor.withValues(alpha: 0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? iconColor.withValues(alpha: 0.4) : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                  size: 16,
                                  color: isSelected ? iconColor : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '#${item.catCode}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.catName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                    ),
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
  }

  Widget _buildShuttleActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return _HoverTactileButton(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 4. BOTTOM SERIES SETUP DASHBOARD STRIP & ACTION FOOTER
  // --------------------------------------------------------------------------
  Widget _buildSeriesSetupAndActionFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        children: [
          // 4 Compact Series Input Cards
          Row(
            children: [
              // GRN SERIES
              Expanded(
                child: _buildSeriesInputCard(
                  title: 'GRN SERIES',
                  icon: Icons.approval_rounded,
                  iconColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  controller: _grnCtrl,
                  focusNode: _grnFocusNode,
                  hint: 'e.g. GRN/2026',
                ),
              ),
              const SizedBox(width: 10),

              // ISSUE SERIES
              Expanded(
                child: _buildSeriesInputCard(
                  title: 'ISSUE SERIES',
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFE0F2FE),
                  controller: _issueCtrl,
                  focusNode: _issueFocusNode,
                  hint: 'e.g. ISS/2026',
                ),
              ),
              const SizedBox(width: 10),

              // JOB ISSUE SERIES
              Expanded(
                child: _buildSeriesInputCard(
                  title: 'JOB ISSUE SERIES',
                  icon: Icons.engineering_outlined,
                  iconColor: const Color(0xFFF43F5E),
                  bgColor: const Color(0xFFFFE4E6),
                  controller: _jobIssueCtrl,
                  focusNode: _jobIssueFocusNode,
                  hint: 'e.g. JBI/2026',
                ),
              ),
              const SizedBox(width: 10),

              // JOB RECEIPT SERIES
              Expanded(
                child: _buildSeriesInputCard(
                  title: 'JOB RECEIPT SERIES',
                  icon: Icons.receipt_long_outlined,
                  iconColor: const Color(0xFF059669),
                  bgColor: const Color(0xFFD1FAE5),
                  controller: _jobReceiptCtrl,
                  focusNode: _jobReceiptFocusNode,
                  hint: 'e.g. JBR/2026',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action Buttons Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isEditing) ...[
                OutlinedButton.icon(
                  onPressed: _deleteBook,
                  icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                  label: const Text('Delete Book', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 10),
              ],

              OutlinedButton.icon(
                onPressed: () => _prepareNewBook(),
                icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF475569)),
                label: const Text('Reset (Esc)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(width: 12),

              // ── PRIMARY SAVE / UPDATE BUTTON (REFINED SOFT MUTED GREEN THEME) ──
              SizedBox(
                width: 165,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_buttonValidationMsg != null) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                _buttonValidationMsg!,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    AnimatedSuccessButton(
                      status: _isSubmitting
                          ? ButtonStatus.loading
                          : (_isSaveSuccess ? ButtonStatus.success : ButtonStatus.idle),
                      onPressed: _submitForm,
                      idleText: _isEditing ? 'Update Book' : 'Save Book (F1)',
                      loadingText: 'Saving...',
                      successText: _isEditing ? 'Updated!' : 'Saved!',
                      idleIcon: _isEditing ? Icons.check_rounded : Icons.save_rounded,
                      idleBackgroundColor: AppColors.secondaryColor,
                      successBackgroundColor: const Color(0xFF10B981),
                      height: 38,
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

  Widget _buildSeriesInputCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
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
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 12, color: iconColor),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: iconColor, width: 1.2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 🌟 MODERN GLASSMORPHIC "SELECT BOOK" DROPDOWN SELECTOR WIDGET
// ============================================================================
class _ModernBookDropdownSelector extends StatefulWidget {
  final List<BookDetailItem> books;
  final int selectedBookCode;
  final ValueChanged<BookDetailItem> onBookSelected;
  final VoidCallback onNewBookTap;

  const _ModernBookDropdownSelector({
    required this.books,
    required this.selectedBookCode,
    required this.onBookSelected,
    required this.onNewBookTap,
  });

  @override
  State<_ModernBookDropdownSelector> createState() => _ModernBookDropdownSelectorState();
}

class _ModernBookDropdownSelectorState extends State<_ModernBookDropdownSelector> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismiss area when clicking outside
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeDropdown,
              child: Container(color: Colors.transparent),
            ),
          ),

          // Custom Popover Dropdown Container
          Positioned(
            width: math.max(size.width, 240.0),
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 6),
              child: Material(
                color: Colors.transparent,
                child: _ModernDropdownPopoverMenu(
                  books: widget.books,
                  selectedBookCode: widget.selectedBookCode,
                  onBookSelected: (book) {
                    _closeDropdown();
                    widget.onBookSelected(book);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedBook = widget.books.cast<BookDetailItem?>().firstWhere(
          (b) => b?.bookCode == widget.selectedBookCode,
          orElse: () => null,
        );

    final displayLabel = selectedBook != null
        ? '#${selectedBook.bookCode} - ${selectedBook.bookName}'
        : 'Select Book...';

    return CompositedTransformTarget(
      link: _layerLink,
      child: _HoverTactileButton(
        onTap: _toggleDropdown,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isOpen ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
              width: _isOpen ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isOpen
                    ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _isOpen ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Royal Blue Book Badge Icon
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.auto_stories_rounded, color: Colors.white, size: 12),
                ),
              ),
              const SizedBox(width: 8),

              // Title Label
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  displayLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 8),

              // Revolving Animated Chevron Icon
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── POPOVER MENU CONTAINER FOR MODERN DROPDOWN ──
class _ModernDropdownPopoverMenu extends StatefulWidget {
  final List<BookDetailItem> books;
  final int selectedBookCode;
  final ValueChanged<BookDetailItem> onBookSelected;

  const _ModernDropdownPopoverMenu({
    required this.books,
    required this.selectedBookCode,
    required this.onBookSelected,
  });

  @override
  State<_ModernDropdownPopoverMenu> createState() => _ModernDropdownPopoverMenuState();
}

class _ModernDropdownPopoverMenuState extends State<_ModernDropdownPopoverMenu> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.books.where((b) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return b.bookName.toLowerCase().contains(q) || b.bookCode.toString().contains(q);
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Input Header Inside Popover
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _query = val.trim()),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search books...',
                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 14, color: Color(0xFF2563EB)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 12, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2)),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Book List View
            Flexible(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No matching books', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
                    )
                  : Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final b = filtered[idx];
                        final isSelected = b.bookCode == widget.selectedBookCode;

                        return InkWell(
                          onTap: () => widget.onBookSelected(b),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '#${b.bookCode}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    b.bookName,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF2563EB)),
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
      ),
    );
  }
}

// ============================================================================
// 🌟 MINIMAL HOVERING SUCCESS TOAST (HOVERING ON LEFT SIDE IN HEADER WHITE SPACE)
// With Rightward Pointer Arrow pointing towards Select Book dropdown
// ============================================================================
class _MinimalHoverPointerToast extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _MinimalHoverPointerToast({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main Notification Card (Fresh Crisp Mint Glassmorphism)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.check_rounded, color: Colors.white, size: 10),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.close_rounded, size: 12, color: Color(0xFF047857)),
                ],
              ),
            ),

            // Rightward Pointer Arrow Tip pointing directly towards Select Book dropdown
            CustomPaint(
              size: const Size(6, 10),
              painter: _RightwardPointerArrowPainter(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightwardPointerArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();

    final paint = Paint()
      ..color = const Color(0xFFECFDF5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFA7F3D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 3D HEADER LOGO WIDGET (ROYAL SAPPHIRE BOOK EMBLEM)
// ============================================================================
// ============================================================================
// LOGO BADGE FOR BOOK MASTER (100% IDENTICAL TO IMAGE 2 WITH COOL GLOW)
// ============================================================================
class _BookMasterHeaderLogoWidget extends StatelessWidget {
  final double size;
  const _BookMasterHeaderLogoWidget({this.size = 46.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient Cool Glow (Blue & Purple Aura - Plain on white screen, no box)
          Container(
            width: size * 0.75,
            height: size * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFFA855F7).withValues(alpha: 0.40),
                  blurRadius: 22,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          // 100% Identical Vector Graphic Painter for Image 2 Logo
          CustomPaint(
            size: Size(size, size),
            painter: const _BookMasterImage2LogoPainter(),
          ),
        ],
      ),
    );
  }
}

class _BookMasterImage2LogoPainter extends CustomPainter {
  const _BookMasterImage2LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Linear Gradient from Electric Blue (top) to Vibrant Purple / Magenta (bottom)
    final Shader strokeShader = const LinearGradient(
      colors: [
        Color(0xFF2563EB), // Electric Royal Blue
        Color(0xFF6366F1), // Indigo
        Color(0xFF8B5CF6), // Purple
        Color(0xFFD946EF), // Magenta Pink
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final Shader ribbonFillShader = const LinearGradient(
      colors: [
        Color(0xFF93C5FD), // Light Cyan/Blue
        Color(0xFFC084FC), // Light Purple
        Color(0xFFF472B6), // Light Pink
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final Paint strokePaint = Paint()
      ..shader = strokeShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..shader = ribbonFillShader
      ..style = PaintingStyle.fill;

    // 1. TOP TAB LATCH (Centered above book cover)
    final RRect topTab = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.36, h * 0.05, w * 0.28, h * 0.09),
      const Radius.circular(4),
    );
    canvas.drawRRect(topTab, strokePaint);

    // 2. MAIN BOOK COVER (Rounded Rectangle)
    final RRect bookCover = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.12, w * 0.72, h * 0.68),
      const Radius.circular(10),
    );
    canvas.drawRRect(bookCover, strokePaint);

    // 3. INNER LEFT PAGE - LETTER 'A'
    final Path letterAPath = Path()
      ..moveTo(w * 0.28, h * 0.48)
      ..lineTo(w * 0.37, h * 0.30)
      ..lineTo(w * 0.46, h * 0.48);

    final Path crossBarPath = Path()
      ..moveTo(w * 0.31, h * 0.41)
      ..lineTo(w * 0.43, h * 0.41);

    final Path bottomBarAPath = Path()
      ..moveTo(w * 0.26, h * 0.48)
      ..lineTo(w * 0.48, h * 0.48);

    canvas.drawPath(letterAPath, strokePaint);
    canvas.drawPath(crossBarPath, strokePaint);
    canvas.drawPath(bottomBarAPath, strokePaint);

    // 4. INNER RIGHT PAGE - 4 HORIZONTAL LINES
    final double lineXStart = w * 0.54;
    final double lineXEnd = w * 0.74;
    final List<double> lineY = [h * 0.31, h * 0.37, h * 0.42, h * 0.48];

    for (final y in lineY) {
      canvas.drawLine(Offset(lineXStart, y), Offset(lineXEnd, y), strokePaint);
    }

    // 5. BOTTOM BAR INSIDE COVER
    final RRect bottomBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.65, w * 0.56, h * 0.09),
      const Radius.circular(5),
    );
    canvas.drawRRect(bottomBar, strokePaint);

    // 6. HANGING BOOKMARK RIBBON (Bottom Left with V-Notch Cut)
    final Path ribbonPath = Path()
      ..moveTo(w * 0.30, h * 0.65)
      ..lineTo(w * 0.30, h * 0.93)
      ..lineTo(w * 0.40, h * 0.85) // V-notch cut inner apex
      ..lineTo(w * 0.50, h * 0.93)
      ..lineTo(w * 0.50, h * 0.65)
      ..close();

    canvas.drawPath(ribbonPath, fillPaint);
    canvas.drawPath(ribbonPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// TACTILE HOVER BUTTON WIDGET
// ============================================================================
class _HoverTactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HoverTactileButton({required this.child, required this.onTap});

  @override
  State<_HoverTactileButton> createState() => _HoverTactileButtonState();
}

class _HoverTactileButtonState extends State<_HoverTactileButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: widget.child,
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED ORBIT EXPORT BUTTON & PAINTER (100% PARITY WITH OPERATOR MASTER)
// ============================================================================
class _AnimatedExportButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AnimatedExportButton({required this.onPressed});

  @override
  State<_AnimatedExportButton> createState() => _AnimatedExportButtonState();
}

class _AnimatedExportButtonState extends State<_AnimatedExportButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _isHovered = false;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerExport() {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    _ctrl.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _isAnimating = false);
        widget.onPressed();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _triggerExport,
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
                height: 38,
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
// 100% IDENTICAL EXPORT MODAL DIALOG (OPERATOR MASTER STYLE)
// ============================================================================
class _BookExportModalDialog extends StatefulWidget {
  final List<BookDetailItem> books;
  const _BookExportModalDialog({required this.books});

  @override
  State<_BookExportModalDialog> createState() => _BookExportModalDialogState();
}

class _BookExportModalDialogState extends State<_BookExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'

  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<int> _selectedBookCodes;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedBookCodes = widget.books.map((b) => b.bookCode).toSet();
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

  List<BookDetailItem> get _filteredPreviewBooks {
    if (_modalSearchQuery.isEmpty) return widget.books;
    return widget.books.where((b) {
      final codeStr = b.bookCode.toString();
      final nameStr = b.bookName.toLowerCase();
      return codeStr.contains(_modalSearchQuery) || nameStr.contains(_modalSearchQuery);
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final filtered = _filteredPreviewBooks;
    if (filtered.isEmpty) return false;
    return filtered.every((b) => _selectedBookCodes.contains(b.bookCode));
  }

  void _toggleSelectAllFiltered() {
    final filtered = _filteredPreviewBooks;
    setState(() {
      if (_isAllFilteredSelected) {
        for (var b in filtered) {
          _selectedBookCodes.remove(b.bookCode);
        }
      } else {
        for (var b in filtered) {
          _selectedBookCodes.add(b.bookCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedBookCodes.isEmpty) return;

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

  Future<void> _finalizeFileAndComplete() async {
    final selectedList = widget.books
        .where((b) => _selectedBookCodes.contains(b.bookCode))
        .toList();

    try {
      final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final String fileName = _selectedFormat == 'XLSX'
          ? 'Book_Master_$timeStamp.xlsx'
          : 'Book_Master_$timeStamp.pdf';

      final List<int>? fileBytes = _selectedFormat == 'XLSX'
          ? _generateExcelBytes(selectedList)
          : await _generatePdfBytes(selectedList);

      if (fileBytes == null) {
        throw Exception('Failed to generate export file bytes.');
      }

      await FileExportHelper.saveAndLaunchFile(
        bytes: fileBytes,
        fileName: fileName,
      );

      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _isExportSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  List<int>? _generateExcelBytes(List<BookDetailItem> records) {
    final excel = excel_pkg.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Book Master');
    final excel_pkg.Sheet sheet = excel['Book Master'];

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

    sheet.setColumnWidth(0, 14.0);
    sheet.setColumnWidth(1, 35.0);
    sheet.setColumnWidth(2, 18.0);
    sheet.setColumnWidth(3, 18.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 18.0);

    sheet.setRowHeight(0, 26.0);
    sheet.appendRow([
      excel_pkg.TextCellValue('BOOK CODE'),
      excel_pkg.TextCellValue('BOOK NAME'),
      excel_pkg.TextCellValue('GRN SERIES'),
      excel_pkg.TextCellValue('ISSUE SERIES'),
      excel_pkg.TextCellValue('JOB ISSUE SERIES'),
      excel_pkg.TextCellValue('JOB RECEIPT SERIES'),
    ]);

    for (int col = 0; col < 6; col++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (int i = 0; i < records.length; i++) {
      final b = records[i];
      final style = (i % 2 == 0) ? evenStyle : oddStyle;
      final int rIdx = i + 1;

      sheet.setRowHeight(rIdx, 22.0);
      sheet.appendRow([
        excel_pkg.IntCellValue(b.bookCode),
        excel_pkg.TextCellValue(b.bookName),
        excel_pkg.TextCellValue(b.grn),
        excel_pkg.TextCellValue(b.issue),
        excel_pkg.TextCellValue(b.jobIssue),
        excel_pkg.TextCellValue(b.jobReceipt),
      ]);

      for (int col = 0; col < 6; col++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
      }
    }

    return excel.save();
  }

  Future<List<int>> _generatePdfBytes(List<BookDetailItem> records) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 1000,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'BOOK MASTER CONFIGURATION REPORT',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                ),
                pw.Text(
                  'NEW TECH INFOSOL MMS',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, color: PdfColors.teal800),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated on: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['CODE', 'BOOK NAME', 'GRN', 'ISSUE', 'JOB ISSUE', 'JOB RECEIPT'],
            data: records.map((b) => [
              '#${b.bookCode}',
              b.bookName,
              b.grn,
              b.issue,
              b.jobIssue,
              b.jobReceipt,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0C3B2E)),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.center,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          ),
        ],
      ),
    );

    return pdf.save();
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
            child: Row(
              children: [
                // LEFT COLUMN: Format Selector & Options (440px)
                SizedBox(
                  width: 440,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C3B2E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.sim_card_download_outlined, color: Color(0xFF0C3B2E), size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Export Book Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                SizedBox(height: 2),
                                Text('Select format & download records to PC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        const Text('Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 12),

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
                            backgroundColor: const Color(0xFFE2E8F0),
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

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12.5)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AnimatedSuccessButton(
                                status: _isExportSuccess
                                    ? ButtonStatus.success
                                    : (_isExporting ? ButtonStatus.loading : ButtonStatus.idle),
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

                // RIGHT COLUMN: Interactive Table Preview Box
                Expanded(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildPreviewTableToolbar(),
                        const SizedBox(height: 14),

                        Expanded(
                          child: _buildPreviewDataTable(),
                        ),
                      ],
                    ),
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
      onTap: () => setState(() => _selectedFormat = formatKey),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? brandColor : const Color(0xFFCBD5E1),
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
                  color: isSelected ? brandColor : const Color(0xFF94A3B8),
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
            height: 36,
            child: TextField(
              controller: _modalSearchCtrl,
              style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
              decoration: InputDecoration(
                hintText: 'Search books...',
                hintStyle: TextStyle(fontSize: 11.5, color: AppColors.neutralDark.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF10B981)),
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
              activeColor: const Color(0xFF10B981),
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
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_selectedBookCodes.length} of ${widget.books.length} selected',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final previewList = _filteredPreviewBooks;

    if (previewList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'No Book records found',
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
                  Expanded(child: Text('BOOK NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 80, child: Text('GRN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final item = previewList[idx];
                  final isSelected = _selectedBookCodes.contains(item.bookCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedBookCodes.remove(item.bookCode);
                        } else {
                          _selectedBookCodes.add(item.bookCode);
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedBookCodes.add(item.bookCode);
                                  } else {
                                    _selectedBookCodes.remove(item.bookCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              '#${item.bookCode}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.bookName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              item.grn.isNotEmpty ? item.grn : '-',
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
// RICH 3D VECTOR BRAND LOGO WIDGETS (EXCEL & PDF)
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

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F6C36), Color(0xFF107C41), Color(0xFF1F9A55)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

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

    final linePaint = Paint()
      ..color = const Color(0xFF107C41).withValues(alpha: 0.35)
      ..strokeWidth = w * 0.045;

    canvas.drawLine(Offset(w * 0.45, h * 0.28), Offset(w * 0.92, h * 0.28), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.50), Offset(w * 0.92, h * 0.50), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.72), Offset(w * 0.92, h * 0.72), linePaint);
    canvas.drawLine(Offset(w * 0.68, h * 0.12), Offset(w * 0.68, h * 0.88), linePaint);

    final platePath = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * 0.52, h), Radius.circular(w * 0.18)));

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

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF43F5E), Color(0xFFE11D48), Color(0xFFBE123C)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final glossPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.85, 0)
      ..lineTo(0, h * 0.85)
      ..close();

    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15);
    canvas.drawPath(glossPath, glossPaint);

    final ribbonPath = Path()
      ..moveTo(w * 0.22, h * 0.72)
      ..cubicTo(w * 0.25, h * 0.45, w * 0.42, h * 0.22, w * 0.52, h * 0.22)
      ..cubicTo(w * 0.62, h * 0.22, w * 0.78, h * 0.52, w * 0.78, h * 0.72)
      ..cubicTo(w * 0.70, h * 0.60, w * 0.58, h * 0.45, w * 0.48, h * 0.55)
      ..cubicTo(w * 0.38, h * 0.65, w * 0.28, h * 0.72, w * 0.22, h * 0.72);

    final ribbonPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(ribbonPath, ribbonPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.26,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.28, h * 0.68));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 100% IDENTICAL STANDARDIZED DELETE CONFIRMATION DIALOG & VECTOR PAINTER
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

            SizedBox(
              width: 180,
              height: 130,
              child: CustomPaint(
                painter: const _IdenticalDeleteDialogIllustrationPainter(),
              ),
            ),
            const SizedBox(height: 16),

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

            Row(
              children: [
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

class _IdenticalDeleteDialogIllustrationPainter extends CustomPainter {
  const _IdenticalDeleteDialogIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shadowPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawOval(Rect.fromLTWH(w * 0.12, h * 0.78, w * 0.76, h * 0.12), shadowPaint);

    final windowPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final leftWin = Rect.fromLTWH(w * 0.22, h * 0.16, w * 0.24, h * 0.38);
    canvas.drawRRect(RRect.fromRectAndRadius(leftWin, const Radius.circular(3)), windowPaint);
    canvas.drawLine(Offset(leftWin.left + leftWin.width / 2, leftWin.top), Offset(leftWin.left + leftWin.width / 2, leftWin.bottom), windowPaint);
    canvas.drawLine(Offset(leftWin.left, leftWin.top + leftWin.height / 2), Offset(leftWin.right, leftWin.top + leftWin.height / 2), windowPaint);

    final rightWin = Rect.fromLTWH(w * 0.54, h * 0.20, w * 0.22, h * 0.28);
    canvas.drawRRect(RRect.fromRectAndRadius(rightWin, const Radius.circular(3)), windowPaint);

    final binBody = Path()
      ..moveTo(w * 0.60, h * 0.48)
      ..lineTo(w * 0.80, h * 0.48)
      ..lineTo(w * 0.77, h * 0.86)
      ..lineTo(w * 0.63, h * 0.86)
      ..close();
    canvas.drawPath(binBody, Paint()..color = const Color(0xFFEF4444));

    final stripePaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(w * 0.65, h * 0.50), Offset(w * 0.66, h * 0.84), stripePaint);
    canvas.drawLine(Offset(w * 0.70, h * 0.50), Offset(w * 0.70, h * 0.84), stripePaint);
    canvas.drawLine(Offset(w * 0.75, h * 0.50), Offset(w * 0.74, h * 0.84), stripePaint);

    final binLid = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.58, h * 0.44, w * 0.24, h * 0.06), const Radius.circular(3));
    canvas.drawRRect(binLid, Paint()..color = const Color(0xFFEF4444));

    final skinPaint = Paint()..color = const Color(0xFFFFCCBC);
    final hairPaint = Paint()..color = const Color(0xFF0F172A);
    final coralShirtPaint = Paint()..color = const Color(0xFFEF4444);
    final navyPantsPaint = Paint()..color = const Color(0xFF1E293B);

    final headCenter = Offset(w * 0.38, h * 0.32);
    canvas.drawCircle(headCenter, w * 0.07, skinPaint);
    final hairPath = Path()
      ..addArc(Rect.fromCircle(center: headCenter, radius: w * 0.07), math.pi, math.pi);
    canvas.drawPath(hairPath, hairPaint);

    canvas.drawRect(Rect.fromLTWH(w * 0.33, h * 0.39, w * 0.10, h * 0.18), coralShirtPaint);

    final armPath = Path()
      ..moveTo(w * 0.38, h * 0.41)
      ..lineTo(w * 0.55, h * 0.37)
      ..lineTo(w * 0.55, h * 0.44)
      ..lineTo(w * 0.38, h * 0.48)
      ..close();
    canvas.drawPath(armPath, coralShirtPaint);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.53, h * 0.41, 14, 10), const Radius.circular(2)), Paint()..color = const Color(0xFFF87171));

    canvas.drawRect(Rect.fromLTWH(w * 0.33, h * 0.57, w * 0.04, h * 0.25), navyPantsPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.39, h * 0.57, w * 0.04, h * 0.25), navyPantsPaint);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.31, h * 0.81, w * 0.07, h * 0.04), const Radius.circular(2)), coralShirtPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.38, h * 0.81, w * 0.07, h * 0.04), const Radius.circular(2)), coralShirtPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ANIMATED SUCCESS BUTTON WITH INTEGRATED LOADING/SUCCESS/SHAKE
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
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
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

    final Color bgColor = isSuccess ? widget.successBackgroundColor : (isLoading ? widget.idleBackgroundColor.withValues(alpha: 0.85) : widget.idleBackgroundColor);

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: InkWell(
            onTap: isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: widget.height,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else if (isSuccess)
                      const Icon(Icons.check_circle_rounded, size: 15, color: Colors.white)
                    else
                      Icon(widget.idleIcon, size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      isLoading ? widget.loadingText : (isSuccess ? widget.successText : widget.idleText),
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
