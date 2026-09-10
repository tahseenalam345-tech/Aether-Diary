import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/themes/aether_colors.dart';
import '../../../core/themes/widgets/aether_ambient_background.dart';
import '../data/wallet_providers.dart';
import '../domain/models/aether_account.dart';

// 🌟 IMPORTS FOR OUR NEW EXTRACTED TABS 
import 'wallet_accounts_tab.dart';
import 'wallet_planning_tab.dart';
import 'widgets/wallet_notification_sheet.dart';
import '../data/wallet_notifications_provider.dart';

class WalletDashboardScreen extends ConsumerStatefulWidget {
  const WalletDashboardScreen({super.key});

  @override
  ConsumerState<WalletDashboardScreen> createState() => _WalletDashboardScreenState();
}

class _WalletDashboardScreenState extends ConsumerState<WalletDashboardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // 🌟 SMART SWIPE INDICATOR STATE
  int _swipeCount = 0;
  Timer? _swipeRestorer;

  // 🌟 SMART ONBOARDING FORM STATE
  final _onboardNameController = TextEditingController();
  final _onboardBalanceController = TextEditingController();
  String _onboardCurrency = 'PKR';
  String _onboardType = 'Cash';
  String _onboardProfile = 'Student';

  // 🎨 DASHBOARD PALETTE
  static const Color _bgTop = Color(0xFF060B14);
  static const Color _bgBottom = Color(0xFF0A0714);
  static const Color _heroA = Color(0xFF0EA5A0);
  static const Color _heroB = Color(0xFF6D28D9);
  static const Color _mint = Color(0xFF34F5C5);
  static const Color _rose = Color(0xFFFB7185);
  static const Color _sky = Color(0xFF38BDF8);

  @override
  void initState() {
    super.initState();
    _startSwipeRestorer();
  }

  // 🌟 SWIPE COUNT & TIMER MANAGER
  void _handlePageChange(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentPage = index;
      if (_swipeCount < 2) {
        _swipeCount++;
      }
    });
    _startSwipeRestorer();
  }

  void _startSwipeRestorer() {
    _swipeRestorer?.cancel();
    _swipeRestorer = Timer(const Duration(seconds: 10), () {
      if (mounted && _swipeCount >= 2) {
        setState(() {
          _swipeCount = 0; // Show hint again after idle
        });
      }
    });
  }

  @override
  void dispose() {
    _swipeRestorer?.cancel();
    _pageController.dispose();
    _onboardNameController.dispose();
    _onboardBalanceController.dispose();
    super.dispose();
  }

  Widget _buildQuestionLabel(String emoji, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF06B6D4).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            text, 
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 13, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1);
  }

  Future<void> _createFirstAccount() async {
    HapticFeedback.heavyImpact();
    final name = _onboardNameController.text.trim();
    final balanceText = _onboardBalanceController.text.trim().replaceAll(',', '');
    final balance = double.tryParse(balanceText) ?? 0.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter an account name (e.g., Meezan Bank, Cash)"),
        ),
      );
      return;
    }

    String icon = 'account_balance_wallet';
    String color = '0xFF06B6D4'; 
    
    if (_onboardType == 'Bank') { 
      icon = 'account_balance'; 
      color = '0xFF8B5CF6'; 
    } else if (_onboardType == 'E-Wallet') { 
      icon = 'phone_iphone'; 
      color = '0xFF10B981'; 
    } else if (_onboardType == 'Crypto') { 
      icon = 'currency_bitcoin'; 
      color = '0xFFF59E0B'; 
    }

    final newAccount = AetherAccount(
      title: name,
      accountType: _onboardType.toLowerCase(), 
      initialBalance: balance,
      currency: _onboardCurrency,
      colorHex: color,
      iconName: icon,
      institutionName: _onboardProfile, 
    );

    await ref.read(accountNotifierProvider.notifier).addAccount(newAccount);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account created successfully!"), 
          backgroundColor: AetherColors.walletNeonMint,
        ),
      );
    }
  }

  Widget _glowOrb(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size, 
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle, 
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, 
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: Colors.white70, size: 17),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountNotifierProvider);
    final accounts = accountsAsync.valueOrNull ?? [];
    final bool isFirstTime = accounts.isEmpty;

    // ====================================================================
    // SETUP SCREEN
    // ====================================================================
    if (isFirstTime) {
      return Scaffold(
        backgroundColor: const Color(0xFF050505),
        appBar: AppBar(
          backgroundColor: Colors.transparent, 
          elevation: 0, 
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70), 
            onPressed: () => context.pop(),
          ), 
          title: const Text(
            "Setup Wallet", 
            style: TextStyle(
              color: Colors.white, 
              fontSize: 16, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 1.5,
            ),
          ), 
          centerTitle: true,
        ),
        body: AetherAmbientBackground(
          color1: const Color(0xFF0F766E), 
          color2: const Color(0xFF4C1D95),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24), 
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.1), 
                        shape: BoxShape.circle, 
                        border: Border.all(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.3), 
                          width: 2,
                        ),
                      ), 
                      child: const Icon(
                        Icons.account_balance_wallet, 
                        size: 48, 
                        color: Color(0xFF06B6D4),
                      ),
                    ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      "Welcome to Wealth", 
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 26, 
                        fontWeight: FontWeight.w900, 
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      "Set up your first account to start tracking your finances.", 
                      textAlign: TextAlign.center, 
                      style: TextStyle(
                        color: Colors.white54, 
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  _buildQuestionLabel("🏷️", "ACCOUNT NAME"),
                  TextField(
                    controller: _onboardNameController, 
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                    ), 
                    decoration: InputDecoration(
                      hintText: "e.g., Cash, HBL, Nayapay", 
                      hintStyle: const TextStyle(color: Colors.white24), 
                      filled: true, 
                      fillColor: Colors.white.withValues(alpha: 0.05), 
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16), 
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildQuestionLabel("💰", "STARTING BALANCE"),
                  TextField(
                    controller: _onboardBalanceController, 
                    keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                    style: const TextStyle(
                      color: Colors.greenAccent, 
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                    ), 
                    decoration: InputDecoration(
                      hintText: "0.00", 
                      hintStyle: const TextStyle(color: Colors.white24), 
                      prefixText: "$_onboardCurrency  ", 
                      prefixStyle: const TextStyle(
                        color: Colors.white54, 
                        fontSize: 16,
                      ), 
                      filled: true, 
                      fillColor: Colors.white.withValues(alpha: 0.05), 
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16), 
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildQuestionLabel("💱", "BASE CURRENCY"),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal, 
                    physics: const BouncingScrollPhysics(), 
                    child: Row(
                      children: ['PKR', 'USD', 'EUR', 'GBP', 'INR'].map((cur) { 
                        final isSelected = _onboardCurrency == cur; 
                        return Padding(
                          padding: const EdgeInsets.only(right: 10), 
                          child: ChoiceChip(
                            label: Text(
                              cur, 
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ), 
                            selected: isSelected, 
                            selectedColor: Colors.blueAccent.withValues(alpha: 0.2), 
                            backgroundColor: Colors.white.withValues(alpha: 0.05), 
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.blueAccent : Colors.white54,
                            ), 
                            side: BorderSide(
                              color: isSelected ? Colors.blueAccent : Colors.transparent, 
                              width: 1.0,
                            ), 
                            onSelected: (_) { 
                              HapticFeedback.selectionClick(); 
                              setState(() {
                                _onboardCurrency = cur;
                              }); 
                            },
                          ),
                        ); 
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildQuestionLabel("🏦", "ACCOUNT TYPE"),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal, 
                    physics: const BouncingScrollPhysics(), 
                    child: Row(
                      children: ['Cash', 'Bank', 'E-Wallet', 'Crypto'].map((type) { 
                        final isSelected = _onboardType == type; 
                        return Padding(
                          padding: const EdgeInsets.only(right: 10), 
                          child: ChoiceChip(
                            label: Text(
                              type, 
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ), 
                            selected: isSelected, 
                            selectedColor: Colors.deepPurpleAccent.withValues(alpha: 0.2), 
                            backgroundColor: Colors.white.withValues(alpha: 0.05), 
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.deepPurpleAccent : Colors.white54,
                            ), 
                            side: BorderSide(
                              color: isSelected ? Colors.deepPurpleAccent : Colors.transparent, 
                              width: 1.0,
                            ), 
                            onSelected: (_) { 
                              HapticFeedback.selectionClick(); 
                              setState(() {
                                _onboardType = type;
                              }); 
                            },
                          ),
                        ); 
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildQuestionLabel("🧑‍💻", "I AM A..."),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal, 
                    physics: const BouncingScrollPhysics(), 
                    child: Row(
                      children: ['Student', 'Employee', 'Freelancer', 'Business'].map((role) { 
                        final isSelected = _onboardProfile == role; 
                        return Padding(
                          padding: const EdgeInsets.only(right: 10), 
                          child: ChoiceChip(
                            label: Text(
                              role, 
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ), 
                            selected: isSelected, 
                            selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2), 
                            backgroundColor: Colors.white.withValues(alpha: 0.05), 
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFF10B981) : Colors.white54,
                            ), 
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF10B981) : Colors.transparent, 
                              width: 1.0,
                            ), 
                            onSelected: (_) { 
                              HapticFeedback.selectionClick(); 
                              setState(() {
                                _onboardProfile = role;
                              }); 
                            },
                          ),
                        ); 
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity, 
                    height: 55, 
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4), 
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ), 
                      onPressed: _createFirstAccount, 
                      child: const Text(
                        "Complete Setup", 
                        style: TextStyle(
                          color: Colors.black, 
                          fontSize: 16, 
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ====================================================================
    // MAIN HOST SCREEN (Wrapper for the 2 Tabs)
    // ====================================================================
    return Scaffold(
      backgroundColor: _bgTop,
      extendBodyBehindAppBar: true,
      
      // 🌟 SHARED TAB APP BAR
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(114),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: _bgTop.withValues(alpha: 0.35),
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _iconButton(Icons.arrow_back_ios_new_rounded, () => context.pop()),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase(), 
                              style: const TextStyle(
                                color: Colors.white38, 
                                fontSize: 10, 
                                fontWeight: FontWeight.w700, 
                                letterSpacing: 2,
                              ),
                            ), 
                            const SizedBox(height: 2), 
                            const Text(
                              "Wealth", 
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 19, 
                                fontWeight: FontWeight.w800, 
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            WalletNotificationBell(
                              category: _currentPage == 0 
                                  ? WalletNotifCategory.account 
                                  : WalletNotifCategory.budget,
                            ),
                            const SizedBox(width: 8),
                            _iconButton(Icons.contactless_outlined, () { 
                              HapticFeedback.selectionClick(); 
                              context.push('/accounts'); 
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // TABS ROW
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () { 
                              HapticFeedback.lightImpact(); 
                              _pageController.animateToPage(
                                0, 
                                duration: const Duration(milliseconds: 350), 
                                curve: Curves.easeInOutCubic,
                              ); 
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Accounts", 
                                    style: TextStyle(
                                      color: _currentPage == 0 ? Colors.white : Colors.white38, 
                                      fontSize: 14, 
                                      fontWeight: _currentPage == 0 ? FontWeight.w800 : FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300), 
                                    height: 3, 
                                    width: _currentPage == 0 ? 36 : 0, 
                                    decoration: BoxDecoration(
                                      color: _sky, 
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: _currentPage == 0 ? [
                                        BoxShadow(color: _sky.withValues(alpha: 0.6), blurRadius: 8)
                                      ] : [],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () { 
                              HapticFeedback.lightImpact(); 
                              _pageController.animateToPage(
                                1, 
                                duration: const Duration(milliseconds: 350), 
                                curve: Curves.easeInOutCubic,
                              ); 
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Budgets & Goals", 
                                    style: TextStyle(
                                      color: _currentPage == 1 ? Colors.white : Colors.white38, 
                                      fontSize: 14, 
                                      fontWeight: _currentPage == 1 ? FontWeight.w800 : FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300), 
                                    height: 3, 
                                    width: _currentPage == 1 ? 48 : 0, 
                                    decoration: BoxDecoration(
                                      color: _mint, 
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: _currentPage == 1 ? [
                                        BoxShadow(color: _mint.withValues(alpha: 0.6), blurRadius: 8)
                                      ] : [],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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

      // 🌟 FLOATING ADD BUTTON (Visible only on Tab 0)
      floatingActionButton: AnimatedScale(
        scale: _currentPage == 0 ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle, 
            gradient: const LinearGradient(
              colors: [_mint, _sky], 
              begin: Alignment.topLeft, 
              end: Alignment.bottomRight,
            ), 
            boxShadow: [
              BoxShadow(
                color: _mint.withValues(alpha: 0.45), 
                blurRadius: 24, 
                spreadRadius: 1, 
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: FloatingActionButton(
            heroTag: null,
            onPressed: () { 
              HapticFeedback.lightImpact(); 
              context.push('/add-transaction'); 
            }, 
            backgroundColor: Colors.transparent, 
            elevation: 0, 
            child: const Icon(
              Icons.add_rounded, 
              color: Colors.black87, 
              size: 30,
            ),
          ),
        ),
      ),
      
      body: Stack(
        children: [
          // Backgrounds
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
            child: _glowOrb(320, _heroA.withValues(alpha: 0.28)),
          ),
          Positioned(
            top: 180, 
            left: -140, 
            child: _glowOrb(280, _heroB.withValues(alpha: 0.22)),
          ),
          Positioned(
            bottom: -100, 
            right: -60, 
            child: _glowOrb(260, _rose.withValues(alpha: 0.12)),
          ),

          // 🌟 THE PAGE VIEW (Handles Swiping)
          PageView(
            controller: _pageController,
            onPageChanged: _handlePageChange,
            children: const [
              WalletAccountsTab(),
              WalletPlanningTab(),
            ],
          ),

          // 🌟 SMART SWIPE INDICATORS (CHEVRONS - SMOOTH & ELEGANT) 🌟
          if (_currentPage == 0 && _swipeCount < 2)
            Positioned(
              right: 0,
              top: MediaQuery.of(context).size.height * 0.45,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.only(left: 8, right: 6, top: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20), 
                      bottomLeft: Radius.circular(20),
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .slideX(begin: 0.12, end: -0.06, duration: 1800.ms, curve: Curves.easeInOutSine)
                .fadeIn(duration: 800.ms),
              ),
            ),
            
          if (_currentPage == 1 && _swipeCount < 2)
            Positioned(
              left: 0,
              top: MediaQuery.of(context).size.height * 0.45,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.only(right: 8, left: 6, top: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20), 
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.chevron_left_rounded, color: Colors.white54, size: 20),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .slideX(begin: -0.12, end: 0.06, duration: 1800.ms, curve: Curves.easeInOutSine)
                .fadeIn(duration: 800.ms),
              ),
            ),
        ],
      ),
    );
  }
}