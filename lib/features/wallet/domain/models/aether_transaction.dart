import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'aether_transaction.g.dart';

@HiveType(typeId: 8)
class AetherTransaction extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String title;
  @HiveField(2) final String? description;
  @HiveField(3) final double amount;
  
  @HiveField(4) final String currency; 
  @HiveField(5) final double exchangeRate; 
  
  @HiveField(6) final String type; 
  @HiveField(7) final String category; 
  @HiveField(8) final String? subcategory;
  
  @HiveField(9) final String accountId; 
  @HiveField(10) final String? destinationAccountId; 
  
  @HiveField(11) final List<String>? tags;
  @HiveField(12) final List<String>? labels;
  @HiveField(13) final String? notes;
  
  // FIXED: Bulletproof Primitive Storage (No more cross-module crashing)
  @HiveField(14) final List<String>? attachmentPaths; 
  
  @HiveField(15) final String? merchant;
  @HiveField(16) final String? geoLocation;
  @HiveField(17) final String? mood; 
  
  @HiveField(18) final DateTime date;
  @HiveField(19) final DateTime? reminderDate;
  @HiveField(20) final DateTime? dueDate;
  @HiveField(21) final String transactionStatus; 
  @HiveField(22) final String paymentMethod; 
  @HiveField(23) final String? recurringRule; 
  @HiveField(24) final String? installmentPlanId;
  
  @HiveField(25) final DateTime createdAt;
  @HiveField(26) final DateTime updatedAt;

  AetherTransaction({
    String? id,
    required this.title,
    this.description,
    required this.amount,
    this.currency = 'PKR',
    this.exchangeRate = 1.0,
    required this.type,
    required this.category,
    this.subcategory,
    required this.accountId,
    this.destinationAccountId,
    this.tags,
    this.labels,
    this.notes,
    this.attachmentPaths, // Updated Field
    this.merchant,
    this.geoLocation,
    this.mood,
    DateTime? date,
    this.reminderDate,
    this.dueDate,
    this.transactionStatus = 'completed',
    this.paymentMethod = 'unspecified',
    this.recurringRule,
    this.installmentPlanId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  AetherTransaction copyWith({
    String? transactionStatus,
    DateTime? updatedAt,
  }) {
    return AetherTransaction(
      id: this.id,
      title: title,
      amount: amount,
      currency: currency,
      exchangeRate: exchangeRate,
      type: type,
      category: category,
      accountId: accountId,
      destinationAccountId: destinationAccountId,
      transactionStatus: transactionStatus ?? this.transactionStatus,
      date: date,
      createdAt: createdAt,
      attachmentPaths: attachmentPaths,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}