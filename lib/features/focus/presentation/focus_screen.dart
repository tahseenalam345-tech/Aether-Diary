import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../productivity/data/productivity_providers.dart';
import '../../productivity/domain/models/aether_task.dart';

enum FocusPhase { focus, shortBreak, longBreak }

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  
  // CORE SETTINGS
  int _focusDurationMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;
  bool _isStrictMode = true; 

  late int _timeLeftSeconds;
  bool _isActive = false;
  FocusPhase _currentPhase = FocusPhase.focus;
  Timer? _timer;
  DateTime? _lastPausedTime;
  DateTime? _sessionStartTime; // 🌟 NAYA: Session Start Time Tracker

  int _completedCycles = 0; 

  final AudioPlayer _audioPlayer = AudioPlayer();
  String _currentSoundscape = 'None';
  bool _isMusicPlaying = false;
  bool _isMusicBuffering = false;
  double _soundscapeVolume = 0.75; 

  final Map<String, String> _soundscapes = {
    'None': '',
    '🌧️ Heavy Rain': 'https://raw.githubusercontent.com/karthiknvd/noctune/master/sounds/rain.mp3',
    '⚡ Thunder': 'https://raw.githubusercontent.com/karthiknvd/noctune/master/sounds/thunder.mp3',
    '🌲 Pine Forest': 'https://raw.githubusercontent.com/karthiknvd/noctune/master/sounds/forest.mp3',
    '🌊 River Stream': 'https://raw.githubusercontent.com/karthiknvd/noctune/master/sounds/river.mp3',
    '🔥 Campfire': 'https://raw.githubusercontent.com/karthiknvd/noctune/master/sounds/campfire.mp3',
    '🌌 Midnight Calm': 'https://raw.githubusercontent.com/karthiknvd/noctune/master/sounds/night.mp3',
    '🚂 Cozy Train': 'https://raw.githubusercontent.com/karthiknvd/noctune/master/sounds/train.mp3',
    '💨 Gentle Breeze': 'https://raw.githubusercontent.com/karthiknvd/noctune/master/sounds/wind.mp3',
  };

  final List<String> _distractionNotes = [];

  final List<String> _motivationalQuotes = [
    "“Deep work is the ability to focus without distraction on a demanding task.”",
    "“Simplicity boils down to: Identify the essential. Eliminate the rest.”",
    "“Starve your distractions, feed your focus.”",
    "“Where focus goes, energy flows and results show.”",
    "“One hour of pure flow is worth five hours of fractured attention.”",
    "“Your future is created by what you do today, not tomorrow.”",
  ];
  int _quoteIndex = 0;
  Timer? _quoteTimer;

  AetherTask? _selectedTask;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _timeLeftSeconds = _focusDurationMinutes * 60;
    WidgetsBinding.instance.addObserver(this);

    AudioPlayer.global.setAudioContext(AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
      respectSilence: false,
      stayAwake: true,
    ).build());

    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.setVolume(_soundscapeVolume);
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isMusicPlaying = state == PlayerState.playing;
          _isMusicBuffering = false;
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // Thora slow, deep breath feel
    )..repeat(reverse: true);

    _quoteTimer = Timer.periodic(const Duration(seconds: 35), (timer) {
      if (mounted) {
        setState(() {
          _quoteIndex = (_quoteIndex + 1) % _motivationalQuotes.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _quoteTimer?.cancel();
    _audioPlayer.dispose();
    _pulseController.dispose();
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_isActive) {
        if (_isStrictMode && _currentPhase == FocusPhase.focus) {
          _failSession();
        } else {
          _lastPausedTime = DateTime.now();
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isActive && !_isStrictMode && _lastPausedTime != null) {
        final elapsedSeconds = DateTime.now().difference(_lastPausedTime!).inSeconds;
        setState(() {
          _timeLeftSeconds -= elapsedSeconds;
          if (_timeLeftSeconds <= 0) {
            _timeLeftSeconds = 0;
            _handlePhaseCompletion();
          }
        });
        _lastPausedTime = null;
      }
    }
  }

  Future<void> _toggleSoundscape(String name) async {
    HapticFeedback.selectionClick();
    if (name == 'None') {
      await _audioPlayer.stop();
      setState(() {
        _currentSoundscape = name;
        _isMusicPlaying = false;
        _isMusicBuffering = false;
      });
      return;
    }

    try {
      if (_currentSoundscape == name && _isMusicPlaying) {
        await _audioPlayer.pause();
      } else {
        setState(() {
          _currentSoundscape = name;
          _isMusicBuffering = true;
        });
        await _audioPlayer.setVolume(_soundscapeVolume);
        await _audioPlayer.play(UrlSource(_soundscapes[name]!, mimeType: 'audio/mpeg'));
      }
    } catch (e) {
      setState(() => _isMusicBuffering = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Audio error: $e"), backgroundColor: Colors.redAccent.withValues(alpha: 0.8)));
    }
  }

  Future<void> _updateVolume(double value) async {
    setState(() => _soundscapeVolume = value);
    await _audioPlayer.setVolume(value);
  }

  void _toggleTimer() {
    HapticFeedback.selectionClick();
    if (_isActive) {
      if (_isStrictMode && _currentPhase == FocusPhase.focus) {
        _showStrictPauseWarning();
      } else {
        _pauseTimerDirectly();
      }
    } else {
      _startTimer();
    }
  }

  int get _totalPhaseSeconds {
    switch (_currentPhase) {
      case FocusPhase.focus: return _focusDurationMinutes * 60;
      case FocusPhase.shortBreak: return _shortBreakMinutes * 60;
      case FocusPhase.longBreak: return _longBreakMinutes * 60;
    }
  }

  void _startTimer() {
    if (_timeLeftSeconds == _totalPhaseSeconds || _timeLeftSeconds == 0) {
      _timeLeftSeconds = _totalPhaseSeconds;
      _sessionStartTime = DateTime.now(); // Record start time for history
    }
    setState(() => _isActive = true);
    WakelockPlus.enable();

    if (_currentSoundscape != 'None' && !_isMusicPlaying) {
      _audioPlayer.resume();
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeftSeconds > 0) {
          _timeLeftSeconds--;
        } else {
          _handlePhaseCompletion();
        }
      });
    });
  }

  void _pauseTimerDirectly() {
    setState(() => _isActive = false);
    _timer?.cancel();
    _audioPlayer.pause();
    WakelockPlus.disable();
  }

  void _showStrictPauseWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("🛡️ Strict Mode Alert", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("Pausing will break your deep focus state. Are you sure you want to stop?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Keep Focusing", style: TextStyle(color: Colors.white))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () { Navigator.pop(ctx); _pauseTimerDirectly(); },
            child: const Text("Pause Session", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // 🌟 NAYA: LOG FAILURES TO HISTORY
  Future<void> _failSession() async {
    _timer?.cancel();
    _audioPlayer.stop();
    WakelockPlus.disable();
    
    int actualSecs = _sessionStartTime != null ? DateTime.now().difference(_sessionStartTime!).inSeconds : 0;

    await ref.read(focusSessionNotifierProvider.notifier).logSession(
      plannedMinutes: _focusDurationMinutes,
      actualSeconds: actualSecs,
      startTime: _sessionStartTime ?? DateTime.now(),
      taskName: _selectedTask?.title ?? 'Deep Work',
      notes: _distractionNotes,
      status: 'Failed (Strict Mode)',
    );
    _distractionNotes.clear();

    setState(() {
      _isActive = false;
      _timeLeftSeconds = _focusDurationMinutes * 60;
      _isMusicPlaying = false;
    });

    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.heavyImpact());

    if (mounted) {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2A0D0D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5))),
          title: const Text("🚨 Focus Broken!", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: const Text("You left the app while Strict Mode was ON. Your deep work session has been destroyed but logged in history.", style: TextStyle(color: Colors.white70)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => context.pop(),
              child: const Text("I'll do better", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
  }

  // 🌟 NAYA: LOG ABORTS TO HISTORY
  Future<void> _cancelSession() async {
    HapticFeedback.heavyImpact();
    
    int actualSecs = _sessionStartTime != null ? DateTime.now().difference(_sessionStartTime!).inSeconds : 0;
    
    await ref.read(focusSessionNotifierProvider.notifier).logSession(
      plannedMinutes: _currentPhase == FocusPhase.focus ? _focusDurationMinutes : (_currentPhase == FocusPhase.shortBreak ? _shortBreakMinutes : _longBreakMinutes),
      actualSeconds: actualSecs,
      startTime: _sessionStartTime ?? DateTime.now(),
      taskName: _selectedTask?.title ?? 'Break Time',
      notes: _distractionNotes,
      status: 'Aborted',
    );
    _distractionNotes.clear();

    setState(() {
      _isActive = false;
      _currentPhase = FocusPhase.focus;
      _timeLeftSeconds = _focusDurationMinutes * 60;
      _isMusicPlaying = false;
      _isMusicBuffering = false;
    });
    _timer?.cancel();
    _audioPlayer.stop();
    WakelockPlus.disable();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Session aborted and logged.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent.withValues(alpha: 0.8)));
  }

  // 🌟 NAYA: LOG SUCCESS TO HISTORY
  Future<void> _handlePhaseCompletion() async {
    _timer?.cancel();
    _audioPlayer.stop();
    WakelockPlus.disable();
    setState(() {
      _isActive = false;
      _isMusicPlaying = false;
    });
    HapticFeedback.heavyImpact();

    if (_currentPhase == FocusPhase.focus) {
      final newCycleCount = _completedCycles + 1;
      setState(() => _completedCycles = newCycleCount);

      int actualSecs = _sessionStartTime != null ? DateTime.now().difference(_sessionStartTime!).inSeconds : _focusDurationMinutes * 60;

      await ref.read(focusSessionNotifierProvider.notifier).logSession(
        plannedMinutes: _focusDurationMinutes,
        actualSeconds: actualSecs,
        startTime: _sessionStartTime ?? DateTime.now().subtract(Duration(minutes: _focusDurationMinutes)),
        taskName: _selectedTask?.title ?? 'Deep Work',
        notes: _distractionNotes,
        status: 'Completed',
      );
      _distractionNotes.clear();

      if (_selectedTask != null && !_selectedTask!.isCompleted) {
        await ref.read(taskNotifierProvider.notifier).toggleTaskCompletion(_selectedTask!);
      }

      final isLongBreakCycle = (newCycleCount % 4 == 0);

      if (mounted) {
        showDialog(
          context: context, barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF10B981))),
            title: Row(
              children: [
                Icon(isLongBreakCycle ? Icons.military_tech : Icons.task_alt, color: isLongBreakCycle ? Colors.amberAccent : const Color(0xFF10B981)),
                const SizedBox(width: 8),
                Text(isLongBreakCycle ? "🏆 4 Cycles Complete!" : "🎯 Focus Complete!", style: TextStyle(color: isLongBreakCycle ? Colors.amberAccent : const Color(0xFF10B981), fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              isLongBreakCycle
                  ? "Incredible work! You completed a full 4-Pomodoro deep focus block.\n\nReward yourself with a $_longBreakMinutes min Long Break!"
                  : "You focused deeply for $_focusDurationMinutes minutes (Cycle $newCycleCount/4).\n${_selectedTask != null ? '\nTask Marked as Done:\n${_selectedTask!.title}' : ''}",
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(onPressed: () { context.pop(); _safePop(); }, child: const Text("End Session", style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isLongBreakCycle ? Colors.amberAccent : const Color(0xFF10B981)),
                onPressed: () {
                  context.pop();
                  setState(() {
                    _currentPhase = isLongBreakCycle ? FocusPhase.longBreak : FocusPhase.shortBreak;
                    _timeLeftSeconds = isLongBreakCycle ? _longBreakMinutes * 60 : _shortBreakMinutes * 60;
                  });
                },
                child: Text(isLongBreakCycle ? "Start Long Break ($_longBreakMinutes m)" : "Start Short Break ($_shortBreakMinutes m)", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        showDialog(
          context: context, barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF06B6D4))),
            title: const Text("☕ Break Over", style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold)),
            content: const Text("Mind refreshed! Ready for the next deep work session?", style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () { context.pop(); _safePop(); }, child: const Text("End", style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
                onPressed: () {
                  context.pop();
                  setState(() {
                    _currentPhase = FocusPhase.focus;
                    _timeLeftSeconds = _focusDurationMinutes * 60;
                  });
                },
                child: const Text("Focus Again", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    }
  }

  void _safePop() {
    _timer?.cancel();
    _quoteTimer?.cancel();
    _audioPlayer.stop();
    WakelockPlus.disable();
    context.pop();
  }

  void _promptCustomTime(String title, ValueChanged<int> onSave) {
    final TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        scrollable: true,
        title: Text("Custom $title", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), autofocus: true,
          decoration: InputDecoration(hintText: "Enter minutes (e.g. 50)", hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.white.withValues(alpha: 0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
            onPressed: () {
              int? val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0) { onSave(val); Navigator.pop(ctx); } else { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Enter a valid number"))); }
            },
            child: const Text("Save", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // 🌟 NAYA: HISTORY UI
  void _showHistorySheet() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(color: const Color(0xFF121018).withValues(alpha: 0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: const Border(top: BorderSide(color: Colors.white12))),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.all(12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
              const Padding(padding: EdgeInsets.only(bottom: 16.0), child: Text("FOCUS ANALYTICS & HISTORY", style: TextStyle(color: Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final sessions = ref.watch(focusSessionNotifierProvider).valueOrNull ?? [];
                    if (sessions.isEmpty) return const Center(child: Text("No focus history yet.", style: TextStyle(color: Colors.white54)));
                    
                    return ListView.builder(
                      controller: scrollController, physics: const BouncingScrollPhysics(), itemCount: sessions.length, padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final bool isAborted = session.status.contains('Aborted') || session.status.contains('Failed');
                        final Color statusColor = isAborted ? Colors.redAccent : const Color(0xFF10B981);
                        final String timeSpent = "${session.actualDurationSeconds ~/ 60}m ${session.actualDurationSeconds % 60}s";

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(DateFormat('MMM d, yyyy - h:mm a').format(session.startTime), style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Text(session.status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.track_changes, color: Color(0xFF06B6D4), size: 14), const SizedBox(width: 6),
                                  Expanded(child: Text(session.taskName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text("Target: ${session.durationMinutes}m  •  Spent: $timeSpent", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              
                              if (session.capturedNotes.isNotEmpty) ...[
                                const Padding(padding: EdgeInsets.only(top: 12, bottom: 6), child: Text("CAPTURED NOTES:", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0))),
                                ...session.capturedNotes.map((note) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.only(top: 4, right: 6), child: Icon(Icons.circle, size: 4, color: Color(0xFFA78BFA))), Expanded(child: Text(note, style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)))],))),
                              ]
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDistractionScratchpad() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFF121018).withValues(alpha: 0.95), border: Border(top: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)))),
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.psychology, color: Color(0xFFA78BFA), size: 20)),
                        const SizedBox(width: 12),
                        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("BRAIN DUMP & SCRATCHPAD", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2)), Text("Jot distracting thoughts without breaking flow", style: TextStyle(color: Colors.white54, fontSize: 11))]),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: textController, autofocus: true, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 2,
                      decoration: InputDecoration(hintText: "What just popped into your head?", hintStyle: const TextStyle(color: Colors.white38, fontSize: 12), filled: true, fillColor: Colors.white.withValues(alpha: 0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFA78BFA)))),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: BorderSide(color: Colors.white.withValues(alpha: 0.2)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            onPressed: () {
                              final text = textController.text.trim();
                              if (text.isNotEmpty) {
                                setState(() => _distractionNotes.add(text));
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thought captured in session scratchpad."), duration: Duration(seconds: 2)));
                              }
                            },
                            icon: const Icon(Icons.note_add, size: 16), label: const Text("Keep Note", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            onPressed: () async {
                              final text = textController.text.trim();
                              if (text.isNotEmpty) {
                                await ref.read(taskNotifierProvider.notifier).addTask(title: text, category: "Quick Capture", priority: 1);
                                setState(() => _distractionNotes.add("📋 Task: $text"));
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved as Task: \"$text\""), backgroundColor: const Color(0xFF8B5CF6), duration: const Duration(seconds: 2))); }
                              }
                            },
                            icon: const Icon(Icons.add_task, size: 16), label: const Text("Save as Task", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    if (_distractionNotes.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text("CAPTURED THIS SESSION", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: ListView.builder(
                          shrinkWrap: true, itemCount: _distractionNotes.length,
                          itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [const Icon(Icons.circle, size: 6, color: Color(0xFFA78BFA)), const SizedBox(width: 8), Expanded(child: Text(_distractionNotes[i], style: const TextStyle(color: Colors.white70, fontSize: 12)))])),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTaskSelector() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: const Color(0xFF0D0A14).withValues(alpha: 0.9),
              child: Column(
                children: [
                  Container(margin: const EdgeInsets.all(12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
                  const Text("SELECT TARGET TASK", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final tasks = ref.watch(taskNotifierProvider).valueOrNull?.where((t) => !t.isCompleted).toList() ?? [];
                        if (tasks.isEmpty) return const Center(child: Text("No pending tasks. Create one in Command Center.", style: TextStyle(color: Colors.white54)));
                        return ListView.builder(
                          controller: scrollController, itemCount: tasks.length, physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemBuilder: (ctx, i) {
                            final t = tasks[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), tileColor: Colors.white.withValues(alpha: 0.05),
                              leading: const Icon(Icons.radio_button_unchecked, color: Colors.white38), title: Text(t.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text(t.category, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              onTap: () { setState(() => _selectedTask = t); context.pop(); },
                            );
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTimerSettings() {
    if (_isActive) return;
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1E1E1E), isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("FOCUS SETTINGS", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            const Text("Focus Duration", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                ...[10, 15, 25, 45, 60].map((mins) => ChoiceChip(label: Text("$mins m", style: const TextStyle(fontWeight: FontWeight.bold)), selected: _focusDurationMinutes == mins, selectedColor: const Color(0xFF06B6D4), onSelected: (_) { setState(() { _focusDurationMinutes = mins; if (_currentPhase == FocusPhase.focus) _timeLeftSeconds = mins * 60; }); context.pop(); })),
                ChoiceChip(label: const Text("Custom ✏️", style: TextStyle(fontWeight: FontWeight.bold)), selected: false, selectedColor: const Color(0xFF06B6D4), onSelected: (_) { context.pop(); _promptCustomTime("Focus Duration", (val) { setState(() { _focusDurationMinutes = val; if (_currentPhase == FocusPhase.focus) _timeLeftSeconds = val * 60; }); }); })
              ],
            ),
            const SizedBox(height: 24),
            
            const Text("Short Break Duration", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                ...[3, 5, 10, 15].map((mins) => ChoiceChip(label: Text("$mins m", style: const TextStyle(fontWeight: FontWeight.bold)), selected: _shortBreakMinutes == mins, selectedColor: const Color(0xFF10B981), onSelected: (_) { setState(() { _shortBreakMinutes = mins; if (_currentPhase == FocusPhase.shortBreak) _timeLeftSeconds = mins * 60; }); context.pop(); })),
                ChoiceChip(label: const Text("Custom ✏️", style: TextStyle(fontWeight: FontWeight.bold)), selected: false, selectedColor: const Color(0xFF10B981), onSelected: (_) { context.pop(); _promptCustomTime("Short Break", (val) { setState(() { _shortBreakMinutes = val; if (_currentPhase == FocusPhase.shortBreak) _timeLeftSeconds = val * 60; }); }); })
              ],
            ),
            const SizedBox(height: 24),

            const Text("Long Break Duration (After 4 Cycles)", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                ...[15, 20, 30].map((mins) => ChoiceChip(label: Text("$mins m", style: const TextStyle(fontWeight: FontWeight.bold)), selected: _longBreakMinutes == mins, selectedColor: Colors.amberAccent, onSelected: (_) { setState(() { _longBreakMinutes = mins; if (_currentPhase == FocusPhase.longBreak) _timeLeftSeconds = mins * 60; }); context.pop(); })),
                ChoiceChip(label: const Text("Custom ✏️", style: TextStyle(fontWeight: FontWeight.bold)), selected: false, selectedColor: Colors.amberAccent, onSelected: (_) { context.pop(); _promptCustomTime("Long Break", (val) { setState(() { _longBreakMinutes = val; if (_currentPhase == FocusPhase.longBreak) _timeLeftSeconds = val * 60; }); }); })
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String minutes = (_timeLeftSeconds ~/ 60).toString().padLeft(2, '0');
    final String seconds = (_timeLeftSeconds % 60).toString().padLeft(2, '0');

    Color accentColor = const Color(0xFF06B6D4);
    if (_currentPhase == FocusPhase.shortBreak) { accentColor = const Color(0xFF10B981); } 
    else if (_currentPhase == FocusPhase.longBreak) { accentColor = Colors.amberAccent; } 
    else if (_timeLeftSeconds <= 60 && _isActive) { accentColor = Colors.redAccent; }

    final double progressFraction = _totalPhaseSeconds > 0 ? (_timeLeftSeconds / _totalPhaseSeconds).clamp(0.0, 1.0) : 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      resizeToAvoidBottomInset: false, 
      body: Stack(
        children: [
          // 🌟 FIXED 360° OUT-OF-BOUNDS BREATHING WAVE 🌟
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                // Radius expands massively from 0.8 (black visible) to 2.5 (black completely out of screen)
                final double waveExpansion = _isActive ? 0.8 + (_pulseController.value * 2.0) : 0.8;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        accentColor.withValues(alpha: _isActive ? 0.15 : 0.05), // Center color
                        Colors.black, // Pushed completely out of bounds when expanded
                      ],
                      stops: const [0.2, 1.0], // Smooth fade towards edges
                      radius: waveExpansion,
                      center: Alignment.center,
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 30), onPressed: _isActive ? null : _safePop),
                      
                      // 🌟 HISTORY BUTTON 🌟
                      IconButton(icon: const Icon(Icons.history, color: Colors.white54, size: 24), onPressed: _isActive ? null : _showHistorySheet),

                      // Strict Mode Toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: _isStrictMode ? Colors.redAccent.withValues(alpha: 0.12) : Colors.white10, borderRadius: BorderRadius.circular(20), border: Border.all(color: _isStrictMode ? Colors.redAccent.withValues(alpha: 0.5) : Colors.transparent)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_isStrictMode ? Icons.shield : Icons.shield_outlined, size: 14, color: _isStrictMode ? Colors.redAccent : Colors.white54), const SizedBox(width: 6),
                            Text("Strict", style: TextStyle(color: _isStrictMode ? Colors.redAccent : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(width: 4),
                            Switch(value: _isStrictMode, activeThumbColor: Colors.redAccent, activeTrackColor: Colors.redAccent.withValues(alpha: 0.3), inactiveThumbColor: Colors.white54, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, onChanged: (val) => setState(() => _isStrictMode = val)),
                          ],
                        ),
                      ),

                      IconButton(
                        tooltip: "Zen Distraction Pad",
                        icon: Stack(children: [const Icon(Icons.psychology, color: Color(0xFFA78BFA), size: 26), if (_distractionNotes.isNotEmpty) Positioned(right: 0, top: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle)))]),
                        onPressed: _showDistractionScratchpad, 
                      ),
                      IconButton(icon: const Icon(Icons.settings, color: Colors.white54), onPressed: _isActive ? null : _showTimerSettings),
                    ],
                  ),
                ),

                const SizedBox(height: 6),
                _buildCycleStreakBar(),

                const Spacer(),

                AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: _isActive ? 0.15 : 1.0,
                  child: GestureDetector(
                    onTap: _isActive ? null : _showTaskSelector,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: _selectedTask != null ? accentColor.withValues(alpha: 0.5) : Colors.white12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_selectedTask != null ? Icons.track_changes : Icons.ads_click, size: 15, color: _selectedTask != null ? accentColor : Colors.white54), const SizedBox(width: 8),
                          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(_selectedTask != null ? _selectedTask!.title : "Select target task", style: TextStyle(color: _selectedTask != null ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // 🌟 MAIN ZEN TIMER 🌟
                GestureDetector(
                  onTap: _toggleTimer,
                  onLongPress: _cancelSession,
                  child: SizedBox(
                    width: 290, height: 290,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(child: CustomPaint(painter: _FocusProgressPainter(progress: progressFraction, accentColor: accentColor, isActive: _isActive))),
                        Container(
                          width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.4)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_currentPhase == FocusPhase.focus ? "DEEP WORK" : _currentPhase == FocusPhase.shortBreak ? "SHORT BREAK" : "LONG BREAK", style: TextStyle(color: accentColor.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 3.0)),
                              const SizedBox(height: 6),
                              Text("$minutes:$seconds", style: const TextStyle(color: Colors.white, fontSize: 74, fontWeight: FontWeight.w200, fontFeatures: [FontFeature.tabularFigures()])).animate(target: _isActive ? 1 : 0).shimmer(duration: 2000.ms, color: Colors.white24),
                              if (!_isActive) ...[const SizedBox(height: 10), const Text("TAP TO START", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0))] 
                              else if (_isActive && _isStrictMode) ...[const SizedBox(height: 10), const Icon(Icons.shield, color: Colors.redAccent, size: 15).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.3, 1.3), duration: const Duration(seconds: 1))]
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().scaleXY(begin: 0.92, duration: 600.ms, curve: Curves.easeOutBack),

                const SizedBox(height: 16),
                AnimatedOpacity(duration: const Duration(milliseconds: 300), opacity: _isActive ? 1.0 : 0.0, child: const Text("Hold circle to abort session", style: TextStyle(color: Colors.white24, fontSize: 10))),
                const Spacer(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    child: Text(_motivationalQuotes[_quoteIndex], key: ValueKey<int>(_quoteIndex), textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: _isActive ? 0.35 : 0.6), fontSize: 11, fontStyle: FontStyle.italic, height: 1.4)),
                  ),
                ),
                const SizedBox(height: 16),

                AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: _isActive ? 0.2 : 1.0,
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), border: const Border(top: BorderSide(color: Colors.white12))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.headphones, color: Colors.white54, size: 15), const SizedBox(width: 8),
                            const Text("SOUNDSCAPE AMBIENCE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)), const Spacer(),
                            if (_isMusicBuffering) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4))) else if (_isMusicPlaying) const Icon(Icons.graphic_eq, color: Color(0xFF06B6D4), size: 15).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1000.ms),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: _soundscapes.keys.length,
                            itemBuilder: (context, i) {
                              String name = _soundscapes.keys.elementAt(i); bool isSelected = _currentSoundscape == name;
                              return GestureDetector(
                                onTap: _isActive ? null : () => _toggleSoundscape(name),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(color: isSelected ? const Color(0xFF06B6D4).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? const Color(0xFF06B6D4).withValues(alpha: 0.6) : Colors.white12)),
                                  child: Center(child: Text(name, style: TextStyle(color: isSelected ? const Color(0xFF06B6D4) : Colors.white60, fontSize: 11, fontWeight: FontWeight.bold))),
                                ),
                              );
                            },
                          ),
                        ),
                        if (_currentSoundscape != 'None') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(_soundscapeVolume == 0 ? Icons.volume_mute : Icons.volume_down, color: Colors.white38, size: 16),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 12), activeTrackColor: const Color(0xFF06B6D4), inactiveTrackColor: Colors.white10, thumbColor: Colors.white),
                                  child: Slider(value: _soundscapeVolume, min: 0.0, max: 1.0, onChanged: (val) => _updateVolume(val)),
                                ),
                              ),
                              const Icon(Icons.volume_up, color: Colors.white38, size: 16), const SizedBox(width: 6),
                              Text("${(_soundscapeVolume * 100).round()}%", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 FIXED CYCLE DOTS LOGIC
  Widget _buildCycleStreakBar() {
    int cycleInBlock = _completedCycles % 4;
    if (_completedCycles > 0 && cycleInBlock == 0 && _currentPhase == FocusPhase.longBreak) cycleInBlock = 4;

    const Color dotColor = Color(0xFF06B6D4); 

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("CYCLE ${cycleInBlock == 0 && _completedCycles > 0 && _currentPhase == FocusPhase.focus ? 4 : cycleInBlock + 1}/4", style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(width: 10),
          Row(
            children: List.generate(4, (index) {
              final bool isCompleted = index < cycleInBlock;
              final bool isActiveCycle = index == cycleInBlock;
              
              Color currentColor = isCompleted 
                  ? dotColor 
                  : (isActiveCycle ? dotColor.withValues(alpha: _isActive ? 0.9 : 0.4) : Colors.white24);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActiveCycle && _isActive ? 10 : 8, height: isActiveCycle && _isActive ? 10 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: currentColor,
                  boxShadow: isCompleted || (isActiveCycle && _isActive) ? [BoxShadow(color: dotColor.withValues(alpha: 0.6), blurRadius: isActiveCycle ? 8 : 4)] : null,
                ),
              );
            }),
          ),
          if (_completedCycles > 0) ...[
            const SizedBox(width: 8),
            Text("• $_completedCycles done", style: const TextStyle(color: dotColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );
  }
}

class _FocusProgressPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final bool isActive;

  _FocusProgressPainter({required this.progress, required this.accentColor, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;

    final trackPaint = Paint()..color = Colors.white.withValues(alpha: 0.04)..style = PaintingStyle.stroke..strokeWidth = 6.0..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.0) return;

    if (isActive) {
      final glowPaint = Paint()..color = accentColor.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 14.0..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, glowPaint);
    }

    final progressPaint = Paint()..shader = SweepGradient(startAngle: 0.0, endAngle: 2 * math.pi, colors: [accentColor.withValues(alpha: 0.4), accentColor], transform: const GradientRotation(-math.pi / 2)).createShader(Rect.fromCircle(center: center, radius: radius))..style = PaintingStyle.stroke..strokeWidth = isActive ? 7.0 : 5.0..strokeCap = StrokeCap.round;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, progressPaint);

    if (progress > 0.01 && progress < 0.999) {
      final headAngle = startAngle + sweepAngle;
      final headX = center.dx + radius * math.cos(headAngle);
      final headY = center.dy + radius * math.sin(headAngle);
      final headPoint = Offset(headX, headY);

      final dotGlowPaint = Paint()..color = accentColor.withValues(alpha: 0.7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(headPoint, 6, dotGlowPaint);
      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(headPoint, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FocusProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accentColor != accentColor || oldDelegate.isActive != isActive;
  }
}