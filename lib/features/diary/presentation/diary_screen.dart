import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/models/diary_entry.dart';
import '../data/diary_provider.dart';
import '../../wallet/presentation/widgets/aether_liquid_date_picker.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedMood;
  DateTime? _selectedDate;
  String _selectedFolder = 'All';

  // Multi-Selection State
  bool _isSelectionMode = false;
  final Set<String> _selectedEntryIds = {};

  final List<String> _folders = ['All', 'Personal', 'Ideas', 'Work', 'Reflections', 'Gratitude'];

  final List<Map<String, dynamic>> _moods = [
    {'name': 'Happy', 'emoji': '😊', 'color': const Color(0xFFFFD700)},
    {'name': 'Calm', 'emoji': '🌊', 'color': const Color(0xFF4ADE80)},
    {'name': 'Sad', 'emoji': '🌧️', 'color': const Color(0xFF60A5FA)},
    {'name': 'Anxious', 'emoji': '⚡', 'color': const Color(0xFFF472B6)},
    {'name': 'Angry', 'emoji': '🔥', 'color': const Color(0xFFEF4444)},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedEntryIds.contains(id)) {
        _selectedEntryIds.remove(id);
        if (_selectedEntryIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedEntryIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedEntryIds.clear();
      _isSelectionMode = false;
    });
  }

  void _showBulkActionsSheet(List<DiaryEntry> allEntries) {
    final selectedEntries = allEntries.where((e) => _selectedEntryIds.contains(e.id)).toList();
    if (selectedEntries.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0C101E).withValues(alpha: 0.96),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Actions for ${selectedEntries.length} Reflections",
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Bulk Pin
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined, color: Color(0xFFFBBF24)),
                  title: const Text("Pin / Unpin Selected", style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(context);
                    final anyUnpinned = selectedEntries.any((e) => !e.isPinned);
                    await ref.read(diaryEntriesProvider.notifier).bulkPin(_selectedEntryIds.toList(), anyUnpinned);
                    _clearSelection();
                  },
                ),

                // Bulk Move to Folder
                ListTile(
                  leading: const Icon(Icons.folder_open_rounded, color: Color(0xFF38BDF8)),
                  title: const Text("Move to Folder", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _showMoveFolderDialog();
                  },
                ),

                // Bulk Share
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: Color(0xFF2DD4BF)),
                  title: const Text("Export & Share Combined", style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(context);
                    final combined = selectedEntries.map((e) => "=== ${e.title} ===\n${e.content}\n").join("\n\n");
                    await Share.share(combined);
                    _clearSelection();
                  },
                ),

                // Bulk Delete
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text("Delete Selected", style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF131826),
                        title: Text("Delete ${selectedEntries.length} entries?", style: const TextStyle(color: Colors.white)),
                        content: const Text("This cannot be undone.", style: TextStyle(color: Colors.white54)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Delete"),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(diaryEntriesProvider.notifier).bulkDelete(_selectedEntryIds.toList());
                      _clearSelection();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoveFolderDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0C101E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Move Selected to Folder", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _folders.where((f) => f != 'All').map((f) {
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(diaryEntriesProvider.notifier).bulkMoveFolder(_selectedEntryIds.toList(), f);
                    _clearSelection();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                    ),
                    child: Text(f, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncEntries = ref.watch(diaryEntriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              heroTag: null,
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/create');
              },
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: const Color(0xFF060B14),
              child: const Icon(Icons.add_rounded, size: 28),
            ).animate().scale(curve: Curves.easeOutBack),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 🌟 Top Navigation App Bar
            _buildAppBar(context, asyncEntries.valueOrNull ?? []),

            // 🌟 Folders & Categorization Pill Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    _buildSearchBar(),

                    const SizedBox(height: 14),

                    // Folders Bar
                    _buildFoldersBar(),

                    const SizedBox(height: 12),

                    // Mood & Date Quick Filter Chips
                    _buildMoodFilterBar(),
                  ],
                ),
              ),
            ),

            // 🌟 Entries List
            asyncEntries.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
              ),
              error: (err, _) => SliverFillRemaining(
                child: Center(child: Text("Error: $err", style: const TextStyle(color: Colors.redAccent))),
              ),
              data: (allEntries) {
                final filtered = allEntries.where((e) {
                  final matchQuery = _searchQuery.isEmpty ||
                      e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      e.content.toLowerCase().contains(_searchQuery.toLowerCase());
                  final matchMood = _selectedMood == null || e.mood == _selectedMood;
                  final matchFolder = _selectedFolder == 'All' || e.tags.contains(_selectedFolder);
                  final matchDate = _selectedDate == null ||
                      (e.createdAt.year == _selectedDate!.year &&
                          e.createdAt.month == _selectedDate!.month &&
                          e.createdAt.day == _selectedDate!.day);
                  return matchQuery && matchMood && matchFolder && matchDate;
                }).toList();

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyVault(),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = filtered[index];
                        final isSelected = _selectedEntryIds.contains(entry.id);
                        return _buildEntryCard(context, entry, isSelected);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 APP BAR WITH SELECTION AWARE CONTROLS
  // ---------------------------------------------------------------------------
  Widget _buildAppBar(BuildContext context, List<DiaryEntry> allEntries) {
    if (_isSelectionMode) {
      return SliverAppBar(
        backgroundColor: const Color(0xFF0C101E),
        pinned: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _clearSelection,
        ),
        title: Text(
          "${_selectedEntryIds.length} Selected",
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all, color: Colors.white70),
            onPressed: () {
              setState(() {
                if (_selectedEntryIds.length == allEntries.length) {
                  _selectedEntryIds.clear();
                } else {
                  _selectedEntryIds.addAll(allEntries.map((e) => e.id));
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
            onPressed: () => _showBulkActionsSheet(allEntries),
          ),
        ],
      );
    }

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        "SANCTUARY VAULT",
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.checklist_rounded, color: Colors.white70),
          tooltip: "Select Multiple",
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _isSelectionMode = true);
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 SEARCH BAR
  // ---------------------------------------------------------------------------
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: "Search reflections, tags or memories...",
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 FOLDERS / CATEGORIZATION PILL BAR
  // ---------------------------------------------------------------------------
  Widget _buildFoldersBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _folders.map((folder) {
          final isSelected = _selectedFolder == folder;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedFolder = folder);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 1.2 : 1.0,
                ),
              ),
              child: Text(
                folder,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 MOOD & DATE QUICK FILTER BAR
  // ---------------------------------------------------------------------------
  Widget _buildMoodFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Date Filter Button
          GestureDetector(
            onTap: () async {
              final picked = await showAetherLiquidDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                accentColor: const Color(0xFF38BDF8),
                title: "Filter by Date",
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _selectedDate != null ? const Color(0xFF38BDF8).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _selectedDate != null ? const Color(0xFF38BDF8) : Colors.white10),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: _selectedDate != null ? const Color(0xFF38BDF8) : Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    _selectedDate != null ? DateFormat('MMM d').format(_selectedDate!) : "Date",
                    style: TextStyle(color: _selectedDate != null ? const Color(0xFF38BDF8) : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  if (_selectedDate != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _selectedDate = null),
                      child: const Icon(Icons.close, size: 12, color: Colors.white54),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Mood Chips
          ..._moods.map((m) {
            final isSelected = _selectedMood == m['name'];
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedMood = isSelected ? null : m['name'];
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? (m['color'] as Color).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? (m['color'] as Color) : Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Text(m['emoji'], style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(m['name'], style: TextStyle(color: isSelected ? (m['color'] as Color) : Colors.white54, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 ENTRY CARD
  // ---------------------------------------------------------------------------
  Widget _buildEntryCard(BuildContext context, DiaryEntry entry, bool isSelected) {
    return GestureDetector(
      onLongPress: () => _toggleSelection(entry.id),
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(entry.id);
        } else {
          HapticFeedback.lightImpact();
          context.push('/create', extra: entry);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : (entry.isPinned ? const Color(0xFFFBBF24).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
            width: isSelected || entry.isPinned ? 1.3 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Top Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (_isSelectionMode) ...[
                        Icon(isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isSelected ? const Color(0xFF38BDF8) : Colors.white38, size: 18),
                        const SizedBox(width: 8),
                      ],
                      if (entry.isPinned) ...[
                        const Icon(Icons.push_pin_rounded, color: Color(0xFFFBBF24), size: 14),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        DateFormat('MMM d, yyyy • h:mm a').format(entry.createdAt),
                        style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (entry.mood != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(entry.mood!, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                entry.title.isNotEmpty ? entry.title : "Untitled Reflection",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Excerpt
              Text(
                entry.content.replaceAll('\n', ' ').trim(),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (entry.tags.isNotEmpty || entry.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    ...entry.tags.map((t) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text("#$t", style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                        )),
                    const Spacer(),
                    if (entry.attachments.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.attachment_rounded, color: Colors.white38, size: 14),
                          const SizedBox(width: 4),
                          Text("${entry.attachments.length}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyVault() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_stories_outlined, color: Colors.white24, size: 48),
          const SizedBox(height: 16),
          const Text("No Reflections Found", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty ? "Try changing your search terms" : "Tap the + button to capture your thoughts",
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}