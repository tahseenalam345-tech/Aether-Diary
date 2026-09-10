import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../home/presentation/home_screen.dart';
import '../../diary/data/diary_provider.dart';
import '../../productivity/data/productivity_providers.dart';
import '../../wallet/data/wallet_providers.dart';

class ConsistencyAnalyticsScreen extends ConsumerStatefulWidget {
  const ConsistencyAnalyticsScreen({super.key});

  @override
  ConsumerState<ConsistencyAnalyticsScreen> createState() => _ConsistencyAnalyticsScreenState();
}

class _ConsistencyAnalyticsScreenState extends ConsumerState<ConsistencyAnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(activityStatsProvider);
    final notes = ref.watch(diaryEntriesProvider).valueOrNull ?? [];
    final tasks = ref.watch(taskNotifierProvider).valueOrNull ?? [];
    final txs = ref.watch(transactionNotifierProvider).valueOrNull ?? [];

    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final today = dateOnly(DateTime.now());

    // Compute Activity Density Matrix (GitHub Heatmap Style for 12 weeks = 84 days)
    final Map<DateTime, int> dailyActivityScore = {};
    for (var n in notes) {
      final d = dateOnly(n.createdAt);
      dailyActivityScore[d] = (dailyActivityScore[d] ?? 0) + 2;
    }
    for (var t in tasks) {
      if (t.isCompleted) {
        final d = dateOnly(t.createdAt);
        dailyActivityScore[d] = (dailyActivityScore[d] ?? 0) + 1;
      }
    }
    for (var x in txs) {
      final d = dateOnly(x.date);
      dailyActivityScore[d] = (dailyActivityScore[d] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      body: Stack(
        children: [
          // Background ambient cosmic dust
          Positioned.fill(
            child: CustomPaint(
              painter: _ConsistencyCosmicPainter(),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🌟 1. HERO STREAK TROPHY CARD
                      _buildStreakHeroCard(stats)
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 20),

                      // 🌟 2. GITHUB-STYLE CONTRIBUTION HEATMAP MATRIX
                      _buildContributionHeatmap(dailyActivityScore, today)
                          .animate()
                          .fadeIn(delay: 150.ms)
                          .slideY(begin: 0.08, end: 0),

                      const SizedBox(height: 20),

                      // 🌟 3. FL_CHART CONSISTENCY TRAJECTORY GRAPH
                      _buildConsistencyTrendChart(dailyActivityScore, today)
                          .animate()
                          .fadeIn(delay: 250.ms)
                          .slideY(begin: 0.08, end: 0),

                      const SizedBox(height: 20),

                      // 🌟 4. STATISTICAL MATRIX & METRICS
                      _buildHistoricalStatsGrid(stats)
                          .animate()
                          .fadeIn(delay: 350.ms)
                          .slideY(begin: 0.08, end: 0),

                      const SizedBox(height: 20),

                      // 🌟 5. MILESTONES & MASTERY BADGES
                      _buildMasteryBadgesSection(stats)
                          .animate()
                          .fadeIn(delay: 450.ms)
                          .slideY(begin: 0.08, end: 0),

                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 APP BAR
  // ---------------------------------------------------------------------------
  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      toolbarHeight: 60,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
        onPressed: () {
          HapticFeedback.lightImpact();
          context.pop();
        },
      ),
      title: const Text(
        "CONSISTENCY ENGINE",
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
      centerTitle: true,
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 HERO STREAK TROPHY CARD
  // ---------------------------------------------------------------------------
  Widget _buildStreakHeroCard(ActivityStats stats) {
    return _glassCard(
      glowColor: Colors.amberAccent,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          "CURRENT STREAK",
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "${stats.currentStreak}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "DAYS STRONG",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stats.milestoneText,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Text("🔥", style: TextStyle(fontSize: 58))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.95, end: 1.15, duration: 800.ms),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (stats.currentStreak % 30) / 30.0,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Cycle Progress: ${stats.currentStreak % 30}/30 Days",
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Text(
                "${(100 - (stats.currentStreak % 30) / 30.0 * 100).toInt()}% to Next Milestone",
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 GITHUB-STYLE CONTRIBUTION HEATMAP MATRIX
  // ---------------------------------------------------------------------------
  Widget _buildContributionHeatmap(Map<DateTime, int> scores, DateTime today) {
    // Generate 12 weeks of dates (7 rows x 12 columns = 84 days)
    const int totalDays = 84;
    final startDate = today.subtract(Duration(days: totalDays - 1));

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.grid_view_rounded, color: Color(0xFF2DD4BF), size: 18),
                  SizedBox(width: 8),
                  Text(
                    "ACTIVITY HEATMAP (12 WEEKS)",
                    style: TextStyle(
                      color: Color(0xFF2DD4BF),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _heatmapLegendBox(const Color(0xFF131826)),
                  const SizedBox(width: 3),
                  _heatmapLegendBox(const Color(0xFF0D9488).withValues(alpha: 0.3)),
                  const SizedBox(width: 3),
                  _heatmapLegendBox(const Color(0xFF14B8A6)),
                  const SizedBox(width: 3),
                  _heatmapLegendBox(const Color(0xFF2DD4BF)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scrollable Heatmap Grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(12, (colIndex) {
                return Column(
                  children: List.generate(7, (rowIndex) {
                    final dayOffset = (colIndex * 7) + rowIndex;
                    final cellDate = startDate.add(Duration(days: dayOffset));
                    if (cellDate.isAfter(today)) {
                      return const SizedBox(width: 18, height: 18);
                    }
                    final score = scores[cellDate] ?? 0;
                    return Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: _getHeatmapColor(score),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: score > 0 ? const Color(0xFF2DD4BF).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
                          width: 0.8,
                        ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${DateFormat('MMM d').format(startDate)}",
                style: const TextStyle(color: Colors.white30, fontSize: 10),
              ),
              const Text(
                "Daily Engagement Level",
                style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600),
              ),
              Text(
                "Today (${DateFormat('MMM d').format(today)})",
                style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getHeatmapColor(int score) {
    if (score == 0) return const Color(0xFF0F1523);
    if (score == 1) return const Color(0xFF0F766E).withValues(alpha: 0.5);
    if (score == 2) return const Color(0xFF0D9488);
    if (score == 3) return const Color(0xFF14B8A6);
    return const Color(0xFF2DD4BF);
  }

  Widget _heatmapLegendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 FL_CHART CONSISTENCY TRAJECTORY GRAPH
  // ---------------------------------------------------------------------------
  Widget _buildConsistencyTrendChart(Map<DateTime, int> scores, DateTime today) {
    final spots = <FlSpot>[];
    for (int i = 29; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final score = (scores[d] ?? 0).toDouble();
      spots.add(FlSpot((29 - i).toDouble(), score));
    }

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart_rounded, color: Color(0xFF8B5CF6), size: 18),
                  SizedBox(width: 8),
                  Text(
                    "30-DAY ENGAGEMENT CURVE",
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Text(
                "Daily Action Velocity",
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 29,
                minY: 0,
                maxY: 6,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF8B5CF6),
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                          const Color(0xFF8B5CF6).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 HISTORICAL STATS GRID
  // ---------------------------------------------------------------------------
  Widget _buildHistoricalStatsGrid(ActivityStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "HISTORICAL METRICS",
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _metricBox("Longest Streak", "${stats.longestStreak} Days", Icons.emoji_events_rounded, const Color(0xFFF59E0B))),
            const SizedBox(width: 12),
            Expanded(child: _metricBox("Active Consistency", "${stats.consistency.toStringAsFixed(1)}%", Icons.bolt_rounded, const Color(0xFF10B981))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _metricBox("Active Days", "${stats.totalActiveDays}", Icons.calendar_today_rounded, const Color(0xFF38BDF8))),
            const SizedBox(width: 12),
            Expanded(child: _metricBox("Peak Weekday", stats.mostActiveDay, Icons.trending_up_rounded, const Color(0xFFEC4899))),
          ],
        ),
      ],
    );
  }

  Widget _metricBox(String label, String value, IconData icon, Color color) {
    return _glassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 MASTERY BADGES SECTION
  // ---------------------------------------------------------------------------
  Widget _buildMasteryBadgesSection(ActivityStats stats) {
    final badges = [
      _Badge("🌱", "Novice", "3-Day Streak", stats.longestStreak >= 3),
      _Badge("🔥", "Consistent", "7-Day Streak", stats.longestStreak >= 7),
      _Badge("⚡", "Momentum", "14-Day Streak", stats.longestStreak >= 14),
      _Badge("🏆", "Master", "30-Day Streak", stats.longestStreak >= 30),
      _Badge("👑", "Centurion", "100-Day Streak", stats.longestStreak >= 100),
    ];

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "MASTERY MILESTONES",
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: badges.map((b) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: b.unlocked ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: b.unlocked ? const Color(0xFFFBBF24).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        b.emoji,
                        style: TextStyle(
                          fontSize: 26,
                          color: b.unlocked ? null : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        b.title,
                        style: TextStyle(
                          color: b.unlocked ? Colors.white : Colors.white30,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.subtitle,
                        style: TextStyle(
                          color: b.unlocked ? const Color(0xFFFBBF24) : Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    Color? glowColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: glowColor != null ? glowColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.07),
              width: 1.1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Badge {
  final String emoji;
  final String title;
  final String subtitle;
  final bool unlocked;
  _Badge(this.emoji, this.title, this.subtitle, this.unlocked);
}

class _ConsistencyCosmicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(1337);

    for (int i = 0; i < 70; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.2;
      final alpha = random.nextDouble() * 0.35 + 0.05;

      paint.color = Colors.white.withValues(alpha: alpha);
      if (i % 4 == 0) paint.color = const Color(0xFF2DD4BF).withValues(alpha: alpha * 0.6);
      if (i % 7 == 0) paint.color = const Color(0xFF8B5CF6).withValues(alpha: alpha * 0.6);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
