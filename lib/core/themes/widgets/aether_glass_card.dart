import 'dart:ui';
import 'package:flutter/material.dart';

class AetherGlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const AetherGlassCard({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.opacity = 0.03,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      // SCALABILITY OPTIMIZATION: 
      // HardEdge eliminates expensive anti-aliasing math on the GPU for the blur boundaries.
      clipBehavior: Clip.hardEdge, 
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08), // Outer rim highlight
              width: 1.5,
            ),
            boxShadow: [
              // Premium drop shadow for depth
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: -5,
                offset: const Offset(0, 10),
              ),
              // Inner glowing edge illusion
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.02),
                blurRadius: 0,
                spreadRadius: 1,
                offset: const Offset(0, 1),
              )
            ],
          ),
          // SCALABILITY OPTIMIZATION: 
          // Caches the internal child (text/icons) as a static texture. 
          // Prevents the text from re-rendering on every scroll frame.
          child: RepaintBoundary(child: child), 
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    
    return card;
  }
}