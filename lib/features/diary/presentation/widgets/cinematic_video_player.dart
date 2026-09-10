import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CinematicVideoPlayer extends StatefulWidget {
  final String videoPath;

  const CinematicVideoPlayer({super.key, required this.videoPath});

  @override
  State<CinematicVideoPlayer> createState() => _CinematicVideoPlayerState();
}

class _CinematicVideoPlayerState extends State<CinematicVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
      });
      
    // Loop video by default for a cinematic feel
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        width: 200,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white38),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: 240,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. The Native Video Layer
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),

              // 2. Play/Pause Overlay Overlay
              if (!_controller.value.isPlaying)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 12)
                        ]
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                    ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
                  ),
                ),
                
              // 3. Media Type Badge
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.videocam, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text("VIDEO", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
}