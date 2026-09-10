import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/search_providers.dart';
import '../../diary/data/diary_provider.dart';

// Global Design System
import '../../../core/themes/aether_colors.dart';
import '../../../core/themes/widgets/aether_ambient_background.dart';
import '../../../core/themes/widgets/aether_glass_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(globalSearchQueryProvider);
    final searchState = ref.watch(globalSearchEngineProvider);

    return Scaffold(
      backgroundColor: AetherColors.pureBlack, 
      body: AetherAmbientBackground(
        color1: AetherColors.analyticsCyan,
        color2: AetherColors.analyticsNeonPurple,
        child: SafeArea(
          child: Column(
            children: [
              // --- SEARCH BAR HEADER ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.read(globalSearchQueryProvider.notifier).state = '';
                        context.pop();
                      },
                    ),
                    Expanded(
                      child: AetherGlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        borderRadius: 30, // Pill shape
                        blur: 20,
                        opacity: 0.05,
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search OS Memory...',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            icon: Icon(Icons.manage_search, color: Colors.white38),
                          ),
                          onChanged: (value) => ref.read(globalSearchQueryProvider.notifier).state = value,
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- SEARCH RESULTS LIST ---
              Expanded(
                child: query.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hub_outlined, size: 80, color: Colors.white.withValues(alpha: 0.05)),
                            const SizedBox(height: 16),
                            Text("Awaiting query protocol...", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white38, letterSpacing: 1.2)),
                          ],
                        ).animate().fadeIn(delay: 200.ms),
                      )
                    : searchState.when(
                        loading: () => const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
                        error: (err, stack) => Center(child: Text("Search failed: $err", style: const TextStyle(color: Colors.redAccent))),
                        data: (results) {
                          if (results.isEmpty) {
                            return Center(
                              child: Text("No global data found for '$query'", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white38)),
                            ).animate().fadeIn();
                          }
                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final item = results[index];
                              final dateStr = DateFormat('MMM d, yyyy').format(item.date);
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    // Smart Routing based on module type
                                    if (item.type == 'diary') {
                                      final allDiaries = ref.read(diaryEntriesProvider).valueOrNull ?? [];
                                      final target = allDiaries.firstWhere((e) => e.id == item.id);
                                      context.push('/create', extra: target); 
                                    } else if (item.type == 'task') {
                                      context.push('/productivity');
                                    } else if (item.type == 'transaction') {
                                      context.push('/wallet');
                                    }
                                  },
                                  child: _buildResultCard(context, item, dateStr),
                                ),
                              ).animate().fadeIn(delay: Duration(milliseconds: 50 * (index < 10 ? index : 0))).slideY(begin: 0.1, end: 0);
                            },
                          );
                        }
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, SearchItemDto item, String dateStr) {
    IconData typeIcon;
    Color typeColor;

    switch (item.type) {
      case 'task': typeIcon = Icons.task_alt; typeColor = Colors.amberAccent; break;
      case 'transaction': typeIcon = Icons.account_balance_wallet; typeColor = Colors.greenAccent; break;
      default: typeIcon = Icons.my_library_books; typeColor = Colors.pinkAccent; break; // diary
    }

    return AetherGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(typeIcon, color: typeColor, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(item.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 18), overflow: TextOverflow.ellipsis)),
              Text(dateStr, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(item.extraBadge, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10, color: typeColor)),
          ),
          const SizedBox(height: 12),
          Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4, color: Colors.white60)),
        ],
      ),
    );
  }
}