import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'aether_goal.g.dart';

@HiveType(typeId: 12)
class AetherGoal extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String title;
  @HiveField(2) final double targetAmount;
  @HiveField(3) final double savedAmount;
  @HiveField(4) final DateTime? deadline;
  @HiveField(5) final String colorHex;
  @HiveField(6) final String iconName;
  @HiveField(7) final DateTime createdAt;

  AetherGoal({
    String? id,
    required this.title,
    required this.targetAmount,
    this.savedAmount = 0.0,
    this.deadline,
    this.colorHex = "10B981", // Default to Neon Mint
    this.iconName = "savings",
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  AetherGoal copyWith({
    String? title,
    double? targetAmount,
    double? savedAmount,
    DateTime? deadline,
    String? colorHex,
    String? iconName,
  }) {
    return AetherGoal(
      id: this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      deadline: deadline ?? this.deadline,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      createdAt: this.createdAt,
    );
  }
}