import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'aether_goal.g.dart';

@HiveType(typeId: 4) // Ensure typeId is unique in your Hive setup
class AetherGoal extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  String category; // e.g., 'Finance', 'Personal', 'Health'

  @HiveField(4)
  double targetAmount;

  @HiveField(5)
  double currentAmount;

  @HiveField(6)
  DateTime targetDate;

  @HiveField(7)
  bool autoSyncWealth; // 🔥 Intelligent Feature: Pulls progress directly from Wallet

  @HiveField(8)
  final DateTime createdAt;

  AetherGoal({
    String? id,
    required this.title,
    this.description = '',
    this.category = 'Personal',
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.targetDate,
    this.autoSyncWealth = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
}