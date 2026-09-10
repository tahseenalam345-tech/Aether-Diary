import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'aether_budget.g.dart';

@HiveType(typeId: 11)
class AetherBudget extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String category; 
  @HiveField(2) final double limitAmount;
  @HiveField(3) final String period; 
  @HiveField(4) final DateTime createdAt;
  @HiveField(5) final String? name; 
  @HiveField(6) final bool includePastTransactions; 
  @HiveField(7) final bool isActive; 
  @HiveField(8) final List<DateTime> pauseTimestamps; // 🌟 Paused timings tracking
  @HiveField(9) final List<DateTime> resumeTimestamps; // 🌟 Resume timings tracking
  @HiveField(10) final String? accountId; // 🌟 Account-specific linked budget (null or 'all' = Global)

  AetherBudget({
    String? id,
    required this.category,
    required this.limitAmount,
    this.period = 'monthly',
    DateTime? createdAt,
    this.name,
    this.includePastTransactions = false, 
    this.isActive = true,
    this.pauseTimestamps = const [],
    this.resumeTimestamps = const [],
    this.accountId,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  AetherBudget copyWith({
    String? id,
    String? category,
    double? limitAmount,
    String? period,
    String? name,
    bool? includePastTransactions,
    bool? isActive,
    List<DateTime>? pauseTimestamps,
    List<DateTime>? resumeTimestamps,
    String? accountId,
    DateTime? createdAt,
  }) {
    return AetherBudget(
      id: id ?? this.id,
      category: category ?? this.category,
      limitAmount: limitAmount ?? this.limitAmount,
      period: period ?? this.period,
      name: name ?? this.name,
      includePastTransactions: includePastTransactions ?? this.includePastTransactions,
      isActive: isActive ?? this.isActive,
      pauseTimestamps: pauseTimestamps ?? this.pauseTimestamps,
      resumeTimestamps: resumeTimestamps ?? this.resumeTimestamps,
      accountId: accountId ?? this.accountId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}