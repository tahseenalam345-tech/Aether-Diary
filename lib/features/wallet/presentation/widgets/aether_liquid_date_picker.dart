import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

enum AetherDatePickerMode {
  singleDate,
  dateRange,
  dateTime,
}

/// 🌟 AETHER LIQUID GLASS DATE & TIME PICKER 🌟
/// A fluid, ultra-premium glassmorphic calendar and range/time selector.
class AetherLiquidDatePicker extends StatefulWidget {
  final AetherDatePickerMode mode;
  final DateTime? initialDate;
  final DateTimeRange? initialDateRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final Color accentColor;
  final bool showPresets;
  final String title;

  const AetherLiquidDatePicker({
    super.key,
    this.mode = AetherDatePickerMode.singleDate,
    this.initialDate,
    this.initialDateRange,
    required this.firstDate,
    required this.lastDate,
    this.accentColor = const Color(0xFF38BDF8), // Sky Blue default
    this.showPresets = true,
    this.title = "Select Date",
  });

  @override
  State<AetherLiquidDatePicker> createState() => _AetherLiquidDatePickerState();
}

class _AetherLiquidDatePickerState extends State<AetherLiquidDatePicker> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  late int _selectedHour;
  late int _selectedMinute;
  late String _selectedAmPm;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.mode == AetherDatePickerMode.dateRange) {
      _rangeStart = widget.initialDateRange?.start ?? now.subtract(const Duration(days: 6));
      _rangeEnd = widget.initialDateRange?.end ?? now;
      _currentMonth = DateTime(_rangeEnd!.year, _rangeEnd!.month, 1);
    } else {
      _selectedDate = widget.initialDate ?? now;
      _currentMonth = DateTime(_selectedDate!.year, _selectedDate!.month, 1);
    }

    final initialTime = widget.initialDate ?? now;
    int rawHour = initialTime.hour;
    _selectedAmPm = rawHour >= 12 ? 'PM' : 'AM';
    _selectedHour = rawHour % 12;
    if (_selectedHour == 0) _selectedHour = 12;
    _selectedMinute = initialTime.minute;
  }

  void _prevMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _onDayTapped(DateTime day) {
    HapticFeedback.lightImpact();
    setState(() {
      if (widget.mode == AetherDatePickerMode.singleDate || widget.mode == AetherDatePickerMode.dateTime) {
        _selectedDate = day;
      } else {
        // Date Range Mode
        if (_rangeStart == null || (_rangeStart != null && _rangeEnd != null)) {
          _rangeStart = day;
          _rangeEnd = null;
        } else if (_rangeStart != null && _rangeEnd == null) {
          if (day.isBefore(_rangeStart!)) {
            _rangeEnd = _rangeStart;
            _rangeStart = day;
          } else {
            _rangeEnd = day;
          }
        }
      }
    });
  }

  void _applyPreset(String preset) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      if (preset == 'Today') {
        _selectedDate = today;
        _rangeStart = today;
        _rangeEnd = today;
        _currentMonth = DateTime(today.year, today.month, 1);
      } else if (preset == 'Yesterday') {
        final y = today.subtract(const Duration(days: 1));
        _selectedDate = y;
        _rangeStart = y;
        _rangeEnd = y;
        _currentMonth = DateTime(y.year, y.month, 1);
      } else if (preset == 'This Week') {
        final start = today.subtract(Duration(days: today.weekday - 1));
        _rangeStart = start;
        _rangeEnd = today;
        _selectedDate = today;
        _currentMonth = DateTime(start.year, start.month, 1);
      } else if (preset == 'This Month') {
        final start = DateTime(today.year, today.month, 1);
        final end = DateTime(today.year, today.month + 1, 0);
        _rangeStart = start;
        _rangeEnd = end.isAfter(today) ? today : end;
        _selectedDate = today;
        _currentMonth = DateTime(today.year, today.month, 1);
      } else if (preset == 'Last 30 Days') {
        final start = today.subtract(const Duration(days: 29));
        _rangeStart = start;
        _rangeEnd = today;
        _selectedDate = today;
        _currentMonth = DateTime(today.year, today.month, 1);
      }
    });
  }

  void _submit() {
    HapticFeedback.heavyImpact();
    if (widget.mode == AetherDatePickerMode.dateRange) {
      final start = _rangeStart ?? DateTime.now();
      final end = _rangeEnd ?? start;
      Navigator.of(context).pop(DateTimeRange(start: start, end: end));
    } else if (widget.mode == AetherDatePickerMode.dateTime) {
      final date = _selectedDate ?? DateTime.now();
      int hour = _selectedHour % 12;
      if (_selectedAmPm == 'PM') hour += 12;
      final result = DateTime(date.year, date.month, date.day, hour, _selectedMinute);
      Navigator.of(context).pop(result);
    } else {
      Navigator.of(context).pop(_selectedDate ?? DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0C101E).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.15),
                  blurRadius: 32,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🌟 HEADER: TITLE & SELECTION SUMMARY
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: widget.accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildSelectedSummary(),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),

                  // 🌟 QUICK PRESETS CHIPS
                  if (widget.showPresets) ...[
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _presetChip('Today'),
                          if (widget.mode != AetherDatePickerMode.dateRange) _presetChip('Yesterday'),
                          _presetChip('This Week'),
                          _presetChip('This Month'),
                          _presetChip('Last 30 Days'),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  const SizedBox(height: 14),

                  // 🌟 MONTH NAVIGATION HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(_currentMonth),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _prevMonth,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _nextMonth,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 🌟 DAYS OF WEEK ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
                      return SizedBox(
                        width: 36,
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 8),

                  // 🌟 CALENDAR DAYS GRID
                  _buildCalendarGrid(),

                  // 🌟 TIME PICKER SECTION (FOR DATETIME MODE)
                  if (widget.mode == AetherDatePickerMode.dateTime) ...[
                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                    const SizedBox(height: 14),
                    _buildTimePickerSection(),
                  ],

                  const SizedBox(height: 20),

                  // 🌟 ACTION BUTTONS
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text(
                                "Cancel",
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _submit,
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [widget.accentColor, widget.accentColor.withValues(alpha: 0.8)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.accentColor.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                "Apply Selection",
                                style: TextStyle(color: Color(0xFF060B14), fontSize: 13.5, fontWeight: FontWeight.w800),
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
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedSummary() {
    if (widget.mode == AetherDatePickerMode.dateRange) {
      if (_rangeStart != null && _rangeEnd != null) {
        return Text(
          "${DateFormat('MMM d').format(_rangeStart!)} - ${DateFormat('MMM d, yyyy').format(_rangeEnd!)}",
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
        );
      } else if (_rangeStart != null) {
        return Text(
          "${DateFormat('MMM d, yyyy').format(_rangeStart!)} - Select End",
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
        );
      }
      return const Text("Pick Date Range", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800));
    } else if (widget.mode == AetherDatePickerMode.dateTime) {
      final dateStr = DateFormat('MMM d, yyyy').format(_selectedDate ?? DateTime.now());
      final timeStr = "${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')} $_selectedAmPm";
      return Text(
        "$dateStr • $timeStr",
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
      );
    } else {
      return Text(
        DateFormat('EEEE, MMM d, yyyy').format(_selectedDate ?? DateTime.now()),
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
      );
    }
  }

  Widget _presetChip(String label) {
    return GestureDetector(
      onTap: () => _applyPreset(label),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: widget.accentColor.withValues(alpha: 0.9),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7; // Sunday = 0

    List<Widget> dayWidgets = [];

    // Preceding empty slots
    for (int i = 0; i < firstDayWeekday; i++) {
      dayWidgets.add(const SizedBox(width: 36, height: 36));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int day = 1; day <= daysInMonth; day++) {
      final currentDayDate = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isToday = currentDayDate.year == today.year && currentDayDate.month == today.month && currentDayDate.day == today.day;

      bool isSelected = false;
      bool isInRange = false;
      bool isRangeStart = false;
      bool isRangeEnd = false;

      if (widget.mode == AetherDatePickerMode.dateRange) {
        if (_rangeStart != null && _isSameDay(currentDayDate, _rangeStart!)) {
          isRangeStart = true;
          isSelected = true;
        }
        if (_rangeEnd != null && _isSameDay(currentDayDate, _rangeEnd!)) {
          isRangeEnd = true;
          isSelected = true;
        }
        if (_rangeStart != null && _rangeEnd != null) {
          if (currentDayDate.isAfter(_rangeStart!) && currentDayDate.isBefore(_rangeEnd!)) {
            isInRange = true;
          }
        }
      } else {
        if (_selectedDate != null && _isSameDay(currentDayDate, _selectedDate!)) {
          isSelected = true;
        }
      }

      Color cellColor = Colors.transparent;
      if (isSelected) {
        cellColor = widget.accentColor;
      } else if (isInRange) {
        cellColor = widget.accentColor.withValues(alpha: 0.18);
      }

      dayWidgets.add(
        GestureDetector(
          onTap: () => _onDayTapped(currentDayDate),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: cellColor,
              shape: (isRangeStart || isRangeEnd || (!isInRange && isSelected)) ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isInRange ? BorderRadius.circular(6) : null,
              border: isToday && !isSelected ? Border.all(color: widget.accentColor.withValues(alpha: 0.6), width: 1.2) : null,
            ),
            child: Center(
              child: Text(
                "$day",
                style: TextStyle(
                  color: isSelected ? const Color(0xFF060B14) : (isInRange ? widget.accentColor : Colors.white),
                  fontSize: 12.5,
                  fontWeight: (isSelected || isToday) ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 6,
      runSpacing: 2,
      children: dayWidgets,
    );
  }

  Widget _buildTimePickerSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(Icons.access_time_rounded, color: Colors.white54, size: 16),
            SizedBox(width: 8),
            Text(
              "TIME",
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ],
        ),
        Row(
          children: [
            // Hour Picker
            _timeWheelBox(
              value: _selectedHour.toString().padLeft(2, '0'),
              onIncrement: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedHour = (_selectedHour % 12) + 1);
              },
              onDecrement: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedHour = _selectedHour == 1 ? 12 : _selectedHour - 1);
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(":", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            // Minute Picker
            _timeWheelBox(
              value: _selectedMinute.toString().padLeft(2, '0'),
              onIncrement: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedMinute = (_selectedMinute + 5) % 60);
              },
              onDecrement: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedMinute = (_selectedMinute - 5 + 60) % 60);
              },
            ),
            const SizedBox(width: 8),
            // AM / PM Toggle
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedAmPm = _selectedAmPm == 'AM' ? 'PM' : 'AM');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _selectedAmPm,
                  style: TextStyle(color: widget.accentColor, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _timeWheelBox({
    required String value,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onIncrement,
                child: const Icon(Icons.arrow_drop_up_rounded, color: Colors.white70, size: 16),
              ),
              GestureDetector(
                onTap: onDecrement,
                child: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🌟 CONVENIENCE GLOBAL HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Future<DateTime?> showAetherLiquidDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  Color accentColor = const Color(0xFF38BDF8),
  String title = "Select Date",
}) async {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => AetherLiquidDatePicker(
      mode: AetherDatePickerMode.singleDate,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
      accentColor: accentColor,
      title: title,
    ),
  );
}

Future<DateTimeRange?> showAetherLiquidDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialDateRange,
  DateTime? firstDate,
  DateTime? lastDate,
  Color accentColor = const Color(0xFF38BDF8),
  String title = "Select Date Range",
}) async {
  return showDialog<DateTimeRange>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => AetherLiquidDatePicker(
      mode: AetherDatePickerMode.dateRange,
      initialDateRange: initialDateRange,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
      accentColor: accentColor,
      title: title,
    ),
  );
}

Future<DateTime?> showAetherLiquidDateTimePicker({
  required BuildContext context,
  DateTime? initialDateTime,
  DateTime? firstDate,
  DateTime? lastDate,
  Color accentColor = const Color(0xFF38BDF8),
  String title = "Select Date & Time",
}) async {
  return showDialog<DateTime>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => AetherLiquidDatePicker(
      mode: AetherDatePickerMode.dateTime,
      initialDate: initialDateTime,
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
      accentColor: accentColor,
      title: title,
    ),
  );
}
