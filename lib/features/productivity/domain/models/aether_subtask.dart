import 'package:hive/hive.dart';

part 'aether_subtask.g.dart';

@HiveType(typeId: 2) 
class AetherSubtask extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isCompleted;

  @HiveField(3)
  DateTime? completedAt;

  // 🌟 NEW FIELD: Individual Subtask Deadline
  @HiveField(4)
  DateTime? deadline;

  AetherSubtask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.completedAt,
    this.deadline,
  });
}