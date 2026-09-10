import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/themes/aether_colors.dart';
import '../data/wallet_providers.dart';
import '../domain/models/aether_subscription.dart';
import '../domain/utils/aether_currency.dart';
import 'widgets/aether_liquid_dropdown.dart';
import 'widgets/aether_liquid_date_picker.dart';

// 🎨 PREMIUM PALETTE 
const Color _bgTop = Color(0xFF060B14);
const Color _bgBottom = Color(0xFF0A0714);
const Color _violet = Color(0xFFA78BFA);
const Color _rose = Color(0xFFFB7185);

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  void _showAddSubscriptionSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (context) => const _AddSubscriptionSheet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(subscriptionNotifierProvider);
    ref.watch(primaryCurrencyProvider); // Rebuild on currency change

    return Scaffold(
      backgroundColor: _bgTop,
      extendBodyBehindAppBar: true,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [_violet, _rose], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: _violet.withValues(alpha: 0.45), blurRadius: 24, spreadRadius: 1, offset: const Offset(0, 10))],
        ),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () => _showAddSubscriptionSheet(context),
          backgroundColor: Colors.transparent, elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.black87, size: 30),
        ),
      ).animate().scale(delay: 400.ms, duration: 400.ms, curve: Curves.easeOutBack),
      
      body: Stack(
        children: [
          Positioned.fill(child: DecoratedBox(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, Color(0xFF0B0F1C), _bgBottom], stops: [0.0, 0.45, 1.0])))),
          Positioned(top: -120, right: -80, child: _glowOrb(320, _violet.withValues(alpha: 0.15))),
          Positioned(bottom: -100, left: -60, child: _glowOrb(260, _rose.withValues(alpha: 0.12))),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent, elevation: 0, pinned: true, toolbarHeight: 64,
                  flexibleSpace: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(color: _bgTop.withValues(alpha: 0.35)))),
                  leading: Padding(padding: const EdgeInsets.only(left: 12), child: GestureDetector(onTap: () { HapticFeedback.lightImpact(); context.pop(); }, child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.08))), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 17)))),
                  title: const Text("Recurring Bills", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  centerTitle: true,
                ),
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [Container(width: 3, height: 16, decoration: BoxDecoration(color: _violet, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 8), const Text("Upcoming Liabilities", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))]).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 20),
                        
                        subscriptionsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator(color: _violet)),
                          error: (e, st) => Text("Error: $e", style: const TextStyle(color: Colors.red)),
                          data: (subs) {
                            if (subs.isEmpty) {
                              return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 60.0), child: Column(children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), shape: BoxShape.circle), child: const Icon(Icons.autorenew_rounded, color: Colors.white24, size: 40)), const SizedBox(height: 16), Text("No recurring bills.\nTap + to track Netflix, Rent, etc.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white38, height: 1.5))]))).animate().fadeIn();
                            }

                            double totalMonthly = subs.fold(0.0, (sum, sub) => sum + (sub.billingCycle == 'monthly' ? sub.amount : sub.billingCycle == 'yearly' ? sub.amount / 12 : sub.amount * 4));

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text("Est. Monthly Burn", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w700)),
                                          Text(AetherCurrency.format(totalMonthly), style: const TextStyle(color: _rose, fontSize: 18, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                                        ],
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(),
                                const SizedBox(height: 24),

                                ...List.generate(subs.length, (index) {
                                  final sub = subs[index];
                                  final daysUntilDue = sub.nextDueDate.difference(DateTime.now()).inDays + 1;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16.0),
                                    child: Dismissible(
                                      key: Key(sub.id),
                                      direction: DismissDirection.endToStart,
                                      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24.0), decoration: BoxDecoration(color: _rose.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.delete_sweep_rounded, color: Colors.black87, size: 28)),
                                      onDismissed: (_) { HapticFeedback.mediumImpact(); ref.read(subscriptionNotifierProvider.notifier).deleteSubscription(sub.id); },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(22),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                                            child: Row(
                                              children: [
                                                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _violet.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.autorenew_rounded, color: _violet, size: 22)),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(sub.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                      const SizedBox(height: 5),
                                                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)), child: Text("${sub.billingCycle.toUpperCase()} • Due ${DateFormat('MMM d').format(sub.nextDueDate)}", style: const TextStyle(color: Colors.white38, fontSize: 10.5, fontWeight: FontWeight.w600))),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(AetherCurrency.format(sub.amount), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
                                                    const SizedBox(height: 4),
                                                    Text(daysUntilDue <= 0 ? "Due Now" : "Due in $daysUntilDue d", style: TextStyle(color: daysUntilDue <= 3 ? _rose : Colors.white24, fontSize: 11, fontWeight: daysUntilDue <= 3 ? FontWeight.w700 : FontWeight.w600)),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.1, end: 0);
                                })
                              ],
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

  Widget _glowOrb(double size, Color color) {
    return IgnorePointer(child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, Colors.transparent]))));
  }
}

class _AddSubscriptionSheet extends ConsumerStatefulWidget { const _AddSubscriptionSheet(); @override ConsumerState<_AddSubscriptionSheet> createState() => _AddSubscriptionSheetState(); }
class _AddSubscriptionSheetState extends ConsumerState<_AddSubscriptionSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _cycle = 'monthly';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final picked = await showAetherLiquidDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      accentColor: _violet,
      title: "Bill Due Date",
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), behavior: HitTestBehavior.opaque,
      child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF0A0714).withValues(alpha: 0.85), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Track Bill", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)), GestureDetector(onTap: () { HapticFeedback.lightImpact(); context.pop(); }, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20)))]), const SizedBox(height: 28),
        Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))), child: TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: _violet, fontSize: 26, fontWeight: FontWeight.w800), decoration: InputDecoration(prefixText: "${AetherCurrency.currentSymbol} ", prefixStyle: const TextStyle(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.w600), hintText: "0.00", hintStyle: const TextStyle(color: Colors.white24), border: InputBorder.none))), const SizedBox(height: 16),
        Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))), child: TextField(controller: _titleController, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600), decoration: const InputDecoration(hintText: "Service Name (e.g. Netflix, Rent)", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none))), const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          SizedBox(
            width: 140,
            child: AetherLiquidDropdown<String>(
              value: _cycle,
              items: const ['weekly', 'monthly', 'yearly'],
              accentColor: _violet,
              itemLabel: (e) => e.toUpperCase(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _cycle = v);
                }
              },
            ),
          ),
          GestureDetector(onTap: _pickDate, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(color: _violet.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: _violet.withValues(alpha: 0.3))), child: Row(children: [const Icon(Icons.calendar_today_rounded, color: _violet, size: 16), const SizedBox(width: 8), Text(DateFormat('MMM d, yyyy').format(_dueDate), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))]))),
        ]), const SizedBox(height: 36),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _violet, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), onPressed: () { if (_titleController.text.isNotEmpty && _amountController.text.isNotEmpty) { HapticFeedback.heavyImpact(); ref.read(subscriptionNotifierProvider.notifier).addSubscription(AetherSubscription(name: _titleController.text.trim(), amount: double.tryParse(_amountController.text.trim()) ?? 0.0, billingCycle: _cycle, nextDueDate: _dueDate, categoryId: 'Bills')); context.pop(); } }, child: const Text("Save Subscription", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))))
      ])))))),
    );
  }
}