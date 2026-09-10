import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../productivity/data/productivity_providers.dart';
import '../../wallet/data/wallet_providers.dart';
import '../../diary/data/diary_provider.dart';

// --- ENHANCED DATA TRANSFER OBJECT FOR AI INSIGHTS ---
class AiReflectionState {
  final String dailyNarrative;
  final String dominantMood;
  final String topSpendingCategory;
  final String productivityStatus;
  final int streakDays;
  final String energyLevel;
  final List<String> actionableAdvice;
  final List<String> activityHighlights;

  AiReflectionState({
    required this.dailyNarrative,
    required this.dominantMood,
    required this.topSpendingCategory,
    required this.productivityStatus,
    required this.streakDays,
    required this.energyLevel,
    required this.actionableAdvice,
    required this.activityHighlights,
  });
}

// --- HEURISTIC LOCAL AI MONITORING ENGINE ---
final localAiReflectionProvider = Provider<AiReflectionState>((ref) {
  final tasks = ref.watch(taskNotifierProvider).valueOrNull ?? [];
  final sessions = ref.watch(focusSessionNotifierProvider).valueOrNull ?? [];
  final transactions = ref.watch(transactionNotifierProvider).valueOrNull ?? [];
  final diaries = ref.watch(diaryEntriesProvider).valueOrNull ?? [];
  final habits = ref.watch(habitNotifierProvider).valueOrNull ?? [];

  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));

  // 1. MOOD ANALYSIS (From Diary)
  Map<String, int> moodCounts = {};
  for (var entry in diaries) {
    if (entry.createdAt.isAfter(weekAgo)) {
      final mood = entry.mood ?? 'Calm';
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    }
  }

  String dominantMood = 'Calm & Balanced';
  int maxMoodCount = 0;
  moodCounts.forEach((key, value) {
    if (value > maxMoodCount) {
      maxMoodCount = value;
      dominantMood = key;
    }
  });

  // 2. FINANCIAL ANALYSIS (From Wallet)
  Map<String, double> categorySpend = {};
  double totalSpentThisWeek = 0.0;

  for (var tx in transactions) {
    if (tx.type == 'expense' && tx.date.isAfter(weekAgo)) {
      categorySpend[tx.category] = (categorySpend[tx.category] ?? 0.0) + tx.amount;
      totalSpentThisWeek += tx.amount;
    }
  }

  String topCategory = 'General Essentials';
  double maxSpend = 0.0;
  categorySpend.forEach((key, value) {
    if (value > maxSpend && key != 'Global') {
      maxSpend = value;
      topCategory = key;
    }
  });

  // 3. PRODUCTIVITY ANALYSIS (From Tasks & Habits)
  int completedTasksThisWeek = 0;
  int pendingTasks = 0;
  int focusMinutes = 0;

  for (var task in tasks) {
    if (task.isCompleted && task.createdAt.isAfter(weekAgo)) {
      completedTasksThisWeek++;
    } else if (!task.isCompleted) {
      pendingTasks++;
    }
  }
  for (var session in sessions) {
    if (session.startTime.isAfter(weekAgo)) focusMinutes += session.durationMinutes.toInt();
  }

  String prodStatus = 'Steady Execution';
  String energyLevel = 'Optimal Focus';
  if (completedTasksThisWeek >= 10) {
    prodStatus = 'Unstoppable Flow';
    energyLevel = 'High Momentum 🔥';
  } else if (completedTasksThisWeek >= 4) {
    prodStatus = 'Consistent Progress';
    energyLevel = 'Balanced Pace ⚡';
  } else if (pendingTasks > 6) {
    prodStatus = 'Task Accumulation';
    energyLevel = 'High Demand 🧘';
  } else {
    prodStatus = 'Gentle Rhythm';
    energyLevel = 'Calm Recharge 🌿';
  }

  // 4. ACTIONABLE ADVICE & HIGHLIGHTS
  final List<String> advice = [];
  if (pendingTasks > 3) {
    advice.add("Prioritize 2 urgent tasks and run a 25m Focus Sprint to clear mental clutter.");
  }
  if (totalSpentThisWeek > 0) {
    advice.add("Review your $topCategory spending to maintain healthy budget margin.");
  }
  if (diaries.isEmpty || !diaries.any((d) => d.createdAt.isAfter(now.subtract(const Duration(days: 2))))) {
    advice.add("Capture an evening reflection to synthesize your thoughts and close the day.");
  }
  if (advice.isEmpty) {
    advice.add("Great cross-module harmony today! Continue executing at this sustainable pace.");
  }

  final List<String> highlights = [
    "$completedTasksThisWeek tasks completed this week",
    "${diaries.where((d) => d.createdAt.isAfter(weekAgo)).length} memories reflected in the vault",
    "${habits.length} daily habit routines monitored",
    if (focusMinutes > 0) "$focusMinutes minutes of deep focus logged",
  ];

  // 5. NARRATIVE SYNTHESIS
  final narrative = "Your current rhythm reflects $prodStatus. Mood signals remain predominantly $dominantMood. "
      "Financially, your primary resource flow has centered on $topCategory. "
      "Aether OS observes your holistic alignment is steady—maintain this intentional trajectory.";

  return AiReflectionState(
    dailyNarrative: narrative,
    dominantMood: dominantMood,
    topSpendingCategory: topCategory,
    productivityStatus: prodStatus,
    streakDays: completedTasksThisWeek > 0 ? 5 : 1,
    energyLevel: energyLevel,
    actionableAdvice: advice,
    activityHighlights: highlights,
  );
});