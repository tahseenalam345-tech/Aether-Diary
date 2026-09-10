import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/themes/aether_colors.dart';
import '../../../core/themes/widgets/aether_glass_card.dart';
import '../data/goals_provider.dart';
import '../domain/models/aether_goal.dart';

// Hide to avoid provider conflicts
import '../../wallet/data/wallet_providers.dart' hide goalNotifierProvider; 
import '../../wallet/domain/utils/aether_currency.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _AddGoalSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalNotifierProvider);
    
    // Auto-Sync Logic: Calculate Total Wealth based on the exact field in your model
    final accounts = ref.watch(accountNotifierProvider).valueOrNull ?? [];
    double totalWealth = 0;
    for (var acc in accounts) { 
      totalWealth += acc.initialBalance; 
    }

    return Scaffold(
      backgroundColor: Colors.transparent, 
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8)),
          ],
        ),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () => _showAddGoalSheet(context, ref),
          backgroundColor: Colors.transparent, elevation: 0, highlightElevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),

      // NEW SEAMLESS DENSE DOODLE BACKGROUND
      body: GoalsDoodleBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent, 
                elevation: 0, 
                pinned: true,
                centerTitle: true, // TEXT CENTERED
                leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70), onPressed: () => context.pop()),
                // FONT SIZE REDUCED TO FIT PERFECTLY
                title: Text("Directives & Goals", style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 20, color: Colors.white, letterSpacing: 0.5)),
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: const Text("Track your life milestones and dreams.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14)).animate().fadeIn(delay: 200.ms),
                ),
              ),

              goalsAsync.when(
                loading: () => SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))),
                error: (e, st) => SliverFillRemaining(child: Center(child: Text("Error: $e", style: const TextStyle(color: Colors.redAccent)))),
                data: (goals) {
                  if (goals.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(child: const Text("No active directives.\nTap + to set a new goal.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, height: 1.5)).animate().fadeIn()),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final goal = goals[index];
                          
                          // SMART SYNC
                          double displayAmount = goal.autoSyncWealth ? totalWealth : goal.currentAmount;
                          double progress = goal.targetAmount > 0 ? (displayAmount / goal.targetAmount).clamp(0.0, 1.0) : 0.0;
                          bool isCompleted = progress >= 1.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Dismissible(
                              key: Key(goal.id),
                              direction: DismissDirection.endToStart,
                              background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24.0), decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.delete_sweep, color: Colors.white, size: 28)),
                              onDismissed: (_) {
                                HapticFeedback.mediumImpact();
                                ref.read(goalNotifierProvider.notifier).deleteGoal(goal.id);
                              },
                              child: AetherGlassCard(
                                padding: const EdgeInsets.all(20), opacity: isCompleted ? 0.02 : 0.05,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(goal.category.toUpperCase(), style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                        if (goal.autoSyncWealth) 
                                          const Icon(Icons.sync, color: Colors.blueAccent, size: 14),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(goal.title, style: TextStyle(color: isCompleted ? Colors.white38 : Colors.white, fontSize: 18, fontWeight: FontWeight.bold, decoration: isCompleted ? TextDecoration.lineThrough : null)),
                                    const SizedBox(height: 20),
                                    
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 8,
                                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                                        valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.greenAccent : Theme.of(context).primaryColor),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("${AetherCurrency.format(displayAmount, compact: true)} / ${AetherCurrency.format(goal.targetAmount, compact: true)}", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text("${(progress * 100).toStringAsFixed(1)}%", style: TextStyle(color: isCompleted ? Colors.greenAccent : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text("Target: ${DateFormat('MMM d, yyyy').format(goal.targetDate)}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: Duration(milliseconds: 100 * index)).slideX(begin: 0.1);
                        },
                        childCount: goals.length,
                      ),
                    ),
                  );
                }
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddGoalSheet extends ConsumerStatefulWidget {
  const _AddGoalSheet();
  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _selectedDate;
  bool _autoSyncWealth = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF0A0A0A).withValues(alpha: 0.9), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Set Directive", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => context.pop()),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _titleController, autofocus: true, style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: const InputDecoration(hintText: "What is your goal? (e.g. Dream Car)", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
                ),
                const Divider(color: Colors.white12),
                
                TextField(
                  controller: _amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(hintText: "Target Amount (Rs)", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
                ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Auto-Sync with Wallet", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text("Tracks progress using total wealth.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    Switch(
                      value: _autoSyncWealth,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (val) => setState(() => _autoSyncWealth = val),
                    )
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_selectedDate == null ? "No Target Date" : "Target: ${DateFormat('dd-MM-yy').format(_selectedDate!)}", style: TextStyle(color: _selectedDate != null ? Colors.amberAccent : Colors.white38, fontSize: 12)),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2050));
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 14, color: Colors.white54),
                      label: const Text("Set Date", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () {
                      if (_titleController.text.isNotEmpty && _amountController.text.isNotEmpty && _selectedDate != null) {
                        HapticFeedback.heavyImpact();
                        ref.read(goalNotifierProvider.notifier).addGoal(AetherGoal(
                          title: _titleController.text,
                          category: 'Finance',
                          targetAmount: double.tryParse(_amountController.text) ?? 0.0,
                          targetDate: _selectedDate!,
                          autoSyncWealth: _autoSyncWealth,
                        ));
                        context.pop();
                      }
                    },
                    child: const Text("Initialize Goal", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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

// =============================================================================
// NEW: WHATSAPP-STYLE DENSE SEAMLESS DOODLE BACKGROUND
// =============================================================================
class GoalsDoodleBackground extends StatelessWidget {
  final Widget child;
  const GoalsDoodleBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Fixed seed to keep the pattern consistent across rebuilds
    final random = math.Random(42); 
    
    // Core dream/goal icons
    final icons = [
      Icons.home_outlined, Icons.directions_car_outlined, Icons.flight_takeoff,
      Icons.public, Icons.school_outlined, Icons.account_balance_wallet_outlined,
      Icons.favorite_border, Icons.star_border, Icons.landscape_outlined,
      Icons.diamond_outlined, Icons.shopping_bag_outlined, Icons.rocket_launch_outlined,
      Icons.monetization_on_outlined, Icons.castle_outlined, Icons.pool_outlined,
    ];

    return Stack(
      children: [
        // 1. Deep Slate to Dark Emerald Gradient Base
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF064E3B)], 
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        
        // 2. Tightly Packed Seamless Doodles Layer
        Positioned.fill(
          child: Opacity(
            opacity: 0.04, // Very subtle, like a watermark
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                
                // Spacing logic for dense packing
                const spacing = 45.0; 
                final cols = (width / spacing).ceil() + 2;
                final rows = (height / spacing).ceil() + 2;

                List<Widget> doodles = [];

                // Create a staggered/interlocking grid pattern
                for (int r = -1; r < rows; r++) {
                  for (int c = -1; c < cols; c++) {
                    final icon = icons[random.nextInt(icons.length)];
                    final size = 20.0 + random.nextDouble() * 15.0; // Randomize size slightly
                    final angle = random.nextDouble() * 2 * math.pi; // Randomize rotation

                    // Staggering every alternative row to interlock them tightly
                    double offsetX = c * spacing + (r % 2 == 0 ? spacing / 2 : 0);
                    // Compressing vertical spacing to pack them closer
                    double offsetY = r * (spacing * 0.85); 

                    // Adding micro-randomness so it feels hand-drawn and mixed
                    offsetX += (random.nextDouble() - 0.5) * 15;
                    offsetY += (random.nextDouble() - 0.5) * 15;

                    doodles.add(
                      Positioned(
                        left: offsetX,
                        top: offsetY,
                        child: Transform.rotate(
                          angle: angle,
                          child: Icon(icon, size: size, color: Colors.white),
                        ),
                      ),
                    );
                  }
                }
                // Clip.none ensures doodles on edges aren't cut sharply
                return Stack(clipBehavior: Clip.none, children: doodles);
              },
            ),
          ),
        ),

        // 3. Foreground Content
        child,
      ],
    );
  }
}