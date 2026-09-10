import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/aether_attachment.dart';

class CinematicImageViewer extends StatefulWidget {
  final List<AetherAttachment> attachments;
  final int initialIndex;

  const CinematicImageViewer({
    super.key,
    required this.attachments,
    this.initialIndex = 0,
  });

  @override
  State<CinematicImageViewer> createState() => _CinematicImageViewerState();
}

class _CinematicImageViewerState extends State<CinematicImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Hide status bar for true fullscreen immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Restore status bar when leaving
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleUI,
        child: Stack(
          children: [
            // 1. THE IMAGE PAGER
            PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(), // Safe here (PageView accepts physics)
              onPageChanged: (index) {
                HapticFeedback.selectionClick();
                setState(() => _currentIndex = index);
              },
              itemCount: widget.attachments.length,
              itemBuilder: (context, index) {
                final attachment = widget.attachments[index];
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  // THE PATCH: Removed the invalid physics parameter from here
                  child: Hero(
                    tag: attachment.id,
                    child: Image.file(
                      File(attachment.path),
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),

            // 2. THE GLASSMORPHISM APP BAR
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: _showUI ? 0 : -100,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 16,
                      bottom: 16,
                      left: 16,
                      right: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${_currentIndex + 1} / ${widget.attachments.length}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // Balance for centering
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}