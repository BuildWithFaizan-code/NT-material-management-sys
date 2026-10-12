import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design/app_colors.dart';
import '../po_advance_models.dart';

class PoAdvancePartyLookupModal extends StatefulWidget {
  final List<PoAdvancePartyLookup> parties;
  final Function(PoAdvancePartyLookup) onSelect;

  const PoAdvancePartyLookupModal({
    super.key,
    required this.parties,
    required this.onSelect,
  });

  @override
  State<PoAdvancePartyLookupModal> createState() => _PoAdvancePartyLookupModalState();
}

class _PoAdvancePartyLookupModalState extends State<PoAdvancePartyLookupModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  String _selectedAlphabet = 'ALL';
  int _selectedIndex = 0;

  static const List<String> _alphabets = [
    'ALL', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
        _selectedIndex = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<PoAdvancePartyLookup> get _filteredParties {
    return widget.parties.where((p) {
      final name = p.pName.toLowerCase();
      final code = p.pCode.toString();

      // 1. Alphabetical filter
      if (_selectedAlphabet != 'ALL') {
        if (!name.startsWith(_selectedAlphabet.toLowerCase())) {
          return false;
        }
      }

      // 2. Search query filter
      if (_searchQuery.isNotEmpty) {
        return name.contains(_searchQuery) || code.contains(_searchQuery);
      }

      return true;
    }).toList();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final list = _filteredParties;
    if (list.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, list.length - 1);
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, list.length - 1);
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_selectedIndex >= 0 && _selectedIndex < list.length) {
        widget.onSelect(list[_selectedIndex]);
        Navigator.of(context).pop();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    const itemHeight = 38.0;
    final target = _selectedIndex * itemHeight;
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredParties;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Container(
          width: 780,
          constraints: const BoxConstraints(maxHeight: 680),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. TOP HEADER BAR (Group Master show-record parity)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.manage_search_rounded,
                        color: AppColors.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Approved Supplier / Party',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Suppliers with approved active purchase orders',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Count Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Text(
                        '${list.length} / ${widget.parties.length} Parties',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Keyboard Helper Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.swap_vert_rounded, size: 13, color: Color(0xFF64748B)),
                          SizedBox(width: 4),
                          Text(
                            '↑/↓ navigate | Enter select | Esc close',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. SEARCH INPUT
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _searchQuery.isNotEmpty ? AppColors.secondaryColor : const Color(0xFFCBD5E1),
                      width: 1.1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Type to filter by Supplier Name, Code...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 17, color: AppColors.primaryColor),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 38),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 15, color: Color(0xFF64748B)),
                              onPressed: () => _searchCtrl.clear(),
                              splashRadius: 12,
                              padding: EdgeInsets.zero,
                            )
                          : null,
                      suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 38),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                      isDense: true,
                    ),
                  ),
                ),
              ),

              // 3. A TO Z ALPHABETICAL FILTER BAR (Group Master parity)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _alphabets.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(width: 4),
                    itemBuilder: (ctx, idx) {
                      final alpha = _alphabets[idx];
                      final isSelected = _selectedAlphabet == alpha;

                      return InkWell(
                        onTap: () => setState(() {
                          _selectedAlphabet = alpha;
                          _selectedIndex = 0;
                        }),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: EdgeInsets.symmetric(
                            horizontal: alpha == 'ALL' ? 10 : 8,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryColor : const Color(0xFFCBD5E1),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryColor.withValues(alpha: 0.25),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            alpha,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // 4. TABLE HEADER
              Container(
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Center(
                        child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text('CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    Expanded(
                      child: Text('SUPPLIER / PARTY NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                    SizedBox(
                      width: 140,
                      child: Center(
                        child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. TABLE BODY
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 18, right: 18, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: list.isEmpty
                      ? const Center(
                          child: Text(
                            'No approved suppliers found matching your filter',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          itemCount: list.length,
                          separatorBuilder: (ctx, idx) => const Divider(height: 1, thickness: 1, color: Color(0xFFF8FAFC)),
                          itemBuilder: (ctx, idx) {
                            final party = list[idx];
                            final isHighlight = idx == _selectedIndex;

                            return InkWell(
                              onTap: () {
                                widget.onSelect(party);
                                Navigator.of(context).pop();
                              },
                              hoverColor: const Color(0xFFF1F5F9),
                              child: Container(
                                height: 38,
                                color: isHighlight
                                    ? AppColors.primaryColor.withValues(alpha: 0.08)
                                    : (idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA)),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      child: Center(
                                        child: Text(
                                          '${idx + 1}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Text(
                                          '${party.pCode}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'monospace',
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        party.pName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 140,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFA7F3D0)),
                                          ),
                                          child: const Text(
                                            'Approved PO',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF047857),
                                            ),
                                          ),
                                        ),
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
        ),
      ),
    );
  }
}
