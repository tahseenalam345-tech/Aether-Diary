import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../domain/models/aether_transaction.dart';
import '../domain/models/aether_subscription.dart';
import '../domain/models/aether_account.dart';
import '../domain/models/aether_budget.dart';
import '../domain/models/aether_goal.dart';

class WalletRepository {
  static final WalletRepository _instance = WalletRepository._internal();
  factory WalletRepository() => _instance;
  WalletRepository._internal();

  late Box<AetherTransaction> _transactionBox;
  late Box<AetherSubscription> _subscriptionBox;
  late Box<AetherAccount> _accountBox;
  late Box<AetherBudget> _budgetBox;
  late Box<AetherGoal> _goalBox;

  Future<Box<T>> _safeOpenBox<T>(String boxName) async {
    try {
      return await Hive.openBox<T>(boxName);
    } catch (e) {
      debugPrint('Hive Schema Conflict detected on $boxName. Wiping corrupted legacy box...');
      await Hive.deleteBoxFromDisk(boxName);
      return await Hive.openBox<T>(boxName);
    }
  }

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(AetherTransactionAdapter());
    if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(AetherSubscriptionAdapter());
    if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(AetherAccountAdapter());
    if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(AetherBudgetAdapter());
    if (!Hive.isAdapterRegistered(12)) Hive.registerAdapter(AetherGoalAdapter());

    // OPTIMIZED: Open all 5 finance boxes concurrently
    final boxes = await Future.wait([
      _safeOpenBox<AetherTransaction>('aether_transactions'),
      _safeOpenBox<AetherSubscription>('aether_subscriptions'),
      _safeOpenBox<AetherAccount>('aether_accounts'),
      _safeOpenBox<AetherBudget>('aether_budgets'),
      _safeOpenBox<AetherGoal>('aether_goals'),
    ]);

    _transactionBox = boxes[0] as Box<AetherTransaction>;
    _subscriptionBox = boxes[1] as Box<AetherSubscription>;
    _accountBox = boxes[2] as Box<AetherAccount>;
    _budgetBox = boxes[3] as Box<AetherBudget>;
    _goalBox = boxes[4] as Box<AetherGoal>;
  }

  List<AetherAccount> getAllAccounts() {
    final accounts = _accountBox.values.toList();
    accounts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return accounts;
  }
  Future<void> saveAccount(AetherAccount account) async => await _accountBox.put(account.id, account);
  Future<void> deleteAccount(String id) async => await _accountBox.delete(id);

  List<AetherTransaction> getAllTransactions() {
    final transactions = _transactionBox.values.toList();
    transactions.sort((a, b) => b.date.compareTo(a.date)); 
    return transactions;
  }
  
  Future<void> saveTransaction(AetherTransaction transaction) async => await _transactionBox.put(transaction.id, transaction);
  
  Future<void> deleteTransaction(String id) async {
    final transaction = _transactionBox.get(id);
    
    if (transaction != null && transaction.attachmentPaths != null) {
      for (var path in transaction.attachmentPaths!) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Failed to delete orphaned attachment: $e');
        }
      }
    }

    await _transactionBox.delete(id);
  }

  List<AetherSubscription> getAllSubscriptions() {
    final subs = _subscriptionBox.values.toList();
    subs.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate)); 
    return subs;
  }
  Future<void> saveSubscription(AetherSubscription sub) async => await _subscriptionBox.put(sub.id, sub);
  Future<void> deleteSubscription(String id) async => await _subscriptionBox.delete(id);

  List<AetherBudget> getAllBudgets() => _budgetBox.values.toList();
  Future<void> saveBudget(AetherBudget budget) async => await _budgetBox.put(budget.id, budget);
  Future<void> deleteBudget(String id) async => await _budgetBox.delete(id);

  List<AetherGoal> getAllGoals() {
    final goals = _goalBox.values.toList();
    goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return goals;
  }
  Future<void> saveGoal(AetherGoal goal) async => await _goalBox.put(goal.id, goal);
  Future<void> deleteGoal(String id) async => await _goalBox.delete(id);
}