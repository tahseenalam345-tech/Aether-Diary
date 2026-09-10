import 'dart:math' as math;
import '../models/aether_budget.dart';

/// 🌟 AETHER BUDGET DATE HELPER 🌟
/// Provides mathematically precise cycle date calculations for all budget periods:
/// - Daily: Exact 00:00:00 to 23:59:59 of each day.
/// - Weekly: Exact 7-day windows anchored from budget creation date.
/// - Monthly:
///     - Calendar-aligned (1st of month): 1st 00:00:00 to end of month 23:59:59.
///     - Anchor-based (e.g. 4th): 4th 00:00:00 to 3rd of next month 23:59:59 (safe 30/31/28-day clamping).
/// - Yearly: Exact 12-month calendar or anchor block.
/// - Custom: Exact user defined start & end timestamps.
/// - Cycle Offset: Supports time-traveling (0 = current, -1 = previous, +1 = next).
class AetherBudgetDateHelper {
  /// Safely add or subtract months to a date without Dart month rollover bugs (e.g., Jan 31 + 1 month -> Feb 28).
  static DateTime addMonths(DateTime date, int months) {
    int totalMonths = (date.year * 12 + (date.month - 1)) + months;
    int newYear = totalMonths ~/ 12;
    int newMonth = (totalMonths % 12) + 1;
    int daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    int newDay = math.min(date.day, daysInNewMonth);
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute, date.second, date.millisecond);
  }

  /// Calculates the exact start and end `DateTime` for a budget period given `createdAt` and `period`.
  static (DateTime start, DateTime end, int totalDays, int elapsedDays, int remainingDays, bool isCurrentCycle) getPeriodRangeFromDetails({
    required DateTime createdAt,
    required String period,
    int cycleOffset = 0,
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();
    final cDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final nDate = DateTime(now.year, now.month, now.day);
    final periodNormalized = period.toLowerCase().trim();

    DateTime activeCycleStart;
    DateTime activeCycleEnd;

    if (periodNormalized == 'daily' || periodNormalized == 'day') {
      activeCycleStart = DateTime(nDate.year, nDate.month, nDate.day);
      activeCycleEnd = DateTime(nDate.year, nDate.month, nDate.day, 23, 59, 59);
    } else if (periodNormalized == 'weekly' || periodNormalized == 'week') {
      int daysSinceCreation = nDate.difference(cDate).inDays;
      int cycles = daysSinceCreation >= 0 ? (daysSinceCreation ~/ 7) : ((daysSinceCreation - 6) ~/ 7);
      activeCycleStart = cDate.add(Duration(days: cycles * 7));
      activeCycleEnd = activeCycleStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    } else if (periodNormalized == 'yearly' || periodNormalized == 'year') {
      int yearDiff = nDate.year - cDate.year;
      DateTime candidate = DateTime(cDate.year + yearDiff, cDate.month, cDate.day);
      if (nDate.isBefore(candidate)) {
        yearDiff--;
      }
      activeCycleStart = DateTime(cDate.year + yearDiff, cDate.month, cDate.day);
      DateTime nextYearAnchor = DateTime(activeCycleStart.year + 1, activeCycleStart.month, activeCycleStart.day);
      activeCycleEnd = nextYearAnchor.subtract(const Duration(seconds: 1));
    } else {
      // Monthly Period (Default)
      if (cDate.day == 1) {
        // 🌟 Exact Calendar Month (1st to Last Day of Month)
        activeCycleStart = DateTime(nDate.year, nDate.month, 1);
        int daysInMonth = DateTime(nDate.year, nDate.month + 1, 0).day;
        activeCycleEnd = DateTime(nDate.year, nDate.month, daysInMonth, 23, 59, 59);
      } else {
        // 🌟 Anchor-based Rolling Month (e.g. Sep 4 to Oct 3)
        int monthDiff = (nDate.year - cDate.year) * 12 + (nDate.month - cDate.month);
        DateTime candidate = addMonths(cDate, monthDiff);
        if (nDate.isBefore(candidate)) {
          monthDiff--;
        }
        activeCycleStart = addMonths(cDate, monthDiff);
        DateTime nextMonthAnchor = addMonths(activeCycleStart, 1);
        activeCycleEnd = nextMonthAnchor.subtract(const Duration(seconds: 1));
      }
    }

    // Apply cycleOffset for period time-travel navigation
    DateTime targetStart = activeCycleStart;
    DateTime targetEnd = activeCycleEnd;

    if (cycleOffset != 0) {
      if (periodNormalized == 'daily' || periodNormalized == 'day') {
        targetStart = activeCycleStart.add(Duration(days: cycleOffset));
        targetEnd = DateTime(targetStart.year, targetStart.month, targetStart.day, 23, 59, 59);
      } else if (periodNormalized == 'weekly' || periodNormalized == 'week') {
        targetStart = activeCycleStart.add(Duration(days: cycleOffset * 7));
        targetEnd = targetStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      } else if (periodNormalized == 'yearly' || periodNormalized == 'year') {
        targetStart = DateTime(activeCycleStart.year + cycleOffset, activeCycleStart.month, activeCycleStart.day);
        DateTime nextYear = DateTime(targetStart.year + 1, targetStart.month, targetStart.day);
        targetEnd = nextYear.subtract(const Duration(seconds: 1));
      } else {
        // Monthly offset
        if (cDate.day == 1) {
          int totalMonths = (activeCycleStart.year * 12 + (activeCycleStart.month - 1)) + cycleOffset;
          int y = totalMonths ~/ 12;
          int m = (totalMonths % 12) + 1;
          targetStart = DateTime(y, m, 1);
          int daysInM = DateTime(y, m + 1, 0).day;
          targetEnd = DateTime(y, m, daysInM, 23, 59, 59);
        } else {
          targetStart = addMonths(activeCycleStart, cycleOffset);
          DateTime nextAnchor = addMonths(targetStart, 1);
          targetEnd = nextAnchor.subtract(const Duration(seconds: 1));
        }
      }
    }

    targetStart = DateTime(targetStart.year, targetStart.month, targetStart.day);
    int totalDays = targetEnd.difference(targetStart).inDays + 1;
    if (totalDays <= 0) totalDays = 1;

    bool isCurrentCycle = (cycleOffset == 0);
    int elapsedDays;
    int remainingDays;

    if (cycleOffset < 0) {
      // Historical cycle already ended
      elapsedDays = totalDays;
      remainingDays = 0;
    } else if (cycleOffset > 0) {
      // Future cycle not yet started
      elapsedDays = 0;
      remainingDays = totalDays;
    } else {
      // Active current cycle
      elapsedDays = now.difference(targetStart).inDays + 1;
      elapsedDays = elapsedDays.clamp(1, totalDays);
      remainingDays = math.max(0, totalDays - elapsedDays);
    }

    return (targetStart, targetEnd, totalDays, elapsedDays, remainingDays, isCurrentCycle);
  }

  /// Calculates the exact start and end `DateTime` for an `AetherBudget` instance.
  static (DateTime start, DateTime end, int totalDays, int elapsedDays, int remainingDays, bool isCurrentCycle) getPeriodRange(
    AetherBudget budget, {
    int cycleOffset = 0,
    DateTime? referenceNow,
  }) {
    return getPeriodRangeFromDetails(
      createdAt: budget.createdAt,
      period: budget.period,
      cycleOffset: cycleOffset,
      referenceNow: referenceNow,
    );
  }
}
