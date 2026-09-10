import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/themes/aether_colors.dart';
import '../../../core/themes/widgets/aether_ambient_background.dart';
import '../../../core/themes/widgets/aether_glass_card.dart';
import '../domain/models/aether_transaction.dart';
import '../domain/utils/aether_category.dart';
import '../domain/utils/aether_currency.dart';
import '../data/wallet_providers.dart';

// NEW: Universal Attachment Card
import 'widgets/aether_attachment_card.dart'; 

class TransactionDetailsScreen extends ConsumerWidget {
  final AetherTransaction transaction;
  const TransactionDetailsScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = transaction.type == 'income';
    final isTransfer = transaction.type == 'transfer';
    
    final Color primaryColor = isTransfer ? Colors.blueAccent : isIncome ? AetherColors.walletNeonMint : Colors.redAccent;
    final Color ambientPrimary = isTransfer ? Colors.blueAccent : isIncome ? AetherColors.walletEmeraldGlow : AetherColors.focusCrimson;
    final Color ambientSecondary = isTransfer ? Colors.indigo : isIncome ? AetherColors.walletForest : AetherColors.focusDeepRed;
    
    final category = isTransfer ? const AetherCategory(id: 't', name: 'Transfer', icon: Icons.sync_alt, color: Colors.blueAccent, subcategories: []) : AetherCategory.fromName(transaction.category);
    
    final accounts = ref.read(accountNotifierProvider).valueOrNull ?? [];
    final sourceAccountName = accounts.where((a) => a.id == transaction.accountId).firstOrNull?.title ?? "Unknown Account";
    final destAccountName = transaction.destinationAccountId != null 
        ? accounts.where((a) => a.id == transaction.destinationAccountId).firstOrNull?.title ?? "Unknown Account" 
        : null;

    return Scaffold(
      backgroundColor: AetherColors.pureBlack,
      body: AetherAmbientBackground(
        color1: ambientPrimary,
        color2: ambientSecondary,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white54),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(transactionNotifierProvider.notifier).deleteTransaction(transaction.id);
                      context.pop();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(category.icon, color: primaryColor, size: 40),
                      ).animate().scaleXY(begin: 0.8, duration: 400.ms, curve: Curves.easeOutBack),
                      
                      const SizedBox(height: 24),
                      Text(
                        transaction.title,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(),
                      
                      const SizedBox(height: 8),
                      Text(
                        "${isTransfer ? '' : isIncome ? '+' : '-'}${AetherCurrency.format(transaction.amount, currencyCode: transaction.currency)}",
                        style: TextStyle(color: primaryColor, fontSize: 48, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()]),
                      ).animate().fadeIn(delay: 100.ms),
                      
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(transaction.date),
                        style: const TextStyle(color: Colors.white38, fontSize: 14),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 40),

                      AetherGlassCard(
                        padding: const EdgeInsets.all(24),
                        opacity: 0.05,
                        child: Column(
                          children: [
                            _buildMetaRow("Status", "Completed", Icons.check_circle, primaryColor),
                            const Divider(color: Colors.white12, height: 32),
                            _buildMetaRow("Category", transaction.subcategory ?? transaction.category, category.icon, Colors.white70),
                            const Divider(color: Colors.white12, height: 32),
                            _buildMetaRow(isTransfer ? "From" : "Account", sourceAccountName, Icons.account_balance_wallet, Colors.white70),
                            
                            if (isTransfer && destAccountName != null) ...[
                              const Divider(color: Colors.white12, height: 32),
                              _buildMetaRow("To Account", destAccountName, Icons.login_rounded, Colors.blueAccent),
                            ]
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),

                      // NEW LOGIC: Universal Attachment System Hookup
                      if (transaction.attachmentPaths != null && transaction.attachmentPaths!.isNotEmpty) ...[
                        const SizedBox(height: 40),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Attached Files", style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                        const SizedBox(height: 16),
                        ...transaction.attachmentPaths!.map((path) {
                          // Uses the safe, native file-opener card we built!
                          return AetherAttachmentCard(path: path);
                        }),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 16)),
        const Spacer(),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}