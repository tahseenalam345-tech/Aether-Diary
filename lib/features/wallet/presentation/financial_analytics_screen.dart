import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/themes/aether_colors.dart';
import '../data/wallet_providers.dart';
import '../domain/utils/aether_currency.dart';
import '../domain/models/wallet_category_system.dart'; 

// 🎨 PREMIUM PALETTE 
const Color _bgTop = Color(0xFF060B14);
const Color _bgBottom = Color(0xFF0A0714);
const Color _mint = Color(0xFF34F5C5);
const Color _sky = Color(0xFF38BDF8);
const Color _rose = Color(0xFFFB7185);
const Color _violet = Color(0xFFA78BFA);

final weeklySpendingTrendProvider = Provider<List<FlSpot>>((ref) {
  final transactions = ref.watch(transactionNotifierProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  
  Map<int, double> dailyTotals = { for (int i=0; i<7; i++) i: 0.0 };
  
  for (var t in transactions) {
    if (t.type == 'expense') {
      final tDate = DateTime(t.date.year, t.date.month, t.date.day);
      final difference = today.difference(tDate).inDays;
      if (difference >= 0 && difference < 7) {
        dailyTotals[6 - difference] = (dailyTotals[6 - difference] ?? 0) + (t.amount * t.exchangeRate);
      }
    }
  }
  return dailyTotals.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
});

class FinancialAnalyticsScreen extends ConsumerWidget {
  const FinancialAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(transactionNotifierProvider);
    final analyticsAsync = ref.watch(asyncAnalyticsEngineProvider);
    ref.watch(primaryCurrencyProvider); // Rebuild on currency change
    final weeklyTrend = ref.watch(weeklySpendingTrendProvider);
    final categories = ref.watch(walletCategoryProvider).valueOrNull ?? [];
    
    final cashFlow = ref.watch(monthlyCashFlowProvider);
    final categorySpent = ref.watch(budgetProgressProvider);

    final Map<String, double> validSpending = Map.from(categorySpent)..removeWhere((key, value) => key == 'Global' || value <= 0);

    return Scaffold(
      backgroundColor: _bgTop,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [_bgTop, Color(0xFF0B0F1C), _bgBottom], stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned(top: -120, right: -80, child: _glowOrb(320, _sky.withValues(alpha: 0.15))),
          Positioned(top: 250, left: -100, child: _glowOrb(260, _violet.withValues(alpha: 0.15))),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent, elevation: 0, pinned: true, toolbarHeight: 64,
                  flexibleSpace: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(color: _bgTop.withValues(alpha: 0.35)))),
                  leading: Padding(padding: const EdgeInsets.only(left: 12), child: GestureDetector(onTap: () { HapticFeedback.lightImpact(); context.pop(); }, child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.08))), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 17)))),
                  title: const Text("Intelligence", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  centerTitle: true,
                ),
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("Monthly Cash Flow", _sky).animate().fadeIn(),
                        const SizedBox(height: 16),
                        
                        // GLASS CASH FLOW CARD
                        ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                              child: Row(
                                children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _mint.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.arrow_downward_rounded, color: _mint, size: 14)), const SizedBox(width: 8), const Text("Inflow", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold))]), const SizedBox(height: 12), Text(AetherCurrency.format(cashFlow['income'] ?? 0), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]))])),
                                  Container(width: 1.5, height: 50, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(1))),
                                  const SizedBox(width: 16),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _rose.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.arrow_upward_rounded, color: _rose, size: 14)), const SizedBox(width: 8), const Text("Outflow", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold))]), const SizedBox(height: 12), Text(AetherCurrency.format(cashFlow['expense'] ?? 0), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]))])),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn().slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 36),

                        _buildSectionHeader("7-Day Trajectory", _mint).animate().fadeIn(delay: 100.ms),
                        const SizedBox(height: 16),
                        
                        // GLASS LINE CHART CARD
                        Container(
                          padding: const EdgeInsets.only(top: 32, bottom: 16, left: 16, right: 24), height: 200,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1)),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (value, meta) {
                                  final targetDate = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                                  return SideTitleWidget(meta: meta, space: 8, child: Text(DateFormat('E').format(targetDate).toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)));
                                })),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: weeklyTrend, isCurved: true, color: _sky, barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [_sky.withValues(alpha: 0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 150.ms).scaleXY(begin: 0.95),

                        const SizedBox(height: 36),

                        _buildSectionHeader("Capital Allocation", _violet).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 16),

                        if (validSpending.isEmpty)
                          Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white.withValues(alpha: 0.06))), child: const Center(child: Text("Not enough data to map allocation.", style: TextStyle(color: Colors.white38))))
                        else
                          _IsolatedPieChart(validSpending: validSpending, categories: categories).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color accent) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _glowOrb(double size, Color color) {
    return IgnorePointer(child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, Colors.transparent]))));
  }
}

class _IsolatedPieChart extends StatefulWidget {
  final Map<String, double> validSpending;
  final List<AetherWalletCategory> categories;
  const _IsolatedPieChart({required this.validSpending, required this.categories});

  @override
  State<_IsolatedPieChart> createState() => _IsolatedPieChartState();
}

class _IsolatedPieChartState extends State<_IsolatedPieChart> {
  int _touchedIndex = -1;

  Color _getCategoryColor(String name) {
    final cat = widget.categories.where((c) => c.name == name).firstOrNull;
    return cat?.color ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24), 
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Column(
        children: [
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1; return;
                      }
                      _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      if (event is FlTapUpEvent) HapticFeedback.selectionClick();
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2, centerSpaceRadius: 50,
                sections: widget.validSpending.entries.toList().asMap().entries.map((entry) {
                  final index = entry.key; final catName = entry.value.key; final amount = entry.value.value;
                  final isTouched = index == _touchedIndex;
                  final color = _getCategoryColor(catName);

                  return PieChartSectionData(
                    color: color, value: amount,
                    title: isTouched ? AetherCurrency.format(amount) : '',
                    radius: isTouched ? 75.0 : 60.0,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16, runSpacing: 12,
            children: widget.validSpending.keys.map((catName) {
              final color = _getCategoryColor(catName);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)])),
                  const SizedBox(width: 8),
                  Text(catName, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              );
            }).toList(),
          )
        ],
      ),
    );
  }
}