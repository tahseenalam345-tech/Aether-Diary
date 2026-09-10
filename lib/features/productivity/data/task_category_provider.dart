import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/models/aether_task.dart';

final taskCategoriesProvider = StateNotifierProvider<TaskCategoriesNotifier, List<String>>((ref) {
  return TaskCategoriesNotifier();
});

class TaskCategoriesNotifier extends StateNotifier<List<String>> {
  TaskCategoriesNotifier() : super(List.from(AetherTask.predefinedCategories)) {
    _load();
  }

  static const String boxName = 'aether_meta';
  static const String key = 'custom_task_categories';

  Future<void> _load() async {
    final box = await Hive.openBox(boxName);
    final stored = (box.get(key) as List?)?.cast<String>() ?? [];
    state = [...AetherTask.predefinedCategories, ...stored];
  }

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.any((c) => c.toLowerCase() == trimmed.toLowerCase())) return;

    final box = await Hive.openBox(boxName);
    final stored = (box.get(key) as List?)?.cast<String>() ?? [];
    stored.add(trimmed);
    await box.put(key, stored);
    state = [...AetherTask.predefinedCategories, ...stored];
  }

  Future<void> removeCategory(String name) async {
    if (AetherTask.predefinedCategories.contains(name)) return; 
    final box = await Hive.openBox(boxName);
    final stored = (box.get(key) as List?)?.cast<String>() ?? [];
    stored.remove(name);
    await box.put(key, stored);
    state = [...AetherTask.predefinedCategories, ...stored];
  }
}