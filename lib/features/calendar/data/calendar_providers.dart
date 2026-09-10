import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../productivity/data/productivity_providers.dart';
import '../../diary/data/diary_provider.dart';
import '../../wallet/data/wallet_providers.dart';

// --- UNIFIED CROSS-MODULE EVENT DTO ---
class AetherEvent {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'task', 'diary', 'focus', 'expense', 'income', 'habit', 'subscription'
  final DateTime date;
  final bool isCompleted;
  final double? amount;
  final String? category;
  final String? mood;
  final int? priority;
  final String? icon;

  AetherEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.date,
    this.isCompleted = false,
    this.amount,
    this.category,
    this.mood,
    this.priority,
    this.icon,
  });
}

// Strip time to allow exact day grouping
DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

// Tracks the day the user has clicked on in the UI
final selectedCalendarDateProvider = StateProvider<DateTime>((ref) => _normalizeDate(DateTime.now()));

// --- O(N) CROSS-MODULE TIMELINE AGGREGATOR ENGINE ---
final calendarEventsProvider = Provider<Map<DateTime, List<AetherEvent>>>((ref) {
  final tasks = ref.watch(taskNotifierProvider).valueOrNull ?? [];
  final diaries = ref.watch(diaryEntriesProvider).valueOrNull ?? [];
  final sessions = ref.watch(focusSessionNotifierProvider).valueOrNull ?? [];
  final txs = ref.watch(transactionNotifierProvider).valueOrNull ?? [];
  final habits = ref.watch(habitNotifierProvider).valueOrNull ?? [];
  final subscriptions = ref.watch(subscriptionNotifierProvider).valueOrNull ?? [];

  final Map<DateTime, List<AetherEvent>> eventMap = {};

  void addEvent(DateTime rawDate, AetherEvent event) {
    final date = _normalizeDate(rawDate);
    if (!eventMap.containsKey(date)) eventMap[date] = [];
    eventMap[date]!.add(event);
  }

  // 1. Map Tasks (Due Dates and Creation Dates)
  for (var task in tasks) {
    if (task.dueDate != null) {
      addEvent(
        task.dueDate!,
        AetherEvent(
          id: task.id,
          title: task.title,
          subtitle: task.category.isNotEmpty ? task.category : "Action Item",
          type: 'task',
          date: task.dueDate!,
          isCompleted: task.isCompleted,
          category: task.category,
          priority: task.priority,
        ),
      );
    } else {
      addEvent(
        task.createdAt,
        AetherEvent(
          id: task.id,
          title: task.title,
          subtitle: task.category.isNotEmpty ? task.category : "Created Task",
          type: 'task',
          date: task.createdAt,
          isCompleted: task.isCompleted,
          category: task.category,
          priority: task.priority,
        ),
      );
    }
  }

  // 2. Map Diary Entries
  for (var entry in diaries) {
    addEvent(
      entry.createdAt,
      AetherEvent(
        id: entry.id,
        title: entry.title.isNotEmpty ? entry.title : "Reflection Note",
        subtitle: entry.mood ?? 'Calm',
        type: 'diary',
        date: entry.createdAt,
        isCompleted: true,
        mood: entry.mood,
      ),
    );
  }

  // 3. Map Focus Sessions
  for (var session in sessions) {
    addEvent(
      session.startTime,
      AetherEvent(
        id: session.startTime.millisecondsSinceEpoch.toString(),
        title: 'Deep Work Sprint',
        subtitle: '${session.durationMinutes} Minutes Focus',
        type: 'focus',
        date: session.startTime,
        isCompleted: true,
      ),
    );
  }

  // 4. Map Wallet Transactions (Expenses, Incomes)
  for (var tx in txs) {
    addEvent(
      tx.date,
      AetherEvent(
        id: tx.id,
        title: tx.title,
        subtitle: tx.category,
        type: tx.type == 'income' ? 'income' : 'expense',
        date: tx.date,
        isCompleted: true,
        amount: tx.amount,
        category: tx.category,
      ),
    );
  }

  // 5. Map Habits Completed
  for (var habit in habits) {
    habit.history.forEach((dateStr, recordStr) {
      final parsedDate = DateTime.tryParse(dateStr);
      if (parsedDate != null) {
        final isCompleted = recordStr.contains('true');
        addEvent(
          parsedDate,
          AetherEvent(
            id: '${habit.id}_$dateStr',
            title: habit.title,
            subtitle: habit.category,
            type: 'habit',
            date: parsedDate,
            isCompleted: isCompleted,
            icon: habit.iconEmoji,
          ),
        );
      }
    });
  }

  // 6. Map Subscriptions Billing Dates
  for (var sub in subscriptions) {
    addEvent(
      sub.nextDueDate,
      AetherEvent(
        id: sub.id,
        title: '${sub.name} Due',
        subtitle: sub.billingCycle,
        type: 'subscription',
        date: sub.nextDueDate,
        isCompleted: false,
        amount: sub.amount,
        category: sub.categoryId,
      ),
    );
  }

  // Sort events chronologically (00:00 to 23:59) within each day
  eventMap.forEach((key, list) {
    list.sort((a, b) => a.date.compareTo(b.date));
  });

  return eventMap;
});

// Returns only the events for the currently selected day
final selectedDayEventsProvider = Provider<List<AetherEvent>>((ref) {
  final selectedDate = ref.watch(selectedCalendarDateProvider);
  final allEvents = ref.watch(calendarEventsProvider);
  return allEvents[selectedDate] ?? [];
});