import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'aether_subscription.g.dart';

@HiveType(typeId: 9)
class AetherSubscription extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String name;
  @HiveField(2) final double amount;
  @HiveField(3) final String billingCycle; // 'monthly', 'yearly', 'weekly'
  @HiveField(4) final DateTime nextDueDate;
  @HiveField(5) final String categoryId;
  @HiveField(6) final bool isAutoPay;
  @HiveField(7) final DateTime createdAt;

  AetherSubscription({
    String? id,
    required this.name,
    required this.amount,
    required this.billingCycle,
    required this.nextDueDate,
    required this.categoryId,
    this.isAutoPay = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  AetherSubscription copyWith({
    String? name,
    double? amount,
    String? billingCycle,
    DateTime? nextDueDate,
    String? categoryId,
    bool? isAutoPay,
  }) {
    return AetherSubscription(
      id: this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      billingCycle: billingCycle ?? this.billingCycle,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      categoryId: categoryId ?? this.categoryId,
      isAutoPay: isAutoPay ?? this.isAutoPay,
      createdAt: this.createdAt,
    );
  }
}