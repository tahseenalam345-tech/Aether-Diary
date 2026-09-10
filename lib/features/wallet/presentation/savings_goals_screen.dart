import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/themes/aether_colors.dart';
import '../../../core/themes/widgets/aether_ambient_background.dart';
import '../data/wallet_providers.dart';
import '../domain/models/aether_goal.dart';
import '../domain/utils/aether_currency.dart';

// 🎨 PREMIUM PALETTE 
const Color _bgTop = Color(0xFF060B14);
const Color _bgBottom = Color(0xFF0A0714);
const Color _mint = Color(0xFF34F5C5);
const Color _sky = Color(0xFF38BDF8);

class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  void _showAddGoalSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (context) => const _AddGoalSheet());
  }

  void _showDepositSheet(BuildContext context, AetherGoal goal) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (context) => _DepositGoalSheet(goal: goal));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalNotifierProvider);
    ref.watch(primaryCurrencyProvider); // Rebuild on currency change

    return Scaffold(
      backgroundColor: _bgTop,
      extendBodyBehindAppBar: true,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [_mint, _sky], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: _mint.withValues(alpha: 0.45), blurRadius: 24, spreadRadius: 1, offset: const Offset(0, 10))],
        ),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () => _showAddGoalSheet(context),
          backgroundColor: Colors.transparent, elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.black87, size: 30),
        ),
      ).animate().scale(delay: 400.ms, duration: 400.ms, curve: Curves.easeOutBack),
      
      body: Stack(
        children: [
          Positioned.fill(child: DecoratedBox(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, Color(0xFF0B0F1C), _bgBottom], stops: [0.0, 0.45, 1.0])))),
          Positioned(top: -120, right: -80, child: _glowOrb(320, _mint.withValues(alpha: 0.15))),
          Positioned(bottom: -100, left: -60, child: _glowOrb(260, _sky.withValues(alpha: 0.12))),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent, elevation: 0, pinned: true, toolbarHeight: 64,
                  flexibleSpace: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(color: _bgTop.withValues(alpha: 0.35)))),
                  leading: Padding(padding: const EdgeInsets.only(left: 12), child: GestureDetector(onTap: () { HapticFeedback.lightImpact(); context.pop(); }, child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.08))), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 17)))),
                  title: const Text("Savings Vaults", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  centerTitle: true,
                ),
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [Container(width: 3, height: 16, decoration: BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 8), const Text("Your Targets", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))]).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 20),
                        
                        goalsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator(color: _mint)),
                          error: (e, st) => Text("Error: $e", style: const TextStyle(color: Colors.red)),
                          data: (goals) {
                            if (goals.isEmpty) {
                              return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 60.0), child: Column(children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), shape: BoxShape.circle), child: const Icon(Icons.savings_rounded, color: Colors.white24, size: 40)), const SizedBox(height: 16), Text("No goals created.\nTap + to build your wealth targets.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white38, height: 1.5))]))).animate().fadeIn();
                            }

                            return Column(
                              children: List.generate(goals.length, (index) {
                                final goal = goals[index];
                                final percentage = (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0);
                                
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Dismissible(
                                    key: Key(goal.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24.0), decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.delete_sweep_rounded, color: Colors.black87, size: 28)),
                                    onDismissed: (_) { HapticFeedback.mediumImpact(); ref.read(goalNotifierProvider.notifier).deleteGoal(goal.id); },
                                    child: GestureDetector(
                                      onTap: () => _showDepositSheet(context, goal),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(26),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                          child: Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 58, height: 58,
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      CircularProgressIndicator(value: 1.0, strokeWidth: 5, valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.05))),
                                                      CircularProgressIndicator(value: percentage, strokeWidth: 5, valueColor: const AlwaysStoppedAnimation(_mint), backgroundColor: Colors.transparent),
                                                      Center(child: Text("${(percentage * 100).toInt()}%", style: const TextStyle(color: _mint, fontSize: 13, fontWeight: FontWeight.bold))),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(goal.title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                                                      const SizedBox(height: 6),
                                                      Text("${AetherCurrency.format(goal.savedAmount)} / ${AetherCurrency.format(goal.targetAmount)}", style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                                                    ],
                                                  ),
                                                ),
                                                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _mint.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: _mint, size: 20))
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.1, end: 0);
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

  Widget _glowOrb(double size, Color color) {
    return IgnorePointer(child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, Colors.transparent]))));
  }
}

class _AddGoalSheet extends ConsumerStatefulWidget { const _AddGoalSheet(); @override ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState(); }
class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), behavior: HitTestBehavior.opaque,
      child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF0A0714).withValues(alpha: 0.85), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("New Vault", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)), GestureDetector(onTap: () { HapticFeedback.lightImpact(); context.pop(); }, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20)))]), const SizedBox(height: 28),
        Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))), child: TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: _mint, fontSize: 26, fontWeight: FontWeight.w800), decoration: InputDecoration(prefixText: "${AetherCurrency.currentSymbol} ", prefixStyle: const TextStyle(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.w600), hintText: "Target", hintStyle: const TextStyle(color: Colors.white24), border: InputBorder.none))), const SizedBox(height: 16),
        Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))), child: TextField(controller: _titleController, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600), decoration: const InputDecoration(hintText: "What are you saving for?", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none))), const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _mint, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), onPressed: () { if (_titleController.text.isNotEmpty && _amountController.text.isNotEmpty) { HapticFeedback.heavyImpact(); ref.read(goalNotifierProvider.notifier).addGoal(AetherGoal(title: _titleController.text.trim(), targetAmount: double.tryParse(_amountController.text.trim()) ?? 0.0)); context.pop(); } }, child: const Text("Create Vault", style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w800))))
      ])))))),
    );
  }
}

class _DepositGoalSheet extends ConsumerStatefulWidget { final AetherGoal goal; const _DepositGoalSheet({required this.goal}); @override ConsumerState<_DepositGoalSheet> createState() => _DepositGoalSheetState(); }
class _DepositGoalSheetState extends ConsumerState<_DepositGoalSheet> {
  final _amountController = TextEditingController();
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), behavior: HitTestBehavior.opaque,
      child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF0A0714).withValues(alpha: 0.85), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Deposit to ${widget.goal.title}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), GestureDetector(onTap: () { HapticFeedback.lightImpact(); context.pop(); }, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20)))]), const SizedBox(height: 28),
        Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))), child: TextField(controller: _amountController, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: _mint, fontSize: 32, fontWeight: FontWeight.w800), decoration: InputDecoration(prefixText: "+ ${AetherCurrency.currentSymbol} ", prefixStyle: const TextStyle(color: Colors.white38, fontSize: 24, fontWeight: FontWeight.w600), hintText: "0", hintStyle: const TextStyle(color: Colors.white24), border: InputBorder.none))), const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 54, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _mint, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), onPressed: () { if (_amountController.text.isNotEmpty) { HapticFeedback.heavyImpact(); ref.read(goalNotifierProvider.notifier).updateGoalProgress(widget.goal, double.tryParse(_amountController.text.trim()) ?? 0.0); context.pop(); } }, child: const Text("Add Funds", style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w800))))
      ])))))),
    );
  }
}