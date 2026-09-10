import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../data/ai_reflection_providers.dart';

class AiReflectionScreen extends ConsumerStatefulWidget {
  const AiReflectionScreen({super.key});

  @override
  ConsumerState<AiReflectionScreen> createState() => _AiReflectionScreenState();
}

class _AiReflectionScreenState extends ConsumerState<AiReflectionScreen> {
  bool _isAnalyzing = true;
  String? _activeCoachResponse;
  String? _activeCoachTitle;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _isAnalyzing = false);
    });
  }

  void _triggerPrompt(String title, String response) {
    HapticFeedback.mediumImpact();
    setState(() {
      _activeCoachTitle = title;
      _activeCoachResponse = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(localAiReflectionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      body: SafeArea(
        child: Column(
          children: [
            // 🌟 TOP APP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  const Text(
                    "NEURAL REFLECTOR",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: _isAnalyzing
                  ? _buildLoadingState()
                  : _buildReflectionState(aiState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 10),
              ],
            ),
            child: const CircularProgressIndicator(color: Color(0xFF8B5CF6), strokeWidth: 2.5),
          ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1800.ms),
          const SizedBox(height: 32),
          const Text(
            "Synthesizing Cross-Module Signals...",
            style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.bold),
          ).animate().fadeIn(duration: 600.ms),
        ],
      ),
    );
  }

  Widget _buildReflectionState(AiReflectionState aiState) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🌟 1. NEURAL ORB & ENERGY LEVEL BANNER
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF2DD4BF)],
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF060B14), size: 30),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.95, end: 1.05, duration: 1500.ms),
                const SizedBox(height: 12),
                Text(
                  aiState.energyLevel,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Holistic System Health & Momentum",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 🌟 2. SYNTHESIZED NARRATIVE CARD
          _buildGlassCard(
            glow: const Color(0xFF8B5CF6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.psychology_rounded, color: Color(0xFF8B5CF6), size: 20),
                    SizedBox(width: 8),
                    Text(
                      "CROSS-MODULE MONITORING SYNTHESIS",
                      style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  aiState.dailyNarrative,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 18),

          // 🌟 3. ACTIVE COACH PROMPT RESPONSE (IF TRIGGERED)
          if (_activeCoachResponse != null) ...[
            _buildGlassCard(
              glow: const Color(0xFF2DD4BF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _activeCoachTitle ?? "AI Coach Insight",
                        style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                        onPressed: () => setState(() => _activeCoachResponse = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _activeCoachResponse!,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.5),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.96, 0.96)),
            const SizedBox(height: 18),
          ],

          // 🌟 4. INTERACTIVE LIFE COACH PROMPTS
          const Text(
            "INTERACTIVE NEURAL QUERIES",
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _promptChip(
                  "⚡ Focus Optimization",
                  "Based on your pending tasks, schedule two 25-minute sprints during your highest energy window (morning) to eliminate backlogs.",
                ),
                _promptChip(
                  "💰 Spending Check",
                  "Your ${aiState.topSpendingCategory} expenses are pacing normally. Setting a weekly ceiling of \$50 helps secure surplus for your savings goals.",
                ),
                _promptChip(
                  "🧘 Mood & Clarity",
                  "Your emotional state is ${aiState.dominantMood}. Evening journaling for 3 minutes has shown to improve morning execution velocity by 25%.",
                ),
                _promptChip(
                  "🗓️ Routine Cadence",
                  "Consistency streak is active! Make sure to check in with your primary habits before 9 PM to lock in your daily mastery score.",
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 🌟 5. ACTIONABLE NEXT STEPS
          const Text(
            "RECOMMENDED ACTIONS FOR TODAY",
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          ...aiState.actionableAdvice.map((adv) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_right_rounded, color: Color(0xFF2DD4BF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(adv, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _promptChip(String title, String response) {
    return GestureDetector(
      onTap: () => _triggerPrompt(title, response),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.35)),
        ),
        child: Text(
          title,
          style: const TextStyle(color: Color(0xFFC084FC), fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, Color? glow}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: glow != null ? glow.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}