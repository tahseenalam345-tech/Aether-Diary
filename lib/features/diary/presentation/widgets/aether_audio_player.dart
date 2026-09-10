import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AetherAudioPlayer extends StatefulWidget {
  final String audioPath;
  const AetherAudioPlayer({super.key, required this.audioPath});

  @override
  State<AetherAudioPlayer> createState() => _AetherAudioPlayerState();
}

class _AetherAudioPlayerState extends State<AetherAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    
    // Setup the player source
    _audioPlayer.setSourceDeviceFile(widget.audioPath);

    // Listen to real-time audio state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    HapticFeedback.lightImpact();
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play(DeviceFileSource(widget.audioPath));
    }
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.toString().padLeft(2, '0');
    String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // 1. Play/Pause Button
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isPlaying ? Colors.white.withValues(alpha: 0.2) : Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: _isPlaying ? [] : [
                        BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.4), blurRadius: 8)
                      ],
                    ),
                    child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 24),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 2. Progress Slider & Timer
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.mic, size: 12, color: Colors.white54),
                              SizedBox(width: 4),
                              Text("Voice Note", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text(
                            "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                            style: const TextStyle(color: Colors.white54, fontSize: 10, fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                          activeTrackColor: Theme.of(context).primaryColor,
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          min: 0,
                          max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                          value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0),
                          onChanged: (value) {
                            _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                          },
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
    );
  }
}