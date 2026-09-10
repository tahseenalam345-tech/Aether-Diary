import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 🌟 MODEL FOR ACTIVE MODULE PREFERENCES
class ModulePreferences {
  final bool isWealthEnabled;
  final bool isDiaryEnabled;
  final bool isProductivityEnabled;

  const ModulePreferences({
    this.isWealthEnabled = true,
    this.isDiaryEnabled = true,
    this.isProductivityEnabled = true,
  });

  ModulePreferences copyWith({
    bool? isWealthEnabled,
    bool? isDiaryEnabled,
    bool? isProductivityEnabled,
  }) {
    return ModulePreferences(
      isWealthEnabled: isWealthEnabled ?? this.isWealthEnabled,
      isDiaryEnabled: isDiaryEnabled ?? this.isDiaryEnabled,
      isProductivityEnabled: isProductivityEnabled ?? this.isProductivityEnabled,
    );
  }

  /// Returns true if at least one module is active
  bool get hasAnyEnabled => isWealthEnabled || isDiaryEnabled || isProductivityEnabled;

  /// Returns the total count of enabled modules
  int get activeModuleCount => (isWealthEnabled ? 1 : 0) + (isDiaryEnabled ? 1 : 0) + (isProductivityEnabled ? 1 : 0);
}

/// 🌟 RIVERPOD 2.x NOTIFIER FOR REAL-TIME DYNAMIC MODULE TOGGLING
class ModulePreferencesNotifier extends Notifier<ModulePreferences> {
  static const String _boxName = 'aether_settings';
  static const String _wealthKey = 'module_wealth_enabled';
  static const String _diaryKey = 'module_diary_enabled';
  static const String _productivityKey = 'module_productivity_enabled';

  @override
  ModulePreferences build() {
    return _loadInitialState();
  }

  ModulePreferences _loadInitialState() {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        final box = Hive.box(_boxName);
        return ModulePreferences(
          isWealthEnabled: box.get(_wealthKey, defaultValue: true) as bool,
          isDiaryEnabled: box.get(_diaryKey, defaultValue: true) as bool,
          isProductivityEnabled: box.get(_productivityKey, defaultValue: true) as bool,
        );
      }
    } catch (_) {
      // Fallback to all enabled defaults
    }
    return const ModulePreferences(
      isWealthEnabled: true,
      isDiaryEnabled: true,
      isProductivityEnabled: true,
    );
  }

  Future<Box> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

  Future<void> toggleWealth(bool enabled) async {
    state = state.copyWith(isWealthEnabled: enabled);
    final box = await _getBox();
    await box.put(_wealthKey, enabled);
  }

  Future<void> toggleDiary(bool enabled) async {
    state = state.copyWith(isDiaryEnabled: enabled);
    final box = await _getBox();
    await box.put(_diaryKey, enabled);
  }

  Future<void> toggleProductivity(bool enabled) async {
    state = state.copyWith(isProductivityEnabled: enabled);
    final box = await _getBox();
    await box.put(_productivityKey, enabled);
  }

  Future<void> setPreferences({
    bool? wealth,
    bool? diary,
    bool? productivity,
  }) async {
    final newState = state.copyWith(
      isWealthEnabled: wealth,
      isDiaryEnabled: diary,
      isProductivityEnabled: productivity,
    );
    state = newState;
    final box = await _getBox();
    if (wealth != null) await box.put(_wealthKey, wealth);
    if (diary != null) await box.put(_diaryKey, diary);
    if (productivity != null) await box.put(_productivityKey, productivity);
  }
}

final modulePreferencesProvider = NotifierProvider<ModulePreferencesNotifier, ModulePreferences>(() {
  return ModulePreferencesNotifier();
});
