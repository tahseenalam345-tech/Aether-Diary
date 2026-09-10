import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/themes/aether_colors.dart';
import '../data/wallet_providers.dart';
import '../domain/models/aether_budget.dart';
import '../domain/models/aether_account.dart';
import '../domain/models/wallet_category_system.dart';
import '../domain/utils/aether_currency.dart';
import '../data/wallet_notifications_provider.dart';
import 'widgets/wallet_notification_sheet.dart';
import 'widgets/aether_liquid_date_picker.dart';

class WalletPlanningTab extends ConsumerWidget {
  const WalletPlanningTab({super.key});

  static const Color _sky = Color(0xFF38BDF8);
  static const Color _rose = Color(0xFFFB7185);
  static const Color _mint = Color(0xFF34F5C5);
  static const Color _amber = Color(0xFFFBBF60);

  void _showAdvancedBudgetForm(BuildContext context, {AetherBudget? editBudget, bool isDuplicate = false}) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, 
      isScrollControlled: true, 
      useSafeArea: true,
      builder: (context) => _AdvancedBudgetSheet(editBudget: editBudget, isDuplicate: isDuplicate),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetNotifierProvider);
    final budgetProgress = ref.watch(budgetProgressProvider);
    ref.watch(primaryCurrencyProvider); // Rebuild on currency change

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 140)), 
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                budgetsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: _rose)),
                  error: (e, st) => Text("Error: $e", style: const TextStyle(color: Colors.red)),
                  data: (budgets) {
                    if (budgets.isEmpty) {
                      return _buildEmptyBudgetCard(context);
                    } else {
                      return _buildActiveBudgets(context, ref, budgets, budgetProgress);
                    }
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(color: _sky.withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: const Center(child: Icon(Icons.ads_click_rounded, color: _sky, size: 28)),
                          ),
                          const SizedBox(width: 20),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Goals", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                SizedBox(height: 6),
                                Text("Set your first goal and have a quick overview of your progress.", style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _sky.withValues(alpha: 0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.push('/savings'); 
                          },
                          child: const Text("Create goal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      )
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
                const SizedBox(height: 100), 
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildEmptyBudgetCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: _rose.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Center(child: Icon(Icons.pie_chart_rounded, color: _rose, size: 28))),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Let's bake your Budget!", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text("Create your first budget and stay on track with your money.", style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _rose.withValues(alpha: 0.8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => _showAdvancedBudgetForm(context),
              child: const Text("Create budget", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          )
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildActiveBudgets(BuildContext context, WidgetRef ref, List<AetherBudget> budgets, Map<String, double> budgetProgress) {
    final accounts = ref.watch(accountNotifierProvider).valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 3, height: 16, decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(2))), 
                const SizedBox(width: 8), 
                const Text("Active Budgets", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/budgets');
              },
              child: const Text("See all", style: TextStyle(color: _sky, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ).animate().fadeIn(),
        const SizedBox(height: 16),

        ...List.generate(budgets.length, (index) {
          final budget = budgets[index];
          final spent = (budgetProgress[budget.id] ?? budgetProgress[budget.category]) ?? 0.0;
          final limit = budget.limitAmount;
          final percentage = limit > 0 ? (spent / limit) : 0.0;
          
          Color statusColor; String statusText;
          if (!budget.isActive) {
            statusText = "Paused"; statusColor = Colors.white54;
          } else if (percentage > 1.0) {
            statusText = "Over Budget"; statusColor = _rose;
          } else if (percentage >= 0.7) {
            statusText = "Warning"; statusColor = _amber;
          } else {
            statusText = "On Track"; statusColor = _mint;
          }

          // 🌟 ROLLING DATE CALCULATION
          final now = DateTime.now();
          DateTime cycleStart = budget.createdAt;
          DateTime cycleEnd = cycleStart;

          if (budget.period == 'Monthly') {
            cycleStart = DateTime(now.year, now.month, 1);
            cycleEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          } else if (budget.period == 'Weekly') {
            final daysSinceStart = now.difference(budget.createdAt).inDays;
            final currentCycleIndex = daysSinceStart >= 0 ? (daysSinceStart / 7).floor() : 0;
            cycleStart = budget.createdAt.add(Duration(days: currentCycleIndex * 7));
            cycleEnd = cycleStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
          } else if (budget.period == 'Yearly') {
            cycleStart = DateTime(now.year, 1, 1);
            cycleEnd = DateTime(now.year, 12, 31, 23, 59, 59);
          } else {
             cycleStart = budget.createdAt;
             cycleEnd = budget.createdAt.add(const Duration(days: 30));
          }

          String periodText = "${DateFormat('MMM d').format(cycleStart)} - ${DateFormat('MMM d').format(cycleEnd)}";
          final displayName = budget.category == 'Global' ? 'Overall Budget' : '${budget.category} Budget';
          final displayBudgetName = (budget.name != null && budget.name!.isNotEmpty) ? budget.name! : displayName;

          String? linkedAccountTitle;
          if (budget.accountId != null && budget.accountId!.isNotEmpty && budget.accountId != 'all') {
            final match = accounts.firstWhere((a) => a.id == budget.accountId, orElse: () => accounts.firstOrNull ?? accounts.first);
            linkedAccountTitle = match.title;
          }

          return Opacity(
            opacity: budget.isActive ? 1.0 : 0.5,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/budget-details', extra: budget); 
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.035), 
                  borderRadius: BorderRadius.circular(24), 
                  border: Border.all(color: budget.isActive ? Colors.white.withValues(alpha: 0.06) : Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP HEADER ROW
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayBudgetName, 
                                style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(budget.category == 'Global' ? Icons.public_rounded : Icons.category_rounded, color: statusColor, size: 13),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      budget.category, 
                                      style: const TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w600), 
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (linkedAccountTitle != null) ...[
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(color: _sky.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.account_balance_wallet_rounded, color: _sky, size: 9),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                linkedAccountTitle, 
                                                style: const TextStyle(color: _sky, fontSize: 9, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (budget.includePastTransactions) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.history_rounded, color: Colors.white38, size: 11),
                                    const SizedBox(width: 2),
                                    const Text("Past", style: TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5), 
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15), 
                                borderRadius: BorderRadius.circular(10), 
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              ), 
                              child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.w800)), 
                            ),
                            _buildBudgetMenu(context, ref, budget),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // MIDDLE AMOUNTS ROW
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded( 
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: RichText(
                              maxLines: 1,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: AetherCurrency.format(spent),
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
                                  ),
                                  TextSpan(
                                    text: " / ${AetherCurrency.format(limit)}",
                                    style: const TextStyle(color: Colors.white38, fontSize: 12.5, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${(percentage * 100).toInt()}%",
                          style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

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
                              color: statusColor,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withValues(alpha: 0.5), 
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // FOOTER ROW (Dates + Active Freeze Button)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
                          child: Text(periodText, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)), 
                        ),
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn().slideX(begin: 0.05);
        }),
      ],
    );
  }

  Widget _buildBudgetMenu(BuildContext context, WidgetRef ref, AetherBudget budget) {
    return Theme(
      data: Theme.of(context).copyWith(splashColor: Colors.transparent, highlightColor: Colors.transparent),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
        color: const Color(0xFF14121E),
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        onSelected: (value) {
          HapticFeedback.lightImpact();
          switch (value) {
            case 'edit': _showAdvancedBudgetForm(context, editBudget: budget); break;
            case 'duplicate': _showAdvancedBudgetForm(context, editBudget: budget, isDuplicate: true); break;
            case 'status':
              final now = DateTime.now();
              List<DateTime> newPauses = List.from(budget.pauseTimestamps);
              List<DateTime> newResumes = List.from(budget.resumeTimestamps);
              if (budget.isActive) { newPauses.add(now); } else { newResumes.add(now); }
              ref.read(budgetNotifierProvider.notifier).updateBudget(budget.copyWith(isActive: !budget.isActive, pauseTimestamps: newPauses, resumeTimestamps: newResumes));
              break;
            case 'past_tx':
              ref.read(budgetNotifierProvider.notifier).updateBudget(budget.copyWith(includePastTransactions: !budget.includePastTransactions));
              break;
            case 'delete':
              ref.read(budgetNotifierProvider.notifier).deleteBudget(budget.id);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Budget deleted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFF060B14), behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFFB7185))), duration: const Duration(seconds: 5),
                action: SnackBarAction(label: 'UNDO', textColor: const Color(0xFF34F5C5), onPressed: () { HapticFeedback.lightImpact(); ref.read(budgetNotifierProvider.notifier).addBudget(budget); }),
              ));
              break;
          }
        },
        itemBuilder: (context) => [
          _buildMenuItem('edit', Icons.edit_rounded, 'Edit Budget', Colors.white),
          _buildMenuItem('duplicate', Icons.copy_rounded, 'Duplicate', Colors.white),
          _buildMenuItem('past_tx', budget.includePastTransactions ? Icons.history_toggle_off_rounded : Icons.history_rounded, budget.includePastTransactions ? 'Exclude past records' : 'Include past records', Colors.white),
          _buildMenuItem('status', Icons.power_settings_new_rounded, budget.isActive ? 'Pause Budget' : 'Resume Budget', Colors.white),
          const PopupMenuDivider(height: 1),
          _buildMenuItem('delete', Icons.delete_rounded, 'Delete', const Color(0xFFFB7185)),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String text, Color color) {
    return PopupMenuItem<String>(value: value, child: Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 10), Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))]));
  }
}

class _AdvancedBudgetSheet extends ConsumerStatefulWidget { 
  final AetherBudget? editBudget;
  final bool isDuplicate;
  const _AdvancedBudgetSheet({this.editBudget, this.isDuplicate = false}); 
  @override ConsumerState<_AdvancedBudgetSheet> createState() => _AdvancedBudgetSheetState(); 
}

class _AdvancedBudgetSheetState extends ConsumerState<_AdvancedBudgetSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _period = 'Monthly'; 
  final List<String> _periods = ['Weekly', 'Monthly', 'Yearly', 'One-time', 'Custom'];
  DateTime? _customStartDate; DateTime? _customEndDate;
  Set<String> _selectedCategories = {'All Categories'}; Set<String> _selectedAccounts = {'All Accounts'};
  bool _notifyTrending = true; bool _notifyOver = true;

  @override void initState() {
    super.initState();
    if (widget.editBudget != null) {
      final b = widget.editBudget!;
      _nameController.text = widget.isDuplicate ? "${b.name ?? b.category} (Copy)" : (b.name ?? '');
      _amountController.text = b.limitAmount.toInt().toString();
      _period = b.period;
      if (b.category == 'Global') { _selectedCategories = {'All Categories'}; } else { _selectedCategories = {b.category}; }
      if (b.accountId != null && b.accountId!.isNotEmpty && b.accountId != 'all') {
        final accounts = ref.read(accountNotifierProvider).valueOrNull ?? [];
        final match = accounts.firstWhere((a) => a.id == b.accountId, orElse: () => accounts.firstOrNull ?? accounts.first);
        _selectedAccounts = {match.title};
      } else {
        _selectedAccounts = {'All Accounts'};
      }
    }
  }

  @override void dispose() { _amountController.dispose(); _nameController.dispose(); super.dispose(); }

  Future<void> _pickDateRange() async {
    HapticFeedback.selectionClick();
    final initialRange = DateTimeRange(start: _customStartDate ?? DateTime.now(), end: _customEndDate ?? DateTime.now().add(const Duration(days: 7)));
    final picked = await showAetherLiquidDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      accentColor: const Color(0xFFFBBF60),
      title: "Budget Period Range",
    );
    if (picked != null) setState(() { _customStartDate = picked.start; _customEndDate = picked.end; });
  }

  void _openCategoryMultiSelectSheet(List<AetherWalletCategory> categories) {
    HapticFeedback.lightImpact(); Set<String> tempSelection = Set.from(_selectedCategories);
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.65, minChildSize: 0.5, maxChildSize: 0.9,
          builder: (_, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), 
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), 
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF0A0714).withValues(alpha: 0.85), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))), 
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
                            onTap: () { setState(() => _selectedCategories = tempSelection); Navigator.pop(ctx); }, 
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFFBBF60).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)), child: const Text("Done", style: TextStyle(color: Color(0xFFFBBF60), fontWeight: FontWeight.bold)))
                          )
                        ]
                      )
                    ), 
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), 
                      child: GestureDetector(
                        onTap: () { HapticFeedback.selectionClick(); setSheetState(() { tempSelection.clear(); tempSelection.add('All Categories'); }); }, 
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(16), 
                          decoration: BoxDecoration(color: tempSelection.contains('All Categories') ? const Color(0xFFFBBF60).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: tempSelection.contains('All Categories') ? const Color(0xFFFBBF60) : Colors.transparent)), 
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center, 
                            children: [Icon(Icons.all_inclusive_rounded, color: tempSelection.contains('All Categories') ? const Color(0xFFFBBF60) : Colors.white54, size: 20), const SizedBox(width: 8), Text("All Categories", style: TextStyle(color: tempSelection.contains('All Categories') ? const Color(0xFFFBBF60) : Colors.white70, fontWeight: FontWeight.bold, fontSize: 16))]
                          )
                        )
                      )
                    ), 
                    Expanded(
                      child: GridView.builder(
                        controller: scrollController, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.85, crossAxisSpacing: 12, mainAxisSpacing: 12), 
                        itemCount: categories.length, 
                        itemBuilder: (context, index) { 
                          final cat = categories[index]; final isSelected = tempSelection.contains(cat.name); 
                          return GestureDetector(
                            onTap: () { HapticFeedback.selectionClick(); setSheetState(() { tempSelection.remove('All Categories'); if (isSelected) { tempSelection.remove(cat.name); if (tempSelection.isEmpty) tempSelection.add('All Categories'); } else { tempSelection.add(cat.name); } }); }, 
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200), decoration: BoxDecoration(color: isSelected ? cat.color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? cat.color : Colors.white.withValues(alpha: 0.05))), 
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center, 
                                children: [Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [cat.color.withValues(alpha: 0.3), cat.color.withValues(alpha: 0.05)])), child: Center(child: Text(cat.iconEmoji, style: const TextStyle(fontSize: 24)))), const SizedBox(height: 10), Text(cat.name, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)]
                              )
                            )
                          ); 
                        }
                      )
                    )
                  ]
                )
              )
            )
          )
        )
      )
    );
  }

  void _openAccountMultiSelectSheet(List<AetherAccount> accounts) {
    HapticFeedback.lightImpact(); Set<String> tempSelection = Set.from(_selectedAccounts);
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.65, minChildSize: 0.5, maxChildSize: 0.9,
          builder: (_, scrollController) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), 
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), 
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF0A0714).withValues(alpha: 0.85), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))), 
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
                            onTap: () { setState(() => _selectedAccounts = tempSelection); Navigator.pop(ctx); }, 
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFFBBF60).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)), child: const Text("Done", style: TextStyle(color: Color(0xFFFBBF60), fontWeight: FontWeight.bold)))
                          )
                        ]
                      )
                    ), 
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), 
                      child: ListTile(
                        onTap: () { HapticFeedback.selectionClick(); setSheetState(() { tempSelection.clear(); tempSelection.add('All Accounts'); }); }, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: tempSelection.contains('All Accounts') ? const Color(0xFFFBBF60) : Colors.transparent)), 
                        tileColor: tempSelection.contains('All Accounts') ? const Color(0xFFFBBF60).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05), 
                        leading: Icon(Icons.account_balance_wallet_rounded, color: tempSelection.contains('All Accounts') ? const Color(0xFFFBBF60) : Colors.white54), 
                        title: Text("All Accounts", style: TextStyle(color: tempSelection.contains('All Accounts') ? const Color(0xFFFBBF60) : Colors.white, fontWeight: FontWeight.bold)), 
                        trailing: tempSelection.contains('All Accounts') ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFBBF60)) : const Icon(Icons.circle_outlined, color: Colors.white24)
                      )
                    ), 
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
                        itemCount: accounts.length, 
                        itemBuilder: (context, index) { 
                          final acc = accounts[index]; final isSelected = tempSelection.contains(acc.title); Color accColor = const Color(0xFF38BDF8); if (acc.accountType == 'cash') accColor = const Color(0xFF34F5C5); else if (acc.accountType == 'crypto') accColor = const Color(0xFFFBBF60); 
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10), 
                            child: ListTile(
                              onTap: () { HapticFeedback.selectionClick(); setSheetState(() { tempSelection.remove('All Accounts'); if (isSelected) { tempSelection.remove(acc.title); if (tempSelection.isEmpty) tempSelection.add('All Accounts'); } else { tempSelection.add(acc.title); } }); }, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isSelected ? accColor.withValues(alpha: 0.5) : Colors.transparent)), 
                              tileColor: isSelected ? accColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.035), 
                              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: accColor.withValues(alpha: 0.2), shape: BoxShape.circle), child: Icon(acc.accountType == 'crypto' ? Icons.currency_bitcoin_rounded : Icons.account_balance_rounded, color: accColor, size: 18)), 
                              title: Text(acc.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text("${acc.accountType.toUpperCase()} • ${acc.currency}", style: const TextStyle(color: Colors.white54, fontSize: 11)), 
                              trailing: isSelected ? Icon(Icons.check_circle_rounded, color: accColor) : const Icon(Icons.circle_outlined, color: Colors.white24)
                            )
                          ); 
                        }
                      )
                    )
                  ]
                )
              )
            )
          )
        )
      )
    );
  }

  @override 
  Widget build(BuildContext context) {
    final categories = ref.watch(walletCategoryProvider).valueOrNull ?? [];
    final accounts = ref.watch(accountNotifierProvider).valueOrNull ?? [];
    String customDateLabel = _customStartDate != null && _customEndDate != null ? "${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d').format(_customEndDate!)}" : "Select Date Range";

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), 
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), 
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9, padding: const EdgeInsets.only(top: 24, left: 24, right: 24), 
            decoration: BoxDecoration(color: const Color(0xFF0A0714).withValues(alpha: 0.85), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))), 
            child: Column(
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    GestureDetector(onTap: () { HapticFeedback.lightImpact(); context.pop(); }, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20))),
                    Text(widget.editBudget != null ? (widget.isDuplicate ? "Duplicate Budget" : "Edit Budget") : "Create Budget", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)), 
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

                          if (widget.editBudget != null && !widget.isDuplicate) {
                            ref.read(budgetNotifierProvider.notifier).updateBudget(
                              widget.editBudget!.copyWith(
                                name: _nameController.text.trim(), 
                                category: catToSave, 
                                limitAmount: double.tryParse(_amountController.text.trim()) ?? 0.0, 
                                period: _period,
                                accountId: accountIdToSave,
                              ),
                            );
                          } else {
                            ref.read(budgetNotifierProvider.notifier).addBudget(
                              AetherBudget(
                                name: _nameController.text.trim(), 
                                category: catToSave, 
                                limitAmount: double.tryParse(_amountController.text.trim()) ?? 0.0, 
                                period: _period, 
                                includePastTransactions: widget.editBudget?.includePastTransactions ?? false, 
                                isActive: true,
                                accountId: accountIdToSave,
                              ),
                            );
                          }
                          context.pop(); 
                        } else {
                          HapticFeedback.vibrate(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter name and amount')));
                        }
                      }, 
                      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFB7185).withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Color(0xFFFB7185), size: 20))
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
                        Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))), child: TextField(controller: _nameController, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600), decoration: const InputDecoration(hintText: "Budget Name (e.g. Monthly Groceries)", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none))), 
                        const SizedBox(height: 24), const Text("Period", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 12),
                        SizedBox(
                          height: 42, 
                          child: ListView.builder(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: _periods.length, itemBuilder: (context, index) { final p = _periods[index]; final isSelected = _period == p; return Padding(padding: const EdgeInsets.only(right: 10.0), child: GestureDetector(onTap: () { HapticFeedback.selectionClick(); setState(() => _period = p); }, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 18), decoration: BoxDecoration(color: isSelected ? const Color(0xFFFB7185).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? const Color(0xFFFB7185).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06))), child: Center(child: Text(p, style: TextStyle(color: isSelected ? const Color(0xFFFB7185) : Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)))))); }),
                        ), 
                        AnimatedSize(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic, child: _period == 'Custom' ? Padding(padding: const EdgeInsets.only(top: 16), child: GestureDetector(onTap: _pickDateRange, child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFBBF60).withValues(alpha: 0.3))), child: Row(children: [const Icon(Icons.date_range_rounded, color: Color(0xFFFBBF60), size: 20), const SizedBox(width: 12), Expanded(child: Text(customDateLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), const Icon(Icons.edit_calendar_rounded, color: Colors.white38, size: 18)])))) : const SizedBox.shrink()),
                        const SizedBox(height: 32), const Text("Set Budget", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))), child: Row(children: [const Text("PKR", style: TextStyle(color: Colors.white38, fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(width: 12), Expanded(child: TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Color(0xFFFB7185), fontSize: 32, fontWeight: FontWeight.w800), decoration: const InputDecoration(hintText: "0.00", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none)))])), 
                        const SizedBox(height: 32), const Text("Define your budget", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
                        GestureDetector(onTap: () => _openCategoryMultiSelectSheet(categories), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))), child: Row(children: [const Icon(Icons.category_rounded, color: Colors.white38, size: 20), const SizedBox(width: 12), Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: Row(children: _selectedCategories.map((c) => Padding(padding: const EdgeInsets.only(right: 8.0), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)), child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))))).toList()))), const Icon(Icons.arrow_drop_down_rounded, color: Colors.white38)]))),
                        const SizedBox(height: 12),
                        GestureDetector(onTap: () => _openAccountMultiSelectSheet(accounts), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))), child: Row(children: [const Icon(Icons.account_balance_wallet_rounded, color: Colors.white38, size: 20), const SizedBox(width: 12), Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: Row(children: _selectedAccounts.map((a) => Padding(padding: const EdgeInsets.only(right: 8.0), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)), child: Text(a, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))))).toList()))), const Icon(Icons.arrow_drop_down_rounded, color: Colors.white38)]))),
                        const SizedBox(height: 32), const Text("Notifications", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.06))), child: Column(children: [SwitchListTile(title: const Text("Trending over", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)), subtitle: const Text("Notify when forecasted spend exceeds budget", style: TextStyle(color: Colors.white38, fontSize: 11)), value: _notifyTrending, activeColor: const Color(0xFFFBBF60), onChanged: (val) => setState(() => _notifyTrending = val)), Divider(color: Colors.white.withValues(alpha: 0.05), height: 1), SwitchListTile(title: const Text("Over budget", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)), subtitle: const Text("Notify when amount has exceeded budget", style: TextStyle(color: Colors.white38, fontSize: 11)), value: _notifyOver, activeColor: const Color(0xFFFB7185), onChanged: (val) => setState(() => _notifyOver = val))])),
                        const SizedBox(height: 100), 
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