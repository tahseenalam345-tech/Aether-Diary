import 'package:hive/hive.dart';
import '../domain/models/aether_task.dart';
import '../domain/models/aether_habit.dart';
import '../domain/models/aether_focus_session.dart';

class ProductivityRepository {
  static final ProductivityRepository _instance = ProductivityRepository._internal();
  factory ProductivityRepository() => _instance;
  ProductivityRepository._internal();

  late Box<AetherTask> _taskBox;
  late Box<AetherHabit> _habitBox;
  late Box<AetherFocusSession> _focusBox;

  Future<void> init() async {
    // OPTIMIZED: Open all boxes concurrently for faster startup
    final boxes = await Future.wait([
      Hive.openBox<AetherTask>('aether_tasks_v2'),
      Hive.openBox<AetherHabit>('aether_habits'),
      Hive.openBox<AetherFocusSession>('aether_focus'),
    ]);

    _taskBox = boxes[0] as Box<AetherTask>;
    _habitBox = boxes[1] as Box<AetherHabit>;
    _focusBox = boxes[2] as Box<AetherFocusSession>;
  }

  // --- TASKS ---
  List<AetherTask> getAllTasks() => _taskBox.values.toList();
  
  Future<void> saveTask(AetherTask task) async {
    await _taskBox.put(task.id, task);
  }

  Future<void> saveAllTasks(List<AetherTask> tasks) async {
    final Map<dynamic, AetherTask> taskMap = {for (var t in tasks) t.id: t};
    await _taskBox.putAll(taskMap);
  }

  Future<void> deleteTask(String id) async {
    await _taskBox.delete(id);
  }

  // --- HABITS ---
  List<AetherHabit> getAllHabits() => _habitBox.values.toList();
  Future<void> saveHabit(AetherHabit habit) async { await _habitBox.put(habit.id, habit); }
  Future<void> deleteHabit(String id) async { await _habitBox.delete(id); }

  // --- FOCUS ---
  List<AetherFocusSession> getAllFocusSessions() => _focusBox.values.toList();
  Future<void> saveFocusSession(AetherFocusSession session) async { await _focusBox.put(session.id, session); }
}