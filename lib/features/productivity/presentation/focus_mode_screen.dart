import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/productivity_providers.dart';
// NEW IMPORTS: Global Design System
import '../../../core/themes/aether_colors.dart';
import '../../../core/themes/widgets/aether_ambient_background.dart';
import '../../../core/themes/widgets/aether_glass_card.dart';

class FocusModeScreen extends ConsumerStatefulWidget {
  const FocusModeScreen({super.key});

  @override
  ConsumerState<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends ConsumerState<FocusModeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _breathingController;
  Timer? _uiTicker;
  
  bool _isRunning = false;
  Duration _selectedDuration = const Duration(minutes: 25);
  Duration _remainingTime = const Duration(minutes: 25);
  DateTime? _targetEndTime;
  String _sessionType = "Deep Work";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), 
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      _uiTicker?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_isRunning && _targetEndTime != null) {
        final now = DateTime.now();
        if (now.isAfter(_targetEndTime!)) {
          _remainingTime = Duration.zero;
          _completeSession();
        } else {
          setState(() {
            _remainingTime = _targetEndTime!.difference(now);
          });
          _startUITicker(); 
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    _uiTicker?.cancel();
    _breathingController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_remainingTime.inSeconds == 0) return;

    HapticFeedback.heavyImpact(); 
    WakelockPlus.enable(); 
    
    setState(() {
      _isRunning = true;
      _targetEndTime = DateTime.now().add(_remainingTime);
    });

    _breathingController.repeat(reverse: true);
    _startUITicker();
  }

  void _startUITicker() {
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      final now = DateTime.now();
      if (_targetEndTime != null && now.isAfter(_targetEndTime!)) {
        _completeSession();
      } else if (_targetEndTime != null) {
        setState(() {
          _remainingTime = _targetEndTime!.difference(now);
        });
      }
    });
  }

  void _pauseTimer() {
    HapticFeedback.mediumImpact();
    WakelockPlus.disable(); 
    _uiTicker?.cancel();
    _breathingController.stop();
    setState(() {
      _isRunning = false;
      _targetEndTime = null; 
    });
  }

  void _resetTimer() {
    HapticFeedback.selectionClick();
    _pauseTimer();
    setState(() {
      _remainingTime = _selectedDuration;
    });
  }

  void _completeSession() {
    _uiTicker?.cancel();
    _breathingController.stop();
    WakelockPlus.disable();
    SystemSound.play(SystemSoundType.click); 
    HapticFeedback.heavyImpact(); 

    setState(() {
      _isRunning = false;
      _remainingTime = _selectedDuration;
      _targetEndTime = null;
    });

    ref.read(focusSessionNotifierProvider.notifier).logSession(
      plannedMinutes: _selectedDuration.inMinutes,
      actualSeconds: _selectedDuration.inSeconds,
      startTime: DateTime.now().subtract(_selectedDuration),
      taskName: _sessionType,
      notes: [],
      status: 'Completed',
    );

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildCompletionDialog(),
      );
    }
  }

  Widget _buildCompletionDialog() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: AlertDialog(
        backgroundColor: const Color(0xFF121212).withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        title: const Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 64),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Session Complete", style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24)),
            const SizedBox(height: 12),
            Text("+${_selectedDuration.inMinutes * 2} OS Score added to your Analytics vault.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
            child: Text("Continue", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _changeDuration(int minutes) {
    if (_isRunning) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDuration = Duration(minutes: minutes);
      _remainingTime = _selectedDuration;
    });
  }

  @override
  Widget build(BuildContext context) {
    String minutes = (_remainingTime.inSeconds ~/ 60).toString().padLeft(2, '0');
    String seconds = (_remainingTime.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: AetherColors.pureBlack, 
      body: AetherAmbientBackground(
        color1: _isRunning ? AetherColors.focusCrimson : AetherColors.focusDeepRed, // Pulses harder when running
        color2: AetherColors.depthBlack,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  // Top Nav
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.pop();
                          },
                        ),
                        AetherGlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          borderRadius: 20,
                          opacity: 0.05,
                          blur: 10,
                          child: Text(_sessionType, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                        const SizedBox(width: 48), // Balance spacing
                      ],
                    ),
                  ),

                  const Spacer(),

                  // UPDATED: The Holographic Clock inside thick frosted glass
                  AetherGlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                    blur: 30, // Extremely thick glass
                    opacity: 0.02,
                    borderRadius: 40,
                    child: Text(
                      "$minutes:$seconds", 
                      style: TextStyle(
                        fontSize: 96, 
                        fontWeight: FontWeight.w200, 
                        color: Colors.white, 
                        fontFeatures: const [FontFeature.tabularFigures()],
                        shadows: [
                          Shadow(
                            color: _isRunning ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.2),
                            blurRadius: _isRunning ? 30 : 10,
                          )
                        ]
                      )
                    ),
                  ).animate(target: _isRunning ? 1 : 0).scaleXY(end: 1.05, duration: 4.seconds, curve: Curves.easeInOutSine), // Slowly breathes while running
                  
                  const SizedBox(height: 64),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_isRunning) ...[
                        _buildTimeSelector(25), const SizedBox(width: 16),
                        _buildTimeSelector(50), const SizedBox(width: 16),
                        _buildTimeSelector(90),
                      ] else ...[
                        IconButton(
                          onPressed: _resetTimer,
                          icon: const Icon(Icons.stop_rounded, color: Colors.white54, size: 36),
                        ),
                      ]
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Massive Play/Pause Button
                  GestureDetector(
                    onTap: _isRunning ? _pauseTimer : _startTimer,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRunning ? Colors.white.withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.8), // Red tint for focus
                        boxShadow: _isRunning ? [] : [
                          BoxShadow(color: Colors.redAccent.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5),
                          BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 2, offset: const Offset(0, -1)) // Inner glass edge
                        ],
                      ),
                      child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelector(int mins) {
    final isSelected = _selectedDuration.inMinutes == mins;
    return GestureDetector(
      onTap: () => _changeDuration(mins),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? Colors.white54 : Colors.white12),
        ),
        child: Text("$mins", style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}