import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/models/aether_budget.dart';
import '../domain/models/aether_transaction.dart';
import '../domain/utils/aether_currency.dart';
import '../domain/utils/aether_budget_date_helper.dart';
import '../data/wallet_providers.dart';
import 'widgets/aether_liquid_dropdown.dart';
import 'widgets/aether_liquid_date_picker.dart';

// =========================================================================
// 🧠 1. ADVANCED ANALYTICS & ALERT DATA MODELS
// =========================================================================
class CategoryStats {
  final double category_total;
  final double category_percent;
  final int category_txn_count;
  final double category_avg_txn;
  final double? category_variance_vs_prev_period;

  CategoryStats({
    required this.category_total, required this.category_percent,
    required this.category_txn_count, required this.category_avg_txn, this.category_variance_vs_prev_period,
  });
}

class BudgetAnalyticsData {
  final int baseTotalDays; final int baseElapsedDays; final int baseRemainingDays;
  final double baseSpent; final double baseRemaining; final double? basePercentUsed;
  final int filterDays; final double filterSpent; final double pastFilterSpent; final double filterDailyAvg;
  final DateTime filterStartDate; final DateTime filterEndDate;
  final DateTime pastFilterStartDate; final DateTime pastFilterEndDate;
  final double safeDailyPace; final double forecastTotal; final double forecastVariance; 
  final String paceStatus; final String prescriptiveMessage; final String? depletionWarning; final double? trendForecast;
  final Map<String, CategoryStats> categoryBreakdown; final Map<String, double> pastBreakdown;
  final Map<int, double> weekdayAvgSpend; final int highestSpendWeekday;
  final Map<DateTime, double> baseDailySeries; final Map<DateTime, double> pastBaseDailySeries;
  final Map<int, Map<String, double>> dailyCategorySpends;
  final bool isNotStarted; final DateTime baseStartDate; final DateTime baseEndDate; 
  final String filterName; final String comparisonName; final String granularity; final bool isCompareActive;

  BudgetAnalyticsData({
    required this.baseTotalDays, required this.baseElapsedDays, required this.baseRemainingDays,
    required this.baseSpent, required this.baseRemaining, this.basePercentUsed,
    required this.filterDays, required this.filterSpent, required this.pastFilterSpent, required this.filterDailyAvg,
    required this.filterStartDate, required this.filterEndDate,
    required this.pastFilterStartDate, required this.pastFilterEndDate,
    required this.safeDailyPace, required this.forecastTotal, required this.forecastVariance,
    required this.paceStatus, required this.prescriptiveMessage, this.depletionWarning, this.trendForecast,
    required this.categoryBreakdown, required this.pastBreakdown, required this.weekdayAvgSpend,
    required this.highestSpendWeekday, required this.baseDailySeries, required this.pastBaseDailySeries,
    required this.dailyCategorySpends, required this.isNotStarted, required this.baseStartDate, required this.baseEndDate, 
    required this.filterName, required this.comparisonName, required this.granularity, required this.isCompareActive,
  });
}

class _SmartAlert {
  final IconData icon; final Color color; final String title; final String message; final String time;
  _SmartAlert(this.icon, this.color, this.title, this.message, this.time);
}

// =========================================================================
// 🖥️ 2. MAIN SCREEN UI
// =========================================================================
class BudgetDetailsScreen extends ConsumerStatefulWidget {
  final AetherBudget budget;
  const BudgetDetailsScreen({super.key, required this.budget});

  @override
  ConsumerState<BudgetDetailsScreen> createState() => _BudgetDetailsScreenState();
}

class _BudgetDetailsScreenState extends ConsumerState<BudgetDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  String _selectedFilter = 'Overall';
  final List<String> _filters = const ['Overall', 'Today', 'Last 3 Days', 'Last 7 Days', 'Last 10 Days', 'Last 30 Days', 'This Week', 'This Month', 'Custom'];
  DateTimeRange? _customRange;
  
  // 🌟 ADVANCED 4-TIER COMPARISON ENGINE STATE (By default OFF)
  bool _comparePastPeriod = false;
  String _compareTab = 'Day'; // 'Day', 'Week', 'Month', 'Custom'
  
  // Day options
  String _dayCurrent = 'Today';
  final List<String> _dayCurrentOptions = ['Today', 'Yesterday'];
  String _dayCompareWith = 'Preceding day';
  final List<String> _dayCompareOptions = ['Preceding day', 'Same day last week', 'Same day last month', 'Same day last year'];

  // Week options
  String _weekCurrent = 'Last 7 days';
  final List<String> _weekCurrentOptions = ['Last 7 days', 'This week', 'Last week'];
  String _weekCompareWith = 'Preceding period';
  final List<String> _weekCompareOptions = ['Preceding period', 'Four weeks ago', 'Preceding year same week'];

  // Month options
  String _monthCurrent = 'This month';
  final List<String> _monthCurrentOptions = ['Last 30 days', 'This month', 'Last month'];
  String _monthCompareWith = 'Preceding period';
  final List<String> _monthCompareOptions = ['Preceding period', 'Four weeks ago', 'Preceding year this month'];

  // Custom options
  DateTimeRange? _customCurrentRange;
  DateTimeRange? _customCompareRange;

  int _touchedCategoryIndex = -1;

  String _chartFilter = '7 Days';
  final List<String> _chartFilters = ['Today', '3 Days', '7 Days', '10 Days', '30 Days', 'Full Cycle'];

  String _sortCategoryBy = 'Amount (Desc)';
  final List<String> _sortOptions = const ['Amount (Desc)', 'Amount (Asc)', '% of Total ↓', 'Name (A-Z)', 'Transactions ↓', 'Variance ↓'];

  String _searchQuery = '';
  String _recordSortBy = 'Date (Newest)';
  final List<String> _recordSortOptions = ['Date (Newest)', 'Date (Oldest)', 'Amount (High-Low)', 'Amount (Low-High)', 'Name (A-Z)'];

  // 🌟 NAYA: In-App Notification Visibility State
  bool _showSmartAlerts = true;
  Timer? _alertTimer;
  int _cycleOffset = 0; // 🌟 0 = Current Cycle, -1 = Previous Cycle, -2 = 2 Cycles Ago, etc.

  static const Color _bgDark = Color(0xFF060B14);
  static const Color _sky = Color(0xFF38BDF8);
  static const Color _rose = Color(0xFFFB7185);
  static const Color _mint = Color(0xFF34F5C5);
  static const Color _amber = Color(0xFFFBBF60);
  static const Color _violet = Color(0xFFA78BFA);
  static const Color _slate = Color(0xFF64748B);
  static const List<Color> _palette = [_sky, _rose, _amber, _mint, _violet, _slate, Color(0xFFF472B6), Color(0xFF4ADE80)];

  Color _colorForIndex(int i) => _palette[i % _palette.length];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 🌟 5-Second Auto Hide Timer for Notifications
    _alertTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() { _showSmartAlerts = false; });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _alertTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final range = await showAetherLiquidDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      accentColor: _sky,
      title: "Custom Time Filter",
    );
    if (range != null) {
      setState(() { _customRange = range; _selectedFilter = 'Custom'; _touchedCategoryIndex = -1; });
    }
  }

  Future<void> _pickCustomCurrentRange() async {
    final now = DateTime.now();
    final picked = await showAetherLiquidDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _customCurrentRange ?? DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      accentColor: _sky,
      title: "Current Benchmark Range",
    );
    if (picked != null) {
      setState(() => _customCurrentRange = picked);
    }
  }

  Future<void> _pickCustomCompareRange() async {
    final now = DateTime.now();
    final picked = await showAetherLiquidDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _customCompareRange ?? DateTimeRange(start: now.subtract(const Duration(days: 13)), end: now.subtract(const Duration(days: 7))),
      accentColor: _amber,
      title: "Compare Benchmark Range",
    );
    if (picked != null) {
      setState(() => _customCompareRange = picked);
    }
  }

  // 🌟 RESOLVE COMPARISON & DATE RANGES ACCURATELY
  (DateTime, DateTime, DateTime, DateTime, String, String) _resolveDateRanges(DateTime now, DateTime baseStart, DateTime baseEnd, int baseElapsedDays) {
    if (!_comparePastPeriod) {
      DateTime fStart, fEnd; int fDays;
      if (_selectedFilter == 'Today') {
        fStart = DateTime(now.year, now.month, now.day);
        fEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        fDays = 1;
      } else if (_selectedFilter == 'Last 3 Days') {
        fStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2));
        fEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        fDays = 3;
      } else if (_selectedFilter == 'Last 7 Days') {
        fStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        fEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        fDays = 7;
      } else if (_selectedFilter == 'Last 10 Days') {
        fStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 9));
        fEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        fDays = 10;
      } else if (_selectedFilter == 'Last 30 Days') {
        fStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        fEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        fDays = 30;
      } else if (_selectedFilter == 'This Week') {
        fStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        fEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        fDays = fEnd.difference(fStart).inDays + 1;
      } else if (_selectedFilter == 'This Month') {
        fStart = DateTime(now.year, now.month, 1);
        fEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        fDays = fEnd.difference(fStart).inDays + 1;
      } else if (_selectedFilter == 'Custom' && _customRange != null) {
        fStart = DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day);
        fEnd = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59);
        if (fEnd.isAfter(now)) fEnd = now;
        fDays = fEnd.difference(fStart).inDays + 1;
      } else {
        fStart = baseStart;
        fEnd = now.isBefore(baseEnd) ? now : baseEnd;
        fDays = baseElapsedDays;
      }
      if (fDays < 1) fDays = 1;
      DateTime pStart = fStart.subtract(Duration(days: fDays));
      DateTime pEnd = fStart.subtract(const Duration(seconds: 1));
      return (fStart, fEnd, pStart, pEnd, _selectedFilter, 'Preceding $fDays days');
    }

    // 🌟 ADVANCED 4-TIER COMPARISON ENGINE
    DateTime fStart, fEnd, pStart, pEnd;
    String curLabel, cmpLabel;

    if (_compareTab == 'Day') {
      if (_dayCurrent == 'Yesterday') {
        final y = now.subtract(const Duration(days: 1));
        fStart = DateTime(y.year, y.month, y.day);
        fEnd = DateTime(y.year, y.month, y.day, 23, 59, 59);
        curLabel = 'Yesterday';
      } else {
        fStart = DateTime(now.year, now.month, now.day);
        fEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        curLabel = 'Today';
      }

      if (_dayCompareWith == 'Same day last week') {
        pStart = fStart.subtract(const Duration(days: 7));
        pEnd = fEnd.subtract(const Duration(days: 7));
        cmpLabel = 'Same day last week';
      } else if (_dayCompareWith == 'Same day last month') {
        pStart = DateTime(fStart.year, fStart.month - 1, fStart.day);
        pEnd = DateTime(fEnd.year, fEnd.month - 1, fEnd.day, 23, 59, 59);
        cmpLabel = 'Same day last month';
      } else if (_dayCompareWith == 'Same day last year') {
        pStart = DateTime(fStart.year - 1, fStart.month, fStart.day);
        pEnd = DateTime(fEnd.year - 1, fEnd.month, fEnd.day, 23, 59, 59);
        cmpLabel = 'Same day last year';
      } else {
        // Preceding day
        pStart = fStart.subtract(const Duration(days: 1));
        pEnd = fEnd.subtract(const Duration(days: 1));
        cmpLabel = 'Preceding day';
      }
    } else if (_compareTab == 'Week') {
      if (_weekCurrent == 'This week') {
        fStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        fEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        curLabel = 'This Week';
      } else if (_weekCurrent == 'Last week') {
        final mondayThisWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        fStart = mondayThisWeek.subtract(const Duration(days: 7));
        fEnd = mondayThisWeek.subtract(const Duration(seconds: 1));
        curLabel = 'Last Week';
      } else {
        // Last 7 days
        fStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        fEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        curLabel = 'Last 7 Days';
      }

      int span = fEnd.difference(fStart).inDays + 1;
      if (_weekCompareWith == 'Four weeks ago') {
        pStart = fStart.subtract(const Duration(days: 28));
        pEnd = fEnd.subtract(const Duration(days: 28));
        cmpLabel = '4 Weeks Ago';
      } else if (_weekCompareWith == 'Preceding year same week') {
        pStart = fStart.subtract(const Duration(days: 364));
        pEnd = fEnd.subtract(const Duration(days: 364));
        cmpLabel = 'Preceding Year (Same Week)';
      } else {
        // Preceding period
        pStart = fStart.subtract(Duration(days: span));
        pEnd = fStart.subtract(const Duration(seconds: 1));
        cmpLabel = 'Preceding Period';
      }
    } else if (_compareTab == 'Month') {
      if (_monthCurrent == 'Last month') {
        final firstThisMonth = DateTime(now.year, now.month, 1);
        fStart = DateTime(now.year, now.month - 1, 1);
        fEnd = firstThisMonth.subtract(const Duration(seconds: 1));
        curLabel = 'Last Month';
      } else if (_monthCurrent == 'This month') {
        fStart = DateTime(now.year, now.month, 1);
        fEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        curLabel = 'This Month';
      } else {
        // Last 30 days
        fStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        fEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        curLabel = 'Last 30 Days';
      }

      int span = fEnd.difference(fStart).inDays + 1;
      if (_monthCompareWith == 'Four weeks ago') {
        pStart = fStart.subtract(const Duration(days: 28));
        pEnd = fEnd.subtract(const Duration(days: 28));
        cmpLabel = '4 Weeks Ago';
      } else if (_monthCompareWith == 'Preceding year this month') {
        pStart = DateTime(fStart.year - 1, fStart.month, 1);
        pEnd = DateTime(fStart.year - 1, fStart.month + 1, 0, 23, 59, 59);
        cmpLabel = 'Preceding Year (Same Month)';
      } else {
        // Preceding period
        pStart = fStart.subtract(Duration(days: span));
        pEnd = fStart.subtract(const Duration(seconds: 1));
        cmpLabel = 'Preceding Period';
      }
    } else {
      // Custom
      final curRange = _customCurrentRange ?? DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
      fStart = DateTime(curRange.start.year, curRange.start.month, curRange.start.day);
      fEnd = DateTime(curRange.end.year, curRange.end.month, curRange.end.day, 23, 59, 59);
      curLabel = "${DateFormat('MMM d').format(fStart)} - ${DateFormat('MMM d').format(fEnd)}";

      if (_customCompareRange != null) {
        pStart = DateTime(_customCompareRange!.start.year, _customCompareRange!.start.month, _customCompareRange!.start.day);
        pEnd = DateTime(_customCompareRange!.end.year, _customCompareRange!.end.month, _customCompareRange!.end.day, 23, 59, 59);
        cmpLabel = "${DateFormat('MMM d').format(pStart)} - ${DateFormat('MMM d').format(pEnd)}";
      } else {
        int span = fEnd.difference(fStart).inDays + 1;
        pStart = fStart.subtract(Duration(days: span));
        pEnd = fStart.subtract(const Duration(seconds: 1));
        cmpLabel = "Preceding $span Days";
      }
    }

    return (fStart, fEnd, pStart, pEnd, curLabel, cmpLabel);
  }

  // =========================================================================
  // 🧮 3. THE MATHEMATICAL ENGINE
  // =========================================================================
  BudgetAnalyticsData _computeEngine(List<AetherTransaction> allTxs, AetherBudget b) {
    final now = DateTime.now();
    
    final (baseStart, baseEnd, baseTotalDays, baseElapsedDays, baseRemainingDays, isCurrentCycle) =
        AetherBudgetDateHelper.getPeriodRange(b, cycleOffset: _cycleOffset, referenceNow: now);
    
    bool isNotStarted = baseStart.isAfter(now);

    final (pastBaseStart, pastBaseEnd, _, _, _, _) =
        AetherBudgetDateHelper.getPeriodRange(b, cycleOffset: _cycleOffset - 1, referenceNow: now);

    // 🌟 RESOLVE CURRENT & COMPARISON RANGES VIA NEW ENGINE
    final (filterStart, filterEnd, pastFilterStart, pastFilterEnd, filterLabel, comparisonLabel) =
        _resolveDateRanges(now, baseStart, baseEnd, baseElapsedDays);

    int filterDays = filterEnd.difference(filterStart).inDays + 1;
    if (filterDays < 1) filterDays = 1;

    double baseSpent = 0.0; double filterSpent = 0.0; double pastFilterSpent = 0.0;
    Map<String, double> catSpent = {}; Map<String, int> catCount = {}; Map<String, double> pastCatSpent = {};
    Map<DateTime, double> baseDailySeries = {}; Map<DateTime, double> pastBaseDailySeries = {};
    Map<int, Map<String, double>> dailyCategorySpends = {}; Map<int, double> weekdayTotals = {};

    for (var t in allTxs) {
      if (t.type != 'expense') continue;
      
      // 🌟 ACCOUNT-SPECIFIC LINKED BUDGET FILTER
      if (b.accountId != null && b.accountId!.isNotEmpty && b.accountId != 'all' && b.accountId != t.accountId) {
        continue;
      }

      if (b.category != 'Global' && t.category != b.category) continue;
      
      bool isPaused = false;
      final pauses = b.pauseTimestamps ?? [];
      final resumes = b.resumeTimestamps ?? [];
      for (int i = 0; i < pauses.length; i++) {
        DateTime pStart = pauses[i];
        DateTime? pEnd = (i < resumes.length) ? resumes[i] : null;
        if (t.date.isAfter(pStart) && (pEnd == null || t.date.isBefore(pEnd))) { isPaused = true; break; }
      }
      if (isPaused) continue;
      if (!(b.includePastTransactions ?? false) && t.date.isBefore(b.createdAt)) continue;

      double amt = t.amount.abs();
      DateTime tDate = DateTime(t.date.year, t.date.month, t.date.day);

      if (!t.date.isBefore(baseStart) && !t.date.isAfter(baseEnd)) {
        baseSpent += amt;
        baseDailySeries[tDate] = (baseDailySeries[tDate] ?? 0) + amt;
      } else if (!t.date.isBefore(pastBaseStart) && !t.date.isAfter(pastBaseEnd)) {
        pastBaseDailySeries[tDate] = (pastBaseDailySeries[tDate] ?? 0) + amt;
      }
      
      if (!t.date.isBefore(filterStart) && !t.date.isAfter(filterEnd)) {
        filterSpent += amt;
        catSpent[t.category] = (catSpent[t.category] ?? 0) + amt;
        catCount[t.category] = (catCount[t.category] ?? 0) + 1;
        weekdayTotals[t.date.weekday] = (weekdayTotals[t.date.weekday] ?? 0.0) + amt;
        
        int dayOffset = tDate.difference(filterStart).inDays;
        final catMap = dailyCategorySpends.putIfAbsent(dayOffset, () => {});
        catMap[t.category] = (catMap[t.category] ?? 0.0) + amt;
      } else if (!t.date.isBefore(pastFilterStart) && !t.date.isAfter(pastFilterEnd)) {
        pastFilterSpent += amt;
        pastCatSpent[t.category] = (pastCatSpent[t.category] ?? 0) + amt;
      }
    }

    double limit = b.limitAmount;
    double baseRemaining = limit - baseSpent;
    double? basePercentUsed = limit > 0 ? (baseSpent / limit) * 100 : null;
    
    double safeDailyPace = baseRemainingDays > 0 ? math.max(baseRemaining, 0) / baseRemainingDays : math.max(baseRemaining, 0);
    double filterDailyAvg = filterDays > 0 ? filterSpent / filterDays : 0;
    
    double forecastTotal = baseSpent + (filterDailyAvg * baseRemainingDays);
    double forecastVariance = forecastTotal - limit;

    double? trendForecast;
    if (baseElapsedDays >= 3) {
      List<double> xVals = []; List<double> yVals = []; double cum = 0;
      for (int i = 0; i < baseElapsedDays; i++) {
        cum += baseDailySeries[baseStart.add(Duration(days: i))] ?? 0.0;
        xVals.add(i.toDouble()); yVals.add(cum);
      }
      double n = baseElapsedDays.toDouble();
      double sumX = xVals.reduce((a, b) => a + b); double sumY = yVals.reduce((a, b) => a + b);
      double sumXY = 0; double sumX2 = 0;
      for (int i = 0; i < n; i++) { sumXY += xVals[i] * yVals[i]; sumX2 += xVals[i] * xVals[i]; }
      double denom = n * sumX2 - sumX * sumX;
      if (denom != 0) {
        double slope = (n * sumXY - sumX * sumY) / denom;
        double intercept = (sumY - slope * sumX) / n;
        double val = slope * (baseTotalDays - 1) + intercept;
        trendForecast = val < 0 ? 0 : val;
      }
    }
    
    String paceStatus; String prescriptiveMessage; String? depletionWarning;

    if (limit == 0) {
      paceStatus = "Tracking Only";
      prescriptiveMessage = "No limit set. During $_selectedFilter, you spent an average of ${AetherCurrency.format(filterDailyAvg)}/day.";
    } else {
      double paceDiff = filterDailyAvg - safeDailyPace;
      if (baseRemaining < 0) {
        paceStatus = "Over Budget";
        prescriptiveMessage = "You have exceeded your overall budget limit by ${AetherCurrency.format(baseRemaining.abs())}. Halt non-essential expenses immediately.";
      } else if (paceDiff > 0) {
        paceStatus = "Spending Too Fast";
        prescriptiveMessage = "During $_selectedFilter, your average was ${AetherCurrency.format(filterDailyAvg)}/day. This is higher than your safe limit of ${AetherCurrency.format(safeDailyPace)}/day. Slow down to avoid overspending.";
        if (filterDailyAvg > 0) {
          int daysUntilEmpty = (baseRemaining / filterDailyAvg).floor();
          if (daysUntilEmpty < baseRemainingDays) {
            DateTime emptyDate = now.add(Duration(days: daysUntilEmpty));
            depletionWarning = "⚠️ At this pace, your budget will completely run out on ${DateFormat('MMMM d').format(emptyDate)}.";
          }
        }
      } else {
        paceStatus = "Perfect Pacing";
        prescriptiveMessage = "Great job! During $_selectedFilter, your daily average of ${AetherCurrency.format(filterDailyAvg)} is well within your safe limit (${AetherCurrency.format(safeDailyPace)}). Keep it up!";
      }
    }

    Map<String, CategoryStats> categoryBreakdown = {};
    catSpent.forEach((cat, amt) {
      double pct = filterSpent > 0 ? (amt / filterSpent) * 100 : 0;
      int count = catCount[cat] ?? 1;
      double avgTxn = amt / count;
      
      double? varVsPrev;
      double prevAmt = pastCatSpent[cat] ?? 0.0;
      if (prevAmt > 0) { varVsPrev = ((amt - prevAmt) / prevAmt) * 100; } 
      else if (amt > 0) { varVsPrev = double.infinity; }

      categoryBreakdown[cat] = CategoryStats(category_total: amt, category_percent: pct, category_txn_count: count, category_avg_txn: avgTxn, category_variance_vs_prev_period: varVsPrev);
    });

    Map<int, int> weekdayOccurrences = {};
    for (int i = 0; i < filterDays; i++) {
      weekdayOccurrences[filterStart.add(Duration(days: i)).weekday] = (weekdayOccurrences[filterStart.add(Duration(days: i)).weekday] ?? 0) + 1;
    }
    Map<int, double> weekdayAvgSpend = {}; int highestSpendWeekday = 1; double maxWkAvg = -1;
    weekdayTotals.forEach((wd, total) {
      double avg = total / (weekdayOccurrences[wd] ?? 1);
      weekdayAvgSpend[wd] = avg;
      if (avg > maxWkAvg) { maxWkAvg = avg; highestSpendWeekday = wd; }
    });

    String granularity = filterDays <= 14 ? 'day' : 'month';
    return BudgetAnalyticsData(
      baseTotalDays: baseTotalDays, baseElapsedDays: baseElapsedDays, baseRemainingDays: baseRemainingDays,
      baseSpent: baseSpent, baseRemaining: baseRemaining, basePercentUsed: basePercentUsed,
      filterDays: filterDays, filterSpent: filterSpent, pastFilterSpent: pastFilterSpent, filterDailyAvg: filterDailyAvg,
      filterStartDate: filterStart, filterEndDate: filterEnd, 
      pastFilterStartDate: pastFilterStart, pastFilterEndDate: pastFilterEnd,
      safeDailyPace: safeDailyPace, forecastTotal: forecastTotal, forecastVariance: forecastVariance,
      paceStatus: paceStatus, prescriptiveMessage: prescriptiveMessage, depletionWarning: depletionWarning, trendForecast: trendForecast,
      categoryBreakdown: categoryBreakdown, pastBreakdown: pastCatSpent, weekdayAvgSpend: weekdayAvgSpend,
      highestSpendWeekday: highestSpendWeekday, baseDailySeries: baseDailySeries, pastBaseDailySeries: pastBaseDailySeries,
      dailyCategorySpends: dailyCategorySpends,
      isNotStarted: isNotStarted, baseStartDate: baseStart, baseEndDate: baseEnd, 
      filterName: filterLabel, comparisonName: comparisonLabel, granularity: granularity, isCompareActive: _comparePastPeriod,
    );
  }

  // =========================================================================
  // 🌟 4. SMART NOTIFICATIONS GENERATOR (10 Unique Scenarios)
  // =========================================================================
  List<_SmartAlert> _generateAlerts(BudgetAnalyticsData a) {
    List<_SmartAlert> alerts = [];
    final now = DateTime.now();
    
    // Dynamically fetch username from Hive (Fallback to "User")
    String username = "User";
    try {
      final box = Hive.box('aether_settings');
      username = box.get('username', defaultValue: 'User') as String;
    } catch(e) { /* Ignore if box isn't open yet */ }

    // 1. Critical Overspend (Red)
    if (a.baseRemaining < 0) {
      alerts.add(_SmartAlert(Icons.warning_rounded, _rose, "Budget Exceeded", "Hey $username, you've crossed your cycle limit by ${AetherCurrency.format(a.baseRemaining.abs())}. Time to hold off on expenses!", "Just now"));
    } 
    // 2. Approaching Limit (Amber)
    else if (a.basePercentUsed != null && a.basePercentUsed! >= 85) {
      alerts.add(_SmartAlert(Icons.trending_up_rounded, _amber, "Approaching Limit", "Careful $username, you've consumed ${a.basePercentUsed!.toStringAsFixed(1)}% of your budget. Slow down.", "1h ago"));
    }
    // 3. Halfway Benchmark (Blue)
    else if (a.basePercentUsed != null && a.basePercentUsed! >= 50 && a.basePercentUsed! < 55) {
      alerts.add(_SmartAlert(Icons.pie_chart_outline_rounded, _sky, "Halfway There", "You've reached half of your budget limit. Keep pacing yourself, $username.", "2h ago"));
    }

    // 4. Evening Check-in (Violet)
    if (now.hour >= 20 && a.filterSpent > 0) {
      alerts.add(_SmartAlert(Icons.nights_stay_rounded, _violet, "Evening Check-in", "Good evening $username! You spent ${AetherCurrency.format(a.filterSpent)} today. Make sure to log everything.", "Now"));
    }
    // 5. Morning Brief (Amber)
    else if (now.hour <= 10 && a.baseRemaining > 0) {
      alerts.add(_SmartAlert(Icons.wb_sunny_rounded, _amber, "Morning Overview", "Good morning $username! You have ${AetherCurrency.format(a.baseRemaining)} left for the remaining ${a.baseRemainingDays} days.", "Now"));
    }

    // 6. Weekly Report (Sky)
    if (now.weekday == DateTime.monday) {
      alerts.add(_SmartAlert(Icons.mail_rounded, _sky, "Weekly Report Ready", "Your spending summary for last week is compiled. Tap to review your progress.", "3h ago"));
    }

    // 7. Perfect Pacing (Mint)
    if (a.baseRemaining > 0 && a.paceStatus == "Perfect Pacing") {
      alerts.add(_SmartAlert(Icons.verified_rounded, _mint, "On Track", "Great discipline $username! You're perfectly pacing your expenses this cycle.", "Today"));
    }
    
    // 8. Spending Too Fast (Rose)
    if (a.baseRemaining > 0 && a.paceStatus == "Spending Too Fast") {
      alerts.add(_SmartAlert(Icons.speed_rounded, _rose, "Pacing Fast", "You are spending faster than your safe daily limit of ${AetherCurrency.format(a.safeDailyPace)}. Slow down!", "Just now"));
    }

    // 9. Behavioral Insight (Slate)
    if (a.highestSpendWeekday == now.weekday && a.filterSpent > 0) {
      alerts.add(_SmartAlert(Icons.psychology_rounded, _slate, "Spending Pattern", "Did you know? You usually spend the most on ${DateFormat('EEEE').format(now)}s.", "5h ago"));
    }

    // 10. Savings Opportunity (Mint)
    if (a.baseRemainingDays <= 3 && a.basePercentUsed != null && a.basePercentUsed! < 70) {
      alerts.add(_SmartAlert(Icons.savings_rounded, _mint, "Great Savings!", "Only ${a.baseRemainingDays} days left and you still have plenty of budget. Great job saving, $username!", "Today"));
    }

    return alerts;
  }

  Widget _buildSmartNotifications(BudgetAnalyticsData a) {
    final alerts = _generateAlerts(a);
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 12),
          child: Text("Smart Alerts", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Container(
                width: MediaQuery.of(context).size.width * 0.75,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: alert.color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: alert.color.withOpacity(0.15), shape: BoxShape.circle),
                      child: Icon(alert.icon, color: alert.color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(alert.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(alert.time, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(alert.message, style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOverviewTab(BudgetAnalyticsData a, List<AetherTransaction> allTxs) {
    if (a.baseSpent == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.query_stats_rounded, color: Colors.white.withValues(alpha: 0.1), size: 64),
            const SizedBox(height: 16),
            const Text("No spending recorded yet.", style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🌟 5-SECOND AUTO-HIDE ANIMATED ALERTS 🌟
          AnimatedSize(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            child: _showSmartAlerts ? _buildSmartNotifications(a) : const SizedBox.shrink(),
          ),

          _buildHeroPulseCard(a),
          const SizedBox(height: 10), 
          _buildComparePastToggle(a),
          const SizedBox(height: 10), 
          _buildPaceAndPrescriptionCard(a),
          const SizedBox(height: 32),
          
          _buildMonthlySpendTrend(a, allTxs),
          const SizedBox(height: 32),

          if (widget.budget.limitAmount > 0) ...[
            _buildSpendTrendChart(a, allTxs),
            const SizedBox(height: 32),
          ],
          
          if (widget.budget.category == 'Global') ...[
            _buildInteractiveDonutChart(a),
            const SizedBox(height: 24),
            _buildStackedBarChart(a),
            const SizedBox(height: 24),
            _buildCategorySortableTable(a),
            const SizedBox(height: 24),
          ],
          _buildDayOfWeekAnalyzer(a),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildComparePastToggle(BudgetAnalyticsData a) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _comparePastPeriod ? _sky.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
          width: _comparePastPeriod ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _sky.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.compare_arrows_rounded, color: _sky, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Overlay Previous Period",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _comparePastPeriod ? "Comparing historical benchmarks" : "Compare spending trends with prior periods",
                            style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _comparePastPeriod,
                activeColor: _sky,
                activeTrackColor: _sky.withValues(alpha: 0.3),
                inactiveThumbColor: Colors.white38,
                inactiveTrackColor: Colors.white10,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _comparePastPeriod = val);
                },
              ),
            ],
          ),

          if (_comparePastPeriod) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 16),

            // 🌟 4 MAIN TABS: DAY, WEEK, MONTH, CUSTOM
            Row(
              children: ['Day', 'Week', 'Month', 'Custom'].map((tab) {
                final isSelected = _compareTab == tab;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _compareTab = tab);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? _sky.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _sky : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          tab,
                          style: TextStyle(
                            color: isSelected ? _sky : Colors.white54,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // 🌟 CURRENT & COMPARE WITH SELECTION DROPDOWNS / PICKERS
            if (_compareTab == 'Day') ...[
              _buildCompareDropdownRow(
                currentTitle: "Day Period",
                currentValue: _dayCurrent,
                currentItems: _dayCurrentOptions,
                onCurrentChanged: (v) => setState(() => _dayCurrent = v!),
                compareTitle: "Compare With",
                compareValue: _dayCompareWith,
                compareItems: _dayCompareOptions,
                onCompareChanged: (v) => setState(() => _dayCompareWith = v!),
              ),
            ] else if (_compareTab == 'Week') ...[
              _buildCompareDropdownRow(
                currentTitle: "Week Period",
                currentValue: _weekCurrent,
                currentItems: _weekCurrentOptions,
                onCurrentChanged: (v) => setState(() => _weekCurrent = v!),
                compareTitle: "Compare With",
                compareValue: _weekCompareWith,
                compareItems: _weekCompareOptions,
                onCompareChanged: (v) => setState(() => _weekCompareWith = v!),
              ),
            ] else if (_compareTab == 'Month') ...[
              _buildCompareDropdownRow(
                currentTitle: "Month Period",
                currentValue: _monthCurrent,
                currentItems: _monthCurrentOptions,
                onCurrentChanged: (v) => setState(() => _monthCurrent = v!),
                compareTitle: "Compare With",
                compareValue: _monthCompareWith,
                compareItems: _monthCompareOptions,
                onCompareChanged: (v) => setState(() => _monthCompareWith = v!),
              ),
            ] else if (_compareTab == 'Custom') ...[
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickCustomCurrentRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("CURRENT RANGE", style: TextStyle(color: _sky, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              _customCurrentRange != null
                                  ? "${DateFormat('MMM d').format(_customCurrentRange!.start)} - ${DateFormat('MMM d').format(_customCurrentRange!.end)}"
                                  : "Pick Range",
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickCustomCompareRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("COMPARE RANGE", style: TextStyle(color: _amber, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              _customCompareRange != null
                                  ? "${DateFormat('MMM d').format(_customCompareRange!.start)} - ${DateFormat('MMM d').format(_customCompareRange!.end)}"
                                  : "Preceding Duration",
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // 🌟 REALTIME COMPARISON KPI BANNER
            _buildComparisonKpiBanner(a),
          ],
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildCompareDropdownRow({
    required String currentTitle,
    required String currentValue,
    required List<String> currentItems,
    required ValueChanged<String?> onCurrentChanged,
    required String compareTitle,
    required String compareValue,
    required List<String> compareItems,
    required ValueChanged<String?> onCompareChanged,
  }) {
    final safeCurrent = currentItems.contains(currentValue) ? currentValue : currentItems.first;
    final safeCompare = compareItems.contains(compareValue) ? compareValue : compareItems.first;

    return Row(
      children: [
        Expanded(
          child: AetherLiquidDropdown<String>(
            label: currentTitle,
            value: safeCurrent,
            items: currentItems,
            accentColor: _sky,
            itemLabel: (s) => s,
            onChanged: (v) {
              if (v != null) onCurrentChanged(v);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AetherLiquidDropdown<String>(
            label: compareTitle,
            value: safeCompare,
            items: compareItems,
            accentColor: _amber,
            itemLabel: (s) => s,
            onChanged: (v) {
              if (v != null) onCompareChanged(v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonKpiBanner(BudgetAnalyticsData a) {
    final double diff = a.filterSpent - a.pastFilterSpent;
    final double pct = a.pastFilterSpent > 0 ? (diff / a.pastFilterSpent) * 100 : (a.filterSpent > 0 ? 100 : 0);
    final bool isSaving = diff <= 0;
    final Color trendColor = isSaving ? _mint : _rose;

    final double maxCompareVal = math.max(1.0, math.max(a.filterSpent, a.pastFilterSpent));
    final double currentRatio = (a.filterSpent / maxCompareVal).clamp(0.02, 1.0);
    final double pastRatio = (a.pastFilterSpent / maxCompareVal).clamp(0.02, 1.0);

    final double pastDailyAvg = a.pastFilterSpent / math.max(1, a.filterDays);
    final double dailyDiff = a.filterDailyAvg - pastDailyAvg;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C101E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: trendColor.withValues(alpha: 0.28), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: trendColor.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🌟 TOP 3-COLUMN METRICS (100% OVERFLOW PROTECTED)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CURRENT (${a.filterName.toUpperCase()})",
                      style: const TextStyle(color: _sky, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AetherCurrency.format(a.filterSpent),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 8), color: Colors.white12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "PREVIOUS PERIOD",
                      style: TextStyle(color: _amber, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AetherCurrency.format(a.pastFilterSpent),
                        style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w700),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 8), color: Colors.white12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "VARIANCE",
                      style: TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isSaving ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: trendColor, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            "${pct.abs().toStringAsFixed(1)}%",
                            style: TextStyle(color: trendColor, fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 18),

          // 🌟 DUAL COMPARATIVE PROGRESS VISUALIZATION BARS
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: _sky, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text("Current Cycle Pacing", style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text("${(currentRatio * 100).toInt()}% of Peak", style: const TextStyle(color: _sky, fontSize: 10.5, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 8,
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.05),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: currentRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_sky, Color(0xFF06B6D4)]),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: _sky.withValues(alpha: 0.5), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: _amber, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text("Historical Benchmark", style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text("${(pastRatio * 100).toInt()}% of Peak", style: const TextStyle(color: _amber, fontSize: 10.5, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 8,
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.05),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pastRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_amber, Color(0xFFF59E0B)]),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: _amber.withValues(alpha: 0.4), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 🌟 DAILY BURN RATE COMPARATIVE CARDS
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("CURRENT DAILY AVG", style: TextStyle(color: _sky, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AetherCurrency.format(a.filterDailyAvg),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("BENCHMARK DAILY AVG", style: TextStyle(color: _amber, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AetherCurrency.format(pastDailyAvg),
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 🌟 PRESCRIPTION SUMMARY PILL
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: trendColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isSaving ? Icons.verified_rounded : Icons.info_outline_rounded,
                  color: trendColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSaving
                        ? "Great discipline! You spent ${AetherCurrency.format(diff.abs())} less (-${pct.abs().toStringAsFixed(1)}%) with a daily burn savings of ${AetherCurrency.format(dailyDiff.abs())}/day."
                        : "Notice: Spending is ${AetherCurrency.format(diff)} higher (+${pct.abs().toStringAsFixed(1)}%) than the benchmark (+${AetherCurrency.format(dailyDiff)}/day).",
                    style: TextStyle(color: trendColor, fontSize: 11, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 🎨 5. COMPONENT RENDERING
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    ref.watch(primaryCurrencyProvider); // Rebuild on currency change
    final allTxs = ref.watch(transactionNotifierProvider).valueOrNull ?? [];
    final analytics = _computeEngine(allTxs, widget.budget);

    final displayName = (widget.budget.name?.isNotEmpty ?? false) ? widget.budget.name! : widget.budget.category;

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: () { HapticFeedback.lightImpact(); context.pop(); }),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(widget.budget.isActive ? "Active Insights" : "Paused Mode", style: TextStyle(color: widget.budget.isActive ? _mint : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length, itemBuilder: (context, index) {
                final f = _filters[index]; final isSelected = _selectedFilter == f;
                String label = f;
                if (f == 'Custom' && _customRange != null && isSelected) {
                  label = '${DateFormat('MMM d').format(_customRange!.start)} - ${DateFormat('MMM d').format(_customRange!.end)}';
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 8, bottom: 8),
                  child: GestureDetector(
                    onTap: () { 
                      HapticFeedback.selectionClick(); 
                      if (f == 'Custom') { _pickCustomRange(); } else { setState(() { _selectedFilter = f; _touchedCategoryIndex = -1; }); }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: isSelected ? _sky.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? _sky.withValues(alpha: 0.5) : Colors.transparent)),
                      child: Center(child: Text(label, style: TextStyle(color: isSelected ? _sky : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold))),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Theme(
            data: Theme.of(context).copyWith(splashColor: Colors.transparent, highlightColor: Colors.transparent),
            child: TabBar(
              controller: _tabController, indicatorColor: _sky, indicatorWeight: 3, labelColor: Colors.white,
              unselectedLabelColor: Colors.white38, labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [Tab(text: "Overview"), Tab(text: "Records")],
            ),
          ),

          Expanded(
            child: analytics.isNotStarted 
              ? Center(child: Text("Budget cycle starts on ${DateFormat('MMM d, yyyy').format(analytics.baseStartDate)}", style: const TextStyle(color: Colors.white54, fontSize: 16)))
              : TabBarView(
                  controller: _tabController,
                  children: [ _buildOverviewTab(analytics, allTxs), _buildRecordsTab(allTxs, analytics) ],
                ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomCycleNavigator(analytics),
    );
  }

  Widget _buildBottomCycleNavigator(BudgetAnalyticsData a) {
    final bool isHistorical = _cycleOffset < 0;
    final bool isFuture = _cycleOffset > 0;
    final Color pillAccent = isHistorical ? _amber : (isFuture ? _violet : _sky);
    final String dateDisplay = "${DateFormat('d MMM').format(a.baseStartDate)} - ${DateFormat('d MMM, yyyy').format(a.baseEndDate)}";

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0C101E).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: pillAccent.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: pillAccent.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🌟 PREVIOUS PERIOD ARROW
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    tooltip: "Previous Period",
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _cycleOffset--;
                        _touchedCategoryIndex = -1;
                      });
                    },
                  ),

                  // 🌟 CENTER DATE PERIOD CAPSULE (CLICKABLE FOR CUSTOM PICKER)
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showAetherLiquidDateRangePicker(
                          context: context,
                          initialDateRange: DateTimeRange(start: a.baseStartDate, end: a.baseEndDate),
                          accentColor: pillAccent,
                          title: "Jump to Custom Cycle Period",
                        );
                        if (picked != null) {
                          setState(() {
                            _customRange = picked;
                            _selectedFilter = 'Custom';
                            _touchedCategoryIndex = -1;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: pillAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isHistorical
                                      ? Icons.history_rounded
                                      : (isFuture ? Icons.update_rounded : Icons.calendar_month_rounded),
                                  color: pillAccent,
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      dateDisplay,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        fontFeatures: [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_cycleOffset != 0) ...[
                              const SizedBox(height: 2),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _cycleOffset = 0;
                                    _selectedFilter = 'Overall';
                                    _touchedCategoryIndex = -1;
                                  });
                                },
                                child: Text(
                                  isHistorical
                                      ? "Historical Cycle • Tap to Reset to Active"
                                      : "Future Forecast • Tap to Reset",
                                  style: TextStyle(
                                    color: pillAccent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 🌟 NEXT PERIOD ARROW
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: _cycleOffset < 0 ? Colors.white : Colors.white30,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                    tooltip: "Next Period",
                    onPressed: _cycleOffset < 0
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _cycleOffset++;
                              _touchedCategoryIndex = -1;
                            });
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPulseCard(BudgetAnalyticsData a) {
    bool hasLimit = widget.budget.limitAmount > 0;
    Color statusColor = hasLimit ? (a.basePercentUsed! >= 100 ? _rose : (a.basePercentUsed! >= 70 ? _amber : _mint)) : _sky;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Overall Cycle Spent", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(AetherCurrency.format(a.baseSpent), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (hasLimit)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("Remaining", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(a.baseRemaining < 0 ? "Exceeded" : AetherCurrency.format(a.baseRemaining), style: TextStyle(color: a.baseRemaining < 0 ? _rose : Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                )
            ],
          ),
          const SizedBox(height: 24),
          if (hasLimit) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 12, width: double.infinity, color: Colors.white.withValues(alpha: 0.05),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft, widthFactor: (a.basePercentUsed! / 100).clamp(0.0, 1.0),
                  child: Container(decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 8)])),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${a.basePercentUsed!.toStringAsFixed(1)}% Consumed", style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
                Text("Day ${a.baseElapsedDays} of ${a.baseTotalDays}", style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            )
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildPaceAndPrescriptionCard(BudgetAnalyticsData a) {
    Color color = a.paceStatus == "Over Budget" ? _rose : (a.paceStatus == "Spending Too Fast" ? _amber : _mint);
    IconData icon = a.paceStatus == "Over Budget" ? Icons.warning_rounded : (a.paceStatus == "Perfect Pacing" ? Icons.check_circle_rounded : Icons.trending_up_rounded);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20), const SizedBox(width: 8),
              Text(a.filterName == 'Overall' ? 'Pace Analysis' : 'Pace Analysis (${a.filterName})', style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Text(a.prescriptiveMessage, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          if (a.depletionWarning != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _rose.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(a.depletionWarning!, style: const TextStyle(color: _rose, fontSize: 12, fontWeight: FontWeight.bold)),
            )
          ],
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildMonthlySpendTrend(BudgetAnalyticsData a, List<AetherTransaction> allTxs) {
    final now = DateTime.now();
    double limit = widget.budget.limitAmount;
    
    List<Map<String, dynamic>> monthlyData = [];
    for (int i = 4; i >= 0; i--) {
      DateTime monthTarget = DateTime(now.year, now.month - i, 1);
      DateTime startOfMonth = DateTime(monthTarget.year, monthTarget.month, 1);
      DateTime endOfMonth = DateTime(monthTarget.year, monthTarget.month + 1, 0, 23, 59, 59);

      double spentInMonth = 0;
      for (var t in allTxs) {
        if (t.type != 'expense') continue;
        if (widget.budget.category != 'Global' && t.category != widget.budget.category) continue;
        
        bool isPaused = false;
        for (int p = 0; p < (widget.budget.pauseTimestamps?.length ?? 0); p++) {
          DateTime pStart = widget.budget.pauseTimestamps![p];
          DateTime? pEnd = (p < (widget.budget.resumeTimestamps?.length ?? 0)) ? widget.budget.resumeTimestamps![p] : null;
          if (t.date.isAfter(pStart) && (pEnd == null || t.date.isBefore(pEnd))) { isPaused = true; break; }
        }
        if (isPaused) continue;

        if (!t.date.isBefore(startOfMonth) && !t.date.isAfter(endOfMonth)) {
          spentInMonth += t.amount.abs();
        }
      }

      monthlyData.add({
        'label': DateFormat('MMM yyyy').format(monthTarget),
        'spent': spentInMonth,
      });
    }

    double maxMonthSpend = monthlyData.map((m) => m['spent'] as double).fold(0.0, math.max);
    double maxY = math.max(limit, maxMonthSpend) * 1.25;
    if (maxY == 0) maxY = 1000;

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < monthlyData.length; i++) {
      double spent = monthlyData[i]['spent'];
      double pct = limit > 0 ? (spent / limit) : 0;
      
      Color barColor;
      if (pct > 1.0) barColor = _rose; 
      else if (pct >= 0.7) barColor = _amber; 
      else barColor = _mint; 

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: spent > 0 ? spent : 0.0,
              color: barColor,
              width: 32,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: limit > 0 ? limit : maxY * 0.8,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Spend Trend", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("THIS MONTH", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(AetherCurrency.format(a.baseSpent), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 240,
          padding: const EdgeInsets.only(right: 20, top: 20, bottom: 10, left: 0),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16)),
          child: BarChart(
            BarChartData(
              gridData: FlGridData(
                show: true, drawVerticalLine: false, drawHorizontalLine: true,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.04), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false), maxY: maxY, barGroups: barGroups,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      AetherCurrency.format(rod.toY),
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      int idx = value.toInt();
                      if (idx >= 0 && idx < monthlyData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(monthlyData[idx]['label'], style: const TextStyle(color: Colors.white54, fontSize: 9)),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 42, interval: maxY > 4 ? maxY / 4 : 1,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(NumberFormat.compact().format(value), style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.right),
                      );
                    },
                  ),
                ),
              ),
              extraLinesData: limit > 0 ? ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: limit, color: Colors.white38, strokeWidth: 1.5, dashArray: const [5, 5],
                    label: HorizontalLineLabel(show: true, style: const TextStyle(color: Colors.white54, fontSize: 10), alignment: Alignment.topRight, labelResolver: (line) => "Budget"),
                  ),
                ],
              ) : ExtraLinesData(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildLegendItem(_mint, "On Track"), const SizedBox(width: 14),
            _buildLegendItem(_amber, "Trending Over"), const SizedBox(width: 14),
            _buildLegendItem(_rose, "Over Budget"),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 250.ms);
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildSpendTrendChart(BudgetAnalyticsData a, List<AetherTransaction> allTxs) {
    int chartDays = 7;
    if (_chartFilter == 'Today') chartDays = 1;
    else if (_chartFilter == '3 Days') chartDays = 3;
    else if (_chartFilter == '7 Days') chartDays = 7;
    else if (_chartFilter == '10 Days') chartDays = 10;
    else if (_chartFilter == '30 Days') chartDays = 30;
    else if (_chartFilter == 'Full Cycle') chartDays = a.baseTotalDays;

    DateTime chartEnd = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);
    DateTime chartStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(Duration(days: chartDays - 1));
    if (_chartFilter == 'Full Cycle') {
      chartStart = a.baseStartDate;
      chartEnd = a.baseEndDate;
    }

    double windowTotalSpent = 0;
    double maxSpendInWindow = 0;
    List<FlSpot> actualSpots = [];

    for (int i = 0; i < chartDays; i++) {
      DateTime d = chartStart.add(Duration(days: i));
      double dailyAmt = 0.0;
      
      if (!d.isBefore(a.baseStartDate) && !d.isAfter(a.baseEndDate)) {
        dailyAmt = a.baseDailySeries[d] ?? 0.0;
      }
      
      actualSpots.add(FlSpot(i.toDouble(), dailyAmt));
      if (dailyAmt > maxSpendInWindow) maxSpendInWindow = dailyAmt;
      windowTotalSpent += dailyAmt;
    }

    if (actualSpots.length == 1 && a.baseTotalDays > 1) {
      actualSpots.add(FlSpot(0.5, actualSpots[0].y));
    }

    // 🌟 HISTORICAL BENCHMARK OVERLAY SPOTS
    List<FlSpot> pastSpots = [];
    if (_comparePastPeriod) {
      for (int i = 0; i < chartDays; i++) {
        DateTime pastD = a.pastFilterStartDate.add(Duration(days: i));
        double pastDaily = a.pastBaseDailySeries[pastD] ?? (a.pastFilterSpent / math.max(1, a.filterDays));
        pastSpots.add(FlSpot(i.toDouble(), pastDaily));
        if (pastDaily > maxSpendInWindow) maxSpendInWindow = pastDaily;
      }
      if (pastSpots.length == 1 && a.baseTotalDays > 1) {
        pastSpots.add(FlSpot(0.5, pastSpots[0].y));
      }
    }

    double limit = widget.budget.limitAmount;
    double vsBudgetPct = limit > 0 ? ((windowTotalSpent - limit) / limit * 100) : 0;
    double maxY = math.max(limit, maxSpendInWindow) * 1.25;
    if (maxY == 0) maxY = 1000;

    Color statusColor = (limit > 0 && windowTotalSpent > limit) ? _rose : _mint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Forecasted Spend", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            _buildChartFilterDropdown(),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_chartFilter == 'Full Cycle' ? "THIS CYCLE" : "LAST ${_chartFilter.toUpperCase()}", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(AetherCurrency.format(windowTotalSpent), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            if (limit > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("vs budget", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text(
                    "${vsBudgetPct > 0 ? '+' : ''}${vsBudgetPct.toStringAsFixed(0)}%", 
                    style: TextStyle(color: vsBudgetPct > 0 ? _rose : _mint, fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 240, 
          padding: const EdgeInsets.only(right: 20, top: 20, bottom: 10, left: 0),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16)),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true, drawVerticalLine: true, drawHorizontalLine: true,
                getDrawingVerticalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
              ), 
              borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1)), left: BorderSide(color: Colors.white.withOpacity(0.1)))),
              minX: 0, maxX: math.max(1, (chartDays - 1).toDouble()), minY: 0, maxY: maxY,
              
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 28, interval: 1, 
                    getTitlesWidget: (value, meta) {
                      bool isStart = value == 0;
                      bool isEnd = value == meta.max;
                      double safeInterval = math.max(1, (chartDays / 4).floorToDouble());
                      bool isInterval = (value % safeInterval == 0);

                      if (isInterval && !isStart && !isEnd) {
                        if (meta.max - value <= safeInterval * 0.85) {
                          return const SizedBox.shrink(); 
                        }
                      }

                      if (isStart || isEnd || isInterval) {
                         DateTime d = chartStart.add(Duration(days: value.toInt()));
                         return Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Text(DateFormat('M/d/yy').format(d), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                         );
                      }
                      return const SizedBox.shrink();
                    }
                  )
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 46, interval: maxY > 4 ? maxY / 4 : 1,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(NumberFormat.compact().format(value), style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.right),
                      );
                    }
                  )
                )
              ),

              extraLinesData: limit > 0 ? ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: limit, color: Colors.white38, strokeWidth: 1.5, dashArray: const [5, 5], 
                    label: HorizontalLineLabel(show: true, style: const TextStyle(color: Colors.white54, fontSize: 10), alignment: Alignment.topLeft, labelResolver: (line) => "Budget")
                  ),
                ]
              ) : ExtraLinesData(),
              
              lineBarsData: [
                LineChartBarData(
                  spots: actualSpots, isCurved: true, curveSmoothness: 0.25, color: statusColor, barWidth: 2.5, 
                  dotData: FlDotData(show: actualSpots.length <= 2), 
                  belowBarData: BarAreaData(show: true, color: statusColor.withOpacity(0.18))
                ),
                if (_comparePastPeriod && pastSpots.isNotEmpty)
                  LineChartBarData(
                    spots: pastSpots, isCurved: true, curveSmoothness: 0.25, color: _amber.withOpacity(0.85), barWidth: 2, 
                    dashArray: const [5, 4],
                    dotData: const FlDotData(show: false), 
                    belowBarData: BarAreaData(show: true, color: _amber.withOpacity(0.06))
                  ),
              ],
            )
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(3))), 
            const SizedBox(width: 6), 
            const Text("Current Cycle", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)), 
            if (_comparePastPeriod) ...[
              const SizedBox(width: 16),
              Container(width: 14, height: 3, decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(2))), 
              const SizedBox(width: 6), 
              const Text("Historical Benchmark", style: TextStyle(color: _amber, fontSize: 11, fontWeight: FontWeight.bold)), 
            ],
          ],
        )
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildChartFilterDropdown() {
    return SizedBox(
      width: 120,
      child: AetherLiquidDropdown<String>(
        value: _chartFilter,
        items: _chartFilters,
        accentColor: _sky,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        itemLabel: (s) => s,
        onChanged: (v) {
          if (v != null) setState(() => _chartFilter = v);
        },
      ),
    );
  }

  Widget _buildInteractiveDonutChart(BudgetAnalyticsData a) {
    if (a.categoryBreakdown.isEmpty) return const SizedBox.shrink();

    var sortedCats = a.categoryBreakdown.entries.toList()..sort((x, y) => y.value.category_total.compareTo(x.value.category_total));
    
    int touchedIndex = _touchedCategoryIndex == -1 ? 0 : _touchedCategoryIndex;
    if (touchedIndex >= sortedCats.length) touchedIndex = 0; 

    List<PieChartSectionData> sections = [];
    for (int i = 0; i < sortedCats.length; i++) {
      final entry = sortedCats[i];
      final isTouched = i == touchedIndex;
      sections.add(PieChartSectionData(
        value: entry.value.category_total,
        color: _colorForIndex(i),
        radius: isTouched ? 35 : 20, 
        showTitle: false,
      ));
    }

    DateTime displayStart = _selectedFilter == 'Overall' ? a.baseStartDate : a.filterStartDate;
    DateTime displayEnd = _selectedFilter == 'Overall' ? a.baseEndDate : a.filterEndDate;

    final centerCat = sortedCats[touchedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Spend Breakdown", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${DateFormat('MMM d').format(displayStart)} - ${DateFormat('MMM d, yyyy').format(displayEnd)}", 
                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)
                  ),
                  if (_comparePastPeriod && a.pastFilterSpent > 0)
                    Text(
                      "vs past ${a.filterSpent > a.pastFilterSpent ? '+' : ''}${((a.filterSpent - a.pastFilterSpent) / a.pastFilterSpent * 100).toStringAsFixed(1)}%", 
                      style: TextStyle(color: a.filterSpent > a.pastFilterSpent ? _rose : _mint, fontSize: 10, fontWeight: FontWeight.bold)
                    )
                ]
              ),
              const SizedBox(height: 8),
              Text(AetherCurrency.format(_selectedFilter == 'Overall' ? a.baseSpent : a.filterSpent), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: _sky.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text("Categories", style: TextStyle(color: _sky, fontSize: 13, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                return; 
                              }
                              _touchedCategoryIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              HapticFeedback.selectionClick();
                            });
                          },
                        ),
                        sectionsSpace: 4,
                        centerSpaceRadius: 75,
                        sections: sections,
                      )
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(centerCat.key, style: TextStyle(color: _colorForIndex(touchedIndex), fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(AetherCurrency.format(centerCat.value.category_total), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                        const SizedBox(height: 4),
                        Text("${centerCat.value.category_percent.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _buildStackedBarChart(BudgetAnalyticsData a) {
    if (a.categoryBreakdown.isEmpty || a.filterDays <= 0) return const SizedBox.shrink();

    List<String> topCats = (a.categoryBreakdown.keys.toList()..sort((x, y) => (a.categoryBreakdown[y]?.category_total ?? 0).compareTo(a.categoryBreakdown[x]?.category_total ?? 0))).take(4).toList();
    bool hasOther = a.categoryBreakdown.length > topCats.length;
    List<String> stackKeys = [...topCats, if (hasOther) 'Other'];

    int bucketSize = a.granularity == 'day' ? 1 : (a.granularity == 'week' ? 7 : 30);
    int numBuckets = (a.filterDays / bucketSize).ceil();
    if (numBuckets < 1) numBuckets = 1; if (numBuckets > 40) numBuckets = 40;

    List<BarChartGroupData> groups = [];
    double maxY = 0;

    for (int b = 0; b < numBuckets; b++) {
      Map<String, double> bucketTotals = {};
      int rangeStart = b * bucketSize;
      int rangeEnd = math.min((b + 1) * bucketSize, a.filterDays);
      for (int d = rangeStart; d < rangeEnd; d++) {
        final dayMap = a.dailyCategorySpends[d];
        if (dayMap == null) continue;
        dayMap.forEach((cat, amt) {
          String key = topCats.contains(cat) ? cat : 'Other';
          bucketTotals[key] = (bucketTotals[key] ?? 0.0) + amt;
        });
      }
      List<BarChartRodStackItem> stackItems = [];
      double running = 0;
      for (int ci = 0; ci < stackKeys.length; ci++) {
        final amt = bucketTotals[stackKeys[ci]] ?? 0.0;
        if (amt <= 0) continue;
        stackItems.add(BarChartRodStackItem(running, running + amt, _colorForIndex(ci)));
        running += amt;
      }
      if (running > maxY) maxY = running;
      groups.add(BarChartGroupData(x: b, barRods: [BarChartRodData(toY: running, rodStackItems: stackItems, width: 22, borderRadius: BorderRadius.circular(4))]));
    }
    if (maxY == 0) maxY = 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Spending Over Time", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Container(
          height: 220, padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
          child: BarChart(BarChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)), 
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42, interval: maxY > 4 ? maxY / 4 : 1, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(right: 8), child: Text(NumberFormat.compact().format(v), style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.right)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, m) {
                if (v % math.max(1, (numBuckets / 4).floorToDouble()) == 0) {
                  DateTime d = a.filterStartDate.add(Duration(days: (v * bucketSize).toInt()));
                  return Padding(padding: const EdgeInsets.only(top: 8), child: Text(DateFormat('MMM d').format(d), style: const TextStyle(color: Colors.white54, fontSize: 10)));
                }
                return const SizedBox.shrink();
              }))
            ), 
            borderData: FlBorderData(show: false), 
            maxY: maxY * 1.15, 
            barGroups: groups,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (g, gr, r, ro) => BarTooltipItem(AetherCurrency.format(r.toY), const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            )
          )),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12, runSpacing: 8,
          children: stackKeys.asMap().entries.map((e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: _colorForIndex(e.key), shape: BoxShape.circle)), const SizedBox(width: 6),
                Text(e.value, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildCategorySortableTable(BudgetAnalyticsData a) {
    if (a.categoryBreakdown.isEmpty) return const SizedBox.shrink();

    var rows = a.categoryBreakdown.entries.toList();
    
    if (_sortCategoryBy == 'Amount (Desc)') { rows.sort((x, y) => y.value.category_total.compareTo(x.value.category_total)); } 
    else if (_sortCategoryBy == 'Amount (Asc)') { rows.sort((x, y) => x.value.category_total.compareTo(y.value.category_total)); } 
    else if (_sortCategoryBy == 'Name (A-Z)') { rows.sort((x, y) => x.key.compareTo(y.key)); } 
    else if (_sortCategoryBy == '% of Total ↓') { rows.sort((x, y) => y.value.category_percent.compareTo(x.value.category_percent)); } 
    else if (_sortCategoryBy == 'Transactions ↓') { rows.sort((x, y) => y.value.category_txn_count.compareTo(x.value.category_txn_count)); } 
    else if (_sortCategoryBy == 'Variance ↓') { rows.sort((x, y) => (y.value.category_variance_vs_prev_period ?? -999).compareTo(x.value.category_variance_vs_prev_period ?? -999)); }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Category Diagnostics", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            _buildSortDropdown(),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.04))),
          child: Column(
            children: rows.map((entry) {
              final stat = entry.value;
              final hasVar = stat.category_variance_vs_prev_period != null;
              final isNew = stat.category_variance_vs_prev_period == double.infinity;
              final isVarUp = hasVar && !isNew && stat.category_variance_vs_prev_period! > 0;
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.03)))),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text("${stat.category_txn_count} txns • Avg ${AetherCurrency.format(stat.category_avg_txn, currencyCode: '')}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(AetherCurrency.format(stat.category_total), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          if (isNew)
                            const Text("New Category", style: TextStyle(color: _sky, fontSize: 10, fontWeight: FontWeight.bold))
                          else if (hasVar)
                            Text("${isVarUp ? '↑' : '↓'} ${stat.category_variance_vs_prev_period!.abs().toStringAsFixed(1)}% vs prev", style: TextStyle(color: isVarUp ? _rose : _mint, fontSize: 10, fontWeight: FontWeight.bold))
                          else
                            const Text("N/A (no prior data)", style: TextStyle(color: Colors.white24, fontSize: 10)),
                        ],
                      )
                    )
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildSortDropdown() {
    return PopupMenuButton<String>(
      color: const Color(0xFF0D1420),
      initialValue: _sortCategoryBy,
      onSelected: (v) => setState(() => _sortCategoryBy = v),
      itemBuilder: (ctx) => _sortOptions.map((s) => PopupMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 12)))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_sortCategoryBy, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildDayOfWeekAnalyzer(BudgetAnalyticsData a) {
    if (a.weekdayAvgSpend.isEmpty) return const SizedBox.shrink();

    final List<String> days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    double maxVal = 0;
    a.weekdayAvgSpend.forEach((k, v) { if (v > maxVal) maxVal = v; });
    if (maxVal == 0) maxVal = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Behavioral Analysis", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("In this period, your highest spending happens on ${DateFormat('EEEE').format(DateTime(2024, 1, a.highestSpendWeekday))}s.", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  double val = a.weekdayAvgSpend[i + 1] ?? 0.0;
                  double ht = (val / maxVal) * 80;
                  bool isHighest = (i + 1) == a.highestSpendWeekday;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(duration: const Duration(milliseconds: 500), width: 24, height: ht > 0 ? ht : 4, decoration: BoxDecoration(color: isHighest ? _rose : _sky.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 8),
                      Text(days[i], style: TextStyle(color: isHighest ? Colors.white : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  );
                }),
              )
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms);
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return "Today";
    if (target == yesterday) return "Yesterday";
    return DateFormat('MMMM d, yyyy').format(date);
  }

  Widget _buildRecordsTab(List<AetherTransaction> allTxs, BudgetAnalyticsData a) {
    DateTime filterStart; DateTime filterEnd;
    final now = DateTime.now();
    if (_selectedFilter == 'Today') { filterStart = DateTime(now.year, now.month, now.day); filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59); }
    else if (_selectedFilter == 'Last 3 Days') { filterStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2)); filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59); }
    else if (_selectedFilter == 'Last 7 Days') { filterStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)); filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59); }
    else if (_selectedFilter == 'Last 10 Days') { filterStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 9)); filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59); }
    else if (_selectedFilter == 'Last 30 Days') { filterStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)); filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59); }
    else if (_selectedFilter == 'This Week') { filterStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1)); filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59); }
    else if (_selectedFilter == 'This Month') { filterStart = DateTime(now.year, now.month, 1); filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59); }
    else if (_selectedFilter == 'Custom' && _customRange != null) { filterStart = DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day); filterEnd = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59); }
    else { filterStart = a.baseStartDate; filterEnd = a.baseEndDate; }

    var budgetTxs = allTxs.where((t) {
      if (t.type != 'expense') return false;
      bool matchesCategory = (widget.budget.category == 'Global') || (t.category == widget.budget.category);
      if (!matchesCategory) return false;
      
      bool isPausedDuringTx = false;
      for (int i = 0; i < (widget.budget.pauseTimestamps?.length ?? 0); i++) {
        DateTime pStart = widget.budget.pauseTimestamps![i];
        DateTime? pEnd = (i < (widget.budget.resumeTimestamps?.length ?? 0)) ? widget.budget.resumeTimestamps![i] : null;
        if (t.date.isAfter(pStart) && (pEnd == null || t.date.isBefore(pEnd))) { isPausedDuringTx = true; break; }
      }
      if (isPausedDuringTx) return false;
      if (!(widget.budget.includePastTransactions ?? false) && t.date.isBefore(widget.budget.createdAt)) return false;
      if (t.date.isBefore(filterStart) || t.date.isAfter(filterEnd)) return false;
      return true;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      budgetTxs = budgetTxs.where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    if (_recordSortBy == 'Date (Newest)') { budgetTxs.sort((x, y) => y.date.compareTo(x.date)); }
    else if (_recordSortBy == 'Date (Oldest)') { budgetTxs.sort((x, y) => x.date.compareTo(y.date)); }
    else if (_recordSortBy == 'Amount (High-Low)') { budgetTxs.sort((x, y) => y.amount.abs().compareTo(x.amount.abs())); }
    else if (_recordSortBy == 'Amount (Low-High)') { budgetTxs.sort((x, y) => x.amount.abs().compareTo(y.amount.abs())); }
    else if (_recordSortBy == 'Name (A-Z)') { budgetTxs.sort((x, y) => x.title.toLowerCase().compareTo(y.title.toLowerCase())); }

    double totalFilteredSpent = budgetTxs.fold(0.0, (sum, t) => sum + t.amount.abs());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Container(
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(hintText: "Search transactions...", hintStyle: TextStyle(color: Colors.white24, fontSize: 14), prefixIcon: Icon(Icons.search_rounded, color: Colors.white38, size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 14)),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${budgetTxs.length} Transactions", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(AetherCurrency.format(totalFilteredSpent), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              PopupMenuButton<String>(
                color: const Color(0xFF0D1420),
                initialValue: _recordSortBy,
                onSelected: (v) => setState(() => _recordSortBy = v),
                itemBuilder: (ctx) => _recordSortOptions.map((s) => PopupMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 12)))).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_recordSortBy, style: const TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(width: 6),
                      const Icon(Icons.sort_rounded, color: Colors.white54, size: 14),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),

        Expanded(
          child: budgetTxs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded, color: Colors.white.withValues(alpha: 0.1), size: 48), const SizedBox(height: 16),
                    const Text("No transactions found.", style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ],
                ),
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: budgetTxs.length,
                itemBuilder: (context, index) {
                  final t = budgetTxs[index];
                  bool isDateSort = _recordSortBy.startsWith('Date');
                  bool showDateHeader = false;

                  if (isDateSort) {
                    if (index == 0) {
                      showDateHeader = true;
                    } else {
                      final prevT = budgetTxs[index - 1];
                      if (t.date.year != prevT.date.year || t.date.month != prevT.date.month || t.date.day != prevT.date.day) {
                        showDateHeader = true;
                      }
                    }
                  }

                  Widget card = Container(
                    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.025), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.04))),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _rose.withValues(alpha: 0.1), shape: BoxShape.circle), 
                          child: const Icon(Icons.shopping_bag_rounded, color: _rose, size: 18)
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(
                                t.subcategory != null ? "${t.category} • ${t.subcategory}" : t.category, 
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          )
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(AetherCurrency.format(t.amount), style: const TextStyle(color: _rose, fontSize: 15, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
                            const SizedBox(height: 4),
                            Text(DateFormat('h:mm a').format(t.date), style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          ],
                        )
                      ],
                    ),
                  );

                  if (showDateHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: index == 0 ? 0 : 16, bottom: 12, left: 4),
                          child: Text(_formatDateHeader(t.date).toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ),
                        card,
                      ],
                    );
                  }
                  
                  return card;
                },
              ),
        ),
      ],
    );
  }
}