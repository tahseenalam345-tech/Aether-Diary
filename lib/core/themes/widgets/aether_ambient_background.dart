import 'package:flutter/material.dart';

class AetherAmbientBackground extends StatelessWidget {
  final Widget child;
  final Color color1;
  final Color color2;

  const AetherAmbientBackground({
    super.key,
    required this.child,
    required this.color1,
    required this.color2,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Base Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color1, color2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // 2. Safe Noise Texture (Won't crash if asset is missing)
        Positioned.fill(
          child: Opacity(
            opacity: 0.05,
            child: Image.asset(
              'assets/images/noise.png',
              fit: BoxFit.cover,
              repeat: ImageRepeat.repeat,
              errorBuilder: (context, error, stackTrace) {
                // If noise.png is missing, fail silently and return empty box
                return const SizedBox.shrink(); 
              },
            ),
          ),
        ),
        // 3. Foreground Child
        child,
      ],
    );
  }
}