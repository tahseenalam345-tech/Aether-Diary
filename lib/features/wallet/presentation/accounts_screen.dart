import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/themes/aether_colors.dart';
import '../../../core/themes/widgets/aether_ambient_background.dart';
import '../data/wallet_providers.dart';
import '../domain/models/aether_account.dart';
import '../domain/utils/aether_currency.dart';
import 'widgets/aether_liquid_dropdown.dart';

const Color _bgTop = Color(0xFF060B14);
const Color _bgBottom = Color(0xFF0A0714);
const Color _mint = Color(0xFF34F5C5);
const Color _sky = Color(0xFF38BDF8);
const Color _rose = Color(0xFFFB7185);
const Color _amber = Color(0xFFFBBF60);
const Color _violet = Color(0xFFA78BFA);

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  void _showAddAccountSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _AddAccountSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountNotifierProvider);
    final realTimeBalances = ref.watch(accountBalancesProvider);

    return Scaffold(
      backgroundColor: _bgTop,
      extendBodyBehindAppBar: true,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [_mint, _sky], 
            begin: Alignment.topLeft, 
            end: Alignment.bottomRight
          ),
          boxShadow: [
            BoxShadow(
              color: _mint.withValues(alpha: 0.45), 
              blurRadius: 24, 
              spreadRadius: 1, 
              offset: const Offset(0, 10)
            )
          ],
        ),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () => _showAddAccountSheet(context),
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
            top: -120, right: -80, 
            child: IgnorePointer(child: Container(width: 320, height: 320, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_sky.withValues(alpha: 0.15), Colors.transparent]))))
          ),
          Positioned(
            bottom: -100, left: -60, 
            child: IgnorePointer(child: Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [_violet.withValues(alpha: 0.12), Colors.transparent]))))
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent, elevation: 0, pinned: true, toolbarHeight: 64,
                  flexibleSpace: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(color: _bgTop.withValues(alpha: 0.35)),
                    ),
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: GestureDetector(
                      onTap: () { HapticFeedback.lightImpact(); context.pop(); },
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 17),
                      ),
                    ),
                  ),
                  title: const Text("Accounts", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                  centerTitle: true,
                ),
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(width: 3, height: 16, decoration: BoxDecoration(color: _sky, borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 8),
                                const Text("Your Portfolio", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const Text("Hold to reorder", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                          ],
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 20),
                        
                        accountsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator(color: _mint)),
                          error: (e, st) => Text("Error: $e", style: const TextStyle(color: Colors.red)),
                          data: (accounts) {
                            if (accounts.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 60.0),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), shape: BoxShape.circle),
                                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white24, size: 40),
                                      ),
                                      const SizedBox(height: 16),
                                      Text("No accounts found.\nTap + to link a bank, wallet, or cash fund.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white38, height: 1.5)),
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn();
                            }

                            // 🌟 NAYA: REORDERABLE LIST IMPLEMENTATION 🌟
                            return ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              onReorder: (oldIndex, newIndex) {
                                HapticFeedback.lightImpact();
                                ref.read(accountNotifierProvider.notifier).reorderAccounts(oldIndex, newIndex);
                              },
                              proxyDecorator: (child, index, animation) => Material(color: Colors.transparent, child: child),
                              children: accounts.map((acc) {
                                final currentBalance = realTimeBalances[acc.id] ?? 0.0;
                                Color accColor = _sky;
                                if (acc.accountType == 'cash') accColor = _mint;
                                else if (acc.accountType == 'crypto') accColor = _amber;
                                else if (acc.accountType == 'savings') accColor = _violet;

                                return Padding(
                                  key: Key(acc.id),
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Dismissible(
                                          key: Key("d_${acc.id}"),
                                          direction: DismissDirection.endToStart,
                                          background: Container(
                                            alignment: Alignment.centerRight, 
                                            padding: const EdgeInsets.only(right: 24.0), 
                                            decoration: BoxDecoration(color: _rose.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(22)), 
                                            child: const Icon(Icons.delete_sweep_rounded, color: Colors.black87, size: 28)
                                          ),
                                          onDismissed: (_) {
                                            HapticFeedback.mediumImpact();
                                            ref.read(accountNotifierProvider.notifier).deleteAccount(acc.id);
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(22),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.035),
                                                  borderRadius: BorderRadius.circular(22),
                                                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(12),
                                                      decoration: BoxDecoration(color: accColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                                                      child: Icon(acc.accountType == 'crypto' ? Icons.currency_bitcoin_rounded : Icons.account_balance_rounded, color: accColor, size: 22),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(child: Text(acc.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                                              if (acc.isHiddenFromTotal) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.visibility_off_rounded, color: Colors.white24, size: 14)),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 5),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
                                                            child: Text("${acc.accountType.toUpperCase()} • ${acc.currency}", style: const TextStyle(color: Colors.white38, fontSize: 10.5, fontWeight: FontWeight.w600)),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Flexible(
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        alignment: Alignment.centerRight,
                                                        child: Text(
                                                          AetherCurrency.format(currentBalance, currencyCode: acc.currency), 
                                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // 🌟 DRAG HANDLE 
                                      ReorderableDragStartListener(
                                        index: accounts.indexOf(acc),
                                        child: const Icon(Icons.drag_indicator_rounded, color: Colors.white38, size: 28),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
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

class _AddAccountSheet extends ConsumerStatefulWidget {
  const _AddAccountSheet();
  @override
  ConsumerState<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<_AddAccountSheet> {
  final _titleController = TextEditingController();
  final _balanceController = TextEditingController();
  final _exchangeRateController = TextEditingController(text: "1.0"); 
  
  String _accountType = 'bank';
  String _currencyCode = AetherCurrency.defaultCurrency.code;
  bool _isHidden = false;

  final List<String> _types = ['cash', 'bank', 'crypto', 'savings'];

  @override
  void dispose() {
    _titleController.dispose();
    _balanceController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isForeignCurrency = _currencyCode != AetherCurrency.defaultCurrency.code;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0714).withValues(alpha: 0.85), 
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1)))
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, 
                        height: 4, 
                        margin: const EdgeInsets.only(bottom: 20), 
                        decoration: BoxDecoration(
                          color: Colors.white24, 
                          borderRadius: BorderRadius.circular(4)
                        )
                      )
                    ),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Add Account", 
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)
                        ),
                        GestureDetector(
                          onTap: () { HapticFeedback.lightImpact(); context.pop(); },
                          child: Container(
                            padding: const EdgeInsets.all(8), 
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle), 
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20)
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    
                    SizedBox(
                      height: 42,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal, 
                        itemCount: _types.length, 
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final type = _types[index]; 
                          final isSelected = _accountType == type;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: GestureDetector(
                              onTap: () { HapticFeedback.selectionClick(); setState(() => _accountType = type); },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200), 
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                decoration: BoxDecoration(
                                  color: isSelected ? _sky.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.035),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isSelected ? _sky.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06)),
                                ),
                                child: Center(
                                  child: Text(type.toUpperCase(), style: TextStyle(color: isSelected ? _sky : Colors.white54, fontSize: 12, fontWeight: FontWeight.w700))
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                      child: TextField(
                        controller: _balanceController, 
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: _mint, fontSize: 26, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
                        decoration: const InputDecoration(prefixText: "Bal ", prefixStyle: TextStyle(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.w600), hintText: "0.00", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none)
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                      child: TextField(
                        controller: _titleController, 
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(hintText: "Account Name (e.g., Payoneer)", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 145,
                          child: AetherLiquidDropdown<String>(
                            value: _currencyCode,
                            items: AetherCurrency.supportedCurrencies.map((c) => c.code).toList(),
                            accentColor: _sky,
                            itemLabel: (c) {
                              final curr = AetherCurrency.supportedCurrencies.firstWhere((e) => e.code == c);
                              return "${curr.symbol} ${curr.code}";
                            },
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _currencyCode = val);
                              }
                            },
                          ),
                        ),
                        Row(
                          children: [
                            const Text("Hide from Total", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Switch(
                              value: _isHidden, 
                              activeColor: _sky, 
                              activeTrackColor: _sky.withValues(alpha: 0.3), 
                              inactiveThumbColor: Colors.white54,
                              onChanged: (val) { HapticFeedback.lightImpact(); setState(() => _isHidden = val); }
                            )
                          ],
                        )
                      ],
                    ),
                    
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: isForeignCurrency 
                        ? Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(color: _sky.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: _sky.withValues(alpha: 0.2))),
                              child: Row(
                                children: [
                                  const Icon(Icons.currency_exchange_rounded, color: _sky, size: 18),
                                  const SizedBox(width: 12),
                                  const Text("Rate to Base: ", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                                  Expanded(
                                    child: TextField(
                                      controller: _exchangeRateController, 
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(color: _sky, fontWeight: FontWeight.bold, fontSize: 15),
                                      decoration: const InputDecoration(border: InputBorder.none, hintText: "278.50", hintStyle: TextStyle(color: Colors.white24)),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ) 
                        : const SizedBox.shrink(),
                    ),
                    
                    const SizedBox(height: 36),
                    
                    SizedBox(
                      width: double.infinity, 
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _sky, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                        onPressed: () async {
                          if (_titleController.text.trim().isEmpty) {
                            HapticFeedback.vibrate();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter an Account Name.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
                            return;
                          }

                          HapticFeedback.heavyImpact();
                          
                          try {
                            await ref.read(accountNotifierProvider.notifier).addAccount(
                              AetherAccount(
                                title: _titleController.text.trim(),
                                accountType: _accountType,
                                initialBalance: double.tryParse(_balanceController.text.trim()) ?? 0.0,
                                currency: _currencyCode,
                                colorHex: "10B981", 
                                iconName: "bank",
                                isHiddenFromTotal: _isHidden,
                                baseConversionRate: double.tryParse(_exchangeRateController.text.trim()) ?? 1.0, 
                              )
                            );
                            if (context.mounted) context.pop();
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Database Error: $e"), backgroundColor: Colors.redAccent));
                          }
                        },
                        child: const Text("Create Account", style: TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}