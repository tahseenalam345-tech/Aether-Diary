import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../../core/providers/module_preferences_provider.dart';

/// 🌟 AETHER OS MODULAR ONBOARDING QUESTIONNAIRE SCREEN 🌟
/// AMOLED-friendly, frosted glassmorphism, fluid interactive module selection.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _wealthSelected = true;
  bool _diarySelected = true;
  bool _productivitySelected = true;

  static const Color _bgVoid = Color(0xFF060B14);
  static const Color _teal = Color(0xFF2DD4BF);
  static const Color _sky = Color(0xFF38BDF8);
  static const Color _amber = Color(0xFFFBBF24);
  static const Color _violet = Color(0xFF8B5CF6);

  int get _selectedCount =>
      (_wealthSelected ? 1 : 0) +
      (_diarySelected ? 1 : 0) +
      (_productivitySelected ? 1 : 0);

  Future<void> _completeOnboarding() async {
    HapticFeedback.heavyImpact();

    // If user unchecked everything, default all to true so they don't get an empty shell
    final finalWealth = _selectedCount == 0 ? true : _wealthSelected;
    final finalDiary = _selectedCount == 0 ? true : _diarySelected;
    final finalProductivity = _selectedCount == 0 ? true : _productivitySelected;

    // 1. Save module preferences
    await ref.read(modulePreferencesProvider.notifier).setPreferences(
      wealth: finalWealth,
      diary: finalDiary,
      productivity: finalProductivity,
    );

    // 2. Mark onboarding completed in both settings boxes
    try {
      final settingsBox = Hive.isBoxOpen('settings')
          ? Hive.box('settings')
          : await Hive.openBox('settings');
      await settingsBox.put('has_seen_onboarding', true);

      final aetherSettings = Hive.isBoxOpen('aether_settings')
          ? Hive.box('aether_settings')
          : await Hive.openBox('aether_settings');
      await aetherSettings.put('has_seen_onboarding', true);
    } catch (_) {}

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgVoid,
      body: Stack(
        children: [
          // 🌌 AMBIENT COSMIC AURORA BLOBS
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _teal.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _violet.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),

                        // 🌟 BRAND BADGE
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _teal.withValues(alpha: 0.15),
                                  _violet.withValues(alpha: 0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, color: _teal, size: 14),
                                const SizedBox(width: 8),
                                Text(
                                  "AETHER OS • MODULAR SETUP",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, end: 0),
                        ),

                        const SizedBox(height: 24),

                        // 🌟 HEADLINE & SUBTITLE
                        const Text(
                          "What do you want to manage with Aether?",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15, end: 0),

                        const SizedBox(height: 10),

                        Text(
                          "Select the modular workspaces you'd like to activate. You can toggle or customize these anytime in Settings.",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ).animate().fadeIn(delay: 300.ms),

                        const SizedBox(height: 28),

                        // 🌟 MODULE CARD 1: WEALTH & BUDGETS
                        _buildModuleCard(
                          title: "Wealth & Budgets",
                          subtitle: "Track multi-account expenses, smart budgets, cashflow pacing & financial analytics.",
                          tag: "FINANCIAL PULSE",
                          emoji: "💰",
                          accentColor: const Color(0xFF10B981),
                          isSelected: _wealthSelected,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _wealthSelected = !_wealthSelected);
                          },
                        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 14),

                        // 🌟 MODULE CARD 2: PERSONAL DIARY
                        _buildModuleCard(
                          title: "Personal Diary",
                          subtitle: "Capture reflections, mood trends, grateful moments & private encrypted notes.",
                          tag: "SANCTUARY & REFLECTION",
                          emoji: "📝",
                          accentColor: _sky,
                          isSelected: _diarySelected,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _diarySelected = !_diarySelected);
                          },
                        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 14),

                        // 🌟 MODULE CARD 3: PRODUCTIVITY & HABITS
                        _buildModuleCard(
                          title: "Productivity & Habits",
                          subtitle: "Smart task manager, sprint focus timer, recurring habits & streak analytics.",
                          tag: "FOCUS & EXECUTION",
                          emoji: "⚡",
                          accentColor: _amber,
                          isSelected: _productivitySelected,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _productivitySelected = !_productivitySelected);
                          },
                        ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 20),

                        // 🌟 QUICK HINT
                        Center(
                          child: Text(
                            "$_selectedCount of 3 Modules Selected",
                            style: TextStyle(
                              color: _selectedCount > 0 ? _teal : Colors.white30,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 🌟 BOTTOM ACTION BAR
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: GestureDetector(
                    onTap: _completeOnboarding,
                    child: Container(
                      height: 58,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_teal, _violet],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _teal.withValues(alpha: 0.35),
                            blurRadius: 20,
                            spreadRadius: -2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Start Experience",
                              style: TextStyle(
                                color: Color(0xFF060B14),
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, color: Color(0xFF060B14), size: 20),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String subtitle,
    required String tag,
    required String emoji,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.16),
                    blurRadius: 20,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // EMOJI / ICON CONTAINER
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? accentColor.withValues(alpha: 0.4) : Colors.white10,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // TEXT CONTENT
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tag,
                              style: TextStyle(
                                color: isSelected ? accentColor : Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? accentColor : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? accentColor : Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Color(0xFF060B14),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12.5,
                            height: 1.35,
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
    );
  }
}