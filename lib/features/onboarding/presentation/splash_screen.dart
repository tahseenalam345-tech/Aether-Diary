import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    // Wait for the animation duration
    await Future.delayed(const Duration(milliseconds: 3500));
    
    // Open settings to check if this is the first time
    final settingsBox = await Hive.openBox('settings');
    final hasSeenOnboarding = settingsBox.get('has_seen_onboarding', defaultValue: false);

    if (mounted) {
      if (hasSeenOnboarding) {
        context.go('/home'); // Skip onboarding for returning users
      } else {
        context.go('/onboarding'); // Show onboarding for first-time users
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing Logo/Icon placeholder
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 10,
                  )
                ],
              ),
              child: const Icon(
                Icons.auto_awesome, // Premium sparkle icon
                size: 64,
                color: Colors.white,
              ),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2.seconds) // Breathing effect
            .fadeIn(duration: 1.seconds),
            
            const SizedBox(height: 30),
            
            // App Title with premium font
            Text(
              'Aether',
              style: Theme.of(context).textTheme.displayLarge,
            )
            .animate()
            .fadeIn(duration: 1.5.seconds, curve: Curves.easeOut)
            .slideY(begin: 0.2, end: 0, duration: 1.5.seconds, curve: Curves.easeOut),
            
            const SizedBox(height: 10),
            
            // Subtitle
            Text(
              'Your digital sanctuary.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                letterSpacing: 3,
              ),
            )
            .animate()
            .fadeIn(delay: 1.seconds, duration: 1.seconds),
          ],
        ),
      ),
    );
  }
}