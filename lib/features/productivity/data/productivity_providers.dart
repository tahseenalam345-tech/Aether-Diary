import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/aether_task.dart';
import '../domain/models/aether_subtask.dart';
import '../domain/models/aether_habit.dart';
import '../domain/models/aether_focus_session.dart';
import '../../../core/services/task_notification_service.dart';

// ==========================================
// 1. TASK PROVIDER (WITH ECOSYSTEM SYNC)
// ==========================================
final taskNotifierProvider = StateNotifierProvider<TaskNotifier, AsyncValue<List<AetherTask>>>((ref) {
  return TaskNotifier(ref); 
});

class TaskNotifier extends StateNotifier<AsyncValue<List<AetherTask>>> {
  final Ref ref;
  TaskNotifier(this.ref) : super(const AsyncValue.loading()) { _loadTasks(); }
  
  static const String boxName = 'aether_tasks_v5'; 

  Future<void> _loadTasks() async {
    try {
      final box = await Hive.openBox<AetherTask>(boxName);
      List<AetherTask> allTasks = box.values.toList().cast<AetherTask>();

      allTasks.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return a.orderIndex.compareTo(b.orderIndex);
      });

      state = AsyncValue.data(allTasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> syncHabitLinks(String habitId, List<String> linkedTaskIds) async {
    final box = await Hive.openBox<AetherTask>(boxName);
    bool changed = false;
    
    for (var task in box.values) {
      if (linkedTaskIds.contains(task.id)) {
        if (!task.linkedHabitIds.contains(habitId)) {
          task.linkedHabitIds.add(habitId);
          await task.save();
          changed = true;
        }
      } else {
        if (task.linkedHabitIds.contains(habitId)) {
          task.linkedHabitIds.remove(habitId);
          await task.save();
          changed = true;
        }
      }
    }
    if (changed) _loadTasks();
  }

  Future<void> addTask({
    required String title, String description = '', int priority = 0, DateTime? dueDate, 
    String category = 'General', String? recurrenceRule, int reminderOffsetMinutes = 0, String notes = '',
    List<AetherSubtask>? subtasks, List<String>? linkedHabitIds, List<String>? attachments,
  }) async {
    final box = await Hive.openBox<AetherTask>(boxName);
    final task = AetherTask(
      title: title, description: description, priority: priority, dueDate: dueDate, 
      category: category, recurrenceRule: recurrenceRule, reminderOffsetMinutes: reminderOffsetMinutes, notes: notes, 
      subtasks: subtasks, linkedHabitIds: linkedHabitIds, attachments: attachments, orderIndex: box.length,
    );
    await box.put(task.id, task);
    
    if (dueDate != null) await GlobalNotificationEngine().scheduleTaskReminder(task);
    
    if (linkedHabitIds != null) {
      await ref.read(habitNotifierProvider.notifier).syncTaskLinks(task.id, linkedHabitIds);
    }
    
    _loadTasks();
  }

  Future<void> updateTask(AetherTask task, {
    required String title, required String description, required int priority, DateTime? dueDate, 
    required String category, String? recurrenceRule, required int reminderOffsetMinutes, required String notes,
    List<AetherSubtask>? subtasks, List<String>? linkedHabitIds, List<String>? attachments,
  }) async {
    await GlobalNotificationEngine().cancelReminder(task.id);
    task.title = title; task.description = description; task.priority = priority;
    task.dueDate = dueDate; task.category = category; task.recurrenceRule = recurrenceRule;
    task.reminderOffsetMinutes = reminderOffsetMinutes; task.notes = notes;
    
    if (subtasks != null) task.subtasks = subtasks;
    if (linkedHabitIds != null) task.linkedHabitIds = linkedHabitIds;
    if (attachments != null) task.attachments = attachments;
    
    await task.save();
    if (dueDate != null) await GlobalNotificationEngine().scheduleTaskReminder(task);
    
    await ref.read(habitNotifierProvider.notifier).syncTaskLinks(task.id, task.linkedHabitIds);
    
    _loadTasks();
  }

  Future<void> toggleTaskCompletion(AetherTask task) async {
    final markingDone = !task.isCompleted;
    task.isCompleted = markingDone;
    await task.save();

    if (markingDone) {
      await GlobalNotificationEngine().cancelReminder(task.id);
      final next = task.buildNextOccurrence();
      if (next != null) {
        final box = await Hive.openBox<AetherTask>(boxName);
        next.orderIndex = box.length;
        await box.put(next.id, next);
        if (next.dueDate != null) await GlobalNotificationEngine().scheduleTaskReminder(next);
      }
    } else if (task.dueDate != null) {
      await GlobalNotificationEngine().scheduleTaskReminder(task);
    }
    _loadTasks();
  }

  Future<void> moveToBin(AetherTask task) async {
    await GlobalNotificationEngine().cancelReminder(task.id);
    task.lifecycle = 'deleted';
    await task.save();
    _loadTasks();
  }

  Future<void> restoreFromBin(AetherTask task) async {
    task.lifecycle = 'active';
    await task.save();
    if (!task.isCompleted && task.dueDate != null) await GlobalNotificationEngine().scheduleTaskReminder(task);
    _loadTasks();
  }

  Future<void> permanentDelete(String id) async {
    final box = await Hive.openBox<AetherTask>(boxName);
    await box.delete(id);
    await ref.read(habitNotifierProvider.notifier).syncTaskLinks(id, []);
    _loadTasks();
  }

  Future<void> deleteTask(String id) async {
    final box = await Hive.openBox<AetherTask>(boxName);
    await GlobalNotificationEngine().cancelReminder(id);
    await box.delete(id);
    await ref.read(habitNotifierProvider.notifier).syncTaskLinks(id, []);
    _loadTasks();
  }

  Future<void> restoreTask(AetherTask task) async {
    final box = await Hive.openBox<AetherTask>(boxName);
    await box.put(task.id, task);
    if (!task.isCompleted && task.dueDate != null) await GlobalNotificationEngine().scheduleTaskReminder(task);
    await ref.read(habitNotifierProvider.notifier).syncTaskLinks(task.id, task.linkedHabitIds);
    _loadTasks();
  }

  Future<void> togglePin(AetherTask task) async {
    task.isPinned = !task.isPinned;
    await task.save();
    _loadTasks();
  }

  Future<void> duplicateTask(AetherTask task) async {
    final box = await Hive.openBox<AetherTask>(boxName);
    final newTask = task.copyWith(title: "${task.title} (Copy)", id: const Uuid().v4());
    newTask.orderIndex = box.length;
    await box.put(newTask.id, newTask);
    
    await ref.read(habitNotifierProvider.notifier).syncTaskLinks(newTask.id, newTask.linkedHabitIds);
    _loadTasks();
  }

  Future<void> addSubtask(AetherTask task, String title, {DateTime? deadline}) async {
    final subtask = AetherSubtask(id: const Uuid().v4(), title: title, deadline: deadline);
    task.subtasks = List.from(task.subtasks)..add(subtask);
    await task.save();
    _loadTasks();
  }

  Future<void> toggleSubtaskCompletion(AetherTask task, String subtaskId) async {
    final updatedSubtasks = task.subtasks.map((st) {
      if (st.id == subtaskId) {
        final isDone = !st.isCompleted;
        return AetherSubtask(id: st.id, title: st.title, isCompleted: isDone, completedAt: isDone ? DateTime.now() : null, deadline: st.deadline);
      }
      return st;
    }).toList();
    task.subtasks = updatedSubtasks;
    if (updatedSubtasks.isNotEmpty && updatedSubtasks.every((st) => st.isCompleted)) task.isCompleted = true;
    await task.save();
    _loadTasks();
  }

  Future<void> deleteSubtask(AetherTask task, String subtaskId) async {
    task.subtasks = List.from(task.subtasks)..removeWhere((st) => st.id == subtaskId);
    await task.save();
    _loadTasks();
  }

  Future<void> reorderSubtasks(AetherTask task, int oldIndex, int newIndex) async {
    final list = List<AetherSubtask>.from(task.subtasks);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    task.subtasks = list;
    await task.save();
    _loadTasks();
  }

  Future<void> updateTaskOrder(List<AetherTask> orderedActiveTasks) async {
    for (int i = 0; i < orderedActiveTasks.length; i++) {
      orderedActiveTasks[i].orderIndex = i;
      await orderedActiveTasks[i].save();
    }
    _loadTasks();
  }

  Future<void> bulkComplete(List<AetherTask> tasks) async { for (var t in tasks) if (!t.isCompleted) await toggleTaskCompletion(t); }
  Future<void> bulkBin(List<AetherTask> tasks) async { for (var t in tasks) await moveToBin(t); }
  Future<void> bulkPin(List<AetherTask> tasks) async { for (var t in tasks) await togglePin(t); }
  Future<void> bulkDelete(List<AetherTask> tasks) async { for (var t in tasks) await deleteTask(t.id); }
  Future<void> bulkSetCategory(List<AetherTask> tasks, String category) async { for (var t in tasks) { t.category = category; await t.save(); } _loadTasks(); }
  Future<void> bulkSetPriority(List<AetherTask> tasks, int priority) async { for (var t in tasks) { t.priority = priority; await t.save(); } _loadTasks(); }
}

// ==========================================
// 2. SMART HABIT PROVIDER
// ==========================================
final habitNotifierProvider = StateNotifierProvider<HabitNotifier, AsyncValue<List<AetherHabit>>>((ref) {
  return HabitNotifier(ref);
});

class HabitNotifier extends StateNotifier<AsyncValue<List<AetherHabit>>> {
  final Ref ref;
  HabitNotifier(this.ref) : super(const AsyncValue.loading()) { _loadHabits(); }
  
  static const String boxName = 'aether_habits_v5';

  Future<void> _loadHabits() async {
    try {
      final box = await Hive.openBox<AetherHabit>(boxName);
      List<AetherHabit> allHabits = box.values.toList().cast<AetherHabit>();

      allHabits.sort((a, b) {
        if (a.lastMovedToTop != null || b.lastMovedToTop != null) {
          if (a.lastMovedToTop == null) return 1;
          if (b.lastMovedToTop == null) return -1;
          return b.lastMovedToTop!.compareTo(a.lastMovedToTop!);
        }
        if (a.isPinned != b.isPinned) return b.isPinned ? 1 : -1;
        if (a.priority != b.priority) return b.priority.compareTo(a.priority);
        return b.createdAt.compareTo(a.createdAt);
      });

      state = AsyncValue.data(allHabits);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> syncTaskLinks(String taskId, List<String> linkedHabitIds) async {
    final box = await Hive.openBox<AetherHabit>(boxName);
    bool changed = false;

    for (var habit in box.values) {
      if (linkedHabitIds.contains(habit.id)) {
        if (!habit.linkedTaskIds.contains(taskId)) {
          habit.linkedTaskIds.add(taskId);
          await habit.save();
          changed = true;
        }
      } else {
        if (habit.linkedTaskIds.contains(taskId)) {
          habit.linkedTaskIds.remove(taskId);
          await habit.save();
          changed = true;
        }
      }
    }
    if (changed) _loadHabits();
  }

  Future<void> addHabit(AetherHabit habit) async {
    final box = await Hive.openBox<AetherHabit>(boxName);
    await box.put(habit.id, habit);
    await ref.read(taskNotifierProvider.notifier).syncHabitLinks(habit.id, habit.linkedTaskIds);
    _loadHabits();
  }

  Future<void> saveHabit(AetherHabit habit) async {
    await habit.save();
    await ref.read(taskNotifierProvider.notifier).syncHabitLinks(habit.id, habit.linkedTaskIds);
    _loadHabits();
  }

  Future<void> deleteHabit(AetherHabit habit) async {
    await GlobalNotificationEngine().cancelHabitReminders(habit.id, habit.reminders.length);
    final box = await Hive.openBox<AetherHabit>(boxName);
    await box.delete(habit.id);
    await ref.read(taskNotifierProvider.notifier).syncHabitLinks(habit.id, []);
    _loadHabits();
  }

  Future<void> duplicateHabit(AetherHabit habit) async {
    final box = await Hive.openBox<AetherHabit>(boxName);
    final newHabit = habit.copy();
    await box.put(newHabit.id, newHabit);
    await ref.read(taskNotifierProvider.notifier).syncHabitLinks(newHabit.id, newHabit.linkedTaskIds);
    _loadHabits();
  }

  Future<void> togglePin(AetherHabit habit) async {
    habit.isPinned = !habit.isPinned;
    await habit.save();
    _loadHabits();
  }

  Future<void> moveToTop(AetherHabit habit) async {
    habit.lastMovedToTop = DateTime.now();
    await habit.save();
    _loadHabits();
  }

  Future<void> updatePriority(AetherHabit habit, int newPriority) async {
    habit.priority = newPriority;
    await habit.save();
    _loadHabits();
  }

  Future<void> setCategory(AetherHabit habit, String category) async {
    habit.category = category;
    await habit.save();
    _loadHabits();
  }

  Future<void> toggleHabitCompletion(AetherHabit habit, DateTime date) async {
    bool isDone = habit.getRecord(date)['isCompleted'];
    await updateSimpleProgress(habit, date, !isDone);
  }

  Future<void> updateSimpleProgress(AetherHabit habit, DateTime date, bool isCompleted) async {
    habit.saveRecord(date, isCompleted ? habit.target : 0.0, [], isCompleted);
    _loadHabits();
  }

  Future<void> updateQuantityProgress(AetherHabit habit, DateTime date, double addedAmount) async {
    final record = habit.getRecord(date);
    double newProgress = (record['progress'] as double) + addedAmount;
    if (newProgress < 0) newProgress = 0;
    bool isCompleted = newProgress >= habit.target;
    habit.saveRecord(date, newProgress, [], isCompleted);
    _loadHabits();
  }

  Future<void> updateSessionStatus(AetherHabit habit, DateTime date, int sessionIndex, String status) async {
    final record = habit.getRecord(date);
    List<String> sessions = List<String>.from(record['sessions']);
    while (sessions.length <= sessionIndex) { sessions.add('P'); }
    sessions[sessionIndex] = status;
    bool isCompleted = sessions.where((s) => s == 'C').length == habit.schedule.length;
    habit.saveRecord(date, record['progress'], sessions, isCompleted);
    _loadHabits();
  }

  Future<void> updateChecklistStatus(AetherHabit habit, DateTime date, int index, bool checked) async {
    final record = habit.getRecord(date);
    List<String> sessions = List<String>.from(record['sessions']);
    while (sessions.length <= index) { sessions.add('P'); }
    sessions[index] = checked ? 'C' : 'P';
    bool isCompleted = habit.schedule.isNotEmpty && sessions.where((s) => s == 'C').length == habit.schedule.length;
    habit.saveRecord(date, record['progress'], sessions, isCompleted);
    _loadHabits();
  }

  Future<void> updateNegativeStatus(AetherHabit habit, DateTime date, bool resisted) async {
    habit.saveRecord(date, resisted ? 1.0 : 0.0, [], resisted);
    _loadHabits();
  }

  Future<void> skipHabit(AetherHabit habit, DateTime date, String reason) async {
    habit.saveRecord(date, 0.0, [], false, reason: reason);
    _loadHabits();
  }
}

// ==========================================
// 3. FOCUS SESSION PROVIDER
// ==========================================
// ==========================================
// 3. FOCUS SESSION PROVIDER (UPDATED FOR HISTORY)
// ==========================================
// ==========================================
// 3. FOCUS SESSION PROVIDER (TRUE HISTORY LOGGER)
// ==========================================
final focusSessionNotifierProvider = StateNotifierProvider<FocusSessionNotifier, AsyncValue<List<AetherFocusSession>>>((ref) {
  return FocusSessionNotifier();
});

class FocusSessionNotifier extends StateNotifier<AsyncValue<List<AetherFocusSession>>> {
  FocusSessionNotifier() : super(const AsyncValue.loading()) { _loadSessions(); }
  
  static const String boxName = 'aether_focus_sessions_v4'; // Clean wipe for new robust tracking

  Future<void> _loadSessions() async {
    try {
      final box = await Hive.openBox<AetherFocusSession>(boxName);
      List<AetherFocusSession> sessions = box.values.toList().cast<AetherFocusSession>();
      
      // Sort by newest first
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      state = AsyncValue.data(sessions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logSession({
    required int plannedMinutes, 
    required int actualSeconds,
    required DateTime startTime,
    required String taskName, 
    required List<String> notes,
    required String status,
  }) async {
    final box = await Hive.openBox<AetherFocusSession>(boxName);
    final session = AetherFocusSession(
      durationMinutes: plannedMinutes, 
      actualDurationSeconds: actualSeconds,
      startTime: startTime,
      sessionType: "Deep Work",
      taskName: taskName,
      capturedNotes: List.from(notes),
      status: status,
    );
    await box.put(session.id, session);
    _loadSessions();
  }
}