import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'aether_subtask.dart';

part 'aether_task.g.dart';

@HiveType(typeId: 1)
class AetherTask extends HiveObject {
  static const List<String> predefinedCategories = [
    'Personal', 'Work', 'University', 'Health', 'Finance', 'Other'
  ];

  static const List<String> recurrenceOptions = ['none', 'daily', 'weekly', 'monthly'];

  @HiveField(0) final String id;
  @HiveField(1) String title;
  @HiveField(2) String description;
  @HiveField(3) bool isCompleted;
  @HiveField(4) DateTime? dueDate;
  @HiveField(5) int priority;
  @HiveField(6) final DateTime createdAt;
  @HiveField(7) String category;
  @HiveField(8) List<AetherSubtask> subtasks;
  @HiveField(9) String? recurrenceRule;
  @HiveField(10) int orderIndex;
  @HiveField(11, defaultValue: 0) int reminderOffsetMinutes;
  @HiveField(12, defaultValue: '') String notes;
  @HiveField(13, defaultValue: 'active') String lifecycle; 
  @HiveField(14, defaultValue: false) bool isPinned;
  @HiveField(15, defaultValue: []) List<String> linkedHabitIds;
  
  // 🌟 NEW FIELD: Media Attachments
  @HiveField(16, defaultValue: []) List<String> attachments;

  AetherTask({
    String? id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    this.dueDate,
    this.priority = 0,
    this.category = 'Personal',
    List<AetherSubtask>? subtasks,
    this.recurrenceRule,
    this.orderIndex = 0,
    this.reminderOffsetMinutes = 0,
    this.notes = '',
    this.lifecycle = 'active',
    this.isPinned = false,
    List<String>? linkedHabitIds,
    List<String>? attachments,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        subtasks = subtasks ?? [],
        linkedHabitIds = linkedHabitIds ?? [],
        attachments = attachments ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get isRecurring => recurrenceRule != null && recurrenceRule != 'none';

  AetherTask copyWith({
    String? id,
    String? title, String? description, bool? isCompleted, DateTime? dueDate,
    int? priority, String? category, List<AetherSubtask>? subtasks,
    String? recurrenceRule, int? orderIndex, int? reminderOffsetMinutes,
    String? notes, String? lifecycle, bool? isPinned, 
    List<String>? linkedHabitIds, List<String>? attachments,
  }) {
    return AetherTask(
      id: id ?? this.id, 
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      subtasks: subtasks != null ? List.from(subtasks) : List.from(this.subtasks),
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      orderIndex: orderIndex ?? this.orderIndex,
      reminderOffsetMinutes: reminderOffsetMinutes ?? this.reminderOffsetMinutes,
      notes: notes ?? this.notes,
      lifecycle: lifecycle ?? this.lifecycle,
      isPinned: isPinned ?? this.isPinned,
      linkedHabitIds: linkedHabitIds != null ? List.from(linkedHabitIds) : List.from(this.linkedHabitIds),
      attachments: attachments != null ? List.from(attachments) : List.from(this.attachments),
      createdAt: createdAt,
    );
  }

  AetherTask? buildNextOccurrence() {
    if (!isRecurring || dueDate == null) return null;

    DateTime nextDate;
    switch (recurrenceRule) {
      case 'daily': nextDate = dueDate!.add(const Duration(days: 1)); break;
      case 'weekly': nextDate = dueDate!.add(const Duration(days: 7)); break;
      case 'monthly':
        final d = dueDate!;
        int year = d.year; int month = d.month + 1;
        if (month > 12) { month = 1; year++; }
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final day = d.day > daysInMonth ? daysInMonth : d.day;
        nextDate = DateTime(year, month, day, d.hour, d.minute);
        break;
      default: return null;
    }

    return AetherTask(
      title: title, description: description, isCompleted: false, dueDate: nextDate,
      priority: priority, category: category, 
      subtasks: subtasks.map<AetherSubtask>((s) => AetherSubtask(id: const Uuid().v4(), title: s.title, deadline: s.deadline)).toList(),
      recurrenceRule: recurrenceRule, orderIndex: orderIndex, reminderOffsetMinutes: reminderOffsetMinutes, 
      notes: notes, linkedHabitIds: List.from(linkedHabitIds), attachments: List.from(attachments),
    );
  }
}