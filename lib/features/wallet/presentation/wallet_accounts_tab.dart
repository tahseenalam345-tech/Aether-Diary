import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/wallet_providers.dart';
import '../domain/models/aether_transaction.dart';
import '../domain/utils/aether_currency.dart';
import '../data/wallet_notifications_provider.dart';
import 'widgets/wallet_notification_sheet.dart';

import 'add_transaction_screen.dart';

class WalletAccountsTab extends ConsumerStatefulWidget {
  const WalletAccountsTab({super.key});

  @override
  ConsumerState<WalletAccountsTab> createState() => _WalletAccountsTabState();
}

class _WalletAccountsTabState extends ConsumerState<WalletAccountsTab> {
  bool _isObscured = false;
  String? _selectedWalletId;
  String _userName = "User";

  static const Color _heroA = Color(0xFF0EA5A0);
  static const Color _heroB = Color(0xFF6D28D9);
  static const Color _mint = Color(0xFF34F5C5);
  static const Color _amber = Color(0xFFFBBF60);
  static const Color _rose = Color(0xFFFB7185);
  static const Color _sky = Color(0xFF38BDF8);
  static const Color _violet = Color(0xFFA78BFA);

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    final box = await Hive.openBox('aether_settings');
    if (mounted) {
      setState(() {
        _userName = box.get('user_name', defaultValue: 'Tahseen');
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return "Today";
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) return "Yesterday";
    return DateFormat('MMMM d, yyyy').format(date);
  }

  void _togglePrivacy() {
    HapticFeedback.selectionClick();
    setState(() => _isObscured = !_isObscured);
  }

  String _maskValue(double value, {String? currencyCode}) {
    if (_isObscured) return "••••••";
    return AetherCurrency.format(value, currencyCode: currencyCode);
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionNotifierProvider);
    final accountsAsync = ref.watch(accountNotifierProvider);
    final realTimeBalances = ref.watch(accountBalancesProvider); 
    
    final accounts = accountsAsync.valueOrNull ?? [];
    final globalCashFlow = ref.watch(monthlyCashFlowProvider);
    final globalTotalBalance = ref.watch(totalBalanceProvider);
    final allTransactions = transactionsAsync.valueOrNull ?? [];
    
    double displayIncome = globalCashFlow['income'] ?? 0;
    double displayExpense = globalCashFlow['expense'] ?? 0;
    double displayBalance = globalTotalBalance;
    String displayTitle = "TOTAL NET WORTH";
    String? displayCurrency;

    List<AetherTransaction> filteredTransactions = allTransactions;

    if (_selectedWalletId != null) {
      final selectedAcc = accounts.firstWhere(
        (a) => a.id == _selectedWalletId, 
        orElse: () => accounts.first
      );
      displayBalance = realTimeBalances[selectedAcc.id] ?? 0.0;
      displayTitle = "${selectedAcc.title.toUpperCase()} BALANCE";
      displayCurrency = selectedAcc.currency;

      filteredTransactions = allTransactions.where((t) {
        return t.accountId == _selectedWalletId || t.destinationAccountId == _selectedWalletId;
      }).toList();

      displayIncome = 0; 
      displayExpense = 0;
      final now = DateTime.now();
      for (var t in filteredTransactions) {
        if (t.date.month == now.month && t.date.year == now.year) {
          if (t.accountId == _selectedWalletId) {
            if (t.type == 'income') {
              displayIncome += t.amount;
            }
            if (t.type == 'expense' || t.type == 'transfer') {
              displayExpense += t.amount; 
            }
          } else if (t.destinationAccountId == _selectedWalletId) {
            if (t.type == 'transfer') {
              displayIncome += t.amount; 
            }
          }
        }
      }
    }

    final double net = displayIncome - displayExpense;
    
    double incomeRatio;
    if (displayIncome == 0 && displayExpense == 0) {
      if (displayBalance > 0) { 
        incomeRatio = 1.0; 
      } else if (displayBalance < 0) { 
        incomeRatio = 0.0; 
      } else { 
        incomeRatio = 0.5; 
      }
    } else {
      incomeRatio = displayIncome / (displayIncome + displayExpense);
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 140)), // Clears the custom app bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(
                  displayTitle, 
                  displayBalance, 
                  net, 
                  displayIncome, 
                  displayExpense, 
                  incomeRatio, 
                  displayCurrency,
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "My Wallets", 
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 16, 
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/accounts'), 
                      child: const Text(
                        "Manage", 
                        style: TextStyle(
                          color: _sky, 
                          fontSize: 12, 
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(),
                const SizedBox(height: 12),
                SizedBox(
                  height: 94,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal, 
                    physics: const BouncingScrollPhysics(), 
                    itemCount: accounts.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildMiniWalletCard(
                          null, 
                          "All Wallets", 
                          globalTotalBalance, 
                          Icons.language_rounded, 
                          _selectedWalletId == null,
                        );
                      }
                      final acc = accounts[index - 1];
                      return _buildMiniWalletCard(
                        acc.id, 
                        acc.title, 
                        realTimeBalances[acc.id] ?? 0.0, 
                        acc.accountType == 'crypto' ? Icons.currency_bitcoin_rounded : Icons.account_balance_wallet_rounded, 
                        _selectedWalletId == acc.id, 
                        currencyCode: acc.currency,
                      );
                    },
                  ),
                ).animate().fadeIn().slideX(begin: 0.1),

                const SizedBox(height: 28),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6, 
                      child: _bentoLarge(
                        context, 
                        "Insights", 
                        Icons.insights_rounded, 
                        _sky, 
                        () => context.push('/financial-analytics'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 5, 
                      child: Column(
                        children: [
                          _bentoSmall(
                            context, 
                            "Vaults", 
                            Icons.savings_rounded, 
                            _mint, 
                            () => context.push('/goals'),
                          ), 
                          const SizedBox(height: 14), 
                          _bentoSmall(
                            context, 
                            "Bills", 
                            Icons.autorenew_rounded, 
                            _violet, 
                            () => context.push('/subscriptions'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.08, end: 0),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _bentoSmall(
                        context, 
                        "Budgets", 
                        Icons.pie_chart_rounded, 
                        _amber, 
                        () => context.push('/budgets'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _bentoSmall(
                        context, 
                        "Accounts", 
                        Icons.account_balance_wallet_rounded, 
                        Colors.white70, 
                        () => context.push('/accounts'),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.08, end: 0),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 3, 
                          height: 16, 
                          decoration: BoxDecoration(
                            color: _mint, 
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ), 
                        const SizedBox(width: 8), 
                        const Text(
                          "Ledger History", 
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 18, 
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _togglePrivacy, 
                      child: Row(
                        children: [
                          Icon(
                            _isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, 
                            color: Colors.white38, 
                            size: 15,
                          ), 
                          const SizedBox(width: 4), 
                          Text(
                            _isObscured ? "Hidden" : "Visible", 
                            style: const TextStyle(
                              color: Colors.white38, 
                              fontSize: 12, 
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 320.ms),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        transactionsAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: SizedBox(
              height: 200, 
              child: Center(
                child: CircularProgressIndicator(color: _mint),
              ),
            ),
          ),
          error: (e, st) => SliverToBoxAdapter(
            child: SizedBox(
              height: 200, 
              child: Center(
                child: Text("Error: $e", style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),
          data: (_) {
            if (filteredTransactions.isEmpty) {
              return SliverToBoxAdapter(
                child: Container(
                  height: 200, 
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20), 
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04), 
                          shape: BoxShape.circle,
                        ), 
                        child: const Icon(
                          Icons.receipt_long_rounded, 
                          color: Colors.white24, 
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Your ledger is clean.\nTap + to log your first transaction.", 
                        textAlign: TextAlign.center, 
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white38, 
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            List<Widget> sliverItems = [];
            DateTime? lastDate;

            for (int index = 0; index < filteredTransactions.length; index++) {
              final t = filteredTransactions[index];
              final isIncome = t.type == 'income';
              final isTransfer = t.type == 'transfer';
              final Color accent = isTransfer ? _sky : (isIncome ? _mint : _rose);

              if (lastDate == null || !_isSameDay(lastDate, t.date)) {
                sliverItems.add(
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10, top: 18), 
                    child: Row(
                      children: [
                        Text(
                          _getDateLabel(t.date).toUpperCase(), 
                          style: const TextStyle(
                            color: Colors.white38, 
                            fontSize: 11, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: 1.5,
                          ),
                        ), 
                        const SizedBox(width: 10), 
                        Expanded(
                          child: Container(
                            height: 1, 
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ],
                    ),
                  )
                );
                lastDate = t.date;
              }

              // ==========================================
              // 🌟 FIX: PROPERLY STRUCTURED AND BRACKETED
              // ==========================================
              sliverItems.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0, left: 20, right: 20),
                  child: Dismissible(
                    key: Key(t.id),
                    direction: DismissDirection.horizontal,
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24.0),
                      decoration: BoxDecoration(
                        color: _sky.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.black87, size: 24),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24.0),
                      decoration: BoxDecoration(
                        color: _rose.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.delete_sweep_rounded, color: Colors.black87, size: 24),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        HapticFeedback.lightImpact();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransactionScreen(editTransaction: t)));
                        return false;
                      } else {
                        HapticFeedback.mediumImpact();
                        ref.read(transactionNotifierProvider.notifier).deleteTransaction(t.id);
                        return true;
                      }
                    },
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/transaction-details', extra: t);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.035),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isTransfer ? Icons.swap_horiz_rounded : (isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                                    color: accent,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              t.title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (t.attachmentPaths != null && t.attachmentPaths!.isNotEmpty)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Icon(
                                                Icons.attach_file_rounded,
                                                color: Colors.white30,
                                                size: 13,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          t.category,
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 140),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          isTransfer ? _maskValue(t.amount, currencyCode: t.currency) : "${isIncome ? '+' : '-'}${_maskValue(t.amount, currencyCode: t.currency)}",
                                          style: TextStyle(
                                            color: isTransfer ? Colors.white70 : accent,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('h:mm a').format(t.date),
                                        style: const TextStyle(color: Colors.white24, fontSize: 10.5),
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              // ==========================================
              // 🌟 END OF LOOP FIX
              // ==========================================
            }

            sliverItems.add(const SizedBox(height: 100)); 
            return SliverList(delegate: SliverChildListDelegate(sliverItems));
          },
        ),
      ],
    );
  }

  // ───────────────────────── Components ─────────────────────────

  Widget _buildMiniWalletCard(String? id, String title, double balance, IconData icon, bool isSelected, {String? currencyCode}) {
    final color = isSelected ? _sky : Colors.white24;
    return GestureDetector(
      onTap: () { 
        HapticFeedback.selectionClick(); 
        setState(() => _selectedWalletId = id); 
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), 
        width: 140, 
        margin: const EdgeInsets.only(right: 12), 
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _sky.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03), 
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(
            color: isSelected ? _sky.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05), 
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 17), 
                const SizedBox(width: 8), 
                Expanded(
                  child: Text(
                    title, 
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54, 
                      fontSize: 12, 
                      fontWeight: FontWeight.w700,
                    ), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _maskValue(balance, currencyCode: currencyCode), 
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70, 
                    fontSize: 14, 
                    fontWeight: FontWeight.w800, 
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ), 
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(String title, double balance, double net, double income, double expense, double incomeRatio, String? currencyCode) {
    final bool isPositiveNet = net >= 0;

    // 🌟 INTELLIGENT FINANCIAL HEALTH & UTILIZATION ENGINE
    double healthRatio = 1.0;
    Color healthColor = _mint;
    String healthStatus = "Optimal Reserve";

    if (balance < 0) {
      healthRatio = 1.0;
      healthColor = _rose;
      healthStatus = "Overdrawn Balance";
    } else if (income > 0) {
      if (expense <= income) {
        double spentRatio = (expense / income).clamp(0.0, 1.0);
        healthRatio = (1.0 - spentRatio).clamp(0.05, 1.0); // Retained percentage
        healthColor = healthRatio >= 0.3 ? _mint : _amber;
        healthStatus = "${(healthRatio * 100).toInt()}% Net Income Saved";
      } else {
        healthRatio = (income / expense).clamp(0.1, 1.0);
        healthColor = _amber;
        healthStatus = "Deficit Spending This Month";
      }
    } else if (expense > 0) {
      // Spending from existing account balance
      double totalFunds = balance + expense;
      if (totalFunds > 0) {
        healthRatio = (balance / totalFunds).clamp(0.05, 1.0);
        if (healthRatio >= 0.4) {
          healthColor = _mint;
          healthStatus = "${(healthRatio * 100).toInt()}% Funds Available";
        } else if (healthRatio >= 0.15) {
          healthColor = _amber;
          healthStatus = "Funds Running Low";
        } else {
          healthColor = _rose;
          healthStatus = "Critical Balance";
        }
      } else {
        healthRatio = 0.05;
        healthColor = _rose;
        healthStatus = "Depleted";
      }
    } else {
      healthRatio = 1.0;
      healthColor = balance > 0 ? _mint : Colors.white38;
      healthStatus = "Optimal Reserve";
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity, 
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32), 
            gradient: LinearGradient(
              begin: Alignment.topLeft, 
              end: Alignment.bottomRight, 
              colors: [_heroA.withValues(alpha: 0.28), _heroB.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.03)],
            ), 
            border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1.2), 
            boxShadow: [
              BoxShadow(
                color: _heroA.withValues(alpha: 0.15), 
                blurRadius: 40, 
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Text(
                          "Hi, $_userName 👋", 
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ), 
                        const SizedBox(height: 2), 
                        StreamBuilder<DateTime>(
                          stream: Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now()), 
                          initialData: DateTime.now(), 
                          builder: (context, snapshot) { 
                            return Text(
                              DateFormat('EEEE, MMM d • h:mm a').format(snapshot.data!), 
                              style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ); 
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), 
                      decoration: BoxDecoration(
                        color: (isPositiveNet ? _mint : _rose).withValues(alpha: 0.15), 
                        borderRadius: BorderRadius.circular(20),
                      ), 
                      child: Row(
                        mainAxisSize: MainAxisSize.min, 
                        children: [
                          Icon(
                            isPositiveNet ? Icons.trending_up_rounded : Icons.trending_down_rounded, 
                            color: isPositiveNet ? _mint : _rose, 
                            size: 13,
                          ), 
                          const SizedBox(width: 4), 
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "${isPositiveNet ? '+' : ''}${_maskValue(net)}", 
                                style: TextStyle(
                                  color: isPositiveNet ? _mint : _rose, 
                                  fontSize: 11, 
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              
              Text(
                title, 
                style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _maskValue(balance, currencyCode: currencyCode), 
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 38, 
                          fontWeight: FontWeight.w300, 
                          letterSpacing: -0.5, 
                          fontFeatures: [FontFeature.tabularFigures()],
                        ), 
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _togglePrivacy, 
                    child: Container(
                      padding: const EdgeInsets.all(8), 
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06), 
                        shape: BoxShape.circle,
                      ), 
                      child: Icon(
                        _isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, 
                        color: Colors.white54, 
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 🌟 SLEEK HEALTH PROGRESS TRACK
              ClipRRect(
                borderRadius: BorderRadius.circular(8), 
                child: Container(
                  height: 7, 
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.08),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: healthRatio.clamp(0.02, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: healthColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: healthColor.withValues(alpha: 0.5),
                            blurRadius: 6,
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      healthStatus,
                      style: TextStyle(
                        color: healthColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPositiveNet ? "Net Surplus" : "Net Deficit",
                    style: TextStyle(
                      color: isPositiveNet ? _mint.withValues(alpha: 0.8) : _rose.withValues(alpha: 0.8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _statPill("Income", income, Icons.south_west_rounded, _mint),
                  ), 
                  const SizedBox(width: 12), 
                  Expanded(
                    child: _statPill("Expenses", expense, Icons.north_east_rounded, _rose),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 550.ms).slideY(begin: 0.06, end: 0);
  }

  Widget _statPill(String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), 
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04), 
        borderRadius: BorderRadius.circular(18), 
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ), 
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7), 
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16), 
              shape: BoxShape.circle,
            ), 
            child: Icon(icon, color: color, size: 14),
          ), 
          const SizedBox(width: 10), 
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(
                  label, 
                  style: const TextStyle(
                    color: Colors.white38, 
                    fontSize: 10.5, 
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ), 
                const SizedBox(height: 2), 
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _maskValue(amount), 
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 13.5, 
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ), 
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bentoLarge(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { 
        HapticFeedback.lightImpact(); 
        onTap(); 
      }, 
      child: Container(
        height: 132, 
        padding: const EdgeInsets.all(18), 
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26), 
          gradient: LinearGradient(
            begin: Alignment.topLeft, 
            end: Alignment.bottomRight, 
            colors: [color.withValues(alpha: 0.20), Colors.white.withValues(alpha: 0.03)],
          ), 
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Container(
              padding: const EdgeInsets.all(10), 
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18), 
                shape: BoxShape.circle,
              ), 
              child: Icon(icon, color: color, size: 20),
            ), 
            Row(
              crossAxisAlignment: CrossAxisAlignment.end, 
              children: List.generate(6, (i) { 
                final heights = [10.0, 18.0, 14.0, 24.0, 16.0, 20.0]; 
                return Padding(
                  padding: const EdgeInsets.only(right: 4), 
                  child: Container(
                    width: 6, 
                    height: heights[i], 
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.55 - (i * 0.04)), 
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ); 
              }),
            ), 
            Text(
              label, 
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 15, 
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bentoSmall(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { 
        HapticFeedback.lightImpact(); 
        onTap(); 
      }, 
      child: Container(
        height: 59, 
        padding: const EdgeInsets.symmetric(horizontal: 16), 
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20), 
          color: Colors.white.withValues(alpha: 0.035), 
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ), 
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8), 
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16), 
                shape: BoxShape.circle,
              ), 
              child: Icon(icon, color: color, size: 16),
            ), 
            const SizedBox(width: 12), 
            Expanded(
              child: Text(
                label, 
                style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.w700, 
                  fontSize: 13.5,
                ), 
                overflow: TextOverflow.ellipsis,
              ),
            ), 
            const Icon(
              Icons.chevron_right_rounded, 
              color: Colors.white24, 
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}