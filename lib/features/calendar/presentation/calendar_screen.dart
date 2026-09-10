import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/calendar_providers.dart';
import '../../wallet/domain/utils/aether_currency.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'task': return const Color(0xFFFBBF24); // Amber
      case 'diary': return const Color(0xFF38BDF8); // Sky
      case 'focus': return const Color(0xFFF43F5E); // Rose
      case 'expense': return const Color(0xFFEF4444); // Red
      case 'income': return const Color(0xFF10B981); // Emerald
      case 'habit': return const Color(0xFF8B5CF6); // Violet
      case 'subscription': return const Color(0xFFEC4899); // Pink
      default: return const Color(0xFF2DD4BF); // Teal
    }
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'task': return Icons.check_circle_outline_rounded;
      case 'diary': return Icons.auto_stories_rounded;
      case 'focus': return Icons.timer_outlined;
      case 'expense': return Icons.arrow_downward_rounded;
      case 'income': return Icons.arrow_upward_rounded;
      case 'habit': return Icons.repeat_rounded;
      case 'subscription': return Icons.credit_card_rounded;
      default: return Icons.event_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = ref.watch(calendarEventsProvider);
    final selectedDayNormalized = _normalizeDate(_selectedDay);
    final dayEvents = allEvents[selectedDayNormalized] ?? [];

    // Calculate Day Metrics
    double dayExpenses = 0.0;
    double dayIncomes = 0.0;
    int dayTasksDone = 0;
    int dayNotes = 0;
    int dayFocusMinutes = 0;

    for (var ev in dayEvents) {
      if (ev.type == 'expense' && ev.amount != null) dayExpenses += ev.amount!;
      if (ev.type == 'income' && ev.amount != null) dayIncomes += ev.amount!;
      if (ev.type == 'task' && ev.isCompleted) dayTasksDone++;
      if (ev.type == 'diary') dayNotes++;
      if (ev.type == 'focus') dayFocusMinutes += 25;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 🌟 TOP APP BAR
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
                onPressed: () => context.pop(),
              ),
              title: const Text(
                "TIMELINE ARCHIVE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              centerTitle: true,
              actions: [
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _focusedDay = DateTime.now();
                      _selectedDay = DateTime.now();
                    });
                  },
                  child: const Text("Today", style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),

            // 🌟 INTERACTIVE FROSTED CALENDAR
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.035),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: TableCalendar<AetherEvent>(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                          CalendarFormat.twoWeeks: '2 Weeks',
                          CalendarFormat.week: 'Week',
                        },
                        onFormatChanged: (format) {
                          setState(() => _calendarFormat = format);
                        },
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        eventLoader: (day) => allEvents[_normalizeDate(day)] ?? [],
                        onDaySelected: (selectedDay, focusedDay) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        daysOfWeekHeight: 36,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: true,
                          formatButtonShowsNext: false,
                          formatButtonTextStyle: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                          formatButtonDecoration: BoxDecoration(
                            color: Color(0x2238BDF8),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          titleCentered: true,
                          titleTextStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          leftChevronIcon: Icon(Icons.chevron_left_rounded, color: Colors.white70),
                          rightChevronIcon: Icon(Icons.chevron_right_rounded, color: Colors.white70),
                        ),
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          defaultTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          weekendTextStyle: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w600),
                          todayDecoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF38BDF8)),
                          ),
                          todayTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          selectedDecoration: const BoxDecoration(
                            color: Color(0xFF38BDF8),
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: const TextStyle(color: Color(0xFF060B14), fontWeight: FontWeight.w900),
                          markersMaxCount: 4,
                          markerSize: 6,
                          markerMargin: const EdgeInsets.symmetric(horizontal: 0.8),
                          markerDecoration: const BoxDecoration(
                            color: Color(0xFF2DD4BF),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 🌟 DAY SUMMARY METRICS BAR
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay),
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${dayEvents.length} Actions",
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (dayExpenses > 0)
                            _daySummaryBadge("Spent: ${AetherCurrency.format(dayExpenses)}", const Color(0xFFEF4444)),
                          if (dayIncomes > 0)
                            _daySummaryBadge("Income: ${AetherCurrency.format(dayIncomes)}", const Color(0xFF10B981)),
                          if (dayTasksDone > 0)
                            _daySummaryBadge("$dayTasksDone Tasks Done", const Color(0xFFFBBF24)),
                          if (dayNotes > 0)
                            _daySummaryBadge("$dayNotes Notes", const Color(0xFF38BDF8)),
                          if (dayFocusMinutes > 0)
                            _daySummaryBadge("${dayFocusMinutes}m Focus", const Color(0xFFF43F5E)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 🌟 00:00 TO 23:59 CHRONOLOGICAL TIMELINE
            if (dayEvents.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_available_outlined, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      const Text("No History Logged for this Date", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Activities recorded on this date will appear chronologically.", style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = dayEvents[index];
                      final color = _getEventColor(event.type);
                      final icon = _getEventIcon(event.type);
                      final timeStr = DateFormat('h:mm a').format(event.date);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.035),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            // Timestamp pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                timeStr,
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Event Type Icon
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: color, size: 16),
                            ),
                            const SizedBox(width: 12),

                            // Event Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    event.subtitle,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),

                            // Event Specific Tag / Amount
                            if (event.amount != null) ...[
                              Text(
                                "${event.type == 'expense' ? '-' : '+'}${AetherCurrency.format(event.amount!)}",
                                style: TextStyle(
                                  color: event.type == 'expense' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ] else if (event.mood != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
                                child: Text(event.mood!, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ] else if (event.priority != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  event.priority == 2 ? "High" : (event.priority == 1 ? "Med" : "Low"),
                                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
                    },
                    childCount: dayEvents.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _daySummaryBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}