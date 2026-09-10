import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../wallet/data/wallet_providers.dart';
import '../../productivity/data/productivity_providers.dart';
import '../../diary/data/diary_provider.dart';

// --- DATA TRANSFER OBJECT FOR GLOBAL INSIGHTS ---
class AetherAnalyticsState {
  final int totalTasksCompleted;
  final int totalTasksPending;
  final int totalFocusMinutes;
  final int totalDiaryEntries;
  
  final List<double> focusWeekTrend; // Last 7 days of focus minutes
  final List<double> expenseWeekTrend; // Last 7 days of spending
  final List<double> moodWeekTrend; // Last 7 days of entry counts

  final double totalExpensesThisWeek;
  final double maxExpenseDay;
  final double maxFocusDay;

  AetherAnalyticsState({
    required this.totalTasksCompleted,
    required this.totalTasksPending,
    required this.totalFocusMinutes,
    required this.totalDiaryEntries,
    required this.focusWeekTrend,
    required this.expenseWeekTrend,
    required this.moodWeekTrend,
    required this.totalExpensesThisWeek,
    required this.maxExpenseDay,
    required this.maxFocusDay,
  });
}

// --- REAL-TIME OFFLINE COMPUTATION ENGINE ---
final globalAnalyticsProvider = Provider<AetherAnalyticsState>((ref) {
  // 1. Ingest Real Data Streams
  final tasks = ref.watch(taskNotifierProvider).valueOrNull ?? [];
  final sessions = ref.watch(focusSessionNotifierProvider).valueOrNull ?? [];
  final transactions = ref.watch(transactionNotifierProvider).valueOrNull ?? [];
  final diaries = ref.watch(diaryEntriesProvider).valueOrNull ?? [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // 2. Initialize 7-Day Rolling Arrays (Index 0 = 6 days ago, Index 6 = Today)
  List<double> focusTrend = List.filled(7, 0.0);
  List<double> expenseTrend = List.filled(7, 0.0);
  List<double> moodTrend = List.filled(7, 0.0);

  int tasksCompleted = 0;
  int tasksPending = 0;
  int totalFocus = 0;
  double expensesThisWeek = 0.0;

  // 3. Process Productivity (Tasks)
  for (var task in tasks) {
    if (task.isCompleted) {
      tasksCompleted++;
    } else {
      tasksPending++;
    }
  }

  // 4. Process Productivity (Focus)
  for (var session in sessions) {
    totalFocus += session.durationMinutes;
    final sessionDay = DateTime(session.startTime.year, session.startTime.month, session.startTime.day);
    final daysDifference = today.difference(sessionDay).inDays;
    
    if (daysDifference >= 0 && daysDifference < 7) {
      final index = 6 - daysDifference;
      focusTrend[index] += session.durationMinutes.toDouble();
    }
  }

  // 5. Process Wealth (Wallet)
  for (var tx in transactions) {
    if (tx.type == 'expense') {
      final txDay = DateTime(tx.date.year, tx.date.month, tx.date.day);
      final daysDifference = today.difference(txDay).inDays;
      
      if (daysDifference >= 0 && daysDifference < 7) {
        final index = 6 - daysDifference;
        final convertedAmount = tx.amount * tx.exchangeRate;
        expenseTrend[index] += convertedAmount;
        expensesThisWeek += convertedAmount;
      }
    }
  }

  // 6. Process Vault (Diary)
  for (var entry in diaries) {
    final entryDay = DateTime(entry.createdAt.year, entry.createdAt.month, entry.createdAt.day);
    final daysDifference = today.difference(entryDay).inDays;
    
    if (daysDifference >= 0 && daysDifference < 7) {
      final index = 6 - daysDifference;
      moodTrend[index] += 1.0; // Count entries per day
    }
  }

  // 7. Calculate normalization maximums for UI rendering
  double maxExp = 0.0;
  for (var e in expenseTrend) { if (e > maxExp) maxExp = e; }
  
  double maxFoc = 0.0;
  for (var f in focusTrend) { if (f > maxFoc) maxFoc = f; }

  return AetherAnalyticsState(
    totalTasksCompleted: tasksCompleted,
    totalTasksPending: tasksPending,
    totalFocusMinutes: totalFocus,
    totalDiaryEntries: diaries.length,
    focusWeekTrend: focusTrend,
    expenseWeekTrend: expenseTrend,
    moodWeekTrend: moodTrend,
    totalExpensesThisWeek: expensesThisWeek,
    maxExpenseDay: maxExp > 0 ? maxExp : 1.0, 
    maxFocusDay: maxFoc > 0 ? maxFoc : 1.0,
  );
});