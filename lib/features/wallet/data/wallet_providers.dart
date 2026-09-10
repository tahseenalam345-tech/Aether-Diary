import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/models/aether_transaction.dart';
import '../domain/models/aether_subscription.dart';
import '../domain/models/aether_account.dart';
import '../domain/models/aether_budget.dart';
import '../domain/models/aether_goal.dart';
import '../domain/utils/aether_budget_date_helper.dart';
import 'wallet_repository.dart';
import 'subscription_engine.dart';
import '../../../core/services/task_notification_service.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) => WalletRepository());

// ==========================================
// 1. ACCOUNT NOTIFIER
// ==========================================
final accountNotifierProvider = AsyncNotifierProvider<AccountNotifier, List<AetherAccount>>(() {
  return AccountNotifier();
});

class AccountNotifier extends AsyncNotifier<List<AetherAccount>> {
  @override
  Future<List<AetherAccount>> build() async {
    final accounts = ref.read(walletRepositoryProvider).getAllAccounts();
    final box = await Hive.openBox('aether_settings');
    final List<String> order = (box.get('account_order') as List<dynamic>?)?.cast<String>() ?? [];

    accounts.sort((a, b) {
      final indexA = order.indexOf(a.id);
      final indexB = order.indexOf(b.id);
      
      if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      
      return a.createdAt.compareTo(b.createdAt); 
    });
    
    return accounts;
  }

  Future<void> addAccount(AetherAccount account) async {
    await ref.read(walletRepositoryProvider).saveAccount(account);
    ref.invalidateSelf(); 
  }

  Future<void> deleteAccount(String id) async {
    await ref.read(walletRepositoryProvider).deleteAccount(id);
    ref.invalidateSelf();
  }

  Future<void> reorderAccounts(int oldIndex, int newIndex) async {
    final List<AetherAccount> accounts = List<AetherAccount>.from(state.value ?? []);
    
    if (newIndex > oldIndex) newIndex -= 1;
    final acc = accounts.removeAt(oldIndex);
    accounts.insert(newIndex, acc);

    final box = await Hive.openBox('aether_settings');
    await box.put('account_order', accounts.map((a) => a.id).toList());

    state = AsyncValue.data(accounts);
  }
}

// ==========================================
// 2. TRANSACTION NOTIFIER
// ==========================================
final transactionNotifierProvider = AsyncNotifierProvider<TransactionNotifier, List<AetherTransaction>>(() {
  return TransactionNotifier();
});

class TransactionNotifier extends AsyncNotifier<List<AetherTransaction>> {
  @override
  Future<List<AetherTransaction>> build() async => ref.read(walletRepositoryProvider).getAllTransactions();

  Future<void> addTransaction(AetherTransaction transaction) async {
    final repo = ref.read(walletRepositoryProvider);
    await repo.saveTransaction(transaction);
    final allTxs = repo.getAllTransactions();
    state = AsyncValue.data(allTxs);

    if (transaction.type == 'expense') {
      try {
        final budgets = repo.getAllBudgets();
        await GlobalNotificationEngine().checkAndAlertOverbudgets(budgets, allTxs);
      } catch (_) {}
    }
  }

  Future<void> deleteTransaction(String id) async {
    await ref.read(walletRepositoryProvider).deleteTransaction(id);
    state = AsyncValue.data(ref.read(walletRepositoryProvider).getAllTransactions());
  }
}

// ==========================================
// 3. SUBSCRIPTION NOTIFIER
// ==========================================
final subscriptionNotifierProvider = AsyncNotifierProvider<SubscriptionNotifier, List<AetherSubscription>>(() {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends AsyncNotifier<List<AetherSubscription>> {
  @override
  Future<List<AetherSubscription>> build() async {
    final repo = ref.read(walletRepositoryProvider);
    final rawSubs = repo.getAllSubscriptions();
    final now = DateTime.now();

    for (int i = 0; i < rawSubs.length; i++) {
      if (rawSubs[i].nextDueDate.isBefore(now)) {
        final rolledDate = SubscriptionEngine().rollDateForward(rawSubs[i].nextDueDate, rawSubs[i].billingCycle);
        final updatedSub = rawSubs[i].copyWith(nextDueDate: rolledDate);
        
        await repo.saveSubscription(updatedSub);
        rawSubs[i] = updatedSub;
      }
      await SubscriptionEngine().scheduleSubscriptionAlerts(rawSubs[i]);
    }

    return rawSubs;
  }

  Future<void> addSubscription(AetherSubscription sub) async {
    final repo = ref.read(walletRepositoryProvider);
    DateTime targetDate = sub.nextDueDate;
    if (targetDate.isBefore(DateTime.now())) {
      targetDate = SubscriptionEngine().rollDateForward(targetDate, sub.billingCycle);
    }
    
    final processedSub = sub.copyWith(nextDueDate: targetDate);
    await repo.saveSubscription(processedSub);
    await SubscriptionEngine().scheduleSubscriptionAlerts(processedSub);

    state = AsyncValue.data(repo.getAllSubscriptions());
  }

  Future<void> deleteSubscription(String id) async {
    final repo = ref.read(walletRepositoryProvider);
    await repo.deleteSubscription(id);
    state = AsyncValue.data(repo.getAllSubscriptions());
  }
}

// ==========================================
// 4. BUDGET NOTIFIER
// ==========================================
final budgetNotifierProvider = AsyncNotifierProvider<BudgetNotifier, List<AetherBudget>>(() {
  return BudgetNotifier();
});

class BudgetNotifier extends AsyncNotifier<List<AetherBudget>> {
  @override
  Future<List<AetherBudget>> build() async => ref.read(walletRepositoryProvider).getAllBudgets();

  Future<void> addBudget(AetherBudget budget) async {
    await ref.read(walletRepositoryProvider).saveBudget(budget);
    state = AsyncValue.data(ref.read(walletRepositoryProvider).getAllBudgets());
  }
  
  Future<void> updateBudget(AetherBudget budget) async {
    await ref.read(walletRepositoryProvider).saveBudget(budget);
    state = AsyncValue.data(ref.read(walletRepositoryProvider).getAllBudgets());
  }

  Future<void> toggleBudgetActive(String id) async {
    final repo = ref.read(walletRepositoryProvider);
    final budgets = repo.getAllBudgets();
    final index = budgets.indexWhere((b) => b.id == id);
    if (index != -1) {
      final b = budgets[index];
      final newActive = !(b.isActive ?? true);
      List<DateTime> updatedPauses = List.from(b.pauseTimestamps ?? []);
      List<DateTime> updatedResumes = List.from(b.resumeTimestamps ?? []);
      final now = DateTime.now();
      if (!newActive) {
        updatedPauses.add(now);
      } else {
        updatedResumes.add(now);
      }
      final updatedBudget = b.copyWith(
        isActive: newActive,
        pauseTimestamps: updatedPauses,
        resumeTimestamps: updatedResumes,
      );
      await repo.saveBudget(updatedBudget);
      state = AsyncValue.data(repo.getAllBudgets());
    }
  }
  
  Future<void> deleteBudget(String id) async {
    await ref.read(walletRepositoryProvider).deleteBudget(id);
    state = AsyncValue.data(ref.read(walletRepositoryProvider).getAllBudgets());
  }
}

// ==========================================
// 5. GOAL NOTIFIER
// ==========================================
final goalNotifierProvider = AsyncNotifierProvider<GoalNotifier, List<AetherGoal>>(() {
  return GoalNotifier();
});

class GoalNotifier extends AsyncNotifier<List<AetherGoal>> {
  @override
  Future<List<AetherGoal>> build() async => ref.read(walletRepositoryProvider).getAllGoals();

  Future<void> addGoal(AetherGoal goal) async {
    await ref.read(walletRepositoryProvider).saveGoal(goal);
    state = AsyncValue.data(ref.read(walletRepositoryProvider).getAllGoals());
  }
  
  Future<void> updateGoalProgress(AetherGoal goal, double addedAmount) async {
    final updatedGoal = goal.copyWith(savedAmount: goal.savedAmount + addedAmount);
    await ref.read(walletRepositoryProvider).saveGoal(updatedGoal);
    state = AsyncValue.data(ref.read(walletRepositoryProvider).getAllGoals());
  }

  Future<void> deleteGoal(String id) async {
    await ref.read(walletRepositoryProvider).deleteGoal(id);
    state = AsyncValue.data(ref.read(walletRepositoryProvider).getAllGoals());
  }
}

// ============================================================================
// --- THE REAL-TIME MULTI-CURRENCY ENGINE (ISOLATE OPTIMIZED) ---
// ============================================================================

class _TxDto {
  final String accountId;
  final double amount;
  final String type;
  final String? destId;
  final DateTime date;
  final double exchangeRate;
  final String category;
  final String? subcategory;
  final String title;
  _TxDto(this.accountId, this.amount, this.type, this.destId, this.date, this.exchangeRate, this.category, this.subcategory, this.title);
}

class _AccDto {
  final String id;
  final double initialBalance;
  final double rate;
  final bool hidden;
  final bool archived;
  _AccDto(this.id, this.initialBalance, this.rate, this.hidden, this.archived);
}

class _BudgetDto {
  final String id;
  final String category;
  final DateTime createdAt;
  final bool includePastTransactions;
  final bool isActive;
  final String period;
  final List<DateTime> pauseTimestamps;
  final List<DateTime> resumeTimestamps;
  final String? accountId;
  _BudgetDto(this.id, this.category, this.createdAt, this.includePastTransactions, this.isActive, this.period, this.pauseTimestamps, this.resumeTimestamps, this.accountId);
}

class _AnalyticsPayload {
  final List<_TxDto> txs;
  final List<_AccDto> accs;
  final List<_BudgetDto> budgets;
  final DateTime now;
  _AnalyticsPayload(this.txs, this.accs, this.budgets, this.now);
}

class WalletAnalyticsState {
  final Map<String, double> accountBalances;
  final double netWorth;
  final Map<String, double> monthlyCashFlow;
  final Map<String, double> budgetProgress; 
  final List<Map<String, dynamic>> recentMerchants;

  WalletAnalyticsState(this.accountBalances, this.netWorth, this.monthlyCashFlow, this.budgetProgress, this.recentMerchants);
}

WalletAnalyticsState _computeAnalyticsInIsolate(_AnalyticsPayload payload) {
  final txs = payload.txs;
  final accs = payload.accs;
  final budgets = payload.budgets;
  final now = payload.now;

  Map<String, double> balances = { for (var a in accs) a.id : a.initialBalance };
  Map<String, double> currentAccountRates = { for (var a in accs) a.id : a.rate };

  double income = 0;
  double expense = 0;
  
  Map<String, double> budgetSpent = {};
  for (var b in budgets) {
    budgetSpent[b.id] = 0.0;
  }
  
  List<_TxDto> recentExpenses = [];

  for (var t in txs) {
    if (t.type == 'income' && balances.containsKey(t.accountId)) {
      balances[t.accountId] = balances[t.accountId]! + t.amount;
    } else if (t.type == 'expense' && balances.containsKey(t.accountId)) {
      balances[t.accountId] = balances[t.accountId]! - t.amount;
      recentExpenses.add(t);
    } else if (t.type == 'transfer') {
      if (balances.containsKey(t.accountId)) balances[t.accountId] = balances[t.accountId]! - t.amount;
      
      final dest = t.destId;
      if (dest != null && balances.containsKey(dest)) {
        double srcRate = t.exchangeRate; 
        double dstRate = currentAccountRates[dest] ?? 1.0; 
        
        double baseValue = t.amount * srcRate;
        double destAmount = baseValue / dstRate;
        
        balances[dest] = balances[dest]! + destAmount;
      }
    }

    double convertedBaseAmount = t.amount * t.exchangeRate; 
    
    // CASH FLOW Calculation (Current Month only)
    if (t.date.month == now.month && t.date.year == now.year) {
      if (t.type == 'income') income += convertedBaseAmount;
      if (t.type == 'expense') expense += convertedBaseAmount;
    }

    // 🌟 BUDGET Calculation (Rolling Cycle Aware + NULL SAFE + Account Linked + Freeze Aware)
    if (t.type == 'expense') {
      for (var b in budgets) {
        if (!b.isActive) continue; // 🌟 Freeze completely when inactive
        
        // 🌟 Account-specific linked budget check
        if (b.accountId != null && b.accountId!.isNotEmpty && b.accountId != 'all' && b.accountId != t.accountId) {
          continue; // ONLY consider transactions belonging to the linked account
        }

        bool matchesCategory = (b.category == 'Global') || (b.category == t.category);
        if (!matchesCategory) continue;

        final (cycleStart, cycleEnd, _, _, _, _) = AetherBudgetDateHelper.getPeriodRangeFromDetails(
          createdAt: b.createdAt,
          period: b.period,
          referenceNow: now,
        );
        bool inPeriod = !t.date.isBefore(cycleStart) && !t.date.isAfter(cycleEnd);

        if (inPeriod) {
          bool isPausedDuringTx = false;
          // 🌟 NULL SAFETY APPLIED TO LISTS TO PREVENT CRASHES 🌟
          for (int i = 0; i < b.pauseTimestamps.length; i++) {
            DateTime pStart = b.pauseTimestamps[i];
            DateTime? pEnd = (i < b.resumeTimestamps.length) ? b.resumeTimestamps[i] : null;
            if (t.date.isAfter(pStart) && (pEnd == null || t.date.isBefore(pEnd))) {
              isPausedDuringTx = true;
              break;
            }
          }

          if (isPausedDuringTx) continue; 

          if (b.includePastTransactions || !t.date.isBefore(b.createdAt)) {
            budgetSpent[b.id] = (budgetSpent[b.id] ?? 0.0) + convertedBaseAmount;
          }
        }
      }
    }
  }

  double netWorth = 0.0;
  for (var acc in accs) {
    if (!acc.hidden && !acc.archived) {
      netWorth += (balances[acc.id] ?? 0.0) * acc.rate;
    }
  }

  recentExpenses.sort((a, b) => b.date.compareTo(a.date));
  final List<Map<String, dynamic>> uniqueMerchants = [];
  final Set<String> seenTitles = {};
  for (var t in recentExpenses) {
    final title = t.title.trim();
    if (title.isNotEmpty && title != 'Transfer') {
      final lower = title.toLowerCase();
      if (!seenTitles.contains(lower)) {
        seenTitles.add(lower);
        uniqueMerchants.add({'title': title, 'category': t.category, 'subcategory': t.subcategory});
      }
    }
    if (uniqueMerchants.length >= 10) break;
  }

  return WalletAnalyticsState(balances, netWorth, {'income': income, 'expense': expense}, budgetSpent, uniqueMerchants);
}

final asyncAnalyticsEngineProvider = FutureProvider<WalletAnalyticsState>((ref) async {
  final txs = ref.watch(transactionNotifierProvider).valueOrNull ?? [];
  final accs = ref.watch(accountNotifierProvider).valueOrNull ?? [];
  final budgets = ref.watch(budgetNotifierProvider).valueOrNull ?? [];
  
  final dtosTxs = txs.map((t) => _TxDto(t.accountId, t.amount, t.type, t.destinationAccountId, t.date, t.exchangeRate, t.category, t.subcategory, t.title)).toList();
  final dtosAccs = accs.map((a) => _AccDto(a.id, a.initialBalance, a.baseConversionRate, a.isHiddenFromTotal, a.isArchived)).toList();
  
  // 🌟 NULL SAFETY IN MAPPING PREVENTS ISOLATE CRASHES FOR OLD DATA 🌟
  final dtosBudgets = budgets.map((b) => _BudgetDto(
    b.id, 
    b.category, 
    b.createdAt, 
    b.includePastTransactions ?? false, 
    b.isActive ?? true, 
    b.period ?? 'monthly', 
    b.pauseTimestamps ?? [], 
    b.resumeTimestamps ?? [],
    b.accountId,
  )).toList();
  
  return await Isolate.run(() => _computeAnalyticsInIsolate(_AnalyticsPayload(dtosTxs, dtosAccs, dtosBudgets, DateTime.now())));
});

final accountBalancesProvider = Provider<Map<String, double>>((ref) {
  return ref.watch(asyncAnalyticsEngineProvider).valueOrNull?.accountBalances ?? {};
});

final totalBalanceProvider = Provider<double>((ref) {
  return ref.watch(asyncAnalyticsEngineProvider).valueOrNull?.netWorth ?? 0.0;
});

final monthlyCashFlowProvider = Provider<Map<String, double>>((ref) {
  return ref.watch(asyncAnalyticsEngineProvider).valueOrNull?.monthlyCashFlow ?? {'income': 0, 'expense': 0};
});

final budgetProgressProvider = Provider<Map<String, double>>((ref) {
  return ref.watch(asyncAnalyticsEngineProvider).valueOrNull?.budgetProgress ?? {};
});

final recentMerchantsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(asyncAnalyticsEngineProvider).valueOrNull?.recentMerchants ?? [];
});