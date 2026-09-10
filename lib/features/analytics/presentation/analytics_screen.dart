import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../diary/data/diary_provider.dart';
import '../../productivity/data/productivity_providers.dart';
import '../../wallet/data/wallet_providers.dart';
import '../../wallet/domain/utils/aether_currency.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _selectedFilterDays = 30; // 7, 30, 90

  Color _getMoodColor(String? mood) {
    switch (mood?.toLowerCase()) {
      case 'happy': return const Color(0xFFFFD700);
      case 'calm': return const Color(0xFF4ADE80);
      case 'sad': return const Color(0xFF60A5FA);
      case 'anxious': return const Color(0xFFF472B6);
      case 'angry': return const Color(0xFFEF4444);
      default: return Colors.white24;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(diaryEntriesProvider).valueOrNull ?? [];
    final tasks = ref.watch(taskNotifierProvider).valueOrNull ?? [];
    final txs = ref.watch(transactionNotifierProvider).valueOrNull ?? [];
    final habits = ref.watch(habitNotifierProvider).valueOrNull ?? [];

    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: _selectedFilterDays));

    // 1. FILTERED DATA
    final periodNotes = notes.where((n) => n.createdAt.isAfter(cutoffDate)).toList();
    final periodTasks = tasks.where((t) => t.createdAt.isAfter(cutoffDate)).toList();
    final periodTxs = txs.where((x) => x.date.isAfter(cutoffDate)).toList();

    // 2. PRODUCTIVITY STATS
    final completedTasks = periodTasks.where((t) => t.isCompleted).length;
    final totalTasks = periodTasks.length;
    final taskCompletionRate = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;
    final highPriorityTasks = periodTasks.where((t) => t.priority == 2).length;
    final highPriorityCompleted = periodTasks.where((t) => t.priority == 2 && t.isCompleted).length;

    // 3. WEALTH STATS
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    Map<String, double> categorySpend = {};

    for (var tx in periodTxs) {
      if (tx.type == 'income') totalIncome += tx.amount;
      if (tx.type == 'expense') {
        totalExpense += tx.amount;
        categorySpend[tx.category] = (categorySpend[tx.category] ?? 0) + tx.amount;
      }
    }
    final netSavings = totalIncome - totalExpense;

    // 4. MINDFULNESS & MOOD STATS
    Map<String, int> moodCounts = {'Happy': 0, 'Calm': 0, 'Sad': 0, 'Anxious': 0, 'Angry': 0};
    for (var n in periodNotes) {
      if (n.mood != null && moodCounts.containsKey(n.mood)) {
        moodCounts[n.mood!] = moodCounts[n.mood!]! + 1;
      }
    }

    // 5. HOLISTIC SYNERGY SCORE (0 - 100%)
    double prodScore = taskCompletionRate * 100;
    double mindScore = math.min(100.0, (periodNotes.length / math.max(1, _selectedFilterDays / 3)) * 100);
    double wealthScore = totalIncome > 0 ? math.max(0.0, math.min(100.0, ((totalIncome - totalExpense) / totalIncome) * 100 + 50)) : 75.0;
    double synergyScore = ((prodScore * 0.4) + (mindScore * 0.3) + (wealthScore * 0.3)).clamp(0.0, 100.0);

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
                "AETHER INTELLIGENCE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              centerTitle: true,
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Filter Chips Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "CROSS-MODULE ANALYTICS",
                          style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                        ),
                        Row(
                          children: [
                            _filterChip(7, "7D"),
                            const SizedBox(width: 6),
                            _filterChip(30, "30D"),
                            const SizedBox(width: 6),
                            _filterChip(90, "90D"),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 🌟 1. HOLISTIC SYNERGY LIFE SCORE CARD
                    _buildGlassCard(
                      glow: const Color(0xFF2DD4BF),
                      child: Row(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 72,
                                height: 72,
                                child: CircularProgressIndicator(
                                  value: synergyScore / 100,
                                  strokeWidth: 6,
                                  backgroundColor: Colors.white12,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
                                ),
                              ),
                              Text(
                                "${synergyScore.toInt()}%",
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Holistic Synergy Score",
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Synthesized balance across productivity, mindfulness reflections, and financial health.",
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 🌟 2. PRODUCTIVITY & VELOCITY SECTION
                    _buildSectionHeader("⚡ EXECUTION & TASK VELOCITY", const Color(0xFFFBBF24)),
                    const SizedBox(height: 10),
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _metricColumn("Completion Rate", "${(taskCompletionRate * 100).toInt()}%", const Color(0xFFFBBF24)),
                              _metricColumn("Tasks Done", "$completedTasks / $totalTasks", Colors.white),
                              _metricColumn("High Priority", "$highPriorityCompleted / $highPriorityTasks", const Color(0xFFF43F5E)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: taskCompletionRate,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "${habits.length} active habits tracked across routines.",
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 🌟 3. WEALTH & RESOURCE FLOW SECTION
                    _buildSectionHeader("💰 WEALTH & CASHFLOW DYNAMICS", const Color(0xFF10B981)),
                    const SizedBox(height: 10),
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _metricColumn("Total Expense", AetherCurrency.format(totalExpense), const Color(0xFFEF4444)),
                              _metricColumn("Total Income", AetherCurrency.format(totalIncome), const Color(0xFF10B981)),
                              _metricColumn("Net Flow", "${netSavings >= 0 ? '+' : ''}${AetherCurrency.format(netSavings)}", netSavings >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text("Top Expense Categories", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (categorySpend.isEmpty)
                            const Text("No expenses recorded in this period.", style: TextStyle(color: Colors.white38, fontSize: 11.5))
                          else
                            ...categorySpend.entries.take(4).map((entry) {
                              final ratio = totalExpense > 0 ? (entry.value / totalExpense) : 0.0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(entry.key, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        Text("${AetherCurrency.format(entry.value)} (${(ratio * 100).toInt()}%)", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: ratio,
                                      backgroundColor: Colors.white10,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                      minHeight: 4,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 🌟 4. SANCTUARY & EMOTIONAL SPECTRUM
                    _buildSectionHeader("📝 MINDFULNESS & EMOTIONAL SPECTRUM", const Color(0xFF38BDF8)),
                    const SizedBox(height: 10),
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _metricColumn("Reflections", "${periodNotes.length}", const Color(0xFF38BDF8)),
                              _metricColumn("Check-ins", "${moodCounts.values.fold(0, (a, b) => a + b)}", Colors.white),
                              _metricColumn("Cadence", "${(periodNotes.length / math.max(1, _selectedFilterDays / 7)).toStringAsFixed(1)} /wk", const Color(0xFF8B5CF6)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text("Emotional Distribution", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: moodCounts.entries.map((m) {
                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _getMoodColor(m.key).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _getMoodColor(m.key).withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    children: [
                                      Text("${m.value}", style: TextStyle(color: _getMoodColor(m.key), fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(m.key, style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
    );
  }

  Widget _metricColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child, Color? glow}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: glow != null ? glow.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _filterChip(int days, String label) {
    final isSelected = _selectedFilterDays == days;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilterDays = days);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2DD4BF).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF2DD4BF) : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? const Color(0xFF2DD4BF) : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}