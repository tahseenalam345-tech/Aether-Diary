import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

// Providers for Real Data
import '../../diary/data/diary_provider.dart';
import '../../productivity/data/productivity_providers.dart';
import '../../wallet/data/wallet_providers.dart';
import '../../wallet/domain/utils/aether_currency.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/module_preferences_provider.dart';
import '../../productivity/presentation/widgets/task_form_dialog.dart';

// ---------------------------------------------------------------------------
// 🌟 AETHER OS — HOME BENTO DESIGN TOKENS
// ---------------------------------------------------------------------------
class _Aether {
  _Aether._();

  // Brand Accents
  static const Color brandTeal = Color(0xFF2DD4BF);
  static const Color brandViolet = Color(0xFF8B5CF6);

  // Modular Workspace Accents
  static const Color wealth = Color(0xFF10B981); // Emerald
  static const Color diary = Color(0xFF38BDF8);  // Sky Blue
  static const Color tasks = Color(0xFFFBBF24);  // Amber
  static const Color habits = Color(0xFF4ADE80); // Mint
  static const Color focus = Color(0xFFF43F5E);  // Rose
}

/// 🌟 FROSTED GLASS BENTO CARD
class _BentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glow;
  final VoidCallback? onTap;

  const _BentoCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
    this.glow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: glow != null ? glow!.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08),
              width: 1.1,
            ),
            boxShadow: glow != null
                ? [
                    BoxShadow(
                      color: glow!.withValues(alpha: 0.12),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: card,
      );
    }

    return card;
  }
}

// ---------------------------------------------------------------------------
// 🌟 ACTIVITY & STREAK STATS ENGINE
// ---------------------------------------------------------------------------
class ActivityStats {
  final int currentStreak;
  final int longestStreak;
  final int previousStreak;
  final int totalActiveDays;
  final int totalMissedDays;
  final double consistency;
  final String mostActiveDay;
  final String milestoneText;
  final Map<DateTime, int> last7DaysActivity;
  final Map<DateTime, String?> last7DaysMood;
  final int totalNotes;
  final int totalTasks;
  final int totalExpenses;
  final double currentMonthSpend;
  final String topExpenseCategory;

  ActivityStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.previousStreak,
    required this.totalActiveDays,
    required this.totalMissedDays,
    required this.consistency,
    required this.mostActiveDay,
    required this.milestoneText,
    required this.last7DaysActivity,
    required this.last7DaysMood,
    required this.totalNotes,
    required this.totalTasks,
    required this.totalExpenses,
    required this.currentMonthSpend,
    required this.topExpenseCategory,
  });
}

final activityStatsProvider = Provider<ActivityStats>((ref) {
  final notes = ref.watch(diaryEntriesProvider).valueOrNull ?? [];
  final tasks = ref.watch(taskNotifierProvider).valueOrNull ?? [];
  final txs = ref.watch(transactionNotifierProvider).valueOrNull ?? [];

  DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  final today = dateOnly(DateTime.now());

  Map<DateTime, int> activeDatesMap = {};
  Map<DateTime, String?> dateMoodMap = {};

  for (var n in notes) {
    final d = dateOnly(n.createdAt);
    activeDatesMap[d] = (activeDatesMap[d] ?? 0) + 1;
    if (n.mood != null && !dateMoodMap.containsKey(d)) {
      dateMoodMap[d] = n.mood;
    }
  }
  for (var t in tasks) {
    if (t.isCompleted) {
      final d = dateOnly(t.createdAt);
      activeDatesMap[d] = (activeDatesMap[d] ?? 0) + 1;
    }
  }
  for (var x in txs) {
    final d = dateOnly(x.date);
    activeDatesMap[d] = (activeDatesMap[d] ?? 0) + 1;
  }

  int currentStreak = 0;
  DateTime checkDate = today;
  if (activeDatesMap.containsKey(checkDate)) {
    while (activeDatesMap.containsKey(checkDate)) {
      currentStreak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
  } else {
    checkDate = today.subtract(const Duration(days: 1));
    while (activeDatesMap.containsKey(checkDate)) {
      currentStreak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
  }

  final sortedDates = activeDatesMap.keys.toList()..sort();
  int longestStreak = 0;
  int tempStreak = 0;
  DateTime? prevDate;

  for (var d in sortedDates) {
    if (prevDate == null) {
      tempStreak = 1;
    } else {
      if (d.difference(prevDate).inDays == 1) {
        tempStreak++;
      } else {
        tempStreak = 1;
      }
    }
    if (tempStreak > longestStreak) longestStreak = tempStreak;
    prevDate = d;
  }
  if (currentStreak > longestStreak) longestStreak = currentStreak;

  int previousStreak = math.max(0, currentStreak - 1);
  int totalActiveDays = activeDatesMap.length;

  int totalDaysSpan = sortedDates.isEmpty ? 1 : today.difference(sortedDates.first).inDays + 1;
  if (totalDaysSpan <= 0) totalDaysSpan = 1;
  int totalMissedDays = math.max(0, totalDaysSpan - totalActiveDays);
  double consistency = (totalActiveDays / totalDaysSpan) * 100;
  if (consistency > 100) consistency = 100.0;

  Map<int, int> weekdayCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
  for (var d in activeDatesMap.keys) {
    weekdayCounts[d.weekday] = (weekdayCounts[d.weekday] ?? 0) + (activeDatesMap[d] ?? 1);
  }
  int maxWeekday = 1;
  int maxCount = -1;
  weekdayCounts.forEach((w, c) {
    if (c > maxCount) {
      maxCount = c;
      maxWeekday = w;
    }
  });
  const days = ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

  String milestone = "Just getting started! 🚀";
  if (currentStreak >= 30) {
    milestone = "Legendary! 1 Month+ Streak 🏆";
  } else if (currentStreak >= 14) {
    milestone = "Unstoppable! 2 Weeks Strong 🔥";
  } else if (currentStreak >= 7) {
    milestone = "Great Pace! 1 Week Completed ✨";
  } else if (currentStreak >= 3) {
    milestone = "Building Momentum! Keep it up ⚡";
  }

  Map<DateTime, int> last7Activity = {};
  Map<DateTime, String?> last7Mood = {};
  for (int i = 6; i >= 0; i--) {
    final d = today.subtract(Duration(days: i));
    last7Activity[d] = activeDatesMap[d] ?? 0;
    last7Mood[d] = dateMoodMap[d];
  }

  double monthSpend = 0.0;
  Map<String, double> catSpends = {};
  final now = DateTime.now();
  for (var t in txs) {
    if (t.type == 'expense' && t.date.year == now.year && t.date.month == now.month) {
      monthSpend += t.amount;
      catSpends[t.category] = (catSpends[t.category] ?? 0.0) + t.amount;
    }
  }
  String topCat = "General";
  double maxCatSpend = -1.0;
  catSpends.forEach((cat, spend) {
    if (spend > maxCatSpend) {
      maxCatSpend = spend;
      topCat = cat;
    }
  });

  return ActivityStats(
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    previousStreak: previousStreak,
    totalActiveDays: totalActiveDays,
    totalMissedDays: totalMissedDays,
    consistency: consistency,
    mostActiveDay: maxCount > 0 ? days[maxWeekday] : "N/A",
    milestoneText: milestone,
    last7DaysActivity: last7Activity,
    last7DaysMood: last7Mood,
    totalNotes: notes.length,
    totalTasks: tasks.length,
    totalExpenses: txs.where((t) => t.type == 'expense').length,
    currentMonthSpend: monthSpend,
    topExpenseCategory: topCat,
  );
});

// ---------------------------------------------------------------------------
// 🌟 HOME SCREEN (BENTO-BOX STYLE UNIVERSAL DASHBOARD)
// ---------------------------------------------------------------------------
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _analyticsDaysFilter = 7; // 7, 30

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning, ";
    if (hour < 17) return "Good afternoon, ";
    return "Good evening, ";
  }

  void _showAddTaskSheet(BuildContext context) {
    showAetherTaskFormDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final userNameAsync = ref.watch(userNameProvider);
    final prefs = ref.watch(modulePreferencesProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          body: CosmicBackground(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildGlassAppBar(context, ref, prefs),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),

                        // 🌟 GREETING & COMMAND BAR
                        _buildGreetingHeader(context, userNameAsync.valueOrNull, prefs)
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .slideY(begin: 0.15, end: 0),

                        const SizedBox(height: 18),

                        // 🌟 ACTIVE STREAK BANNER
                        _buildStreakPill(context, ref)
                            .animate()
                            .fadeIn(delay: 150.ms)
                            .scale(begin: const Offset(0.95, 0.95)),

                        const SizedBox(height: 20),

                        // -----------------------------------------------------------
                        // 🌟 BENTO-BOX DYNAMIC MODULAR CARDS
                        // -----------------------------------------------------------

                        // 💰 1. FINANCIAL PULSE (IF WEALTH ENABLED)
                        if (prefs.isWealthEnabled) ...[
                          _buildFinancialPulseBento(context, ref)
                              .animate()
                              .fadeIn(delay: 250.ms)
                              .slideY(begin: 0.08, end: 0),
                          const SizedBox(height: 16),
                        ],

                        // 📝 2. SANCTUARY & MEMORIES (IF DIARY ENABLED)
                        if (prefs.isDiaryEnabled) ...[
                          _buildSanctuaryBento(context, ref)
                              .animate()
                              .fadeIn(delay: 350.ms)
                              .slideY(begin: 0.08, end: 0),
                          const SizedBox(height: 16),
                        ],

                        // ⚡ 3. FOCUS & TASKS (IF PRODUCTIVITY ENABLED)
                        if (prefs.isProductivityEnabled) ...[
                          _buildProductivityBento(context, ref)
                              .animate()
                              .fadeIn(delay: 450.ms)
                              .slideY(begin: 0.08, end: 0),
                          const SizedBox(height: 16),
                        ],

                        // 🌟 IF ALL MODULES DISABLED: CUSTOMIZATION PROMPT
                        if (!prefs.hasAnyEnabled) ...[
                          _buildEmptyModulesCard(context)
                              .animate()
                              .fadeIn(delay: 200.ms)
                              .scale(begin: const Offset(0.92, 0.92)),
                          const SizedBox(height: 16),
                        ],

                        // 🌟 QUICK LAUNCHER WORKSPACES GRID
                        _buildWorkspacesGrid(context, prefs)
                            .animate()
                            .fadeIn(delay: 550.ms)
                            .slideY(begin: 0.06, end: 0),

                        const SizedBox(height: 24),

                        // 🌟 RICH UNIVERSAL ANALYTICS & ACTIVITY RECORDS DASHBOARD
                        _buildUniversalAnalyticsSection(context, ref, prefs)
                            .animate()
                            .fadeIn(delay: 650.ms)
                            .slideY(begin: 0.06, end: 0),

                        const SizedBox(height: 120), // Bottom padding for navbar
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🌟 EXPANDABLE FAST ACTION FAB
          floatingActionButton: _ExpandableFab(
            prefs: prefs,
            onMemoryTapped: () => context.push('/create'),
            onTaskTapped: () => _showAddTaskSheet(context),
            onExpenseTapped: () => context.push('/add-transaction'),
          ).animate().slideY(begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutBack),
        ),

        // Initial setup overlay if user name not loaded
        if (userNameAsync.valueOrNull == null && !userNameAsync.isLoading)
          const Positioned.fill(child: _AetherInitializationOverlay()),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 APP BAR & HEADER
  // ---------------------------------------------------------------------------
  Widget _buildGlassAppBar(BuildContext context, WidgetRef ref, ModulePreferences prefs) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: const Color(0xFF060B14).withValues(alpha: 0.65),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _Aether.brandTeal,
                          boxShadow: [
                            BoxShadow(
                              color: _Aether.brandTeal.withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "AETHER OS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),

                  // Top Action Icons
                  Row(
                    children: [
                      _circleIconButton(
                        Icons.search_rounded,
                        () {
                          HapticFeedback.selectionClick();
                          context.push('/search');
                        },
                      ),
                      const SizedBox(width: 8),
                      _circleIconButton(
                        Icons.auto_awesome,
                        () {
                          HapticFeedback.selectionClick();
                          context.push('/ai_reflect');
                        },
                        color: _Aether.brandViolet,
                      ),
                      const SizedBox(width: 8),
                      _circleIconButton(
                        Icons.settings_outlined,
                        () {
                          HapticFeedback.selectionClick();
                          context.push('/settings');
                        },
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

  Widget _circleIconButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: color ?? Colors.white70, size: 18),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 GREETING & MODULE BADGES
  // ---------------------------------------------------------------------------
  Widget _buildGreetingHeader(BuildContext context, String? userName, ModulePreferences prefs) {
    final currentDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _Aether.brandTeal.withValues(alpha: 0.15),
                    _Aether.brandViolet.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                currentDate.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 1.4,
                  color: _Aether.brandTeal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            // Active Modules Counter
            Row(
              children: [
                if (prefs.isWealthEnabled) _moduleDot("💰", _Aether.wealth),
                if (prefs.isDiaryEnabled) _moduleDot("📝", _Aether.diary),
                if (prefs.isProductivityEnabled) _moduleDot("⚡", _Aether.tasks),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: _getGreeting(),
                style: const TextStyle(
                  fontSize: 26,
                  color: Colors.white70,
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: userName ?? "Traveler",
                style: const TextStyle(
                  fontSize: 26,
                  color: _Aether.brandTeal,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          "Your modular digital command deck for today.",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _moduleDot(String emoji, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 11)),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 GLOBAL STREAK PILL (NAVIGATES TO CONSISTENCY ANALYTICS)
  // ---------------------------------------------------------------------------
  Widget _buildStreakPill(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(activityStatsProvider);

    return _BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      glow: Colors.amberAccent,
      onTap: () {
        context.push('/consistency-analytics');
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text("🔥", style: TextStyle(fontSize: 20))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.9, end: 1.15, duration: 800.ms),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${stats.currentStreak} Day Mastery Streak",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stats.milestoneText,
                    style: TextStyle(
                      color: Colors.amberAccent.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  "${stats.consistency.toInt()}% Active",
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 💰 BENTO BOX 1: FINANCIAL PULSE (WITH PROMINENT NET WORTH)
  // ---------------------------------------------------------------------------
  Widget _buildFinancialPulseBento(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(transactionNotifierProvider).valueOrNull ?? [];
    final budgets = ref.watch(budgetNotifierProvider).valueOrNull ?? [];
    final accounts = ref.watch(accountNotifierProvider).valueOrNull ?? [];

    double netWorth = 0.0;
    for (var acc in accounts) {
      netWorth += acc.initialBalance;
    }

    final now = DateTime.now();
    double todaySpend = 0.0;
    double monthSpend = 0.0;
    for (var t in txs) {
      if (t.type == 'expense') {
        if (t.date.year == now.year && t.date.month == now.month && t.date.day == now.day) {
          todaySpend += t.amount;
        }
        if (t.date.year == now.year && t.date.month == now.month) {
          monthSpend += t.amount;
        }
      }
    }

    final activeBudgets = budgets.where((b) => b.isActive).toList();

    return _BentoCard(
      glow: _Aether.wealth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _Aether.wealth.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: _Aether.wealth, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "FINANCIAL PULSE",
                    style: TextStyle(
                      color: _Aether.wealth,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.push('/wallet'),
                child: Row(
                  children: [
                    Text("Wallet Hub", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.4), size: 16),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 🌟 PROMINENT NET WORTH BANNER ROW
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _Aether.wealth.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _Aether.wealth.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("TOTAL WALLET NET WORTH", style: TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                    const SizedBox(height: 2),
                    Text(
                      AetherCurrency.format(netWorth),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _Aether.wealth.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${accounts.length} Accounts",
                    style: const TextStyle(color: _Aether.wealth, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Core Metrics Row
          Row(
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Today's Expense", style: TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AetherCurrency.format(todaySpend),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Month: ${AetherCurrency.format(monthSpend)}",
                      style: TextStyle(color: _Aether.wealth.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 44, color: Colors.white10),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Active Budgets", style: TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      activeBudgets.isEmpty ? "No active limits" : "${activeBudgets.length} Monitored",
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeBudgets.isEmpty ? "Tap to set budget" : "Pacing healthy",
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 12),

          // Quick Action Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/add-transaction'),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: _Aether.wealth.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _Aether.wealth.withValues(alpha: 0.3)),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: _Aether.wealth, size: 18),
                          SizedBox(width: 6),
                          Text("Log Expense", style: TextStyle(color: _Aether.wealth, fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/financial-analytics'),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined, color: Colors.white70, size: 16),
                          SizedBox(width: 6),
                          Text("Analytics", style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
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
  // 📝 BENTO BOX 2: SANCTUARY & MEMORIES
  // ---------------------------------------------------------------------------
  Widget _buildSanctuaryBento(BuildContext context, WidgetRef ref) {
    final diaryEntries = ref.watch(diaryEntriesProvider).valueOrNull ?? [];
    final latestEntry = diaryEntries.isNotEmpty ? diaryEntries.first : null;

    return _BentoCard(
      glow: _Aether.diary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _Aether.diary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: _Aether.diary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "SANCTUARY & REFLECTION",
                    style: TextStyle(
                      color: _Aether.diary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.push('/diary'),
                child: Row(
                  children: [
                    Text("Vault", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.4), size: 16),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Mood Quick Check-In Row
          const Text("How are you feeling today?", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _moodQuickChip(context, "😊", "Happy", const Color(0xFFFFD700)),
                _moodQuickChip(context, "🌊", "Calm", const Color(0xFF4ADE80)),
                _moodQuickChip(context, "🌧️", "Sad", const Color(0xFF60A5FA)),
                _moodQuickChip(context, "⚡", "Anxious", const Color(0xFFF472B6)),
                _moodQuickChip(context, "🔥", "Angry", const Color(0xFFEF4444)),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 12),

          // Latest Memory Preview or Create Prompt
          if (latestEntry != null)
            GestureDetector(
              onTap: () => context.push('/create', extra: latestEntry),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _Aether.diary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bookmark_outline_rounded, color: _Aether.diary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            latestEntry.title.isNotEmpty ? latestEntry.title : "Untitled Reflection",
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            latestEntry.content.replaceAll('\n', ' ').trim(),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 12),
                  ],
                ),
              ),
            ),
          // Quick Action Buttons
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/create'),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: _Aether.diary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _Aether.diary.withValues(alpha: 0.3)),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_note_rounded, color: _Aether.diary, size: 18),
                          SizedBox(width: 6),
                          Text("New Entry", style: TextStyle(color: _Aether.diary, fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/consistency-analytics'),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined, color: Colors.white70, size: 16),
                          SizedBox(width: 6),
                          Text("Analytics", style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moodQuickChip(BuildContext context, String emoji, String label, Color color) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/create', extra: {'initialMood': label});
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ⚡ BENTO BOX 3: FOCUS & TASKS
  // ---------------------------------------------------------------------------
  Widget _buildProductivityBento(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(taskNotifierProvider).valueOrNull ?? [];
    final uncompletedTasks = allTasks.where((t) => !t.isCompleted).take(3).toList();

    return _BentoCard(
      glow: _Aether.tasks,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _Aether.tasks.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: _Aether.tasks, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "FOCUS & TASKS",
                    style: TextStyle(
                      color: _Aether.tasks,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.push('/productivity'),
                child: Row(
                  children: [
                    Text("Tasks Hub", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.4), size: 16),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Focus Sprint Launcher
          GestureDetector(
            onTap: () => context.push('/focus'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_Aether.focus.withValues(alpha: 0.2), _Aether.brandViolet.withValues(alpha: 0.2)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _Aether.focus.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, color: _Aether.focus, size: 18),
                      SizedBox(width: 8),
                      Text("Start 25m Focus Sprint", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Icon(Icons.play_circle_fill_rounded, color: _Aether.focus, size: 22),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Tasks Checklist
          if (uncompletedTasks.isNotEmpty) ...[
            Column(
              children: uncompletedTasks.map((task) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(taskNotifierProvider.notifier).toggleTaskCompletion(task);
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _Aether.tasks.withValues(alpha: 0.7), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(task.category, style: const TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: const Text("All tasks completed for today! 🎉", style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],

          const SizedBox(height: 6),

          // Add Task / Habits / Analytics Row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showAddTaskSheet(context),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: _Aether.tasks.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _Aether.tasks.withValues(alpha: 0.3)),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: _Aether.tasks, size: 16),
                          SizedBox(width: 4),
                          Text("Add Task", style: TextStyle(color: _Aether.tasks, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/habits'),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.repeat_rounded, color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text("Habits", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/consistency-analytics'),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined, color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text("Analytics", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
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
  // 🌟 RICH UNIVERSAL ANALYTICS & ACTIVITY RECORDS (CHARTS, TABLES, HISTORY)
  // ---------------------------------------------------------------------------
  Widget _buildUniversalAnalyticsSection(BuildContext context, WidgetRef ref, ModulePreferences prefs) {
    if (!prefs.hasAnyEnabled) return const SizedBox.shrink();

    final txs = ref.watch(transactionNotifierProvider).valueOrNull ?? [];
    final tasks = ref.watch(taskNotifierProvider).valueOrNull ?? [];
    final diaries = ref.watch(diaryEntriesProvider).valueOrNull ?? [];

    final completedTasksCount = tasks.where((t) => t.isCompleted).length;
    final taskRatio = tasks.isEmpty ? 0.0 : (completedTasksCount / tasks.length);

    final recentEntries = diaries.take(3).toList();
    final recentTxs = txs.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "UNIVERSAL COMMAND ANALYTICS",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            Row(
              children: [
                _rangePill(7, "7D"),
                const SizedBox(width: 6),
                _rangePill(30, "30D"),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 🌟 1. INTERACTIVE VELOCITY CHART (FL_CHART)
        _BentoCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Cross-Module Daily Execution", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text("Aggregate activity momentum", style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _Aether.brandTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text("LIVE PULSE", style: TextStyle(color: _Aether.brandTeal, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 130,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: 6,
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          const FlSpot(0, 1.5),
                          const FlSpot(1, 3.2),
                          const FlSpot(2, 2.1),
                          const FlSpot(3, 4.8),
                          const FlSpot(4, 3.7),
                          const FlSpot(5, 5.2),
                          const FlSpot(6, 4.5),
                        ],
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: _Aether.brandTeal,
                        barWidth: 3.0,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _Aether.brandTeal.withValues(alpha: 0.35),
                              _Aether.brandTeal.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 🌟 2. STATS BREAKDOWN GRID
        Row(
          children: [
            if (prefs.isProductivityEnabled)
              Expanded(
                child: _BentoCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: _Aether.tasks, size: 18),
                          Text("VELOCITY", style: TextStyle(color: _Aether.tasks, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text("${(taskRatio * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text("$completedTasksCount of ${tasks.length} done", style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                    ],
                  ),
                ),
              ),

            if (prefs.isProductivityEnabled && (prefs.isDiaryEnabled || prefs.isWealthEnabled))
              const SizedBox(width: 10),

            if (prefs.isDiaryEnabled)
              Expanded(
                child: _BentoCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.auto_stories_rounded, color: _Aether.diary, size: 18),
                          Text("MEMORIES", style: TextStyle(color: _Aether.diary, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text("${diaries.length}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text("Vault Reflections", style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                    ],
                  ),
                ),
              ),

            if (prefs.isDiaryEnabled && prefs.isWealthEnabled && !prefs.isProductivityEnabled)
              const SizedBox(width: 10),

            if (prefs.isWealthEnabled && (!prefs.isProductivityEnabled || !prefs.isDiaryEnabled))
              Expanded(
                child: _BentoCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.payments_outlined, color: _Aether.wealth, size: 18),
                          Text("CASHFLOW", style: TextStyle(color: _Aether.wealth, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text("${txs.length}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text("Logged Records", style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                    ],
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // 🌟 3. RECENT ACTIVITY RECORDS TABLE / TIMELINE
        _BentoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Live Activity History", style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
                  Text("Latest Actions", style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
              const SizedBox(height: 10),

              if (recentEntries.isEmpty && recentTxs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: Text("No recent records logged yet.", style: TextStyle(color: Colors.white38, fontSize: 12))),
                ),

              ...recentEntries.map((e) => _historyRow(
                    icon: Icons.auto_stories_rounded,
                    color: _Aether.diary,
                    title: e.title.isNotEmpty ? e.title : "Reflection",
                    subtitle: DateFormat('MMM d, h:mm a').format(e.createdAt),
                    tag: e.mood ?? "Note",
                  )),

              ...recentTxs.map((t) => _historyRow(
                    icon: Icons.account_balance_wallet_rounded,
                    color: _Aether.wealth,
                    title: t.title,
                    subtitle: DateFormat('MMM d, h:mm a').format(t.date),
                    tag: AetherCurrency.format(t.amount),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rangePill(int days, String label) {
    final isSelected = _analyticsDaysFilter == days;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _analyticsDaysFilter = days);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _Aether.brandTeal.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? _Aether.brandTeal : Colors.white10),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? _Aether.brandTeal : Colors.white54, fontSize: 10.5, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _historyRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String tag,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
            child: Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 EMPTY MODULES FALLBACK CARD
  // ---------------------------------------------------------------------------
  Widget _buildEmptyModulesCard(BuildContext context) {
    return _BentoCard(
      glow: _Aether.brandTeal,
      child: Column(
        children: [
          const Icon(Icons.tune_rounded, color: _Aether.brandTeal, size: 36),
          const SizedBox(height: 12),
          const Text(
            "Customize Your Workspaces",
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "You have deactivated all main modules. Enable Wealth, Diary, or Tasks in Settings to personalize your command deck.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_Aether.brandTeal, _Aether.brandViolet]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text("Open Module Settings", style: TextStyle(color: Color(0xFF060B14), fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 WORKSPACES QUICK GRID
  // ---------------------------------------------------------------------------
  Widget _buildWorkspacesGrid(BuildContext context, ModulePreferences prefs) {
    final List<_ModuleItem> availableModules = [];

    if (prefs.isDiaryEnabled) {
      availableModules.add(const _ModuleItem('📝', 'Diary', _Aether.diary, '/diary'));
    }
    if (prefs.isProductivityEnabled) {
      availableModules.add(const _ModuleItem('📋', 'Tasks', _Aether.tasks, '/productivity'));
      availableModules.add(const _ModuleItem('🔁', 'Habits', _Aether.habits, '/habits'));
      availableModules.add(const _ModuleItem('⏱️', 'Focus', _Aether.focus, '/focus'));
    }
    if (prefs.isWealthEnabled) {
      availableModules.add(const _ModuleItem('💸', 'Wealth', _Aether.wealth, '/wallet'));
      availableModules.add(const _ModuleItem('🎯', 'Budgets', Color(0xFFF59E0B), '/budgets'));
      availableModules.add(const _ModuleItem('📈', 'Analytics', Color(0xFF0EA5E9), '/financial-analytics'));
    }
    availableModules.add(const _ModuleItem('📊', 'Consistency', _Aether.brandTeal, '/consistency-analytics'));
    availableModules.add(const _ModuleItem('📅', 'Calendar', _Aether.brandViolet, '/calendar'));
    availableModules.add(const _ModuleItem('✨', 'AI Reflect', _Aether.brandViolet, '/ai_reflect'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ACTIVE WORKSPACES",
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.2,
          ),
          itemCount: availableModules.length,
          itemBuilder: (context, index) {
            final item = availableModules[index];
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push(item.route);
              },
              child: _BentoCard(
                padding: const EdgeInsets.all(12),
                radius: 18,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 🌟 EXPANDABLE FAB
// ---------------------------------------------------------------------------
class _ExpandableFab extends StatefulWidget {
  final ModulePreferences prefs;
  final VoidCallback onMemoryTapped;
  final VoidCallback onTaskTapped;
  final VoidCallback onExpenseTapped;

  const _ExpandableFab({
    required this.prefs,
    required this.onMemoryTapped,
    required this.onTaskTapped,
    required this.onExpenseTapped,
  });

  @override
  State<_ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<_ExpandableFab> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ...[
          if (widget.prefs.isWealthEnabled) ...[
            _fabItem(Icons.account_balance_wallet_rounded, "Fast Expense", _Aether.wealth, widget.onExpenseTapped),
            const SizedBox(height: 10),
          ],
          if (widget.prefs.isProductivityEnabled) ...[
            _fabItem(Icons.check_circle_rounded, "New Task", _Aether.tasks, widget.onTaskTapped),
            const SizedBox(height: 10),
          ],
          if (widget.prefs.isDiaryEnabled) ...[
            _fabItem(Icons.auto_stories_rounded, "New Memory", _Aether.diary, widget.onMemoryTapped),
            const SizedBox(height: 10),
          ],
        ],
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 54,
            height: 54,
            margin: const EdgeInsets.only(bottom: 60),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_Aether.brandTeal, _Aether.brandViolet],
              ),
              boxShadow: [
                BoxShadow(
                  color: _Aether.brandTeal.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: RotationTransition(
              turns: Tween(begin: 0.0, end: 0.125).animate(_controller),
              child: const Icon(Icons.add_rounded, color: Color(0xFF060B14), size: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fabItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        _toggle();
        onTap();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0C101E).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF060B14), size: 20),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🌟 INITIALIZATION OVERLAY & BACKGROUNDS
// ---------------------------------------------------------------------------
class _AetherInitializationOverlay extends ConsumerStatefulWidget {
  const _AetherInitializationOverlay();

  @override
  ConsumerState<_AetherInitializationOverlay> createState() => _AetherInitializationOverlayState();
}

class _AetherInitializationOverlayState extends ConsumerState<_AetherInitializationOverlay> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, color: _Aether.brandTeal, size: 48),
                const SizedBox(height: 20),
                const Text("Welcome to Aether OS", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("What should we call you?", style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: "Enter your name",
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Aether.brandTeal,
                    foregroundColor: const Color(0xFF060B14),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    if (_nameController.text.trim().isNotEmpty) {
                      ref.read(userNameProvider.notifier).setName(_nameController.text.trim());
                    }
                  },
                  child: const Text("Initialize Sanctuary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CosmicBackground extends StatelessWidget {
  final Widget child;
  const CosmicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: const Color(0xFF060B14),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _CosmicDustPainter(),
          ),
        ),
        child,
      ],
    );
  }
}

class _CosmicDustPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42);

    for (int i = 0; i < 90; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.1;
      final alpha = random.nextDouble() * 0.45 + 0.05;

      paint.color = Colors.white.withValues(alpha: alpha);
      if (i % 5 == 0) paint.color = _Aether.brandTeal.withValues(alpha: alpha * 0.7);
      if (i % 8 == 0) paint.color = _Aether.brandViolet.withValues(alpha: alpha * 0.7);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ModuleItem {
  final String emoji;
  final String label;
  final Color color;
  final String route;
  const _ModuleItem(this.emoji, this.label, this.color, this.route);
}