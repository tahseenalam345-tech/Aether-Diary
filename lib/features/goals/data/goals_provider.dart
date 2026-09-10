import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/aether_goal.dart';

final goalNotifierProvider = StateNotifierProvider<GoalNotifier, AsyncValue<List<AetherGoal>>>((ref) {
  return GoalNotifier();
});

class GoalNotifier extends StateNotifier<AsyncValue<List<AetherGoal>>> {
  GoalNotifier() : super(const AsyncValue.loading()) {
    _loadGoals();
  }

  static const String boxName = 'aether_goals_box';

  Future<void> _loadGoals() async {
    try {
      final box = await Hive.openBox<AetherGoal>(boxName);
      state = AsyncValue.data(box.values.toList().cast<AetherGoal>());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addGoal(AetherGoal goal) async {
    final box = await Hive.openBox<AetherGoal>(boxName);
    await box.put(goal.id, goal);
    _loadGoals();
  }

  Future<void> updateGoalProgress(String id, double newAmount) async {
    final box = await Hive.openBox<AetherGoal>(boxName);
    final goal = box.get(id);
    if (goal != null) {
      goal.currentAmount = newAmount;
      await goal.save();
      _loadGoals();
    }
  }

  Future<void> deleteGoal(String id) async {
    final box = await Hive.openBox<AetherGoal>(boxName);
    await box.delete(id);
    _loadGoals();
  }
}