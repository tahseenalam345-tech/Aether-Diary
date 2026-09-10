import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'aether_account.g.dart';

@HiveType(typeId: 10)
class AetherAccount extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String title;
  @HiveField(2) final String accountType; 
  @HiveField(3) final double initialBalance;
  @HiveField(4) final String currency; 
  @HiveField(5) final String colorHex;
  @HiveField(6) final String iconName;
  @HiveField(7) final String? institutionName;
  @HiveField(8) final String? maskedAccountNumber;
  @HiveField(9) final bool isArchived;
  @HiveField(10) final bool isHiddenFromTotal; 
  @HiveField(11) final DateTime createdAt;
  
  // NEW: Multi-Currency Engine Normalizer
  @HiveField(12) final double baseConversionRate; 

  AetherAccount({
    String? id,
    required this.title,
    required this.accountType,
    this.initialBalance = 0.0,
    this.currency = 'PKR',
    required this.colorHex,
    required this.iconName,
    this.institutionName,
    this.maskedAccountNumber,
    this.isArchived = false,
    this.isHiddenFromTotal = false,
    this.baseConversionRate = 1.0, // Defaults to 1.0 for PKR
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  AetherAccount copyWith({
    String? title,
    String? accountType,
    double? initialBalance,
    String? currency,
    String? colorHex,
    String? iconName,
    String? institutionName,
    String? maskedAccountNumber,
    bool? isArchived,
    bool? isHiddenFromTotal,
    double? baseConversionRate,
  }) {
    return AetherAccount(
      id: this.id,
      title: title ?? this.title,
      accountType: accountType ?? this.accountType,
      initialBalance: initialBalance ?? this.initialBalance,
      currency: currency ?? this.currency,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      institutionName: institutionName ?? this.institutionName,
      maskedAccountNumber: maskedAccountNumber ?? this.maskedAccountNumber,
      isArchived: isArchived ?? this.isArchived,
      isHiddenFromTotal: isHiddenFromTotal ?? this.isHiddenFromTotal,
      baseConversionRate: baseConversionRate ?? this.baseConversionRate,
      createdAt: this.createdAt,
    );
  }
}