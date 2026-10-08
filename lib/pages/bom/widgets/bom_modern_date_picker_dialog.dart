import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows the ultra-modern, glassmorphic ERP Date Picker Dialog.
Future<DateTime?> showModernDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  return showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => BomModernDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2035),
    ),
  );
}

enum _PickerViewMode { days, months, years }

/// ULTRA-MODERN ERP DATE PICKER DIALOG
/// Replaces Flutter's default Material date picker with a sleek, responsive,
/// glassmorphic calendar featuring quick presets, year/month jumpers,
/// smooth hover transitions, and keyboard navigation.
class BomModernDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const BomModernDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<BomModernDatePickerDialog> createState() => _BomModernDatePickerDialogState();
}

class _BomModernDatePickerDialogState extends State<BomModernDatePickerDialog> {
  late DateTime _selectedDate;
  late DateTime _viewMonth;
  _PickerViewMode _viewMode = _PickerViewMode.days;
  final FocusNode _focusNode = FocusNode();

  static const List<String> _weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
  static const List<String> _monthsFull = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const List<String> _monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const List<String> _weekdaysFull = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    _viewMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isDateInRange(DateTime d) {
    final start = DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    final end = DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  void _prevMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
    });
  }

  void _prevYear() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year - 1, _viewMonth.month, 1);
    });
  }

  void _nextYear() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year + 1, _viewMonth.month, 1);
    });
  }

  void _applyPreset(DateTime date) {
    if (_isDateInRange(date)) {
      setState(() {
        _selectedDate = date;
        _viewMonth = DateTime(date.year, date.month, 1);
      });
    }
  }

  void _confirmSelection() {
    Navigator.of(context).pop(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            _confirmSelection();
          }
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 410,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                _buildPresetsBar(),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _buildMonthNavigator(),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildCurrentView(),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TOP HEADER: BRAND ICON + SELECTED DATE PREVIEW + CLOSE BUTTON
  // --------------------------------------------------------------------------
  Widget _buildHeader() {
    final weekdayName = _weekdaysFull[_selectedDate.weekday - 1];
    final monthName = _monthsShort[_selectedDate.month - 1];
    final dayStr = _selectedDate.day.toString().padLeft(2, '0');
    final yearStr = _selectedDate.year.toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          // Sleek Calendar Icon Badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.event_available_rounded, color: Color(0xFF059669), size: 22),
          ),
          const SizedBox(width: 12),

          // Date Display
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'SELECT TRANSACTION DATE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (_isToday(_selectedDate)) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TODAY',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$weekdayName, $dayStr $monthName $yearStr',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),

          // Close Button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 19, color: Color(0xFF64748B)),
            tooltip: 'Cancel (Esc)',
            style: IconButton.styleFrom(
              hoverColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // QUICK PRESETS: TODAY, YESTERDAY, START OF MONTH, END OF MONTH
  // --------------------------------------------------------------------------
  Widget _buildPresetsBar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final startOfMonth = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final nextMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
    final endOfMonth = nextMonth.subtract(const Duration(days: 1));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          _buildPresetChip('Today', today),
          const SizedBox(width: 6),
          _buildPresetChip('Yesterday', yesterday),
          const SizedBox(width: 6),
          _buildPresetChip('1st of Month', startOfMonth),
          const SizedBox(width: 6),
          _buildPresetChip('End of Month', endOfMonth),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, DateTime targetDate) {
    final isSelected = _isSameDay(_selectedDate, targetDate);

    return InkWell(
      onTap: () => _applyPreset(targetDate),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // MONTH & YEAR NAVIGATOR BAR
  // --------------------------------------------------------------------------
  Widget _buildMonthNavigator() {
    final monthName = _monthsFull[_viewMonth.month - 1];
    final yearStr = _viewMonth.year.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Fast Year Jump Backwards
          _buildNavButton(
            icon: Icons.keyboard_double_arrow_left_rounded,
            tooltip: 'Previous Year',
            onTap: _prevYear,
          ),
          const SizedBox(width: 4),

          // Previous Month
          _buildNavButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous Month',
            onTap: _prevMonth,
          ),

          const Spacer(),

          // Month / Year Mode Toggle Button
          InkWell(
            onTap: () {
              setState(() {
                if (_viewMode == _PickerViewMode.days) {
                  _viewMode = _PickerViewMode.months;
                } else if (_viewMode == _PickerViewMode.months) {
                  _viewMode = _PickerViewMode.years;
                } else {
                  _viewMode = _PickerViewMode.days;
                }
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$monthName $yearStr',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    _viewMode == _PickerViewMode.days
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 16,
                    color: const Color(0xFF059669),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Next Month
          _buildNavButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next Month',
            onTap: _nextMonth,
          ),
          const SizedBox(width: 4),

          // Fast Year Jump Forward
          _buildNavButton(
            icon: Icons.keyboard_double_arrow_right_rounded,
            tooltip: 'Next Year',
            onTap: _nextYear,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF475569)),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SWITCHABLE VIEWS: DAYS GRID, MONTHS GRID, OR YEARS GRID
  // --------------------------------------------------------------------------
  Widget _buildCurrentView() {
    switch (_viewMode) {
      case _PickerViewMode.months:
        return _buildMonthsGrid();
      case _PickerViewMode.years:
        return _buildYearsGrid();
      case _PickerViewMode.days:
        return _buildDaysGrid();
    }
  }

  // --------------------------------------------------------------------------
  // DAYS GRID VIEW
  // --------------------------------------------------------------------------
  Widget _buildDaysGrid() {
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_viewMonth.year, _viewMonth.month, 1).weekday % 7; // Sunday=0

    final prevMonthDays = DateTime(_viewMonth.year, _viewMonth.month, 0).day;
    final totalCells = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Weekday Labels
          Row(
            children: _weekdays.map((wd) {
              final isWeekend = wd == 'SUN' || wd == 'SAT';
              return Expanded(
                child: Center(
                  child: Text(
                    wd,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isWeekend ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),

          // Grid of Days
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              DateTime dayDate;
              bool isAdjacentMonth = false;

              if (index < firstWeekday) {
                // Days from previous month
                final dayNumber = prevMonthDays - (firstWeekday - 1 - index);
                dayDate = DateTime(_viewMonth.year, _viewMonth.month - 1, dayNumber);
                isAdjacentMonth = true;
              } else if (index >= firstWeekday + daysInMonth) {
                // Days from next month
                final dayNumber = index - (firstWeekday + daysInMonth) + 1;
                dayDate = DateTime(_viewMonth.year, _viewMonth.month + 1, dayNumber);
                isAdjacentMonth = true;
              } else {
                // Days of current month
                final dayNumber = index - firstWeekday + 1;
                dayDate = DateTime(_viewMonth.year, _viewMonth.month, dayNumber);
              }

              final isSelected = _isSameDay(_selectedDate, dayDate);
              final isToday = _isToday(dayDate);
              final isEnabled = _isDateInRange(dayDate);

              return _ModernDayCell(
                date: dayDate,
                isSelected: isSelected,
                isToday: isToday,
                isAdjacentMonth: isAdjacentMonth,
                isEnabled: isEnabled,
                onTap: isEnabled
                    ? () {
                        setState(() {
                          _selectedDate = dayDate;
                          if (isAdjacentMonth) {
                            _viewMonth = DateTime(dayDate.year, dayDate.month, 1);
                          }
                        });
                      }
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // MONTHS GRID VIEW
  // --------------------------------------------------------------------------
  Widget _buildMonthsGrid() {
    return Container(
      height: 240,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: GridView.builder(
        itemCount: 12,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
        ),
        itemBuilder: (context, index) {
          final monthIndex = index + 1;
          final isSelected = _viewMonth.month == monthIndex;
          final isCurrent = DateTime.now().month == monthIndex && DateTime.now().year == _viewMonth.year;

          return InkWell(
            onTap: () {
              setState(() {
                _viewMonth = DateTime(_viewMonth.year, monthIndex, 1);
                _viewMode = _PickerViewMode.days;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF059669)
                    : (isCurrent ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF059669)
                      : (isCurrent ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _monthsShort[index].toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : (isCurrent ? const Color(0xFF059669) : const Color(0xFF334155)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // YEARS GRID VIEW
  // --------------------------------------------------------------------------
  Widget _buildYearsGrid() {
    final startYear = widget.firstDate.year;
    final endYear = widget.lastDate.year;
    final years = List.generate(endYear - startYear + 1, (i) => startYear + i);

    return Container(
      height: 240,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: GridView.builder(
        itemCount: years.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.5,
        ),
        itemBuilder: (context, index) {
          final year = years[index];
          final isSelected = _viewMonth.year == year;
          final isCurrent = DateTime.now().year == year;

          return InkWell(
            onTap: () {
              setState(() {
                _viewMonth = DateTime(year, _viewMonth.month, 1);
                _viewMode = _PickerViewMode.days;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF059669)
                    : (isCurrent ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF059669)
                      : (isCurrent ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0)),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                year.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : (isCurrent ? const Color(0xFF059669) : const Color(0xFF334155)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // FOOTER ACTIONS: CANCEL & CONFIRM
  // --------------------------------------------------------------------------
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          // Jump to Today Shortcut
          TextButton.icon(
            onPressed: () {
              final now = DateTime.now();
              _applyPreset(DateTime(now.year, now.month, now.day));
            },
            icon: const Icon(Icons.today_rounded, size: 15, color: Color(0xFF059669)),
            label: const Text(
              'Reset to Today',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          const Spacer(),

          // Cancel
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),

          // Apply / Confirm Button
          ElevatedButton.icon(
            onPressed: _confirmSelection,
            icon: const Icon(Icons.check_circle_rounded, size: 15, color: Colors.white),
            label: const Text('Select Date', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              shadowColor: const Color(0xFF059669).withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// MODERN DAY CELL COMPONENT WITH HOVER AND STATUS RENDERING
// ----------------------------------------------------------------------------
class _ModernDayCell extends StatefulWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool isAdjacentMonth;
  final bool isEnabled;
  final VoidCallback? onTap;

  const _ModernDayCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.isAdjacentMonth,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  State<_ModernDayCell> createState() => _ModernDayCellState();
}

class _ModernDayCellState extends State<_ModernDayCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return Center(
        child: Text(
          widget.date.day.toString(),
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFFE2E8F0),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    Color bgColor = Colors.transparent;
    Color textColor = widget.isAdjacentMonth ? const Color(0xFF94A3B8) : const Color(0xFF1E293B);
    Border? border;
    List<BoxShadow>? shadows;

    if (widget.isSelected) {
      bgColor = const Color(0xFF059669);
      textColor = Colors.white;
      shadows = [
        BoxShadow(
          color: const Color(0xFF059669).withValues(alpha: 0.38),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (widget.isToday) {
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF059669);
      border = Border.all(color: const Color(0xFF059669), width: 1.4);
    } else if (_isHovered) {
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF0F172A);
      border = Border.all(color: const Color(0xFFCBD5E1), width: 1.0);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered && !widget.isSelected ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(9),
              border: border,
              boxShadow: shadows,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  widget.date.day.toString(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: widget.isSelected || widget.isToday ? FontWeight.w800 : FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (widget.isToday && !widget.isSelected)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
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
}
