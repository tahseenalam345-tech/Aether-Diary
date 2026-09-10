import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/productivity_providers.dart';
import '../domain/models/aether_habit.dart';
import '../domain/models/aether_task.dart';
import '../../../../core/services/task_notification_service.dart';
import 'habits_analytics_screen.dart';

enum HabitSortOption { defaultOrder, streak, alphabetical, completion }

const Color themeAccent = Color(0xFFF59E0B); 

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  final Set<String> _selectedHabits = {};
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedMode = 'All'; 
  HabitSortOption _sortOption = HabitSortOption.defaultOrder;
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedHabits.contains(id)) {
        _selectedHabits.remove(id);
      } else {
        _selectedHabits.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedHabits.clear());
  }

  void _selectAll(List<AetherHabit> visibleHabits) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_selectedHabits.length == visibleHabits.length) {
        _selectedHabits.clear();
      } else {
        _selectedHabits..clear()..addAll(visibleHabits.map((h) => h.id));
      }
    });
  }

  // =====================================
  // JSON BACKUP SYSTEM (RESTORED)
  // =====================================
  Future<void> _exportBackup(List<AetherHabit> allHabits) async {
    try {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preparing system backup..."), 
          backgroundColor: Color(0xFF1E1E1E), 
          behavior: SnackBarBehavior.floating
        )
      );
      
      List<Map<String, dynamic>> backupData = allHabits.map((h) => {
        'id': h.id,
        'title': h.title,
        'iconEmoji': h.iconEmoji,
        'createdAt': h.createdAt.toIso8601String(),
        'habitType': h.habitType,
        'target': h.target,
        'unit': h.unit,
        'activeDays': h.activeDays,
        'schedule': h.schedule,
        'history': h.history,
        'lifecycle': h.lifecycle,
        'startDate': h.startDate?.toIso8601String(),
        'endDate': h.endDate?.toIso8601String(),
        'priority': h.priority,
        'isPinned': h.isPinned,
        'reminders': h.reminders,
        'lastMovedToTop': h.lastMovedToTop?.toIso8601String(),
        'category': h.category,
        'description': h.description,
      }).toList();

      String jsonString = jsonEncode(backupData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/aether_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'Aether Routines Backup Data');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Backup failed: $e"), backgroundColor: Colors.redAccent));
    }
  }

  // =====================================
  // GLOBAL ALARM PICKER (RESTORED)
  // =====================================
  Future<void> _showGlobalAlarmPicker() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: themeAccent, surface: Color(0xFF1A1A1A), onSurface: Colors.white),
            dialogBackgroundColor: const Color(0xFF1A1A1A),
          ),
          child: child!,
        );
      },
    );

    if (time != null && mounted) {
      await GlobalNotificationEngine().scheduleDailyHabitReminder(
        id: 999999,
        title: "Aether Routines",
        body: "Time to check your daily systems and routines!",
        hour: time.hour,
        minute: time.minute,
        soundFile: 'default.wav',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Global Alarm set for ${time.format(context)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)), 
          backgroundColor: themeAccent, 
          behavior: SnackBarBehavior.floating, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        )
      );
    }
  }

  // =====================================
  // PDF REPORT EXPORT
  // =====================================
  String _cleanTextForPdf(String text) {
    return text.replaceAll(RegExp(r'[^\x00-\x7F]+'), '').trim();
  }

  void _exportReportDialog() {
    if (_isExporting) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Export PDF Report", style: TextStyle(color: themeAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text("All Routines", style: TextStyle(color: Colors.white)), onTap: () => _generateExport('all', ctx)),
            ListTile(title: const Text("High Priority", style: TextStyle(color: Colors.white)), onTap: () => _generateExport('priority', ctx)),
            ListTile(title: const Text("Archived", style: TextStyle(color: Colors.white)), onTap: () => _generateExport('archived', ctx)),
          ],
        ),
      )
    );
  }

  Future<void> _generateExport(String filter, BuildContext ctx) async {
    Navigator.pop(ctx);
    setState(() => _isExporting = true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generating PDF...", style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF1E1E1E), behavior: SnackBarBehavior.floating));

    try {
      final habits = ref.read(habitNotifierProvider).valueOrNull ?? [];
      List<AetherHabit> filtered = [];
      final now = DateTime.now();

      if (filter == 'all') filtered = habits.where((h) => h.lifecycle == 'active').toList();
      else if (filter == 'priority') filtered = habits.where((h) => h.lifecycle == 'active' && h.priority == 2).toList();
      else if (filter == 'archived') filtered = habits.where((h) => h.lifecycle == 'archived').toList();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("AETHER OS ROUTINE REPORT", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                    pw.Text(DateFormat('MMM d, yyyy').format(now), style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ]
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("REPORT TYPE: ${filter.toUpperCase()}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
              pw.Text("Total Routines: ${filtered.length}", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              pw.SizedBox(height: 20),

              if (filtered.isEmpty)
                pw.Center(child: pw.Text("No routines found for this filter.", style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 14)))
              else
                ...filtered.map((h) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      color: PdfColors.white,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                _cleanTextForPdf(h.title), 
                                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black)
                              )
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(color: h.priority == 2 ? PdfColors.red100 : h.priority == 1 ? PdfColors.orange100 : PdfColors.blueGrey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                              child: pw.Text(h.priority == 2 ? 'HIGH' : h.priority == 1 ? 'MED' : 'LOW', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: h.priority == 2 ? PdfColors.red800 : h.priority == 1 ? PdfColors.orange800 : PdfColors.blueGrey800)),
                            )
                          ]
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          children: [
                            pw.Text("Type: ${h.habitType.toUpperCase()}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                            pw.SizedBox(width: 12),
                            pw.Text("Category: ${_cleanTextForPdf(h.category)}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700)),
                          ]
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text("Streak: ${h.currentStreak} Days | Completion Rate: ${(h.completionRate * 100).toStringAsFixed(0)}%", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                        if (h.description.isNotEmpty) ...[
                          pw.SizedBox(height: 6),
                          pw.Text(_cleanTextForPdf(h.description), style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800, fontStyle: pw.FontStyle.italic)),
                        ],
                      ]
                    )
                  );
                }),
            ];
          },
        ),
      );

      Directory? downloadDir;
      if (Platform.isAndroid) {
        downloadDir = await getDownloadsDirectory(); 
      }
      downloadDir ??= await getApplicationDocumentsDirectory();

      final path = '${downloadDir.path}/Aether_Routines_${now.millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Saved to Downloads!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: "Share / Open", 
          textColor: Colors.black, 
          backgroundColor: Colors.white,
          onPressed: () => Share.shareXFiles([XFile(file.path)], text: 'Aether OS Routines Report - ${filter.toUpperCase()}')
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to generate PDF: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _handleMenuAction(String action, List<AetherHabit> allHabits) {
    HapticFeedback.lightImpact();
    final notifier = ref.read(habitNotifierProvider.notifier);

    switch (action) {
      case 'export_pdf': _exportReportDialog(); break;
      case 'export_backup': _exportBackup(allHabits); break;
      case 'global_alarm': _showGlobalAlarmPicker(); break;
      case 'view_archives': setState(() => _selectedMode = 'archived'); break;
      case 'pin':
        for (var id in _selectedHabits) notifier.togglePin(allHabits.firstWhere((h) => h.id == id));
        _clearSelection(); break;
      case 'top':
        for (var id in _selectedHabits) notifier.moveToTop(allHabits.firstWhere((h) => h.id == id));
        _clearSelection(); break;
      case 'duplicate':
        for (var id in _selectedHabits) notifier.duplicateHabit(allHabits.firstWhere((h) => h.id == id));
        _clearSelection(); break;
      case 'edit':
        if (_selectedHabits.length == 1) {
          final habit = allHabits.firstWhere((h) => h.id == _selectedHabits.first);
          _clearSelection();
          _showSmartHabitBuilder(editHabit: habit);
        }
        break;
      case 'archive':
        for (var id in _selectedHabits) {
          final habit = allHabits.firstWhere((h) => h.id == id);
          habit.lifecycle = 'archived';
          notifier.saveHabit(habit);
        }
        _clearSelection();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Habit Archived"), backgroundColor: Color(0xFF1E1E1E), behavior: SnackBarBehavior.floating));
        break;
      case 'unarchive':
        for (var id in _selectedHabits) {
          final habit = allHabits.firstWhere((h) => h.id == id);
          habit.lifecycle = 'active';
          notifier.saveHabit(habit);
        }
        _clearSelection();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Habit Restored"), backgroundColor: Color(0xFF1E1E1E), behavior: SnackBarBehavior.floating));
        break;
      case 'delete':
        for (var habit in allHabits.where((h) => _selectedHabits.contains(h.id))) _deleteWithUndo(habit);
        _clearSelection();
        break;
    }
  }

  void _deleteWithUndo(AetherHabit habit) {
    final snapshot = habit.copy();
    ref.read(habitNotifierProvider.notifier).deleteHabit(habit);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Deleted '${habit.title}'", style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: "Undo", textColor: themeAccent,
          onPressed: () {
            ref.read(habitNotifierProvider.notifier).addHabit(snapshot);
            if (snapshot.reminders.isNotEmpty) GlobalNotificationEngine().scheduleHabitRemindersFromStringList(snapshot.id, snapshot.title, snapshot.reminders);
          },
        ),
      ),
    );
  }

  void _showSmartHabitBuilder({AetherHabit? editHabit}) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context, 
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: Material(
            color: Colors.transparent, 
            child: _SmartHabitBuilderDialog(editHabit: editHabit)
          )
        )
      ),
    );
  }

  List<AetherHabit> _applyFilters(List<AetherHabit> habits) {
    var result = habits.where((h) {
      if (_selectedMode == 'archived') return h.lifecycle == 'archived';
      if (h.lifecycle == 'archived') return false; 

      final matchesMode = _selectedMode == 'All' || h.habitType == _selectedMode;
      final matchesCategory = _selectedCategory == 'All' || h.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || h.title.toLowerCase().contains(_searchQuery.toLowerCase()) || h.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesMode && matchesCategory && matchesSearch;
    }).toList();

    switch (_sortOption) {
      case HabitSortOption.streak: result.sort((a, b) => b.currentStreak.compareTo(a.currentStreak)); break;
      case HabitSortOption.alphabetical: result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())); break;
      case HabitSortOption.completion: result.sort((a, b) => b.completionRate.compareTo(a.completionRate)); break;
      case HabitSortOption.defaultOrder: break;
    }
    return result;
  }

  Widget _buildModeFilterBox(String mode, String label, IconData icon, Color color, int count, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedMode = mode);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color.withValues(alpha: 0.5) : Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.white54, size: 16),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(count.toString(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitNotifierProvider);
    final isSelectionMode = _selectedHabits.isNotEmpty;
    final isArchivedView = _selectedMode == 'archived';

    final popupShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.1)));
    final popupColor = const Color(0xFF1A1A1A).withValues(alpha: 0.98);

    return Scaffold(
      backgroundColor: Colors.transparent,

      floatingActionButton: (isSelectionMode || isArchivedView) ? null : Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [themeAccent, themeAccent.withValues(alpha: 0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: themeAccent.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8))],
        ),
        child: FloatingActionButton(
          heroTag: null,
          onPressed: () => _showSmartHabitBuilder(),
          backgroundColor: Colors.transparent, elevation: 0, highlightElevation: 0,
          child: const Icon(Icons.add, color: Colors.black, size: 28),
        ),
      ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),

      body: HabitsDoodleBackground(
        child: SafeArea(
          child: habitsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: themeAccent)),
            error: (e, st) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.redAccent))),
            data: (allHabits) {
              final visibleHabits = _applyFilters(allHabits);
              final categories = allHabits.where((h) => h.lifecycle != 'archived').map((h) => h.category).where((c) => c.trim().isNotEmpty).toSet().toList()..sort();

              Map<String, int> modeCounts = {'simple': 0, 'multi': 0, 'quantity': 0, 'negative': 0, 'checklist': 0, 'timer': 0};
              int archivedCount = 0;
              
              for(var h in allHabits) {
                if (h.lifecycle == 'archived') {
                  archivedCount++;
                } else {
                  if(modeCounts.containsKey(h.habitType)) modeCounts[h.habitType] = modeCounts[h.habitType]! + 1;
                }
              }
              final activeCount = allHabits.length - archivedCount;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: isSelectionMode ? themeAccent.withValues(alpha: 0.2) : const Color(0xFF101012).withValues(alpha: 0.90),
                    flexibleSpace: isSelectionMode ? null : ClipRect(
                      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent)),
                    ),
                    elevation: 0, pinned: true, centerTitle: true,
                    leading: isSelectionMode
                        ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _clearSelection)
                        : (_isSearching ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70), onPressed: () => setState(() { _isSearching = false; _searchQuery = ''; _searchController.clear(); }))
                                        : IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70), onPressed: () => context.pop())),

                    title: _isSearching
                        ? TextField(controller: _searchController, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Search routines...", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none), onChanged: (v) => setState(() => _searchQuery = v))
                        : Text(isSelectionMode ? "${_selectedHabits.length} Selected" : "ROUTINES", style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 22, color: Colors.white, letterSpacing: 1.5, shadows: [const Shadow(color: Colors.black87, blurRadius: 4)])),

                    actions: [
                      if (isSelectionMode)
                        IconButton(icon: Icon(_selectedHabits.length == visibleHabits.length ? Icons.deselect : Icons.select_all, color: Colors.white), onPressed: () => _selectAll(visibleHabits)),

                      if (!isSelectionMode && !_isSearching) ...[
                        IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () => setState(() => _isSearching = true)),
                        PopupMenuButton<HabitSortOption>(
                          icon: const Icon(Icons.sort, color: Colors.white), color: popupColor, shape: popupShape, elevation: 8, offset: const Offset(0, 40),
                          onSelected: (v) => setState(() => _sortOption = v),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: HabitSortOption.defaultOrder, child: Row(children: [Icon(Icons.format_list_bulleted, color: Colors.white70, size: 18), SizedBox(width: 12), Text("Default (Priority)", style: TextStyle(color: Colors.white))])),
                            const PopupMenuItem(value: HabitSortOption.streak, child: Row(children: [Icon(Icons.local_fire_department, color: Colors.amber, size: 18), SizedBox(width: 12), Text("Longest Streak", style: TextStyle(color: Colors.white))])),
                            const PopupMenuItem(value: HabitSortOption.alphabetical, child: Row(children: [Icon(Icons.sort_by_alpha, color: Colors.white70, size: 18), SizedBox(width: 12), Text("Alphabetical", style: TextStyle(color: Colors.white))])),
                            const PopupMenuItem(value: HabitSortOption.completion, child: Row(children: [Icon(Icons.pie_chart, color: Colors.greenAccent, size: 18), SizedBox(width: 12), Text("Completion Rate", style: TextStyle(color: Colors.white))])),
                          ],
                        ),
                      ],

                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white), color: popupColor, shape: popupShape, elevation: 8, offset: const Offset(0, 40),
                        onSelected: (action) => _handleMenuAction(action, allHabits),
                        itemBuilder: (BuildContext context) {
                          if (!isSelectionMode) return [
                            const PopupMenuItem(value: 'global_alarm', child: Row(children: [Icon(Icons.alarm_add, color: Colors.white, size: 20), SizedBox(width: 12), Text("Set Global Alarm", style: TextStyle(color: Colors.white))])),
                            const PopupMenuDivider(height: 1),
                            const PopupMenuItem(value: 'export_pdf', child: Row(children: [Icon(Icons.picture_as_pdf, color: themeAccent, size: 20), SizedBox(width: 12), Text("Export PDF Report", style: TextStyle(color: themeAccent))])),
                            const PopupMenuItem(value: 'export_backup', child: Row(children: [Icon(Icons.cloud_download, color: Colors.greenAccent, size: 20), SizedBox(width: 12), Text("Export Backup (JSON)", style: TextStyle(color: Colors.greenAccent))])),
                            const PopupMenuDivider(height: 1),
                            const PopupMenuItem(value: 'view_archives', child: Row(children: [Icon(Icons.archive, color: Colors.grey, size: 20), SizedBox(width: 12), Text("View Archives", style: TextStyle(color: Colors.grey))])),
                          ];
                          else if (_selectedHabits.length == 1) {
                            if (isArchivedView) {
                              return [
                                const PopupMenuItem(value: 'unarchive', child: Row(children: [Icon(Icons.unarchive, color: Colors.white, size: 20), SizedBox(width: 12), Text("Restore Habit", style: TextStyle(color: Colors.white))])),
                                const PopupMenuDivider(height: 1),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, color: Colors.redAccent, size: 20), SizedBox(width: 12), Text("Permanent Delete", style: TextStyle(color: Colors.redAccent))])),
                              ];
                            }
                            return [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: themeAccent, size: 20), SizedBox(width: 12), Text("Edit Routine", style: TextStyle(color: Colors.white))])),
                              const PopupMenuItem(value: 'pin', child: Row(children: [Icon(Icons.push_pin_outlined, color: Colors.white, size: 20), SizedBox(width: 12), Text("Pin / Unpin", style: TextStyle(color: Colors.white))])),
                              const PopupMenuItem(value: 'top', child: Row(children: [Icon(Icons.vertical_align_top, color: Colors.white, size: 20), SizedBox(width: 12), Text("Move to Top", style: TextStyle(color: Colors.white))])),
                              const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy, color: Colors.white, size: 20), SizedBox(width: 12), Text("Duplicate", style: TextStyle(color: Colors.white))])),
                              const PopupMenuItem(value: 'archive', child: Row(children: [Icon(Icons.archive_outlined, color: Colors.white, size: 20), SizedBox(width: 12), Text("Archive", style: TextStyle(color: Colors.white))])),
                              const PopupMenuDivider(height: 1),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), SizedBox(width: 12), Text("Delete", style: TextStyle(color: Colors.redAccent))])),
                            ];
                          } else {
                            if (isArchivedView) {
                              return [
                                const PopupMenuItem(value: 'unarchive', child: Row(children: [Icon(Icons.unarchive, color: Colors.white, size: 20), SizedBox(width: 12), Text("Restore Selected", style: TextStyle(color: Colors.white))])),
                                const PopupMenuDivider(height: 1),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, color: Colors.redAccent, size: 20), SizedBox(width: 12), Text("Delete Permanent", style: TextStyle(color: Colors.redAccent))])),
                              ];
                            }
                            return [
                              const PopupMenuItem(value: 'pin', child: Row(children: [Icon(Icons.push_pin_outlined, color: Colors.white, size: 20), SizedBox(width: 12), Text("Pin Selected", style: TextStyle(color: Colors.white))])),
                              const PopupMenuItem(value: 'archive', child: Row(children: [Icon(Icons.archive_outlined, color: Colors.white, size: 20), SizedBox(width: 12), Text("Archive Selected", style: TextStyle(color: Colors.white))])),
                              const PopupMenuDivider(height: 1),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), SizedBox(width: 12), Text("Delete Selected", style: TextStyle(color: Colors.redAccent))])),
                            ];
                          }
                        },
                      ),
                    ],
                  ),

                  if (!isSelectionMode && allHabits.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        height: 40,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildModeFilterBox('All', 'All Systems', Icons.apps, Colors.white, activeCount, _selectedMode == 'All'),
                            if (modeCounts['simple']! > 0) _buildModeFilterBox('simple', 'Simple', Icons.task_alt, const Color(0xFF3B82F6), modeCounts['simple']!, _selectedMode == 'simple'),
                            if (modeCounts['multi']! > 0) _buildModeFilterBox('multi', 'Timeline', Icons.timeline, const Color(0xFF8B5CF6), modeCounts['multi']!, _selectedMode == 'multi'),
                            if (modeCounts['quantity']! > 0) _buildModeFilterBox('quantity', 'Quantity', Icons.water_drop, const Color(0xFF06B6D4), modeCounts['quantity']!, _selectedMode == 'quantity'),
                            if (modeCounts['timer']! > 0) _buildModeFilterBox('timer', 'Focus', Icons.timer, const Color(0xFF10B981), modeCounts['timer']!, _selectedMode == 'timer'),
                            if (modeCounts['checklist']! > 0) _buildModeFilterBox('checklist', 'Checklist', Icons.checklist, const Color(0xFFF59E0B), modeCounts['checklist']!, _selectedMode == 'checklist'),
                            if (modeCounts['negative']! > 0) _buildModeFilterBox('negative', 'Avoid', Icons.block, const Color(0xFFEF4444), modeCounts['negative']!, _selectedMode == 'negative'),
                            _buildModeFilterBox('archived', 'Archived', Icons.archive, Colors.grey, archivedCount, _selectedMode == 'archived'),
                          ],
                        ),
                      ),
                    ),

                  if (!isSelectionMode && !isArchivedView)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 28, 
                                child: ListView(
                                  scrollDirection: Axis.horizontal, 
                                  physics: const BouncingScrollPhysics(),
                                  children: [
                                    _CategoryChip(label: 'All', selected: _selectedCategory == 'All', onTap: () => setState(() => _selectedCategory = 'All')),
                                    if (categories.isNotEmpty) ...categories.map((c) => Padding(padding: const EdgeInsets.only(left: 6), child: _CategoryChip(label: c, selected: _selectedCategory == c, onTap: () => setState(() => _selectedCategory = c)))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HabitsAnalyticsScreen())),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFF59E0B)]),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Text("📊", style: TextStyle(fontSize: 14)),
                                    SizedBox(width: 4),
                                    Text("Stats", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),

                  if (visibleHabits.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          isArchivedView ? "No archived routines." : (allHabits.isEmpty ? "System empty.\nDeploy a new routine via the Emerald core." : "No routines match your filters."), 
                          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(color: Colors.black87, blurRadius: 4)])
                        ).animate().fadeIn(),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                      sliver: SliverReorderableList(
                        itemCount: visibleHabits.length,
                        itemBuilder: (context, index) {
                          final habit = visibleHabits[index];
                          final isSelected = _selectedHabits.contains(habit.id);

                          return KeyedSubtree(
                            key: ValueKey(habit.id),
                            child: Dismissible(
                              key: ValueKey('d_${habit.id}'), 
                              direction: isSelectionMode ? DismissDirection.none : DismissDirection.horizontal,
                              background: Container(
                                alignment: Alignment.centerLeft, 
                                padding: const EdgeInsets.only(left: 24), 
                                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(16)), 
                                child: const Icon(Icons.push_pin, color: Colors.amberAccent)
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight, 
                                padding: const EdgeInsets.only(right: 24), 
                                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(16)), 
                                child: const Icon(Icons.delete, color: Colors.redAccent)
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) { 
                                  ref.read(habitNotifierProvider.notifier).togglePin(habit); 
                                  return false; 
                                } else { 
                                  _deleteWithUndo(habit); 
                                  return false; 
                                }
                              },
                              child: _HabitCard(
                                index: index, 
                                habit: habit, 
                                today: DateTime.now(), 
                                isSelected: isSelected, 
                                isSelectionMode: isSelectionMode,
                                onTap: () { 
                                  if (isSelectionMode) _toggleSelection(habit.id); 
                                  else setState(() {}); 
                                },
                                onLongPress: () => _toggleSelection(habit.id),
                                onMilestone: (streak) { 
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("🔥 $streak-day streak on '${habit.title}'!", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)), 
                                      backgroundColor: themeAccent, 
                                      behavior: SnackBarBehavior.floating, 
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                    )
                                  ); 
                                },
                              ),
                            ),
                          );
                        },
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = visibleHabits.removeAt(oldIndex);
                          visibleHabits.insert(newIndex, item);
                          
                          final now = DateTime.now();
                          for (int i = 0; i < visibleHabits.length; i++) {
                            visibleHabits[i].lastMovedToTop = now.subtract(Duration(seconds: i));
                            visibleHabits[i].save();
                          }
                          
                          HapticFeedback.lightImpact();
                          ref.read(habitNotifierProvider.notifier).saveHabit(visibleHabits.first); 
                        },
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        alignment: Alignment.center, 
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
        decoration: BoxDecoration(
          color: selected ? themeAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.03), 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: selected ? themeAccent : Colors.white12)
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 10, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

const _milestones = [7, 30, 100, 365];

class _HabitCard extends ConsumerStatefulWidget {
  final int index;
  final AetherHabit habit;
  final DateTime today;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(int streak) onMilestone;

  const _HabitCard({
    required this.index, 
    required this.habit, 
    required this.today, 
    required this.isSelected,
    required this.isSelectionMode, 
    required this.onTap, 
    required this.onLongPress, 
    required this.onMilestone,
  });

  @override
  ConsumerState<_HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends ConsumerState<_HabitCard> {
  bool _isExpanded = false;
  
  Timer? _runningTimer;
  DateTime? _timerStartTime;
  int _previouslyElapsed = 0;
  int _currentDisplaySeconds = 0;
  bool _isTimerRunning = false;
  final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();

  @override
  void dispose() {
    _runningTimer?.cancel();
    _cancelTimerNotification();
    super.dispose();
  }

  void _checkMilestone() {
    final streak = widget.habit.currentStreak;
    if (_milestones.contains(streak)) widget.onMilestone(streak);
  }

  void _showTimerNotification() {
    _localNotifs.show(
      id: widget.habit.id.hashCode,
      title: '⏱️ Focus Session Active',
      body: widget.habit.title,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('active_focus_timer', 'Focus Timers', channelDescription: 'Live sticky notification for active timers', importance: Importance.low, priority: Priority.low, ongoing: true, autoCancel: false, showWhen: true, usesChronometer: true, color: themeAccent)
      )
    );
  }

  void _cancelTimerNotification() {
    _localNotifs.cancel(id: widget.habit.id.hashCode);
  }

  void _startTimer() {
    _runningTimer?.cancel();
    setState(() { _isTimerRunning = true; _timerStartTime = DateTime.now(); });
    _showTimerNotification();
    _runningTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timerStartTime != null) {
        setState(() { _currentDisplaySeconds = _previouslyElapsed + DateTime.now().difference(_timerStartTime!).inSeconds; });
      }
    });
  }

  void _pauseTimer() {
    _runningTimer?.cancel();
    _cancelTimerNotification();
    setState(() {
      _isTimerRunning = false;
      if (_timerStartTime != null) {
        _previouslyElapsed += DateTime.now().difference(_timerStartTime!).inSeconds;
        _currentDisplaySeconds = _previouslyElapsed;
        _timerStartTime = null;
      }
    });
  }

  Future<void> _stopAndSaveTimer() async {
    _runningTimer?.cancel();
    _cancelTimerNotification();
    int totalElapsed = _previouslyElapsed;
    if (_timerStartTime != null) {
      totalElapsed += DateTime.now().difference(_timerStartTime!).inSeconds;
    }
    final minutes = totalElapsed / 60.0;
    if (minutes > 0) {
      await ref.read(habitNotifierProvider.notifier).updateQuantityProgress(widget.habit, widget.today, minutes);
      _checkMilestone();
    }
    setState(() { _isTimerRunning = false; _previouslyElapsed = 0; _currentDisplaySeconds = 0; _timerStartTime = null; });
  }

  Future<void> _showSkipDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context, barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent, elevation: 0, insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF0A0A0A).withValues(alpha: 0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Skip Routine", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                    child: TextField(controller: controller, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: const InputDecoration(isDense: true, hintText: "Reason (optional)", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => context.pop(), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: themeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: () {
                          String reason = controller.text.trim();
                          if (reason.isEmpty) reason = "Skipped without reason";
                          ref.read(habitNotifierProvider.notifier).skipHabit(widget.habit, widget.today, reason); 
                          if (mounted) context.pop(); 
                        },
                        child: const Text("Confirm Skip", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _undoSkip() async {
    HapticFeedback.mediumImpact();
    final defaultSessions = List.filled(widget.habit.schedule.length, 'P');
    widget.habit.saveRecord(widget.today, 0.0, defaultSessions, false, reason: '');
    await ref.read(habitNotifierProvider.notifier).saveHabit(widget.habit);
  }

  void _showHistoryTimeline(BuildContext context, Color modeColor) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) => _HistoryTimelineDialog(habit: widget.habit, modeColor: modeColor),
    );
  }

  String _generateSmartInsight() {
    final history = widget.habit.history;
    if (history.isEmpty) return "Start tracking to unlock insights.";
    
    int weekendTotal = 0;
    int weekendCompleted = 0;
    int weekdayTotal = 0;
    int weekdayCompleted = 0;
    
    for (var key in history.keys) {
      final date = DateTime.parse(key);
      final parts = history[key]!.split('|');
      final isCompleted = parts.length > 2 && parts[2] == 'true';
      
      if (date.weekday == 6 || date.weekday == 7) {
        weekendTotal++;
        if (isCompleted) weekendCompleted++;
      } else {
        weekdayTotal++;
        if (isCompleted) weekdayCompleted++;
      }
    }
    
    double weekendRate = weekendTotal > 0 ? weekendCompleted / weekendTotal : 0;
    double weekdayRate = weekdayTotal > 0 ? weekdayCompleted / weekdayTotal : 0;
    
    if (weekendTotal < 2 && weekdayTotal < 2) return "Keep going to build your data trend.";
    
    if (weekendRate > weekdayRate + 0.1) {
      return "💡 Insight: You are stronger on weekends! (${(weekendRate*100).toInt()}% vs ${(weekdayRate*100).toInt()}%)";
    } else if (weekdayRate > weekendRate + 0.1) {
      return "💡 Insight: Weekends disrupt your flow. Plan ahead! (${(weekdayRate*100).toInt()}% vs ${(weekendRate*100).toInt()}%)";
    } else if (weekendRate > 0.8 && weekdayRate > 0.8) {
      return "💡 Insight: Flawless consistency across the whole week!";
    } else {
      return "💡 Insight: Your routine is stable, push for a higher completion rate.";
    }
  }

  Color _getModeColor(String type) {
    switch (type) {
      case 'simple': return const Color(0xFF3B82F6); 
      case 'multi': return const Color(0xFF8B5CF6); 
      case 'quantity': return const Color(0xFF06B6D4); 
      case 'negative': return const Color(0xFFEF4444); 
      case 'checklist': return const Color(0xFFF59E0B); 
      case 'timer': return const Color(0xFF10B981); 
      default: return Colors.white54;
    }
  }

  IconData _getModeIcon(String type) {
    switch (type) {
      case 'simple': return Icons.task_alt;
      case 'multi': return Icons.timeline;
      case 'quantity': return Icons.water_drop;
      case 'negative': return Icons.block;
      case 'checklist': return Icons.checklist;
      case 'timer': return Icons.timer;
      default: return Icons.event;
    }
  }

  String _getMotivationalQuote(String type) {
    switch (type) {
      case 'simple': return "✨ Rooz ka kaam rooz • Daily action";
      case 'multi': return "🕌 Waqt ki pabandi • Master your time";
      case 'quantity': return "💧 Qatra qatra darya • Every drop counts";
      case 'negative': return "🚫 Sabar ka phal meetha • Stay strong";
      case 'checklist': return "☑️ Aik waqt mein aik kaam • Step by step";
      case 'timer': return "⏱️ Tawajjo hi taqat hai • Focus shapes reality";
      default: return "Aage barhte raho • Keep moving forward";
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 LINKING ECOSYSTEM: FETCH TASKS & CHECK PREREQUISITES
    final tasksAsync = ref.watch(taskNotifierProvider);
    final allTasks = tasksAsync.valueOrNull ?? [];
    List<AetherTask> allLinkedTasks = [];
    bool isLocked = false;

    if (widget.habit.linkedTaskIds.isNotEmpty) {
      allLinkedTasks = allTasks.where((t) => widget.habit.linkedTaskIds.contains(t.id)).toList();
      isLocked = allLinkedTasks.any((t) => !t.isCompleted); 
    }

    final record = widget.habit.getRecord(widget.today);
    final isDoneToday = record['isCompleted'];
    final isScheduled = widget.habit.isScheduledFor(widget.today);
    final skipReason = record['reason'] as String? ?? ""; 
    final isSkipped = skipReason.isNotEmpty && !isDoneToday;
    final isArchived = widget.habit.lifecycle == 'archived';

    String priorityEmoji = "⭐";
    if (widget.habit.priority == 0) priorityEmoji = "🧊";
    if (widget.habit.priority == 2) priorityEmoji = "🔥";

    final modeColor = _getModeColor(widget.habit.habitType);
    final modeIcon = _getModeIcon(widget.habit.habitType);
    
    // Dim the card if it's completed, skipped, archived, or LOCKED
    final isDimmed = isDoneToday || isSkipped || isArchived || isLocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () {
          if (widget.isSelectionMode) widget.onTap();
          else { HapticFeedback.selectionClick(); setState(() => _isExpanded = !_isExpanded); }
        },
        onLongPress: widget.onLongPress,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isDimmed && !widget.isSelectionMode ? 0.6 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141414), 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.isSelected ? modeColor : (isLocked ? Colors.redAccent.withValues(alpha: 0.3) : Colors.white12), width: widget.isSelected ? 2 : 1),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  Positioned(left: 0, top: 0, bottom: 0, width: 5, child: Container(decoration: BoxDecoration(color: isLocked ? Colors.redAccent : modeColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15))))),
                  
                  Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: isDoneToday ? modeColor : (isLocked ? Colors.redAccent.withValues(alpha: 0.1) : modeColor.withValues(alpha: 0.1)), shape: BoxShape.circle, border: Border.all(color: isLocked ? Colors.redAccent.withValues(alpha: 0.3) : modeColor.withValues(alpha: 0.3))),
                                child: Icon(isLocked ? Icons.lock : modeIcon, color: isDoneToday ? Colors.black : (isLocked ? Colors.redAccent : modeColor), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (widget.habit.isPinned) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin, color: Colors.white, size: 12)),
                                        if (isArchived) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.archive, color: Colors.grey, size: 12)),
                                        if (isLocked) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.lock, color: Colors.redAccent, size: 12)),
                                        Flexible(
                                          child: Text(
                                            widget.habit.title,
                                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            isArchived ? "• Archived Routine" : (!isScheduled ? "• Off day" : (isLocked ? "• Locked (Pending Tasks)" : (isDoneToday ? "• Completed" : "• Pending"))),
                                            style: TextStyle(color: isDoneToday ? modeColor : (isLocked ? Colors.redAccent : Colors.white54), fontSize: 10, fontWeight: FontWeight.bold),
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      if (widget.habit.priority == 2) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3))), child: const Text("HIGH", style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.w900)))
                                      else if (widget.habit.priority == 0) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3))), child: const Text("LOW", style: TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.w900))),
                                      const SizedBox(width: 4),
                                      Text(priorityEmoji, style: const TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                  if (widget.habit.category.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4)),
                                      child: Text(widget.habit.category, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                  if (widget.isSelectionMode) ...[
                                    const SizedBox(height: 12),
                                    Icon(widget.isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: widget.isSelected ? modeColor : Colors.white54, size: 18),
                                    const SizedBox(height: 16),
                                    ReorderableDragStartListener(
                                      index: widget.index,
                                      child: const Icon(Icons.drag_indicator, color: Colors.white54, size: 24),
                                    )
                                  ]
                                ],
                              ),
                            ],
                          ),
                          
                          if (isScheduled && !widget.isSelectionMode && !isArchived) ...[
                            const SizedBox(height: 8),
                            
                            // 🌟 ENFORCE LOCK ON ACTIONS 🌟
                            if (isLocked)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3))),
                                child: const Center(child: Text("🔒 LOCKED (COMPLETE TASKS FIRST)", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                              )
                            else if (isSkipped)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("🚫 TODAY: SKIPPED", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w900)),
                                    GestureDetector(onTap: _undoSkip, child: const Text("UNDO SKIP", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)))
                                  ],
                                ),
                              )
                            else ...[
                              if (widget.habit.habitType == 'simple') _buildSimpleAction(context, isDoneToday, modeColor),
                              if (widget.habit.habitType == 'negative') _buildNegativeAction(context, isDoneToday),
                              if (widget.habit.habitType == 'quantity') _buildQuantityAction(context, isDoneToday, modeColor),
                              if (widget.habit.habitType == 'timer') _buildTimerAction(context, isDoneToday, modeColor),
                              if (widget.habit.habitType == 'multi') _buildTimelineAction(context, modeColor),
                              if (widget.habit.habitType == 'checklist') _buildChecklistAction(context, record, modeColor),
                            ],
                          ],

                          if (!widget.isSelectionMode) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
                                    _getMotivationalQuote(widget.habit.habitType),
                                    style: TextStyle(color: modeColor.withValues(alpha: 0.8), fontSize: 10, fontStyle: FontStyle.italic, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                if (isScheduled && widget.habit.habitType != 'checklist' && !isDoneToday && !isSkipped && !isArchived && !isLocked)
                                  ElevatedButton.icon(
                                    onPressed: _showSkipDialog,
                                    icon: const Icon(Icons.next_plan, size: 14, color: Colors.white70),
                                    label: const Text("SKIP", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.1), elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      minimumSize: const Size(0, 30), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                
                                const SizedBox(width: 8),
                                Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white38, size: 24),
                              ],
                            ),
                          ],

                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            clipBehavior: Clip.hardEdge,
                            alignment: Alignment.topCenter,
                            child: (!_isExpanded || widget.isSelectionMode) ? const SizedBox.shrink() : Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(color: Colors.white12, height: 12),

                                  if (widget.habit.description.isNotEmpty) ...[
                                      Text(
                                        widget.habit.description, 
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                      const SizedBox(height: 12),
                                  ],

                                  // 🌟 LIVE CONTEXTUAL PREREQUISITE TASKS 🌟
                                  if (allLinkedTasks.isNotEmpty) ...[
                                    Text("LINKED PREREQUISITES (TASKS)", style: TextStyle(color: isLocked ? Colors.redAccent : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6, runSpacing: 6,
                                      children: allLinkedTasks.map((t) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: t.isCompleted ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05), 
                                          borderRadius: BorderRadius.circular(8), 
                                          border: Border.all(color: t.isCompleted ? const Color(0xFF10B981).withValues(alpha: 0.5) : (isLocked && !t.isCompleted ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white12))
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () { 
                                                HapticFeedback.lightImpact(); 
                                                ref.read(taskNotifierProvider.notifier).toggleTaskCompletion(t); 
                                              },
                                              child: Icon(t.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: t.isCompleted ? const Color(0xFF10B981) : (isLocked && !t.isCompleted ? Colors.redAccent : Colors.white54)),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(t.title, style: TextStyle(color: t.isCompleted ? Colors.white38 : Colors.white, fontSize: 11, fontWeight: FontWeight.bold, decoration: t.isCompleted ? TextDecoration.lineThrough : null)),
                                          ],
                                        ),
                                      )).toList(),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStatItem("🔥", "Current", "${widget.habit.currentStreak}"),
                                      _buildStatItem("🏆", "Best", "${widget.habit.longestStreak}"),
                                      _buildStatItem("📊", "Rate", "${(widget.habit.completionRate * 100).toStringAsFixed(0)}%"),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 10),
                                  const Text("THIS WEEK", style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                  const SizedBox(height: 6),
                                  _buildWeeklyChart(modeColor),

                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: themeAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: themeAccent.withValues(alpha: 0.3))),
                                    child: Text(
                                      _generateSmartInsight(), 
                                      style: const TextStyle(color: themeAccent, fontSize: 10, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                                      softWrap: true,
                                    ),
                                  ),

                                  const SizedBox(height: 10),
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () => _showHistoryTimeline(context, modeColor),
                                      icon: Icon(Icons.history, size: 14, color: modeColor),
                                      label: Text("MORE HISTORY", style: TextStyle(color: modeColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                                      style: TextButton.styleFrom(
                                        backgroundColor: modeColor.withValues(alpha: 0.1),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        minimumSize: Size.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(Color modeColor) {
    return Container(
      height: 65, 
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final d = widget.today.subtract(Duration(days: 6 - index));
          final record = widget.habit.getRecord(d);
          double pct = 0;
          
          if (widget.habit.habitType == 'negative') {
            pct = record['isCompleted'] ? 1.0 : (record['reason'].toString().isNotEmpty ? 0.2 : 0.0);
          } else {
            pct = widget.habit.target > 0 ? (record['progress'] / widget.habit.target).clamp(0.0, 1.0) : 0.0;
            if (widget.habit.habitType == 'simple' || widget.habit.habitType == 'checklist' || widget.habit.habitType == 'multi') {
              pct = record['isCompleted'] ? 1.0 : (record['reason'].toString().isNotEmpty ? 0.2 : 0.0);
            }
          }

          final isScheduled = widget.habit.isScheduledFor(d);
          final barColor = record['reason'].toString().isNotEmpty && !record['isCompleted'] ? Colors.redAccent : modeColor;
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 12,
                height: isScheduled ? math.max(4, 30 * pct) : 4,
                decoration: BoxDecoration(
                  color: isScheduled ? barColor.withValues(alpha: pct == 0 ? 0.2 : 1.0) : Colors.white10,
                  borderRadius: BorderRadius.circular(3)
                ),
              ),
              const SizedBox(height: 4),
              Text(DateFormat('E').format(d).substring(0,1), style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold))
            ]
          );
        })
      )
    );
  }

  Widget _buildSimpleAction(BuildContext context, bool isDoneToday, Color modeColor) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        await ref.read(habitNotifierProvider.notifier).updateSimpleProgress(widget.habit, widget.today, !isDoneToday);
        if (!isDoneToday) _checkMilestone();
      },
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: isDoneToday ? modeColor.withValues(alpha: 0.2) : modeColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDoneToday ? modeColor : Colors.transparent)),
        child: Center(child: Text(isDoneToday ? "COMPLETED" : "MARK AS DONE", style: TextStyle(color: isDoneToday ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
      ),
    );
  }

  Widget _buildNegativeAction(BuildContext context, bool resisted) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.selectionClick();
              await ref.read(habitNotifierProvider.notifier).updateNegativeStatus(widget.habit, widget.today, true);
              _checkMilestone();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: resisted ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.greenAccent, borderRadius: BorderRadius.circular(10), border: Border.all(color: resisted ? Colors.greenAccent : Colors.transparent)),
              child: Center(child: Text("RESISTED", style: TextStyle(color: resisted ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.w900))),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              await ref.read(habitNotifierProvider.notifier).updateNegativeStatus(widget.habit, widget.today, false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: !resisted ? Colors.redAccent.withValues(alpha: 0.2) : Colors.redAccent, borderRadius: BorderRadius.circular(10), border: Border.all(color: !resisted ? Colors.redAccent : Colors.transparent)),
              child: Center(child: Text("SLIPPED", style: TextStyle(color: !resisted ? Colors.white : Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityAction(BuildContext context, bool isDoneToday, Color modeColor) {
    final record = widget.habit.getRecord(widget.today);
    final unitParts = widget.habit.unit.split('|');
    final unitName = unitParts[0];
    final stepSize = unitParts.length > 1 ? double.tryParse(unitParts[1]) ?? 1.0 : 1.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("${record['progress']} / ${widget.habit.target} $unitName", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            Text("${((record['progress'] / widget.habit.target) * 100).clamp(0, 100).toStringAsFixed(0)}%", style: TextStyle(color: isDoneToday ? modeColor : Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: (record['progress'] / math.max(0.1, widget.habit.target)).clamp(0.0, 1.0), minHeight: 6, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation<Color>(isDoneToday ? modeColor : modeColor.withValues(alpha: 0.7))),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white54, size: 28), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => ref.read(habitNotifierProvider.notifier).updateQuantityProgress(widget.habit, widget.today, -stepSize)),
            Flexible(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: modeColor, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  await ref.read(habitNotifierProvider.notifier).updateQuantityProgress(widget.habit, widget.today, stepSize);
                  _checkMilestone();
                },
                child: Text("+${stepSize.toStringAsFixed(0)} $unitName", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimerAction(BuildContext context, bool isDoneToday, Color modeColor) {
    final record = widget.habit.getRecord(widget.today);
    final savedMinutes = record['progress'] as double;
    
    final displaySeconds = _currentDisplaySeconds % 60;
    final displayMinutes = _currentDisplaySeconds ~/ 60;

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("TARGET: ${widget.habit.target.toInt()} MIN • LOGGED: ${savedMinutes.toInt()} MIN", style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(
                  "${displayMinutes.toString().padLeft(2, '0')}:${displaySeconds.toString().padLeft(2, '0')}",
                  style: TextStyle(color: isDoneToday ? modeColor : Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          if (!_isTimerRunning && _currentDisplaySeconds == 0)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: modeColor, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16), minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _startTimer,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text("START", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            )
          else ...[
            GestureDetector(
              onTap: _isTimerRunning ? _pauseTimer : _startTimer,
              child: CircleAvatar(radius: 20, backgroundColor: Colors.amber, child: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 24)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _stopAndSaveTimer,
              child: const CircleAvatar(radius: 20, backgroundColor: Colors.redAccent, child: Icon(Icons.stop, color: Colors.white, size: 24)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTimelineAction(BuildContext context, Color modeColor) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.habit.getTodayTimeline().length,
        itemBuilder: (context, i) {
          final session = widget.habit.getTodayTimeline()[i];
          Color sColor = session['status'] == 'C' ? modeColor : (session['status'] == 'M' ? Colors.redAccent : Colors.white54);
          return GestureDetector(
            onTap: session['status'] == 'U' ? null : () async {
              HapticFeedback.lightImpact();
              await ref.read(habitNotifierProvider.notifier).updateSessionStatus(widget.habit, widget.today, i, session['status'] == 'C' ? 'P' : 'C');
              _checkMilestone();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(session['status'] == 'C' ? Icons.check_circle : Icons.circle_outlined, color: sColor, size: 20),
                  const SizedBox(height: 2),
                  Text(session['name'], style: TextStyle(color: sColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChecklistAction(BuildContext context, Map<String, dynamic> record, Color modeColor) {
    final sessions = List<String>.from(record['sessions']);
    return Column(
      children: List.generate(widget.habit.schedule.length, (i) {
        final parts = widget.habit.schedule[i].split('|');
        final name = parts.length > 1 ? parts[1] : 'Item ${i + 1}';
        final checked = i < sessions.length && sessions[i] == 'C';
        return InkWell(
          onTap: () async {
            HapticFeedback.selectionClick();
            await ref.read(habitNotifierProvider.notifier).updateChecklistStatus(widget.habit, widget.today, i, !checked);
            _checkMilestone();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(checked ? Icons.check_box : Icons.check_box_outline_blank, color: checked ? modeColor : Colors.white54, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(color: checked ? Colors.white54 : Colors.white, fontSize: 13, decoration: checked ? TextDecoration.lineThrough : null),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStatItem(String emoji, String label, String value) {
    return Column(
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ],
    );
  }
}

class _HistoryTimelineDialog extends StatelessWidget {
  final AetherHabit habit;
  final Color modeColor;
  
  const _HistoryTimelineDialog({required this.habit, required this.modeColor});

  @override
  Widget build(BuildContext context) {
    final sortedDates = habit.history.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFF101012).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 16),
          Text("HISTORY LOG", style: TextStyle(color: modeColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          Text(habit.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          
          Expanded(
            child: sortedDates.isEmpty 
            ? const Center(child: Text("No history recorded yet.", style: TextStyle(color: Colors.white54)))
            : ListView.builder(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                String dateStr = sortedDates[index];
                DateTime date = DateTime.parse(dateStr);
                Map<String, dynamic> record = habit.getRecord(date);
                
                bool isCompleted = record['isCompleted'];
                String reason = record['reason'] ?? '';
                bool isSkipped = reason.isNotEmpty && !isCompleted;
                double progress = record['progress'];
                
                Color statusColor = isSkipped ? Colors.orangeAccent : (isCompleted ? modeColor : Colors.redAccent);
                IconData statusIcon = isSkipped ? Icons.next_plan : (isCompleted ? Icons.check_circle : Icons.cancel);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(DateFormat('MMM').format(date).toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(DateFormat('dd').format(date), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: const Color(0xFF101012), shape: BoxShape.circle, border: Border.all(color: statusColor, width: 2)),
                          child: Icon(statusIcon, size: 10, color: statusColor),
                        ),
                        if (index != sortedDates.length - 1)
                          Container(width: 2, height: 50, color: Colors.white10),
                      ],
                    ),
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isSkipped ? "SKIPPED" : (isCompleted ? "COMPLETED" : "MISSED / INCOMPLETE"), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            
                            if (isSkipped)
                              Text("Reason: $reason", style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic))
                            else if (habit.habitType == 'quantity')
                              Text("Logged: ${progress.toInt()} / ${habit.target.toInt()} ${habit.unit.split('|')[0]}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
                            else if (habit.habitType == 'timer')
                              Text("Logged: ${progress.toInt()} / ${habit.target.toInt()} mins", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
                            else if (habit.habitType == 'negative')
                              Text(isCompleted ? "Resisted successfully." : "Slipped.", style: const TextStyle(color: Colors.white, fontSize: 13))
                            else if (habit.habitType == 'multi' || habit.habitType == 'checklist')
                              Text("Sessions/Steps marked.", style: const TextStyle(color: Colors.white, fontSize: 13))
                            else
                              const Text("Daily mark recorded.", style: const TextStyle(color: Colors.white, fontSize: 13))
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          if (habit.startDate != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Started on ${DateFormat('MMMM d, yyyy').format(habit.startDate!)}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
            )
        ],
      ),
    );
  }
}

class _SmartHabitBuilderDialog extends ConsumerStatefulWidget {
  final AetherHabit? editHabit;
  const _SmartHabitBuilderDialog({this.editHabit});
  @override
  ConsumerState<_SmartHabitBuilderDialog> createState() => _SmartHabitBuilderDialogState();
}

class _SmartHabitBuilderDialogState extends ConsumerState<_SmartHabitBuilderDialog> {
  int _step = 0;
  bool _isSaving = false;

  String _habitType = 'simple';
  String _title = '';
  double _target = 1.0;
  String _unit = 'times';
  String _stepSize = '1'; 
  int _priority = 1;
  String _category = '';
  String _description = ''; 
  
  List<int> _activeDays = [1, 2, 3, 4, 5, 6, 7];
  List<Map<String, String>> _customTimeline = [];

  int _durationMode = 0; 
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  
  bool _enableAlarms = false;
  int _alarmCount = 1;
  List<TimeOfDay> _alarmTimes = [const TimeOfDay(hour: 8, minute: 0)];
  List<String> _reminders = [];
  String _selectedTune = 'default.wav';

  List<String> _linkedTaskIds = [];

  final List<String> _tunes = ['default.wav', 'crystal.wav', 'chime.wav', 'bell.wav'];
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController(); 

  final List<String> _predefinedCategories = [
    "Health & Fitness", "Work & Career", "Spiritual", "Finance", 
    "Learning", "Mindfulness", "Home & Chores", "Relationships", 
    "Hobbies", "Self-Care", "Side Hustle", "Creative", "Diet & Nutrition"
  ];

  bool get _isEditing => widget.editHabit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.editHabit;
    if (h != null) {
      _step = 1;
      _habitType = h.habitType;
      _title = h.title;
      _titleController.text = h.title;
      _target = h.target;
      _priority = h.priority;
      
      _category = h.category;
      _categoryController.text = h.category;
      _description = h.description; 
      _descriptionController.text = h.description; 
      
      _activeDays = List.from(h.activeDays);
      _customTimeline = h.schedule.map((s) {
        final p = s.split('|');
        return {"time": p[0], "name": p.length > 1 ? p[1] : ''};
      }).toList();
      _startDate = h.startDate ?? DateTime.now();
      _endDate = h.endDate;
      if (_endDate == null) _durationMode = 0;
      else _durationMode = -1; 
      
      if (_habitType == 'quantity') {
        final unitParts = h.unit.split('|');
        _unit = unitParts[0];
        if (unitParts.length > 1) _stepSize = unitParts[1];
      } else {
        _unit = h.unit;
      }

      _reminders = List.from(h.reminders);
      if (_reminders.isNotEmpty) {
        _enableAlarms = true;
        _alarmCount = _reminders.length;
        _alarmTimes = _reminders.map((r) {
          final parts = r.split('|')[0].split(':');
          return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }).toList();
        _selectedTune = _reminders.first.split('|').length > 1 ? _reminders.first.split('|')[1] : 'default.wav';
      }
      _linkedTaskIds = List.from(h.linkedTaskIds);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildModeCard(IconData icon, Color iconColor, String title, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: iconColor.withValues(alpha: 0.3))),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ]))
          ],
        ),
      ),
    );
  }

  void _showModeHelp(String type) {
    String title = "";
    List<String> details = [];

    switch (type) {
      case 'simple': title = "Simple Habit Guide"; details = ["A basic Do / Don't Do routine.", "Just tap 'Mark as Done' on the card to complete it for the day."]; break;
      case 'multi': title = "Strict Timeline Guide"; details = ["Set exact times for your tasks.", "If you miss the time, it will automatically turn Red (Missed).", "Example: Medication -> 08:00 AM Pill A, 08:00 PM Pill B."]; break;
      case 'quantity': title = "Quantity Goal Guide"; details = ["Target: The final daily goal you want to reach (e.g., 2000).", "Unit Name: What are you measuring? (e.g., ml, pages, reps).", "Step (+): How much is added when you tap the button once? (e.g., 250).", "Example: Water goal. Target=2000, Unit=ml, Step=250."]; break;
      case 'negative': title = "Avoid / Quit Guide"; details = ["Track bad habits you want to quit.", "Your streak grows automatically every day you DON'T do it.", "Only tap 'Slipped' if you failed that day."]; break;
      case 'checklist': title = "Checklist Guide"; details = ["Break your routine into smaller sub-tasks.", "Example: Morning Routine -> 1. Make Bed, 2. Brush, 3. Drink Water."]; break;
      case 'timer': title = "Timed Focus Guide"; details = ["Target Minutes: Total time you want to focus (e.g., 30).", "A live stopwatch will appear on the card to track exact seconds/minutes."]; break;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: themeAccent, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: details.map((d) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("• ", style: TextStyle(color: Colors.white70)), Expanded(child: Text(d, style: const TextStyle(color: Colors.white70, fontSize: 13)))]))).toList()),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Got it!", style: TextStyle(color: themeAccent)))],
      ),
    );
  }

  void _addTimelineItem() { setState(() => _customTimeline.add({"time": "12:00", "name": "New Session"})); }
  void _addChecklistItem() { setState(() => _customTimeline.add({"time": "00:00", "name": "New Task"})); }
  void _setDuration(int days, int modeId) { setState(() { _durationMode = modeId; _endDate = DateTime.now().add(Duration(days: days)); }); }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? DateTime.now().add(const Duration(days: 1))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: themeAccent, surface: Color(0xFF1A1A1A), onSurface: Colors.white), dialogBackgroundColor: const Color(0xFF1A1A1A)), child: child!);
      },
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate)) _endDate = _startDate.add(const Duration(days: 1));
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickAlarmTime(int index) async {
    final time = await showTimePicker(
      context: context, initialTime: _alarmTimes[index],
      builder: (context, child) {
        return Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: themeAccent, surface: Color(0xFF1A1A1A), onSurface: Colors.white), dialogBackgroundColor: const Color(0xFF1A1A1A)), child: child!);
      },
    );
    if (time != null && mounted) setState(() { _alarmTimes[index] = time; });
  }

  void _toggleActiveDay(int weekday) {
    setState(() {
      if (_activeDays.contains(weekday)) { if (_activeDays.length > 1) _activeDays.remove(weekday); } 
      else { _activeDays.add(weekday); }
    });
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onHelp}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 12, top: 8),
      decoration: BoxDecoration(color: themeAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: themeAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          if (onHelp != null)
            GestureDetector(
              onTap: onHelp,
              child: const Row(children: [Icon(Icons.info_outline, color: themeAccent, size: 14), SizedBox(width: 4), Text("Guide", style: TextStyle(color: themeAccent, fontSize: 10, fontWeight: FontWeight.bold))]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final tasksAsync = ref.watch(taskNotifierProvider); 

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF101012).withValues(alpha: 0.85), 
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)), 
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 5)],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_step == 0 ? "Select Engine Mode" : (_isEditing ? "Edit Routine" : "Configure System"), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => context.pop()),
                  ],
                ),
                const SizedBox(height: 16),

                if (_step == 0) ...[
                  _buildModeCard(Icons.task_alt, const Color(0xFF3B82F6), "Simple Habit", "Daily single action (e.g. Vitamins)", () => setState(() { _habitType = 'simple'; _step = 1; })),
                  const SizedBox(height: 8),
                  _buildModeCard(Icons.timeline, const Color(0xFF8B5CF6), "Strict Timeline", "Scheduled events (e.g. Prayer/Meds)", () {
                    _habitType = 'multi';
                    _customTimeline = [ {"time": "05:00", "name": "Fajr"}, {"time": "13:30", "name": "Dhuhr"}, {"time": "17:00", "name": "Asr"} ];
                    setState(() => _step = 1);
                  }),
                  const SizedBox(height: 8),
                  _buildModeCard(Icons.water_drop, const Color(0xFF06B6D4), "Quantity Goal", "Track amounts (e.g. Water/Pages)", () => setState(() { _habitType = 'quantity'; _step = 1; })),
                  const SizedBox(height: 8),
                  _buildModeCard(Icons.block, const Color(0xFFEF4444), "Avoid / Quit", "Track resisting a bad habit", () => setState(() { _habitType = 'negative'; _step = 1; })),
                  const SizedBox(height: 8),
                  _buildModeCard(Icons.checklist, const Color(0xFFF59E0B), "Checklist", "Step-by-step routines (e.g. Morning)", () {
                    _habitType = 'checklist';
                    _customTimeline = [{"time": "00:00", "name": "Make Bed"}];
                    setState(() => _step = 1);
                  }),
                  const SizedBox(height: 8),
                  _buildModeCard(Icons.timer, const Color(0xFF10B981), "Timed Focus", "Live stopwatch (e.g. Read/Study)", () => setState(() { _habitType = 'timer'; _unit = 'min'; _target = 30; _step = 1; })),
                ] else ...[
                  
                  _buildSectionHeader("1. CORE DETAILS"),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                    child: TextField(
                      controller: _titleController,
                      onChanged: (val) => _title = val,
                      decoration: const InputDecoration(isDense: true, hintText: "Habit Title", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none),
                      style: const TextStyle(color: themeAccent, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Category", style: TextStyle(color: Colors.white54, fontSize: 10)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _categoryController,
                                      onChanged: (val) => _category = val,
                                      decoration: const InputDecoration(isDense: true, hintText: "e.g. Health", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none),
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                    color: const Color(0xFF1E1E1E),
                                    onSelected: (val) {
                                      setState(() {
                                        _categoryController.text = val;
                                        _category = val;
                                      });
                                    },
                                    itemBuilder: (ctx) => _predefinedCategories.map((c) => PopupMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12)))).toList(),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Priority Level", style: TextStyle(color: Colors.white54, fontSize: 10)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children: [
                                ChoiceChip(label: const Text("🧊", style: TextStyle(fontSize: 10)), selected: _priority == 0, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onSelected: (_) => setState(() => _priority = 0)),
                                ChoiceChip(label: const Text("⭐", style: TextStyle(fontSize: 10)), selected: _priority == 1, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onSelected: (_) => setState(() => _priority = 1)),
                                ChoiceChip(label: const Text("🔥", style: TextStyle(fontSize: 10)), selected: _priority == 2, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onSelected: (_) => setState(() => _priority = 2), selectedColor: Colors.redAccent.withValues(alpha: 0.3)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  const Text("Repeats On", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: List.generate(7, (i) {
                      final weekday = i + 1;
                      final selected = _activeDays.contains(weekday);
                      return GestureDetector(
                        onTap: () => _toggleActiveDay(weekday),
                        child: Container(
                          width: 28, height: 28, 
                          alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? themeAccent : Colors.white10, border: Border.all(color: selected ? themeAccent : Colors.white24)),
                          child: Text(dayLabels[i], style: TextStyle(color: selected ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      );
                    }),
                  ),

                  // 🌟 ECOSYSTEM LINKING 🌟
                  const SizedBox(height: 12),
                  _buildSectionHeader("🔗 LINK ACTION ITEMS (PREREQUISITES)"),
                  tasksAsync.when(
                    data: (tasks) {
                      final activeTasks = tasks.where((t) => t.lifecycle == 'active').toList();
                      if (activeTasks.isEmpty) return const Text("No active tasks to link.", style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic));
                      return Wrap(
                        spacing: 8, runSpacing: 8,
                        children: activeTasks.map((t) {
                          final isSelected = _linkedTaskIds.contains(t.id);
                          return GestureDetector(
                            onTap: () { HapticFeedback.selectionClick(); setState(() { if (isSelected) _linkedTaskIds.remove(t.id); else _linkedTaskIds.add(t.id); }); },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: isSelected ? themeAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? themeAccent : Colors.white12)),
                              child: Text(t.title, style: TextStyle(color: isSelected ? themeAccent : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, decoration: t.isCompleted ? TextDecoration.lineThrough : null)),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: themeAccent)),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // WITH HELP BUTTON
                  _buildSectionHeader("2. MODE SPECIFIC SETUP", onHelp: () => _showModeHelp(_habitType)),

                  if (_habitType == 'simple')
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text("No extra configuration needed. Just check it off daily.", style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
                    ),

                  if (_habitType == 'negative')
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text("Your streak will automatically increase every day you resist this habit. You only need to track when you slip.", style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
                    ),

                  if (_habitType == 'multi' || _habitType == 'checklist') ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _customTimeline.length,
                        itemBuilder: (c, i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              children: [
                                if (_habitType == 'multi')
                                  Expanded(flex: 1, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: TextField(style: const TextStyle(color: themeAccent, fontSize: 12), decoration: const InputDecoration(border: InputBorder.none, isDense: true), controller: TextEditingController(text: _customTimeline[i]["time"]), onChanged: (v) => _customTimeline[i]["time"] = v))),
                                if (_habitType == 'multi') const SizedBox(width: 8),
                                Expanded(flex: 3, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: TextField(style: const TextStyle(color: Colors.white, fontSize: 12), decoration: const InputDecoration(border: InputBorder.none, isDense: true), controller: TextEditingController(text: _customTimeline[i]["name"]), onChanged: (v) => _customTimeline[i]["name"] = v))),
                                IconButton(icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 30), onPressed: () => setState(() => _customTimeline.removeAt(i)))
                              ],
                            ),
                          );
                        }
                      ),
                    ),
                    TextButton.icon(onPressed: _habitType == 'multi' ? _addTimelineItem : _addChecklistItem, icon: const Icon(Icons.add, size: 14, color: themeAccent), label: const Text("Add Step", style: TextStyle(color: themeAccent, fontSize: 11))),
                  ],

                  if (_habitType == 'quantity') ...[
                    Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Target", style: TextStyle(color: Colors.white54, fontSize: 10)),
                          Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: TextField(controller: TextEditingController(text: _target.toString()), onChanged: (val) => _target = math.max(0.1, double.tryParse(val) ?? 1.0), keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true), style: const TextStyle(color: Colors.white, fontSize: 12)))
                        ])),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Unit Name", style: TextStyle(color: Colors.white54, fontSize: 10)),
                          Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: TextField(controller: TextEditingController(text: _unit), onChanged: (val) => _unit = val, decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: "ml, pages"), style: const TextStyle(color: Colors.white, fontSize: 12)))
                        ])),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Step (+)", style: TextStyle(color: Colors.white54, fontSize: 10)),
                          Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: TextField(controller: TextEditingController(text: _stepSize), onChanged: (val) => _stepSize = (double.tryParse(val) ?? 1.0).abs().toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: "e.g. 250"), style: const TextStyle(color: themeAccent, fontSize: 12)))
                        ])),
                      ],
                    ),
                  ],

                  if (_habitType == 'timer') ...[
                    Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Target Minutes", style: TextStyle(color: Colors.white54, fontSize: 10)),
                          Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: TextField(controller: TextEditingController(text: _target.toString()), onChanged: (val) => _target = math.max(0.1, double.tryParse(val) ?? 1.0), keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true), style: const TextStyle(color: Colors.white, fontSize: 12)))
                        ])),
                        const Expanded(child: SizedBox()), 
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Text("Custom Notes / Rules", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                    child: TextField(
                      controller: _descriptionController,
                      onChanged: (val) => _description = val,
                      maxLines: 3, minLines: 1,
                      decoration: const InputDecoration(isDense: true, hintText: "Write your custom rules or motivation here...", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),

                  _buildSectionHeader("3. RULES & ALERTS"),

                  const Text("Duration", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(label: Text("Forever", style: TextStyle(color: _durationMode == 0 ? Colors.black : Colors.white, fontSize: 10, fontWeight: _durationMode == 0 ? FontWeight.bold : FontWeight.normal)), backgroundColor: _durationMode == 0 ? themeAccent : Colors.white10, side: BorderSide(color: _durationMode == 0 ? themeAccent : Colors.white.withValues(alpha: 0.1)), visualDensity: VisualDensity.compact, onPressed: () => setState(() { _durationMode = 0; _endDate = null; })),
                        const SizedBox(width: 6),
                        ActionChip(label: Text("3 Days", style: TextStyle(color: _durationMode == 3 ? Colors.black : Colors.white, fontSize: 10, fontWeight: _durationMode == 3 ? FontWeight.bold : FontWeight.normal)), backgroundColor: _durationMode == 3 ? themeAccent : Colors.white10, side: BorderSide(color: _durationMode == 3 ? themeAccent : Colors.white.withValues(alpha: 0.1)), visualDensity: VisualDensity.compact, onPressed: () => _setDuration(3, 3)),
                        const SizedBox(width: 6),
                        ActionChip(label: Text("7 Days", style: TextStyle(color: _durationMode == 7 ? Colors.black : Colors.white, fontSize: 10, fontWeight: _durationMode == 7 ? FontWeight.bold : FontWeight.normal)), backgroundColor: _durationMode == 7 ? themeAccent : Colors.white10, side: BorderSide(color: _durationMode == 7 ? themeAccent : Colors.white.withValues(alpha: 0.1)), visualDensity: VisualDensity.compact, onPressed: () => _setDuration(7, 7)),
                        const SizedBox(width: 6),
                        ActionChip(label: Text("Custom...", style: TextStyle(color: _durationMode == -1 ? Colors.black : Colors.white, fontSize: 10, fontWeight: _durationMode == -1 ? FontWeight.bold : FontWeight.normal)), backgroundColor: _durationMode == -1 ? themeAccent : Colors.white10, side: BorderSide(color: _durationMode == -1 ? themeAccent : Colors.white.withValues(alpha: 0.1)), visualDensity: VisualDensity.compact, onPressed: () => setState(() => _durationMode = -1)),
                      ],
                    ),
                  ),
                  
                  if (_durationMode == -1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pickDate(true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                                child: Text("Start: ${DateFormat('MMM d').format(_startDate)}", style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pickDate(false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                                child: Text("End: ${_endDate != null ? DateFormat('MMM d').format(_endDate!) : 'Select'}", style: const TextStyle(color: themeAccent, fontSize: 10), textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                    child: CheckboxListTile(
                      value: _enableAlarms,
                      activeColor: themeAccent,
                      checkColor: Colors.black,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      dense: true,
                      title: const Text("Set Notifications", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      onChanged: (val) {
                        setState(() {
                          _enableAlarms = val ?? false;
                          if (_enableAlarms && _alarmTimes.isEmpty) {
                            _alarmCount = 1;
                            _alarmTimes = [const TimeOfDay(hour: 8, minute: 0)];
                          }
                        });
                      },
                    ),
                  ),
                  
                  if (_enableAlarms) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text("Times a day:", style: TextStyle(color: Colors.white54, fontSize: 11)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white54, size: 20),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                          onPressed: () {
                            if (_alarmCount > 1) {
                              setState(() {
                                _alarmCount--;
                                _alarmTimes.removeLast();
                              });
                            }
                          }
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text("$_alarmCount", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: themeAccent, size: 20),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                          onPressed: () {
                            if (_alarmCount < 10) {
                              setState(() {
                                _alarmCount++;
                                _alarmTimes.add(const TimeOfDay(hour: 12, minute: 0));
                              });
                            }
                          }
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_alarmCount, (index) {
                        final time = _alarmTimes[index];
                        return GestureDetector(
                          onTap: () => _pickAlarmTime(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: themeAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: themeAccent.withValues(alpha: 0.3))),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.alarm, size: 14, color: themeAccent),
                                const SizedBox(width: 6),
                                Text(time.format(context), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: themeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _isSaving ? null : () async {
                        if (_title.trim().isEmpty) return;
                        HapticFeedback.heavyImpact();
                        
                        setState(() { _isSaving = true; });

                        try {
                          List<String> finalSchedule = _customTimeline.map((s) {
                            if (_habitType == 'checklist') {
                              return "00:00|${s['name']}"; 
                            }
                            return "${s['time']}|${s['name']}";
                          }).toList();

                          _reminders.clear();
                          if (_enableAlarms) {
                            for (var t in _alarmTimes) {
                              String formattedTime = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
                              _reminders.add("$formattedTime|$_selectedTune");
                            }
                          }

                          String safeStep = (double.tryParse(_stepSize) ?? 1.0).abs().toString();
                          if (safeStep == '0' || safeStep == '0.0') safeStep = '1';
                          String finalUnit = _habitType == 'quantity' ? "$_unit|$safeStep" : _unit;

                          if (_isEditing) {
                            final habit = widget.editHabit!;
                            await GlobalNotificationEngine().cancelHabitReminders(habit.id, habit.reminders.length);

                            habit.title = _title;
                            habit.iconEmoji = '✨'; 
                            habit.habitType = _habitType;
                            habit.target = math.max(0.1, _target);
                            habit.unit = finalUnit;
                            habit.activeDays = _activeDays;
                            habit.schedule = finalSchedule;
                            habit.startDate = _startDate;
                            habit.endDate = _endDate;
                            habit.priority = _priority;
                            habit.reminders = _reminders;
                            habit.category = _category;
                            habit.description = _description; 
                            habit.linkedTaskIds = _linkedTaskIds;

                            await ref.read(habitNotifierProvider.notifier).saveHabit(habit);

                            if (_reminders.isNotEmpty) {
                              await GlobalNotificationEngine().scheduleHabitRemindersFromStringList(habit.id, _title, _reminders);
                            }
                          } else {
                            final habit = AetherHabit(
                              title: _title,
                              iconEmoji: '✨', 
                              habitType: _habitType,
                              target: math.max(0.1, _target),
                              unit: finalUnit,
                              activeDays: _activeDays,
                              priority: _priority,
                              startDate: _startDate,
                              endDate: _endDate,
                              reminders: _reminders,
                              schedule: finalSchedule,
                              category: _category,
                              description: _description,
                              linkedTaskIds: _linkedTaskIds,
                            );

                            await ref.read(habitNotifierProvider.notifier).addHabit(habit);

                            if (_reminders.isNotEmpty) {
                              await GlobalNotificationEngine().scheduleHabitRemindersFromStringList(habit.id, _title, _reminders);
                            }
                          }
                        } finally {
                          if (mounted) setState(() => _isSaving = false);
                        }

                        if (!mounted) return;
                        context.pop();
                      },
                      child: Text(_isSaving ? "PROCESSING..." : (_isEditing ? "UPDATE ROUTINE" : "INITIALIZE SYSTEM"), style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HabitsDoodleBackground extends StatelessWidget {
  final Widget child;
  const HabitsDoodleBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final random = math.Random(88);
    final icons = [
      Icons.local_fire_department, Icons.check_circle_outline, Icons.water_drop_outlined,
      Icons.fitness_center, Icons.menu_book, Icons.self_improvement,
      Icons.wb_sunny_outlined, Icons.bedtime_outlined, Icons.eco_outlined,
      Icons.repeat, Icons.coffee_outlined, Icons.directions_run,
      Icons.alarm, Icons.bolt_outlined, Icons.psychology_outlined,
    ];

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0D0D0D), Color(0xFF161616)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: Opacity(
              opacity: 0.03, 
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  const spacing = 32.0;
                  final cols = (width / spacing).ceil() + 2;
                  final rows = (height / spacing).ceil() + 2;

                  List<Widget> doodles = [];

                  for (int r = -1; r < rows; r++) {
                    for (int c = -1; c < cols; c++) {
                      final icon = icons[random.nextInt(icons.length)];
                      final size = 16.0 + random.nextDouble() * 12.0;
                      final angle = random.nextDouble() * 2 * math.pi;
                      double offsetX = c * spacing + (r % 2 == 0 ? spacing / 2 : 0) + (random.nextDouble() - 0.5) * 8;
                      double offsetY = r * (spacing * 0.85) + (random.nextDouble() - 0.5) * 8;

                      doodles.add(Positioned(left: offsetX, top: offsetY, child: Transform.rotate(angle: angle, child: Icon(icon, size: size, color: Colors.white))));
                    }
                  }
                  return Stack(clipBehavior: Clip.none, children: doodles);
                },
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}