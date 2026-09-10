import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive/hive.dart';
import '../../diary/data/diary_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _isAuthenticating = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometrics();
    });
  }

  Future<void> _triggerBiometrics() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    // 1. Check user preference from Hive Box to prevent blind triggering
    final settingsBox = await Hive.openBox('settings');
    final isBiometricEnabled = settingsBox.get('biometrics_enabled', defaultValue: false);
    
    if (!isBiometricEnabled) {
      if (mounted) context.go('/home');
      return;
    }

    final bioService = ref.read(biometricServiceProvider);
    
    // 2. Check if the phone actually has a fingerprint scanner setup
    final canAuth = await bioService.canAuthenticate();
    
    if (!canAuth) {
      if (mounted) context.go('/home');
      return;
    }

    // 3. Trigger the hardware scanner
    final authenticated = await bioService.authenticateUser();

    if (mounted) {
      setState(() => _isAuthenticating = false);
      
      if (authenticated) {
        context.go('/home');
      } else {
        setState(() => _errorMessage = 'Authentication failed. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)
                ]
              ),
              child: Icon(Icons.fingerprint, size: 80, color: Theme.of(context).primaryColor),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2.seconds),
            
            const SizedBox(height: 40),
            
            Text("AETHER", style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32, letterSpacing: 8)).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 12),
            Text("Your vault is locked", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54)).animate().fadeIn(delay: 400.ms),
            
            const SizedBox(height: 60),

            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
              ).animate().shake(),

            GestureDetector(
              onTap: _isAuthenticating ? null : _triggerBiometrics,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: _isAuthenticating 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Unlock", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.5, end: 0),
          ],
        ),
      ),
    );
  }
}