import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../data/productivity_providers.dart';
import '../domain/models/aether_habit.dart';

class HabitsAnalyticsScreen extends ConsumerStatefulWidget {
  const HabitsAnalyticsScreen({super.key});

  @override
  ConsumerState<HabitsAnalyticsScreen> createState() => _HabitsAnalyticsScreenState();
}

class _HabitsAnalyticsScreenState extends ConsumerState<HabitsAnalyticsScreen> {
  String _selectedRange = 'Last Week';
  DateTime? _customStart;
  DateTime? _customEnd;

  final Map<String, int> _rangeMap = {
    'Today': 0,
    'Last Day': 1,
    'Last 3 Days': 3,
    'Last Week': 7,
    'Last Month': 30,
    'Custom Data': -1,
  };

  void _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFF59E0B), surface: Color(0xFF1A1A1A)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedRange = 'Custom Data';
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  List<DateTime> _getDatesInRange() {
    List<DateTime> dates = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_selectedRange == 'Custom Data' && _customStart != null && _customEnd != null) {
      for (int i = 0; i <= _customEnd!.difference(_customStart!).inDays; i++) {
        dates.add(_customStart!.add(Duration(days: i)));
      }
      return dates;
    }

    final days = _rangeMap[_selectedRange]!;
    if (days == 0) return [today];
    
    for (int i = 0; i < days; i++) {
      dates.add(today.subtract(Duration(days: i)));
    }
    return dates;
  }

  Color _getModeColor(String type) {
    switch (type) {
      case 'simple': return const Color(0xFF3B82F6);
      case 'multi': return const Color(0xFF8B5CF6);
      case 'quantity': return const Color(0xFF06B6D4);
      case 'negative': return const Color(0xFFEF4444);
      case 'checklist': return const Color(0xFFF59E0B);
      case 'timer': return const Color(0xFF10B981);
      default: return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitNotifierProvider);
    final dates = _getDatesInRange();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("ANALYTICS ENGINE", style: TextStyle(color: Color(0xFFF59E0B), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
        error: (e, st) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.redAccent))),
        data: (habits) {
          if (habits.isEmpty) return const Center(child: Text("No data to analyze.", style: TextStyle(color: Colors.white54)));

          // Data Aggregation Variables
          int simpleTotal = 0, simpleDone = 0;
          double quantityTarget = 0, quantityDone = 0;
          double timerTarget = 0, timerDone = 0;
          int negativeResisted = 0, negativeSlipped = 0;
          int checklistTotal = 0, checklistDone = 0;
          int multiTotal = 0, multiDone = 0;

          // Aggregation Engine
          for (var date in dates) {
            for (var h in habits) {
              if (h.isScheduledFor(date)) {
                final rec = h.getRecord(date);
                final isCompleted = rec['isCompleted'] == true;

                switch (h.habitType) {
                  case 'simple':
                    simpleTotal++;
                    if (isCompleted) simpleDone++;
                    break;
                  case 'quantity':
                    quantityTarget += h.target;
                    quantityDone += rec['progress'];
                    break;
                  case 'timer':
                    timerTarget += h.target;
                    timerDone += rec['progress'];
                    break;
                  case 'negative':
                    if (isCompleted) negativeResisted++;
                    else if (rec['reason'].toString().isNotEmpty) negativeSlipped++;
                    break;
                  case 'checklist':
                  case 'multi':
                    final sessions = List<String>.from(rec['sessions']);
                    for (var s in sessions) {
                      if (h.habitType == 'checklist') {
                        checklistTotal++;
                        if (s == 'C') checklistDone++;
                      } else {
                        multiTotal++;
                        if (s == 'C') multiDone++;
                      }
                    }
                    break;
                }
              }
            }
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // TIME FILTERS
              SliverToBoxAdapter(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _rangeMap.keys.map((key) {
                      final isSelected = _selectedRange == key;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          if (key == 'Custom Data') _pickCustomDateRange();
                          else setState(() => _selectedRange = key);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? const Color(0xFFF59E0B) : Colors.white12)
                          ),
                          child: Text(key, style: TextStyle(color: isSelected ? const Color(0xFFF59E0B) : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // DATE RANGE INDICATOR
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    dates.length == 1 
                      ? "Data for: ${DateFormat('MMMM d, yyyy').format(dates.first)}"
                      : "Data for: ${DateFormat('MMM d').format(dates.last)} - ${DateFormat('MMM d, yyyy').format(dates.first)}",
                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              ),

              // ANALYTICS GRIDS
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                  children: [
                    _buildPieCard("Simple Routines", Icons.task_alt, _getModeColor('simple'), simpleDone, simpleTotal, "Completed"),
                    _buildBarCard("Quantity Logged", Icons.water_drop, _getModeColor('quantity'), quantityDone, quantityTarget, "Units"),
                    _buildBarCard("Focus Time", Icons.timer, _getModeColor('timer'), timerDone, timerTarget, "Mins"),
                    _buildVsCard("Avoid / Quit", Icons.block, _getModeColor('negative'), negativeResisted, negativeSlipped),
                    _buildPieCard("Checklist Tasks", Icons.checklist, _getModeColor('checklist'), checklistDone, checklistTotal, "Steps"),
                    _buildPieCard("Timeline Events", Icons.timeline, _getModeColor('multi'), multiDone, multiTotal, "Events"),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 50)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPieCard(String title, IconData icon, Color color, int done, int total, String label) {
    double pct = total > 0 ? (done / total) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const Spacer(),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80, width: 80,
                child: CircularProgressIndicator(value: pct, strokeWidth: 8, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation<Color>(color)),
              ),
              Text("${(pct * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          const Spacer(),
          Text("$done / $total $label", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBarCard(String title, IconData icon, Color color, double done, double total, String label) {
    double pct = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 24, height: math.max(4, 80 * pct), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Container(width: 24, height: 80, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
            ],
          ),
          const Spacer(),
          Text("${done.toInt()} / ${total.toInt()} $label", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildVsCard(String title, IconData icon, Color color, int resisted, int slipped) {
    int total = resisted + slipped;
    double resPct = total > 0 ? (resisted / total) : 0;
    double slipPct = total > 0 ? (slipped / total) : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(resisted.toString(), style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(width: 24, height: math.max(4, 70 * resPct), decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(4))),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Text(slipped.toString(), style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(width: 24, height: math.max(4, 70 * slipPct), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ],
          ),
          const Spacer(),
          const Text("Resisted vs Slipped", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}