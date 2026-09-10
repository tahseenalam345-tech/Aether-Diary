import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/utils/aether_currency.dart';
import 'wallet_providers.dart';

enum WalletNotifCategory { account, budget }

class WalletNotificationItem {
  final String id;
  final WalletNotifCategory category;
  final String title;
  final String message;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  final bool isRead;

  const WalletNotificationItem({
    required this.id,
    required this.category,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.icon,
    required this.color,
    this.isRead = false,
  });

  WalletNotificationItem copyWith({bool? isRead}) {
    return WalletNotificationItem(
      id: id,
      category: category,
      title: title,
      message: message,
      timestamp: timestamp,
      icon: icon,
      color: color,
      isRead: isRead ?? this.isRead,
    );
  }
}

// 🌟 PERSISTENT READ NOTIFICATION IDS
final readWalletNotifIdsProvider = StateNotifierProvider<ReadWalletNotifNotifier, Set<String>>((ref) {
  return ReadWalletNotifNotifier();
});

class ReadWalletNotifNotifier extends StateNotifier<Set<String>> {
  ReadWalletNotifNotifier() : super({}) {
    _loadFromHive();
  }

  Future<void> _loadFromHive() async {
    try {
      final box = await Hive.openBox('aether_settings');
      final list = box.get('read_wallet_notifs', defaultValue: <String>[]) as List;
      state = list.map((e) => e.toString()).toSet();
    } catch (_) {}
  }

  Future<void> markAsRead(String id) async {
    if (state.contains(id)) return;
    final updated = Set<String>.from(state)..add(id);
    state = updated;
    try {
      final box = await Hive.openBox('aether_settings');
      await box.put('read_wallet_notifs', updated.toList());
    } catch (_) {}
  }

  Future<void> markAllAsRead(List<String> ids) async {
    final updated = Set<String>.from(state)..addAll(ids);
    state = updated;
    try {
      final box = await Hive.openBox('aether_settings');
      await box.put('read_wallet_notifs', updated.toList());
    } catch (_) {}
  }

  Future<void> clearAll() async {
    state = {};
    try {
      final box = await Hive.openBox('aether_settings');
      await box.put('read_wallet_notifs', <String>[]);
    } catch (_) {}
  }
}

// 🌟 1. ACCOUNTS NOTIFICATIONS PROVIDER
final accountNotificationsProvider = Provider<List<WalletNotificationItem>>((ref) {
  final accounts = ref.watch(accountNotifierProvider).valueOrNull ?? [];
  final balances = ref.watch(accountBalancesProvider);
  final txs = ref.watch(transactionNotifierProvider).valueOrNull ?? [];
  final cashFlow = ref.watch(monthlyCashFlowProvider);
  final readIds = ref.watch(readWalletNotifIdsProvider);
  final primaryCurr = ref.watch(primaryCurrencyProvider);

  final List<WalletNotificationItem> list = [];
  final now = DateTime.now();

  // 1. Low balance / Negative balance checks
  for (var acc in accounts) {
    if (acc.isArchived || acc.isHiddenFromTotal) continue;
    final bal = balances[acc.id] ?? acc.initialBalance;

    if (bal < 0) {
      final notifId = 'acc_neg_${acc.id}_${now.year}_${now.month}_${now.day}';
      list.add(WalletNotificationItem(
        id: notifId,
        category: WalletNotifCategory.account,
        title: "🚨 Overdrawn Account: ${acc.title}",
        message: "Your ${acc.title} balance is negative (${AetherCurrency.format(bal, currencyCode: acc.currency)}). Deposit funds immediately.",
        timestamp: now.subtract(const Duration(minutes: 5)),
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFFB7185),
        isRead: readIds.contains(notifId),
      ));
    } else if (bal > 0 && bal <= 5000) {
      final notifId = 'acc_low_${acc.id}_${now.year}_${now.month}_${now.day}';
      list.add(WalletNotificationItem(
        id: notifId,
        category: WalletNotifCategory.account,
        title: "⚠️ Low Balance: ${acc.title}",
        message: "Only ${AetherCurrency.format(bal, currencyCode: acc.currency)} remaining in ${acc.title}. Consider replenishing soon.",
        timestamp: now.subtract(const Duration(minutes: 30)),
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFBBF24),
        isRead: readIds.contains(notifId),
      ));
    }
  }

  // 2. Large single expense detection (>30% of account balance)
  for (var t in txs.take(15)) {
    if (t.type != 'expense') continue;
    final acc = accounts.firstWhere((a) => a.id == t.accountId, orElse: () => accounts.firstOrNull ?? accounts.first);
    final bal = balances[t.accountId] ?? 0.0;
    if (bal > 0 && t.amount >= (bal * 0.35)) {
      final notifId = 'acc_large_tx_${t.id}';
      list.add(WalletNotificationItem(
        id: notifId,
        category: WalletNotifCategory.account,
        title: "💸 High Value Expense",
        message: "A large expense of ${AetherCurrency.format(t.amount, currencyCode: t.currency)} (${t.category}) was debited from ${acc.title}.",
        timestamp: t.date,
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFA78BFA),
        isRead: readIds.contains(notifId),
      ));
    }
  }

  // 3. Monthly Inflow/Outflow Health Summary
  final income = cashFlow['income'] ?? 0;
  final expense = cashFlow['expense'] ?? 0;
  if (income > 0 || expense > 0) {
    final notifId = 'acc_cashflow_${now.year}_${now.month}';
    final isPositive = income >= expense;
    list.add(WalletNotificationItem(
      id: notifId,
      category: WalletNotifCategory.account,
      title: isPositive ? "📈 Healthy Net Cash Flow" : "📉 Cash Deficit Warning",
      message: "This month: Inflow ${AetherCurrency.format(income)} vs Outflow ${AetherCurrency.format(expense)} (${isPositive ? 'Surplus' : 'Deficit'} of ${AetherCurrency.format((income - expense).abs())}).",
      timestamp: DateTime(now.year, now.month, now.day, 9, 0),
      icon: isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
      color: isPositive ? const Color(0xFF34F5C5) : const Color(0xFFFB7185),
      isRead: readIds.contains(notifId),
    ));
  }

  // Sort newest first
  list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return list;
});

// 🌟 2. BUDGETS & PLANNING NOTIFICATIONS PROVIDER
final budgetNotificationsProvider = Provider<List<WalletNotificationItem>>((ref) {
  final budgets = ref.watch(budgetNotifierProvider).valueOrNull ?? [];
  final spentMap = ref.watch(budgetProgressProvider);
  final subs = ref.watch(subscriptionNotifierProvider).valueOrNull ?? [];
  final readIds = ref.watch(readWalletNotifIdsProvider);
  final primaryCurr = ref.watch(primaryCurrencyProvider);

  final List<WalletNotificationItem> list = [];
  final now = DateTime.now();

  for (var b in budgets) {
    if (!b.isActive) continue; // Skip inactive frozen budgets
    final spent = spentMap[b.id] ?? 0.0;
    final limit = b.limitAmount;
    final budgetName = (b.name != null && b.name!.trim().isNotEmpty) ? b.name! : b.category;

    if (limit > 0) {
      if (spent > limit) {
        final notifId = 'bgt_over_${b.id}_${now.year}_${now.month}_${now.day}';
        list.add(WalletNotificationItem(
          id: notifId,
          category: WalletNotifCategory.budget,
          title: "🚨 Overbudget Alert: $budgetName",
          message: "You have exceeded your $budgetName budget limit by ${AetherCurrency.format(spent - limit)}! Total spent: ${AetherCurrency.format(spent)} of ${AetherCurrency.format(limit)}.",
          timestamp: now.subtract(const Duration(minutes: 10)),
          icon: Icons.warning_rounded,
          color: const Color(0xFFFB7185),
          isRead: readIds.contains(notifId),
        ));
      } else if (spent >= limit * 0.8) {
        final notifId = 'bgt_warn80_${b.id}_${now.year}_${now.month}_${now.day}';
        list.add(WalletNotificationItem(
          id: notifId,
          category: WalletNotifCategory.budget,
          title: "⚠️ 80% Limit Reached: $budgetName",
          message: "You've used ${(spent / limit * 100).toStringAsFixed(0)}% of your $budgetName budget. Only ${AetherCurrency.format(limit - spent)} remains.",
          timestamp: now.subtract(const Duration(hours: 2)),
          icon: Icons.speed_rounded,
          color: const Color(0xFFFBBF24),
          isRead: readIds.contains(notifId),
        ));
      }
    }
  }

  // Subscriptions due soon (< 3 days)
  for (var s in subs) {
    final diffDays = s.nextDueDate.difference(now).inDays;
    if (diffDays >= 0 && diffDays <= 3) {
      final notifId = 'sub_due_${s.id}_${s.nextDueDate.year}_${s.nextDueDate.month}_${s.nextDueDate.day}';
      list.add(WalletNotificationItem(
        id: notifId,
        category: WalletNotifCategory.budget,
        title: "📅 Upcoming Bill: ${s.name}",
        message: "Your recurring payment of ${AetherCurrency.format(s.amount)} is due ${diffDays == 0 ? 'today' : 'in $diffDays day(s)'} (${s.billingCycle}).",
        timestamp: now.subtract(const Duration(hours: 1)),
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF38BDF8),
        isRead: readIds.contains(notifId),
      ));
    }
  }

  // Sort newest first
  list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return list;
});

// 🌟 UNREAD COUNTERS
final unreadAccountAlertsCountProvider = Provider<int>((ref) {
  final list = ref.watch(accountNotificationsProvider);
  return list.where((n) => !n.isRead).length;
});

final unreadBudgetAlertsCountProvider = Provider<int>((ref) {
  final list = ref.watch(budgetNotificationsProvider);
  return list.where((n) => !n.isRead).length;
});
