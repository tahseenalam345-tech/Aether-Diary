import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

part 'aether_habit.g.dart';

@HiveType(typeId: 3)
class AetherHabit extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1, defaultValue: '') String title;
  @HiveField(2, defaultValue: '🔥') String iconEmoji;
  @HiveField(3) final DateTime createdAt;
  @HiveField(4, defaultValue: 'simple') String habitType; 
  @HiveField(5, defaultValue: 1.0) double target;
  @HiveField(6, defaultValue: 'times') String unit;
  @HiveField(7, defaultValue: [1, 2, 3, 4, 5, 6, 7]) List<int> activeDays;
  @HiveField(8, defaultValue: []) List<String> schedule;
  @HiveField(9, defaultValue: {}) Map<String, String> history;
  @HiveField(10, defaultValue: 'active') String lifecycle;
  @HiveField(11) DateTime? startDate;
  @HiveField(12) DateTime? endDate;
  @HiveField(13, defaultValue: 1) int priority;
  @HiveField(14, defaultValue: false) bool isPinned;
  @HiveField(15, defaultValue: []) List<String> reminders;
  @HiveField(16) DateTime? lastMovedToTop;
  @HiveField(17, defaultValue: 'General') String category;
  @HiveField(18, defaultValue: '') String description; 
  
  // 🌟 NEW FIELD: Linked Tasks
  @HiveField(19, defaultValue: []) List<String> linkedTaskIds;

  AetherHabit({
    String? id,
    required this.title,
    this.iconEmoji = "🔥",
    DateTime? createdAt,
    this.habitType = 'simple',
    this.target = 1.0,
    this.unit = 'times',
    List<int>? activeDays,
    List<String>? schedule,
    Map<String, String>? history,
    this.lifecycle = 'active',
    DateTime? startDate,
    this.endDate,
    this.priority = 1,
    this.isPinned = false,
    List<String>? reminders,
    this.lastMovedToTop,
    this.category = 'General',
    this.description = '',
    List<String>? linkedTaskIds,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        activeDays = activeDays ?? [1, 2, 3, 4, 5, 6, 7],
        schedule = schedule ?? [],
        history = history ?? {},
        startDate = startDate ?? DateTime.now(),
        reminders = reminders ?? [],
        linkedTaskIds = linkedTaskIds ?? [];

  AetherHabit copy() {
    return AetherHabit(
      title: "$title (Copy)",
      iconEmoji: iconEmoji,
      habitType: habitType,
      target: target,
      unit: unit,
      activeDays: List.from(activeDays),
      schedule: List.from(schedule),
      startDate: DateTime.now(),
      endDate: endDate,
      priority: priority,
      reminders: List.from(reminders),
      category: category,
      description: description,
      linkedTaskIds: List.from(linkedTaskIds),
    );
  }

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  bool isScheduledFor(DateTime date) {
    if (startDate != null && date.isBefore(DateTime(startDate!.year, startDate!.month, startDate!.day))) return false;
    if (endDate != null && date.isAfter(DateTime(endDate!.year, endDate!.month, endDate!.day))) return false;
    return activeDays.contains(date.weekday);
  }

  Map<String, dynamic> getRecord(DateTime date) {
    final key = _dateKey(date);
    if (!history.containsKey(key)) {
      return {
        'progress': 0.0,
        'sessions': List.filled(schedule.length, 'P'),
        'isCompleted': habitType == 'negative' ? true : false,
        'reason': '',
      };
    }
    final parts = history[key]!.split('|');
    
    List<String> parsedSessions = parts[1].isEmpty ? [] : parts[1].split(',');
    while (parsedSessions.length < schedule.length) {
      parsedSessions.add('P'); 
    }

    return {
      'progress': double.parse(parts[0]),
      'sessions': parsedSessions,
      'isCompleted': parts[2] == 'true',
      'reason': parts.length > 3 ? parts[3] : '',
    };
  }

  void saveRecord(DateTime date, double progress, List<String> sessions, bool isCompleted, {String reason = ''}) {
    final key = _dateKey(date);
    history[key] = "$progress|${sessions.join(',')}|$isCompleted|$reason";
    save();
  }

  List<Map<String, dynamic>> getTodayTimeline() {
    final now = DateTime.now();
    final record = getRecord(now);
    List<String> sessions = List<String>.from(record['sessions']);
    List<Map<String, dynamic>> timeline = [];

    for (int i = 0; i < schedule.length; i++) {
      final sParts = schedule[i].split('|');
      final timeParts = sParts[0].split(':');
      final sessionTime = DateTime(now.year, now.month, now.day, int.parse(timeParts[0]), int.parse(timeParts[1]));

      String currentStatus = sessions[i];

      if (habitType != 'checklist') {
        if (currentStatus == 'P') {
          if (now.isBefore(sessionTime)) {
            currentStatus = 'U';
          } else if (now.isAfter(sessionTime.add(const Duration(hours: 2)))) {
            currentStatus = 'M';
            sessions[i] = 'M';
            saveRecord(now, record['progress'], sessions, record['isCompleted'], reason: record['reason']);
          }
        }
      }

      timeline.add({
        'index': i,
        'time': DateFormat('h:mm a').format(sessionTime),
        'name': sParts.length > 1 ? sParts[1] : 'Session ${i + 1}',
        'status': currentStatus,
      });
    }
    return timeline;
  }

  bool get isCompletedToday => getRecord(DateTime.now())['isCompleted'];

  int get currentStreak {
    int streak = 0;
    DateTime pointer = DateTime.now();
    int iterations = 0;

    if (!isCompletedToday && isScheduledFor(pointer)) {
      pointer = pointer.subtract(const Duration(days: 1));
    }

    while (iterations < 3650) {
      iterations++;
      if (startDate != null && pointer.isBefore(DateTime(startDate!.year, startDate!.month, startDate!.day))) break;

      if (isScheduledFor(pointer)) {
        if (getRecord(pointer)['isCompleted']) {
          streak++;
        } else {
          break;
        }
      }
      pointer = pointer.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<String>? _cachedSortedKeys;
  int _cachedHistoryLength = -1;

  List<String> _getSortedHistoryKeys() {
    if (_cachedSortedKeys == null || _cachedHistoryLength != history.length) {
      _cachedSortedKeys = history.keys.toList()..sort();
      _cachedHistoryLength = history.length;
    }
    return _cachedSortedKeys!;
  }

  int get longestStreak {
    if (history.isEmpty) return 0;
    int max = 0;
    int current = 0;
    final sortedDates = _getSortedHistoryKeys();
    
    for (var key in sortedDates) {
      final parts = history[key]!.split('|');
      if (parts.length > 2 && parts[2] == 'true') {
        current++;
        if (current > max) max = current;
      } else {
        current = 0;
      }
    }
    return max;
  }

  double get completionRate {
    if (history.isEmpty) return 0.0;
    int totalDays = DateTime.now().difference(DateTime(createdAt.year, createdAt.month, createdAt.day)).inDays + 1;
    if (totalDays <= 0) return 0.0;
    int completedDays = history.values.where((v) => v.split('|').length > 2 && v.split('|')[2] == 'true').length;
    return (completedDays / totalDays).clamp(0.0, 1.0);
  }

  int get totalXp {
    if (history.isEmpty) return 0;
    int xp = 0;
    final sortedDates = _getSortedHistoryKeys();
    int running = 0;
    for (var key in sortedDates) {
      final parts = history[key]!.split('|');
      if (parts.length > 2 && parts[2] == 'true') {
        running++;
        xp += 10;
        if (running == 7 || running == 30 || running == 100 || running == 365) xp += 50;
      } else {
        running = 0;
      }
    }
    return xp;
  }
}