import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/module_preferences_provider.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/diary/presentation/diary_screen.dart';
import '../../features/productivity/presentation/productivity_screen.dart';
import '../../features/wallet/presentation/wallet_dashboard_screen.dart';

/// 🌟 DATA MODEL FOR DYNAMIC NAVIGATION DESTINATIONS
class _NavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color accentColor;
  final Widget screen;
  final String identifier;

  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.accentColor,
    required this.screen,
    required this.identifier,
  });
}

/// 🌟 MAIN SCAFFOLD WITH DYNAMIC LIQUID FLOATING NAVBAR 🌟
/// Rebuilds tabs dynamically when module preferences change in real time.
class MainScaffold extends ConsumerStatefulWidget {
  final int initialIndex;
  const MainScaffold({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainScaffold> createState() => MainScaffoldState();
}

class MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void switchTab(int index) {
    if (mounted) {
      setState(() => _currentIndex = index);
    }
  }

  void switchToModule(String identifier) {
    final destinations = _buildDestinations(ref.read(modulePreferencesProvider));
    final index = destinations.indexWhere((d) => d.identifier == identifier);
    if (index != -1) {
      switchTab(index);
    }
  }

  List<_NavDestination> _buildDestinations(ModulePreferences prefs) {
    final List<_NavDestination> list = [
      const _NavDestination(
        label: 'Home',
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view_rounded,
        accentColor: Color(0xFF2DD4BF), // Teal
        screen: HomeScreen(),
        identifier: 'home',
      ),
    ];

    if (prefs.isDiaryEnabled) {
      list.add(
        const _NavDestination(
          label: 'Diary',
          icon: Icons.auto_stories_outlined,
          selectedIcon: Icons.auto_stories_rounded,
          accentColor: Color(0xFF38BDF8), // Sky Blue
          screen: DiaryScreen(),
          identifier: 'diary',
        ),
      );
    }

    if (prefs.isProductivityEnabled) {
      list.add(
        const _NavDestination(
          label: 'Tasks',
          icon: Icons.bolt_outlined,
          selectedIcon: Icons.bolt_rounded,
          accentColor: Color(0xFFFBBF24), // Amber
          screen: ProductivityScreen(),
          identifier: 'productivity',
        ),
      );
    }

    if (prefs.isWealthEnabled) {
      list.add(
        const _NavDestination(
          label: 'Wealth',
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet_rounded,
          accentColor: Color(0xFF10B981), // Emerald
          screen: WalletDashboardScreen(),
          identifier: 'wealth',
        ),
      );
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(modulePreferencesProvider);
    final destinations = _buildDestinations(prefs);

    // Safety: Clamp index in case a tab was removed while active
    if (_currentIndex >= destinations.length) {
      _currentIndex = 0;
    }

    final activeDestination = destinations[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      body: Stack(
        children: [
          // 1. ACTIVE SCREEN BODY (Preserving state with IndexedStack)
          IndexedStack(
            index: _currentIndex,
            children: destinations.map((d) => d.screen).toList(),
          ),

          // 2. LIQUID FLOATING GLASS BOTTOM NAVBAR
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildFloatingGlassNavBar(destinations, activeDestination),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingGlassNavBar(
    List<_NavDestination> destinations,
    _NavDestination activeDestination,
  ) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E1A).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: activeDestination.accentColor.withValues(alpha: 0.22),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: activeDestination.accentColor.withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(destinations.length, (index) {
                  final item = destinations[index];
                  final isSelected = _currentIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _currentIndex = index);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? item.accentColor.withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                isSelected ? item.selectedIcon : item.icon,
                                color: isSelected ? item.accentColor : Colors.white38,
                                size: isSelected ? 23 : 21,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected ? item.accentColor : Colors.white38,
                                fontSize: 10.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
