import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/themes/aether_colors.dart';
import '../data/wallet_providers.dart';
import '../domain/models/aether_budget.dart';
import '../domain/models/aether_account.dart';
import '../domain/models/wallet_category_system.dart';
import '../domain/utils/aether_currency.dart';
import 'widgets/aether_liquid_date_picker.dart';

// 🎨 PREMIUM PALETTE 
const Color _bgTop = Color(0xFF060B14);
const Color _bgBottom = Color(0xFF0A0714);
const Color _amber = Color(0xFFFBBF60);
const Color _rose = Color(0xFFFB7185);
const Color _mint = Color(0xFF34F5C5);

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  void _showAddBudgetSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, 
      isScrollControlled: true, 
      useSafeArea: true,
      builder: (context) => const _AddBudgetSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetNotifierProvider);
    final budgetProgress = ref.watch(budgetProgressProvider);
    ref.watch(primaryCurrencyProvider); // Rebuild on currency change

    return Scaffold(
      backgroundColor: _bgTop,
      extendBodyBehindAppBar: true,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [_amber, _rose], 
            begin: Alignment.topLeft, 
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _amber.withValues(alpha: 0.45), 
              blurRadius: 24, 
              spreadRadius: 1, 
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () => _showAddBudgetSheet(context),
          backgroundColor: Colors.transparent, 
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.black87, size: 30),
        ),
      ).animate().scale(delay: 400.ms, duration: 400.ms, curve: Curves.easeOutBack),
      
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, 
                  end: Alignment.bottomCenter, 
                  colors: [_bgTop, Color(0xFF0B0F1C), _bgBottom], 
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120, 
            right: -80, 
            child: IgnorePointer(
              child: Container(
                width: 320, 
                height: 320, 
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  gradient: RadialGradient(colors: [_amber.withValues(alpha: 0.15), Colors.transparent]),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100, 
            left: -60, 
            child: IgnorePointer(
              child: Container(
                width: 260, 
                height: 260, 
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  gradient: RadialGradient(colors: [_rose.withValues(alpha: 0.12), Colors.transparent]),
                ),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent, 
                  elevation: 0, 
                  pinned: true, 
                  toolbarHeight: 64,
                  flexibleSpace: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), 
                      child: Container(color: _bgTop.withValues(alpha: 0.35)),
                    ),
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 12), 
                    child: GestureDetector(
                      onTap: () { 
                        HapticFeedback.lightImpact(); 
                        context.pop(); 
                      }, 
                      child: Container(
                        margin: const EdgeInsets.all(8), 
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06), 
                          shape: BoxShape.circle, 
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ), 
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 17),
                      ),
                    ),
                  ),
                  title: const Text(
                    "Budgets", 
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 20, 
                      fontWeight: FontWeight.w800, 
                      letterSpacing: 0.3,
                    ),
                  ),
                  centerTitle: true,
                ),
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 3, 
                              height: 16, 
                              decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(2)),
                            ), 
                            const SizedBox(width: 8), 
                            const Text(
                              "Spending Limits", 
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 18, 
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 20),
                        
                        budgetsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator(color: _amber)),
                          error: (e, st) => Text("Error: $e", style: const TextStyle(color: Colors.red)),
                          data: (budgets) {
                            if (budgets.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 60.0), 
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20), 
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.04), 
                                          shape: BoxShape.circle,
                                        ), 
                                        child: const Icon(Icons.pie_chart_rounded, color: Colors.white24, size: 40),
                                      ), 
                                      const SizedBox(height: 16), 
                                      Text(
                                        "No budgets set.\nTap + to set a spending limit.", 
                                        textAlign: TextAlign.center, 
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white38, height: 1.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn();
                            }

                            final accounts = ref.watch(accountNotifierProvider).valueOrNull ?? [];
                            return Column(
                              children: List.generate(budgets.length, (index) {
                                final budget = budgets[index];
                                final spent = budgetProgress[budget.category] ?? 0.0;
                                final limit = budget.limitAmount;
                                final percentage = (spent / limit).clamp(0.0, 1.0);
                                
                                Color progressColor = _mint;
                                if (percentage > 0.9) {
                                  progressColor = _rose;
                                } else if (percentage > 0.7) {
                                  progressColor = _amber;
                                }

                                String? linkedAccountTitle;
                                if (budget.accountId != null && budget.accountId!.isNotEmpty && budget.accountId != 'all') {
                                  final match = accounts.firstWhere((a) => a.id == budget.accountId, orElse: () => accounts.firstOrNull ?? accounts.first);
                                  linkedAccountTitle = match.title;
                                }

                                final displayName = (budget.name != null && budget.name!.isNotEmpty) ? budget.name! : budget.category;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Dismissible(
                                    key: Key(budget.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight, 
                                      padding: const EdgeInsets.only(right: 24.0), 
                                      decoration: BoxDecoration(
                                        color: _rose.withValues(alpha: 0.85), 
                                        borderRadius: BorderRadius.circular(22),
                                      ), 
                                      child: const Icon(Icons.delete_sweep_rounded, color: Colors.black87, size: 28),
                                    ),
                                    onDismissed: (_) { 
                                      HapticFeedback.mediumImpact(); 
                                      ref.read(budgetNotifierProvider.notifier).deleteBudget(budget.id); 
                                    },
                                    child: Opacity(
                                      opacity: budget.isActive ? 1.0 : 0.5,
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          context.push('/budget-details', extra: budget);
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(22),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                            child: Container(
                                              padding: const EdgeInsets.all(20),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.035), 
                                                borderRadius: BorderRadius.circular(22), 
                                                border: Border.all(color: budget.isActive ? Colors.white.withValues(alpha: 0.06) : Colors.white12),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // TOP HEADER ROW
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              displayName, 
                                                              style: const TextStyle(
                                                                color: Colors.white, 
                                                                fontSize: 16, 
                                                                fontWeight: FontWeight.w700,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Row(
                                                              children: [
                                                                Flexible(
                                                                  child: Text(
                                                                    budget.category, 
                                                                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                                if (linkedAccountTitle != null) ...[
                                                                  const SizedBox(width: 6),
                                                                  Flexible(
                                                                    child: Container(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                                      decoration: BoxDecoration(color: const Color(0xFF38BDF8).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                                                      child: Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF38BDF8), size: 10),
                                                                          const SizedBox(width: 3),
                                                                          Flexible(
                                                                            child: Text(
                                                                              linkedAccountTitle, 
                                                                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.bold),
                                                                              maxLines: 1,
                                                                              overflow: TextOverflow.ellipsis,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ]
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Flexible(
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment.centerRight,
                                                          child: Text(
                                                            "${AetherCurrency.format(spent)} / ${AetherCurrency.format(limit)}", 
                                                            style: TextStyle(
                                                              color: progressColor, 
                                                              fontSize: 13, 
                                                              fontWeight: FontWeight.w800, 
                                                              fontFeatures: const [FontFeature.tabularFigures()],
                                                            ),
                                                            maxLines: 1,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 14),

                                                  // PROGRESS BAR
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Container(
                                                      height: 7, 
                                                      width: double.infinity,
                                                      color: Colors.white.withValues(alpha: 0.06),
                                                      child: FractionallySizedBox(
                                                        alignment: Alignment.centerLeft,
                                                        widthFactor: percentage.clamp(0.0, 1.0),
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: progressColor, 
                                                            borderRadius: BorderRadius.circular(4), 
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: progressColor.withValues(alpha: 0.5), 
                                                                blurRadius: 6,
                                                              )
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),

                                                  // FOOTER ROW
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      // 🌟 ACTIVE / INACTIVE FREEZE SWITCH
                                                      GestureDetector(
                                                        onTap: () {
                                                          HapticFeedback.selectionClick();
                                                          ref.read(budgetNotifierProvider.notifier).toggleBudgetActive(budget.id);
                                                        },
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color: budget.isActive ? _mint.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(color: budget.isActive ? _mint.withValues(alpha: 0.4) : Colors.white24),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(
                                                                budget.isActive ? Icons.play_arrow_rounded : Icons.pause_rounded, 
                                                                color: budget.isActive ? _mint : Colors.white38, 
                                                                size: 12,
                                                              ),
                                                              const SizedBox(width: 3),
                                                              Text(
                                                                budget.isActive ? "ACTIVE" : "FROZEN", 
                                                                style: TextStyle(
                                                                  color: budget.isActive ? _mint : Colors.white38, 
                                                                  fontSize: 8.5, 
                                                                  fontWeight: FontWeight.w900,
                                                                  letterSpacing: 0.5,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        "${(percentage * 100).toInt()}% Used", 
                                                        style: const TextStyle(
                                                          color: Colors.white38, 
                                                          fontSize: 11, 
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(delay: Duration(milliseconds: 40 * index)).slideX(begin: 0.05, end: 0);
                          }),
                        );
                          },
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// 🌟 ADVANCED BUDGET CREATION FORM 🌟
// ====================================================================
class _AddBudgetSheet extends ConsumerStatefulWidget { 
  const _AddBudgetSheet(); 
  @override 
  ConsumerState<_AddBudgetSheet> createState() => _AddBudgetSheetState(); 
}

class _AddBudgetSheetState extends ConsumerState<_AddBudgetSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  
  String _period = 'Monthly'; 
  final List<String> _periods = ['Weekly', 'Monthly', 'Yearly', 'One-time', 'Custom'];
  
  // 🌟 NAYA: Custom Date Range State
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  Set<String> _selectedCategories = {'All Categories'};
  Set<String> _selectedAccounts = {'All Accounts'};
  
  bool _includePastTransactions = false;
  bool _notifyTrending = true;
  bool _notifyOver = true;

  @override 
  void dispose() { 
    _amountController.dispose(); 
    _nameController.dispose();
    super.dispose(); 
  }

  // 🌟 NAYA: Custom Date Picker Logic
  Future<void> _pickDateRange() async {
    HapticFeedback.selectionClick();
    final initialRange = DateTimeRange(
      start: _customStartDate ?? DateTime.now(),
      end: _customEndDate ?? DateTime.now().add(const Duration(days: 7)),
    );
    
    final picked = await showAetherLiquidDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      accentColor: _amber,
      title: "Budget Custom Period",
    );
    
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }

  // 🌟 NAYA: Premium Multi-Select for CATEGORIES (Transaction Screen Style)
  void _openCategoryMultiSelectSheet(List<AetherWalletCategory> categories) {
    HapticFeedback.lightImpact();
    Set<String> tempSelection = Set.from(_selectedCategories);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.65, minChildSize: 0.5, maxChildSize: 0.9,
            builder: (_, scrollController) => ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0714).withValues(alpha: 0.85),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
                      
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Select Categories", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                            GestureDetector(
                              onTap: () {
                                setState(() => _selectedCategories = tempSelection);
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                                decoration: BoxDecoration(color: _amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)), 
                                child: const Text("Done", style: TextStyle(color: _amber, fontWeight: FontWeight.bold))
                              )
                            ),
                          ],
                        ),
                      ),

                      // "All Categories" Big Toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setSheetState(() {
                              tempSelection.clear();
                              tempSelection.add('All Categories');
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: tempSelection.contains('All Categories') ? _amber.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: tempSelection.contains('All Categories') ? _amber : Colors.transparent),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.all_inclusive_rounded, color: tempSelection.contains('All Categories') ? _amber : Colors.white54, size: 20),
                                const SizedBox(width: 8),
                                Text("All Categories", style: TextStyle(color: tempSelection.contains('All Categories') ? _amber : Colors.white70, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.85, crossAxisSpacing: 12, mainAxisSpacing: 12),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = tempSelection.contains(cat.name);

                            return GestureDetector(
                              onTap: () { 
                                HapticFeedback.selectionClick();
                                setSheetState(() {
                                  tempSelection.remove('All Categories');
                                  if (isSelected) {
                                    tempSelection.remove(cat.name);
                                    if (tempSelection.isEmpty) tempSelection.add('All Categories');
                                  } else {
                                    tempSelection.add(cat.name);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSelected ? cat.color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isSelected ? cat.color : Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 48, height: 48,
                                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [cat.color.withValues(alpha: 0.3), cat.color.withValues(alpha: 0.05)])),
                                      child: Center(child: Text(cat.iconEmoji, style: const TextStyle(fontSize: 24))),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(cat.name, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 🌟 NAYA: Premium Multi-Select for ACCOUNTS
  void _openAccountMultiSelectSheet(List<AetherAccount> accounts) {
    HapticFeedback.lightImpact();
    Set<String> tempSelection = Set.from(_selectedAccounts);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.65, minChildSize: 0.5, maxChildSize: 0.9,
            builder: (_, scrollController) => ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0714).withValues(alpha: 0.85),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
                      
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Select Accounts", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                            GestureDetector(
                              onTap: () {
                                setState(() => _selectedAccounts = tempSelection);
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                                decoration: BoxDecoration(color: _amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)), 
                                child: const Text("Done", style: TextStyle(color: _amber, fontWeight: FontWeight.bold))
                              )
                            ),
                          ],
                        ),
                      ),

                      // "All Accounts" Toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: ListTile(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setSheetState(() {
                              tempSelection.clear();
                              tempSelection.add('All Accounts');
                            });
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: tempSelection.contains('All Accounts') ? _amber : Colors.transparent)),
                          tileColor: tempSelection.contains('All Accounts') ? _amber.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                          leading: Icon(Icons.account_balance_wallet_rounded, color: tempSelection.contains('All Accounts') ? _amber : Colors.white54),
                          title: Text("All Accounts", style: TextStyle(color: tempSelection.contains('All Accounts') ? _amber : Colors.white, fontWeight: FontWeight.bold)),
                          trailing: tempSelection.contains('All Accounts') ? const Icon(Icons.check_circle_rounded, color: _amber) : const Icon(Icons.circle_outlined, color: Colors.white24),
                        ),
                      ),

                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: accounts.length,
                          itemBuilder: (context, index) {
                            final acc = accounts[index];
                            final isSelected = tempSelection.contains(acc.title);
                            Color accColor = const Color(0xFF38BDF8); // Default Sky
                            if (acc.accountType == 'cash') accColor = const Color(0xFF34F5C5);
                            else if (acc.accountType == 'crypto') accColor = const Color(0xFFFBBF60);
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setSheetState(() {
                                    tempSelection.remove('All Accounts');
                                    if (isSelected) {
                                      tempSelection.remove(acc.title);
                                      if (tempSelection.isEmpty) tempSelection.add('All Accounts');
                                    } else {
                                      tempSelection.add(acc.title);
                                    }
                                  });
                                },
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isSelected ? accColor.withValues(alpha: 0.5) : Colors.transparent)),
                                tileColor: isSelected ? accColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.035),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: accColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                                  child: Icon(acc.accountType == 'crypto' ? Icons.currency_bitcoin_rounded : Icons.account_balance_rounded, color: accColor, size: 18),
                                ),
                                title: Text(acc.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text("${acc.accountType.toUpperCase()} • ${acc.currency}", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                trailing: isSelected ? Icon(Icons.check_circle_rounded, color: accColor) : const Icon(Icons.circle_outlined, color: Colors.white24),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override 
  Widget build(BuildContext context) {
    final categories = ref.watch(walletCategoryProvider).valueOrNull ?? [];
    final accounts = ref.watch(accountNotifierProvider).valueOrNull ?? [];
    
    // Convert Set to String for UI Display
    String displayCategories = _selectedCategories.contains('All Categories') ? 'All Categories' : _selectedCategories.join(', ');
    String displayAccounts = _selectedAccounts.contains('All Accounts') ? 'All Accounts' : _selectedAccounts.join(', ');
    
    // Check for scope overlap conflict
    final existingBudgets = ref.watch(budgetNotifierProvider).value ?? [];
    AetherBudget? duplicateConflict;
    String targetCat = _selectedCategories.contains('All Categories') ? 'Global' : _selectedCategories.first;
    String? targetAccId;
    if (!_selectedAccounts.contains('All Accounts') && _selectedAccounts.isNotEmpty) {
      final match = accounts.where((a) => a.title == _selectedAccounts.first).firstOrNull;
      targetAccId = match?.id;
    }
    for (var b in existingBudgets) {
      if (!b.isActive) continue;
      bool sameCat = (b.category == targetCat);
      bool sameAcc = (b.accountId == targetAccId) || (b.accountId == null && targetAccId == null) || (b.accountId == 'all' && targetAccId == null);
      bool samePeriod = (b.period.toLowerCase() == _period.toLowerCase());
      if (sameCat && sameAcc && samePeriod) {
        duplicateConflict = b;
        break;
      }
    }

    String customDateLabel = _customStartDate != null && _customEndDate != null 
        ? "${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d').format(_customEndDate!)}"
        : "Select Date Range";

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), 
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), 
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), 
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.only(top: 24, left: 24, right: 24), 
            decoration: BoxDecoration(
              color: const Color(0xFF0A0714).withValues(alpha: 0.85), 
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ), 
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40, 
                    height: 4, 
                    margin: const EdgeInsets.only(bottom: 20), 
                    decoration: BoxDecoration(
                      color: Colors.white24, 
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                
                // 🌟 HEADER: TICK AND CROSS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    GestureDetector(
                      onTap: () { 
                        HapticFeedback.lightImpact(); 
                        context.pop(); 
                      }, 
                      child: Container(
                        padding: const EdgeInsets.all(8), 
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05), 
                          shape: BoxShape.circle,
                        ), 
                        child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      ),
                    ),
                    const Text(
                      "Create Budget", 
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 20, 
                        fontWeight: FontWeight.w800,
                      ),
                    ), 
                    GestureDetector(
                      onTap: () { 
                        if (_amountController.text.isNotEmpty && _nameController.text.isNotEmpty) { 
                          HapticFeedback.heavyImpact(); 
                          String catToSave = _selectedCategories.contains('All Categories') ? 'Global' : _selectedCategories.first;

                          String? accountIdToSave;
                          if (!_selectedAccounts.contains('All Accounts') && _selectedAccounts.isNotEmpty) {
                            final match = accounts.firstWhere((a) => a.title == _selectedAccounts.first, orElse: () => accounts.firstOrNull ?? accounts.first);
                            accountIdToSave = match.id;
                          }

                          ref.read(budgetNotifierProvider.notifier).addBudget(
                            AetherBudget(
                              name: _nameController.text.trim(),
                              category: catToSave, 
                              limitAmount: double.tryParse(_amountController.text.trim()) ?? 0.0,
                              period: _period,
                              includePastTransactions: _includePastTransactions,
                              isActive: true,
                              accountId: accountIdToSave,
                            )
                          ); 
                          context.pop(); 
                        } else {
                          HapticFeedback.vibrate();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter name and amount'))
                          );
                        }
                      }, 
                      child: Container(
                        padding: const EdgeInsets.all(8), 
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: 0.15), 
                          shape: BoxShape.circle,
                        ), 
                        child: const Icon(Icons.check_rounded, color: _amber, size: 20),
                      ),
                    )
                  ]
                ), 
                const SizedBox(height: 28),
                
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🌟 DUPLICATE ACTIVE BUDGET SCOPE CONFLICT WARNING
                        if (duplicateConflict != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded, color: _amber, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Active Scope Overlap",
                                        style: TextStyle(color: _amber, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "An active budget ('${duplicateConflict.name ?? duplicateConflict.category}') already covers $targetCat • ${_selectedAccounts.first} (${_period.toUpperCase()}). Transactions in this scope will track to both budgets.",
                                        style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // NAME
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4), 
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.035), 
                            borderRadius: BorderRadius.circular(20), 
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ), 
                          child: TextField(
                            controller: _nameController, 
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 16, 
                              fontWeight: FontWeight.w600,
                            ), 
                            decoration: const InputDecoration(
                              hintText: "Budget Name (e.g. Monthly Groceries)", 
                              hintStyle: TextStyle(color: Colors.white24), 
                              border: InputBorder.none,
                            ),
                          ),
                        ), 
                        const SizedBox(height: 24),

                        // PERIOD
                        const Text(
                          "Period", 
                          style: TextStyle(
                            color: Colors.white54, 
                            fontSize: 13, 
                            fontWeight: FontWeight.w600,
                          ),
                        ), 
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 42, 
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal, 
                            physics: const BouncingScrollPhysics(), 
                            itemCount: _periods.length, 
                            itemBuilder: (context, index) { 
                              final p = _periods[index]; 
                              final isSelected = _period == p; 
                              return Padding(
                                padding: const EdgeInsets.only(right: 10.0), 
                                child: GestureDetector(
                                  onTap: () { 
                                    HapticFeedback.selectionClick(); 
                                    setState(() => _period = p); 
                                  }, 
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200), 
                                    padding: const EdgeInsets.symmetric(horizontal: 18), 
                                    decoration: BoxDecoration(
                                      color: isSelected ? _amber.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.035), 
                                      borderRadius: BorderRadius.circular(16), 
                                      border: Border.all(
                                        color: isSelected ? _amber.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06),
                                      ),
                                    ), 
                                    child: Center(
                                      child: Text(
                                        p, 
                                        style: TextStyle(
                                          color: isSelected ? _amber : Colors.white54, 
                                          fontSize: 12, 
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ); 
                            },
                          ),
                        ), 
                        
                        // 🌟 NAYA: Custom Date Range Selector (Appears only if "Custom" is selected)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: _period == 'Custom' ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: GestureDetector(
                              onTap: _pickDateRange,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), 
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05), 
                                  borderRadius: BorderRadius.circular(16), 
                                  border: Border.all(color: _amber.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.date_range_rounded, color: _amber, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        customDateLabel, 
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      )
                                    ),
                                    const Icon(Icons.edit_calendar_rounded, color: Colors.white38, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ) : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 32),

                        // SET BUDGET SECTION
                        const Text(
                          "Set Budget", 
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 16, 
                            fontWeight: FontWeight.bold,
                          ),
                        ), 
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), 
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.035), 
                            borderRadius: BorderRadius.circular(20), 
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ), 
                          child: Row(
                            children: [
                              const Text(
                                "PKR", 
                                style: TextStyle(
                                  color: Colors.white38, 
                                  fontSize: 24, 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _amountController, 
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                                  style: const TextStyle(
                                    color: _amber, 
                                    fontSize: 32, 
                                    fontWeight: FontWeight.w800,
                                  ), 
                                  decoration: const InputDecoration(
                                    hintText: "0.00", 
                                    hintStyle: TextStyle(color: Colors.white24), 
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ), 
                        const SizedBox(height: 32),
                        
                        // DEFINE YOUR BUDGET SECTION
                        const Text(
                          "Define your budget", 
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 16, 
                            fontWeight: FontWeight.bold,
                          ),
                        ), 
                        const SizedBox(height: 12),
                        
                        // Categories multi-select
                        GestureDetector(
                          onTap: () => _openCategoryMultiSelectSheet(categories),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), 
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.035), 
                              borderRadius: BorderRadius.circular(20), 
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ), 
                            child: Row(
                              children: [
                                const Icon(Icons.category_rounded, color: Colors.white38, size: 20), 
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: _selectedCategories.map((c) => Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8)
                                          ),
                                          child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                        ),
                                      )).toList(),
                                    )
                                  )
                                ),
                                const Icon(Icons.arrow_drop_down_rounded, color: Colors.white38)
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Accounts multi-select
                        GestureDetector(
                          onTap: () => _openAccountMultiSelectSheet(accounts),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), 
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.035), 
                              borderRadius: BorderRadius.circular(20), 
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ), 
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet_rounded, color: Colors.white38, size: 20), 
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: _selectedAccounts.map((a) => Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8)
                                          ),
                                          child: Text(a, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                        ),
                                      )).toList(),
                                    )
                                  )
                                ),
                                const Icon(Icons.arrow_drop_down_rounded, color: Colors.white38)
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // NOTIFICATIONS
                        const Text(
                          "Notifications", 
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 16, 
                            fontWeight: FontWeight.bold,
                          ),
                        ), 
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8), 
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.035), 
                            borderRadius: BorderRadius.circular(24), 
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ), 
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: const Text(
                                  "Trending over", 
                                  style: TextStyle(
                                    color: Colors.white, 
                                    fontSize: 14, 
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: const Text(
                                  "Notify when forecasted spend exceeds budget", 
                                  style: TextStyle(
                                    color: Colors.white38, 
                                    fontSize: 11,
                                  ),
                                ),
                                value: _notifyTrending,
                                activeColor: const Color(0xFFFBBF60),
                                onChanged: (val) => setState(() => _notifyTrending = val),
                              ),
                              Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                              SwitchListTile(
                                title: const Text(
                                  "Over budget", 
                                  style: TextStyle(
                                    color: Colors.white, 
                                    fontSize: 14, 
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: const Text(
                                  "Notify when amount has exceeded budget", 
                                  style: TextStyle(
                                    color: Colors.white38, 
                                    fontSize: 11,
                                  ),
                                ),
                                value: _notifyOver,
                                activeColor: const Color(0xFFFB7185),
                                onChanged: (val) => setState(() => _notifyOver = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 100), // Scrolling clearance
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}