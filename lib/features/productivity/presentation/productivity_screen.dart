import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

// 🌟 NEW PACKAGES INTEGRATED
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/productivity_providers.dart';
import '../data/task_category_provider.dart';
import '../domain/models/aether_task.dart';
import '../domain/models/aether_subtask.dart';
import 'widgets/task_form_dialog.dart';
import '../../../core/themes/widgets/aether_ambient_background.dart';

const Color taskPrimary = Color(0xFF06B6D4); 
const Color taskSecondary = Color(0xFF8B5CF6); 

enum TaskSortOption { smart, priority, dueDate, alphabetical, created }
enum DueFilter { all, overdue, today, thisWeek, noDate }

const Map<String, String> _kRecurrenceLabels = {'none': 'One-time', 'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly'};
const Map<int, String> _kReminderOffsetLabels = {0: 'At due time', 15: '15 min before', 60: '1 hour before', 1440: '1 day before'};

class ProductivityScreen extends ConsumerStatefulWidget {
  const ProductivityScreen({super.key});
  @override ConsumerState<ProductivityScreen> createState() => _ProductivityScreenState();
}

class _ProductivityScreenState extends ConsumerState<ProductivityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedTasks = {};
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  String _categoryFilter = 'All';
  int? _priorityFilter;
  DueFilter _dueFilter = DueFilter.all;
  
  // 🌟 FEATURE: DEEP SORTING MEMORY
  TaskSortOption _sortOption = TaskSortOption.smart; 
  String _selectedMode = 'active'; 

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() { if (!_tabController.indexIsChanging) { setState(() {}); HapticFeedback.selectionClick(); }});
  }

  // Safely await box configuration on init to prevent race conditions
  Future<void> _loadSettings() async {
    final box = await Hive.openBox('aether_settings');
    final savedSort = box.get('task_sort_pref', defaultValue: TaskSortOption.smart.index);
    if (mounted) {
      setState(() {
        _sortOption = TaskSortOption.values[savedSort];
      });
    }
  }

  Future<void> _saveSortPreference(TaskSortOption option) async {
    final box = await Hive.openBox('aether_settings');
    await box.put('task_sort_pref', option.index);
    setState(() => _sortOption = option);
  }

  @override void dispose() { _tabController.dispose(); _searchController.dispose(); super.dispose(); }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _toggleSelection(String id) { HapticFeedback.selectionClick(); setState(() { if (_selectedTasks.contains(id)) _selectedTasks.remove(id); else _selectedTasks.add(id); }); }
  void _clearSelection() => setState(() => _selectedTasks.clear());
  void _selectAll(List<AetherTask> visible) { HapticFeedback.mediumImpact(); setState(() { if (_selectedTasks.length == visible.length) _selectedTasks.clear(); else { _selectedTasks..clear()..addAll(visible.map((t) => t.id)); } }); }

  void _showTaskFormDialog(BuildContext context, {AetherTask? editTask}) {
    showAetherTaskFormDialog(context, editTask: editTask);
  }

  void _exportReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Export Report", style: TextStyle(color: taskPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text("All Tasks", style: TextStyle(color: Colors.white)), onTap: () => _generateExport('all', ctx)),
            ListTile(title: const Text("Only Completed", style: TextStyle(color: Colors.white)), onTap: () => _generateExport('completed', ctx)),
            ListTile(title: const Text("Only Pending", style: TextStyle(color: Colors.white)), onTap: () => _generateExport('pending', ctx)),
            ListTile(title: const Text("Overdue & Urgent", style: TextStyle(color: Colors.white)), onTap: () => _generateExport('urgent', ctx)),
          ],
        ),
      )
    );
  }

  String _cleanTextForPdf(String text) {
    return text.replaceAll(RegExp(r'[^\x00-\x7F]+'), '').trim();
  }

  Future<void> _generateExport(String filter, BuildContext ctx) async {
    Navigator.pop(ctx);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generating PDF...", style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF1E1E1E), behavior: SnackBarBehavior.floating));

    try {
      final tasks = ref.read(taskNotifierProvider).valueOrNull ?? [];
      List<AetherTask> filtered = [];
      final now = DateTime.now();

      if (filter == 'all') filtered = tasks.where((t) => t.lifecycle == 'active').toList();
      else if (filter == 'completed') filtered = tasks.where((t) => t.lifecycle == 'active' && t.isCompleted).toList();
      else if (filter == 'pending') filtered = tasks.where((t) => t.lifecycle == 'active' && !t.isCompleted).toList();
      else if (filter == 'urgent') filtered = tasks.where((t) => t.lifecycle == 'active' && !t.isCompleted && (t.priority == 2 || (t.dueDate != null && t.dueDate!.isBefore(now)))).toList();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("AETHER OS COMMAND CENTER", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)), pw.Text(DateFormat('MMM d, yyyy').format(now), style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700))])),
              pw.SizedBox(height: 10), pw.Text("REPORT TYPE: ${filter.toUpperCase()}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)), pw.Text("Total Items: ${filtered.length}", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)), pw.SizedBox(height: 20),
              if (filtered.isEmpty) pw.Center(child: pw.Text("No tasks found for this filter.", style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 14)))
              else ...filtered.map((t) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 12), padding: const pw.EdgeInsets.all(12), decoration: pw.BoxDecoration(border: pw.Border.all(color: t.isCompleted ? PdfColors.green300 : PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)), color: t.isCompleted ? PdfColors.green50 : PdfColors.white),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(t.isCompleted ? "[ X ] " : "[   ] ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: t.isCompleted ? PdfColors.green700 : PdfColors.grey800)), pw.Expanded(child: pw.Text(_cleanTextForPdf(t.title), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: t.isCompleted ? PdfColors.grey600 : PdfColors.black, decoration: t.isCompleted ? pw.TextDecoration.lineThrough : pw.TextDecoration.none))), pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: pw.BoxDecoration(color: t.priority == 2 ? PdfColors.red100 : t.priority == 1 ? PdfColors.orange100 : PdfColors.grey200, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))), child: pw.Text(t.priority == 2 ? 'HIGH' : t.priority == 1 ? 'MED' : 'LOW', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: t.priority == 2 ? PdfColors.red800 : t.priority == 1 ? PdfColors.orange800 : PdfColors.grey800)))]),
                        pw.SizedBox(height: 6), pw.Row(children: [if (t.dueDate != null) ...[pw.Text("Due: ${DateFormat('MMM d, h:mm a').format(t.dueDate!)}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: t.dueDate!.isBefore(now) && !t.isCompleted ? PdfColors.red700 : PdfColors.grey700)), pw.SizedBox(width: 12)], pw.Text("Category: ${_cleanTextForPdf(t.category)}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey700))]),
                        if (t.description.isNotEmpty) ...[pw.SizedBox(height: 6), pw.Text(_cleanTextForPdf(t.description), style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800, fontStyle: pw.FontStyle.italic))],
                        if (t.subtasks.isNotEmpty) ...[pw.SizedBox(height: 8), pw.Text("Action Steps: (${t.subtasks.where((st)=>st.isCompleted).length}/${t.subtasks.length} Done)", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)), pw.SizedBox(height: 4), ...t.subtasks.map((st) => pw.Padding(padding: const pw.EdgeInsets.only(left: 10, bottom: 2), child: pw.Text(st.isCompleted ? "* [x] ${_cleanTextForPdf(st.title)}" : "* [ ] ${_cleanTextForPdf(st.title)}", style: pw.TextStyle(fontSize: 9, color: st.isCompleted ? PdfColors.grey500 : PdfColors.grey800)))).toList()]
                      ]
                    )
                  );
                }),
            ];
          },
        ),
      );

      Directory? downloadDir;
      if (Platform.isAndroid) downloadDir = await getDownloadsDirectory(); 
      downloadDir ??= await getApplicationDocumentsDirectory();

      final path = '${downloadDir.path}/Aether_Report_${now.millisecondsSinceEpoch}.pdf';
      final file = File(path); await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Saved to Downloads!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4), action: SnackBarAction(label: "Share / Open", textColor: Colors.black, backgroundColor: Colors.white, onPressed: () => Share.shareXFiles([XFile(file.path)], text: 'Aether OS Task Report - ${filter.toUpperCase()}'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to generate PDF: $e"), backgroundColor: Colors.redAccent));
    }
  }

  void _handleMenuAction(String action, List<AetherTask> allTasks) {
    HapticFeedback.lightImpact();
    final notifier = ref.read(taskNotifierProvider.notifier);

    switch (action) {
      case 'export': _exportReportDialog(); break;
      case 'select_mode': setState(() => _selectedTasks.add(allTasks.firstWhere((t) => t.lifecycle == _selectedMode).id)); break;
      case 'pin': for (var id in _selectedTasks) { final t = allTasks.where((h) => h.id == id).firstOrNull; if(t!=null) notifier.togglePin(t); } _clearSelection(); break;
      case 'duplicate': for (var id in _selectedTasks) { final t = allTasks.where((h) => h.id == id).firstOrNull; if(t!=null) notifier.duplicateTask(t); } _clearSelection(); break;
      case 'bin': notifier.bulkBin(allTasks.where((h) => _selectedTasks.contains(h.id)).toList()); _clearSelection(); break;
      case 'restore': for (var id in _selectedTasks) { final t = allTasks.where((h) => h.id == id).firstOrNull; if(t!=null) notifier.restoreFromBin(t); } _clearSelection(); break;
      case 'delete_perm': for (var id in _selectedTasks) notifier.permanentDelete(id); _clearSelection(); break;
    }
  }

  void _deleteWithUndo(AetherTask task) {
    final snapshot = task.copyWith();
    ref.read(taskNotifierProvider.notifier).moveToBin(task);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Moved '${task.title}' to bin", style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E), behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: "Undo", textColor: taskPrimary, onPressed: () => ref.read(taskNotifierProvider.notifier).restoreFromBin(snapshot)),
      ),
    );
  }

  List<AetherTask> _applyFilters(List<AetherTask> tasks) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekEnd = todayStart.add(const Duration(days: 7));

    var result = tasks.where((t) {
      if (_selectedMode == 'bin') return t.lifecycle == 'deleted';
      if (t.lifecycle == 'deleted') return false; 

      final matchesCategory = _categoryFilter == 'All' || t.category == _categoryFilter;
      final matchesPriority = _priorityFilter == null || t.priority == _priorityFilter;
      final matchesSearch = _searchQuery.isEmpty || t.title.toLowerCase().contains(_searchQuery.toLowerCase()) || t.description.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesDue = true;
      switch (_dueFilter) {
        case DueFilter.overdue: matchesDue = t.dueDate != null && !t.isCompleted && t.dueDate!.isBefore(now); break;
        case DueFilter.today: matchesDue = t.dueDate != null && _isSameDay(t.dueDate!, now); break;
        case DueFilter.thisWeek: matchesDue = t.dueDate != null && t.dueDate!.isAfter(todayStart) && t.dueDate!.isBefore(weekEnd); break;
        case DueFilter.noDate: matchesDue = t.dueDate == null; break;
        case DueFilter.all: matchesDue = true; break;
      }
      return matchesCategory && matchesPriority && matchesSearch && matchesDue;
    }).toList();

    switch (_sortOption) {
      case TaskSortOption.priority: result.sort((a, b) => b.priority.compareTo(a.priority)); break;
      case TaskSortOption.dueDate: result.sort((a, b) { if (a.dueDate == null && b.dueDate == null) return 0; if (a.dueDate == null) return 1; if (b.dueDate == null) return -1; return a.dueDate!.compareTo(b.dueDate!); }); break;
      case TaskSortOption.alphabetical: result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())); break;
      case TaskSortOption.created: result.sort((a, b) => b.createdAt.compareTo(a.createdAt)); break;
      case TaskSortOption.smart: break;
    }
    return result;
  }

  Map<String, List<AetherTask>> _groupTasks(List<AetherTask> tasks) {
    final now = DateTime.now();
    Map<String, List<AetherTask>> groups = {'Pinned': [], 'Critical Action': [], 'Today\'s Focus': [], 'Upcoming': [], 'Backlog': []};

    for (var t in tasks) {
      if (t.isPinned) { groups['Pinned']!.add(t); continue; }
      if (t.dueDate == null) { groups['Backlog']!.add(t); } 
      else if (t.dueDate!.isBefore(now) && !_isSameDay(t.dueDate!, now)) { groups['Critical Action']!.add(t); } 
      else if (_isSameDay(t.dueDate!, now) || (t.dueDate!.isBefore(now) && _isSameDay(t.dueDate!, now))) { groups['Today\'s Focus']!.add(t); } 
      else { groups['Upcoming']!.add(t); }
    }
    groups.forEach((key, list) {
      list.sort((a, b) {
        if (a.priority != b.priority) return b.priority.compareTo(a.priority);
        if (a.dueDate != null && b.dueDate != null) return a.dueDate!.compareTo(b.dueDate!);
        return 0;
      });
    });
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final asyncTasks = ref.watch(taskNotifierProvider);
    final categories = ref.watch(taskCategoriesProvider);
    final isSelectionMode = _selectedTasks.isNotEmpty;
    final isBin = _selectedMode == 'bin';

    return Scaffold(
      backgroundColor: Colors.transparent,
      
      floatingActionButton: (isSelectionMode || isBin) ? null : Container(
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [taskPrimary, taskSecondary], begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: [BoxShadow(color: taskPrimary.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8))]),
        child: FloatingActionButton(heroTag: null, onPressed: () => _showTaskFormDialog(context), backgroundColor: Colors.transparent, elevation: 0, highlightElevation: 0, child: const Icon(Icons.add, color: Colors.white, size: 28)),
      ).animate().scale(delay: 400.ms, duration: 400.ms, curve: Curves.easeOutBack),

      body: TasksDoodleBackground(
        child: SafeArea(
          child: asyncTasks.when(
            loading: () => const Center(child: CircularProgressIndicator(color: taskPrimary)),
            error: (e, st) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.redAccent))),
            data: (allTasks) {
              final visibleTasks = _applyFilters(allTasks);
              final activeVisible = visibleTasks.where((t) => !t.isCompleted).toList();
              final doneVisible = visibleTasks.where((t) => t.isCompleted).toList();
              int binCount = allTasks.where((t) => t.lifecycle == 'deleted').length;

              Map<String, List<AetherTask>> groupedTasks = {};
              if (_sortOption == TaskSortOption.smart) groupedTasks = _groupTasks(activeVisible);

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: isSelectionMode ? taskSecondary.withValues(alpha: 0.2) : const Color(0xFF0D0A14).withValues(alpha: 0.90),
                    flexibleSpace: isSelectionMode ? null : ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
                    elevation: 0, pinned: true, centerTitle: true,
                    leading: isSelectionMode
                        ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _clearSelection)
                        : (_isSearching ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70), onPressed: () => setState(() { _isSearching = false; _searchQuery = ''; _searchController.clear(); }))
                                        : IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70), onPressed: () => context.pop())),
                    
                    title: _isSearching
                        ? TextField(controller: _searchController, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Search tasks...", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none), onChanged: (v) => setState(() => _searchQuery = v))
                        : Text(isSelectionMode ? "${_selectedTasks.length} Selected" : "TASKS", style: const TextStyle(fontSize: 16, color: Colors.white, letterSpacing: 2.0, fontWeight: FontWeight.bold)),
                    
                    actions: [
                      if (isSelectionMode)
                        IconButton(icon: Icon(_selectedTasks.length == visibleTasks.length ? Icons.deselect : Icons.select_all, color: Colors.white), onPressed: () => _selectAll(visibleTasks)),
                      if (!isSelectionMode && !_isSearching) ...[
                        IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () => setState(() => _isSearching = true)),
                        
                        // 🌟 THE SORTING MENU IS HERE
                        PopupMenuButton<TaskSortOption>(
                          icon: const Icon(Icons.sort, color: Colors.white), color: const Color(0xFF1E1E1E),
                          onSelected: _saveSortPreference,
                          itemBuilder: (context) => [
                            PopupMenuItem(value: TaskSortOption.smart, child: Row(children: [Icon(Icons.auto_awesome, color: _sortOption == TaskSortOption.smart ? taskPrimary : Colors.white, size: 18), const SizedBox(width: 8), Text("Smart Grouping", style: TextStyle(color: _sortOption == TaskSortOption.smart ? taskPrimary : Colors.white))])),
                            PopupMenuItem(value: TaskSortOption.priority, child: Row(children: [Icon(Icons.flag, color: _sortOption == TaskSortOption.priority ? taskPrimary : Colors.white, size: 18), const SizedBox(width: 8), Text("Priority", style: TextStyle(color: _sortOption == TaskSortOption.priority ? taskPrimary : Colors.white))])),
                            PopupMenuItem(value: TaskSortOption.dueDate, child: Row(children: [Icon(Icons.calendar_today, color: _sortOption == TaskSortOption.dueDate ? taskPrimary : Colors.white, size: 18), const SizedBox(width: 8), Text("Due Date", style: TextStyle(color: _sortOption == TaskSortOption.dueDate ? taskPrimary : Colors.white))])),
                            PopupMenuItem(value: TaskSortOption.alphabetical, child: Row(children: [Icon(Icons.sort_by_alpha, color: _sortOption == TaskSortOption.alphabetical ? taskPrimary : Colors.white, size: 18), const SizedBox(width: 8), Text("Alphabetical", style: TextStyle(color: _sortOption == TaskSortOption.alphabetical ? taskPrimary : Colors.white))])),
                          ],
                        ),

                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white), color: const Color(0xFF1E1E1E),
                          onSelected: (a) => _handleMenuAction(a, allTasks),
                          itemBuilder: (context) {
                            if (!isSelectionMode) {
                              return [
                                const PopupMenuItem(value: 'add', child: Row(children: [Icon(Icons.add, color: Colors.white, size: 20), SizedBox(width: 12), Text("Add Task", style: TextStyle(color: Colors.white))])),
                                const PopupMenuItem(value: 'select_mode', child: Row(children: [Icon(Icons.checklist, color: Colors.white, size: 20), SizedBox(width: 12), Text("Select Multiple", style: TextStyle(color: Colors.white))])),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.picture_as_pdf, color: taskPrimary, size: 20), SizedBox(width: 12), Text("Export Report", style: TextStyle(color: taskPrimary))])),
                              ];
                            } else {
                              if (isBin) {
                                return [
                                  const PopupMenuItem(value: 'restore', child: Row(children: [Icon(Icons.restore, color: Colors.greenAccent, size: 20), SizedBox(width: 12), Text("Restore", style: TextStyle(color: Colors.greenAccent))])),
                                  const PopupMenuItem(value: 'delete_perm', child: Row(children: [Icon(Icons.delete_forever, color: Colors.redAccent, size: 20), SizedBox(width: 12), Text("Delete Permanently", style: TextStyle(color: Colors.redAccent))])),
                                ];
                              }
                              return [
                                const PopupMenuItem(value: 'pin', child: Row(children: [Icon(Icons.push_pin, color: Colors.white, size: 20), SizedBox(width: 12), Text("Pin / Unpin", style: TextStyle(color: Colors.white))])),
                                const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy, color: Colors.white, size: 20), SizedBox(width: 12), Text("Duplicate", style: TextStyle(color: Colors.white))])),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'bin', child: Row(children: [Icon(Icons.delete, color: Colors.redAccent, size: 20), SizedBox(width: 12), Text("Move to Bin", style: TextStyle(color: Colors.redAccent))])),
                              ];
                            }
                          }
                        ),
                      ],
                    ],
                  ),

                  if (isSelectionMode)
                    SliverToBoxAdapter(
                      child: _SelectionActionBar(selectedIds: _selectedTasks, allTasks: allTasks, categories: categories, onDone: _clearSelection, isBin: isBin),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Container(
                        height: 40, margin: const EdgeInsets.only(bottom: 12),
                        child: ListView(
                          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _FilterChip(label: 'All Active', selected: _selectedMode == 'active' && _categoryFilter == 'All', onTap: () => setState((){ _selectedMode = 'active'; _categoryFilter = 'All'; })),
                            ...categories.map((c) => Padding(padding: const EdgeInsets.only(left: 8), child: _FilterChip(label: c, selected: _selectedMode == 'active' && _categoryFilter == c, onTap: () => setState((){ _selectedMode = 'active'; _categoryFilter = c;})))),
                            if (binCount > 0) Padding(padding: const EdgeInsets.only(left: 8), child: _FilterChip(label: '🗑️ Bin ($binCount)', selected: _selectedMode == 'bin', onTap: () => setState(() => _selectedMode = 'bin'))),
                          ],
                        ),
                      ),
                    ),
                    if (!isBin)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: TabBar(
                            controller: _tabController, indicatorColor: taskPrimary, labelColor: Colors.white, unselectedLabelColor: Colors.white38, dividerColor: Colors.transparent,
                            tabs: [Tab(text: "Action Items (${activeVisible.length})"), Tab(text: "Completed (${doneVisible.length})")],
                          ),
                        ),
                      ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  if (isBin) 
                     visibleTasks.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState("Recycle Bin is empty.", Icons.delete_outline))
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) => _TaskCard(task: visibleTasks[index], index: index, isSelectionMode: isSelectionMode, isSelected: _selectedTasks.contains(visibleTasks[index].id), onToggle: () => _toggleSelection(visibleTasks[index].id), onEdit: () => _showTaskFormDialog(context, editTask: visibleTasks[index])), childCount: visibleTasks.length)),
                        )
                  else if (_tabController.index == 1) 
                    doneVisible.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState("No victories yet.", Icons.emoji_events_outlined))
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) => _TaskCard(task: doneVisible[index], index: index, isSelectionMode: isSelectionMode, isSelected: _selectedTasks.contains(doneVisible[index].id), onToggle: () => _toggleSelection(doneVisible[index].id), onEdit: () => _showTaskFormDialog(context, editTask: doneVisible[index])), childCount: doneVisible.length)),
                        )
                  else if (_tabController.index == 0) 
                    activeVisible.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState(allTasks.isEmpty ? "All caught up.\nEnjoy the silence." : "No tasks match your filters.", Icons.done_all))
                      : (_sortOption == TaskSortOption.smart)
                        ? SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  List<Widget> widgets = [];
                                  if (groupedTasks['Pinned']!.isNotEmpty && index == 0) widgets.addAll([_buildGroupHeader("📌 Pinned", Colors.white), ...groupedTasks['Pinned']!.asMap().entries.map((e) => _TaskCard(task: e.value, index: e.key, isSelectionMode: isSelectionMode, isSelected: _selectedTasks.contains(e.value.id), onToggle: () => _toggleSelection(e.value.id), onEdit: () => _showTaskFormDialog(context, editTask: e.value)))]);
                                  if (groupedTasks['Critical Action']!.isNotEmpty && index == 1) widgets.addAll([_buildGroupHeader("🚨 Critical Action", Colors.redAccent), ...groupedTasks['Critical Action']!.asMap().entries.map((e) => _TaskCard(task: e.value, index: e.key, isSelectionMode: isSelectionMode, isSelected: _selectedTasks.contains(e.value.id), onToggle: () => _toggleSelection(e.value.id), onEdit: () => _showTaskFormDialog(context, editTask: e.value)))]);
                                  if (groupedTasks['Today\'s Focus']!.isNotEmpty && index == 2) widgets.addAll([_buildGroupHeader("⚡ Today's Focus", Colors.amberAccent), ...groupedTasks['Today\'s Focus']!.asMap().entries.map((e) => _TaskCard(task: e.value, index: e.key, isSelectionMode: isSelectionMode, isSelected: _selectedTasks.contains(e.value.id), onToggle: () => _toggleSelection(e.value.id), onEdit: () => _showTaskFormDialog(context, editTask: e.value)))]);
                                  if (groupedTasks['Upcoming']!.isNotEmpty && index == 3) widgets.addAll([_buildGroupHeader("🗓️ Upcoming", taskPrimary), ...groupedTasks['Upcoming']!.asMap().entries.map((e) => _TaskCard(task: e.value, index: e.key, isSelectionMode: isSelectionMode, isSelected: _selectedTasks.contains(e.value.id), onToggle: () => _toggleSelection(e.value.id), onEdit: () => _showTaskFormDialog(context, editTask: e.value)))]);
                                  if (groupedTasks['Backlog']!.isNotEmpty && index == 4) widgets.addAll([_buildGroupHeader("🧊 Backlog", Colors.white54), ...groupedTasks['Backlog']!.asMap().entries.map((e) => _TaskCard(task: e.value, index: e.key, isSelectionMode: isSelectionMode, isSelected: _selectedTasks.contains(e.value.id), onToggle: () => _toggleSelection(e.value.id), onEdit: () => _showTaskFormDialog(context, editTask: e.value)))]);
                                  
                                  if (widgets.isEmpty) return const SizedBox.shrink();
                                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
                                },
                                childCount: 5,
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) => _TaskCard(task: activeVisible[index], index: index, isSelectionMode: isSelectionMode, isSelected: _selectedTasks.contains(activeVisible[index].id), onToggle: () => _toggleSelection(activeVisible[index].id), onEdit: () => _showTaskFormDialog(context, editTask: activeVisible[index])), childCount: activeVisible.length)),
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

  Widget _buildGroupHeader(String title, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 12.0, top: 8.0, left: 4), child: Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2)));
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 60, color: Colors.white.withValues(alpha: 0.05)), const SizedBox(height: 16), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.bold))]).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0));
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? taskPrimary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? taskPrimary : Colors.white12),
        ),
        child: Text(label, style: TextStyle(color: selected ? taskPrimary : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _SelectionActionBar extends ConsumerWidget {
  final Set<String> selectedIds;
  final List<AetherTask> allTasks;
  final List<String> categories;
  final VoidCallback onDone;
  final bool isBin;

  const _SelectionActionBar({required this.selectedIds, required this.allTasks, required this.categories, required this.onDone, this.isBin = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = allTasks.where((t) => selectedIds.contains(t.id)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: isBin ? [
            TextButton.icon(
              onPressed: () { for(var t in selected) {ref.read(taskNotifierProvider.notifier).restoreFromBin(t);} onDone(); },
              icon: const Icon(Icons.restore, size: 16, color: Colors.greenAccent), label: const Text("Restore", style: TextStyle(color: Colors.greenAccent)),
            ),
            TextButton.icon(
              onPressed: () { for(var t in selected) {ref.read(taskNotifierProvider.notifier).permanentDelete(t.id);} onDone(); },
              icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent), label: const Text("Delete Forever", style: TextStyle(color: Colors.redAccent)),
            ),
          ] : [
            TextButton.icon(
              onPressed: () { ref.read(taskNotifierProvider.notifier).bulkComplete(selected); onDone(); },
              icon: const Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)), label: const Text("Complete", style: TextStyle(color: Color(0xFF10B981))),
            ),
            PopupMenuButton<int>(
              icon: const Icon(Icons.flag, color: Colors.white54, size: 20), color: const Color(0xFF1E1E1E),
              onSelected: (p) { ref.read(taskNotifierProvider.notifier).bulkSetPriority(selected, p); onDone(); },
              itemBuilder: (c) => const [PopupMenuItem(value: 2, child: Text("🔥 High", style: TextStyle(color: Colors.white))), PopupMenuItem(value: 1, child: Text("⭐ Medium", style: TextStyle(color: Colors.white))), PopupMenuItem(value: 0, child: Text("🧊 Low", style: TextStyle(color: Colors.white)))],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.label, color: Colors.white54, size: 20), color: const Color(0xFF1E1E1E),
              onSelected: (c) { ref.read(taskNotifierProvider.notifier).bulkSetCategory(selected, c); onDone(); },
              itemBuilder: (context) => categories.map((c) => PopupMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
            ),
            TextButton.icon(
              onPressed: () { ref.read(taskNotifierProvider.notifier).bulkPin(selected); onDone(); },
              icon: const Icon(Icons.push_pin, size: 16, color: Colors.amberAccent), label: const Text("Pin", style: TextStyle(color: Colors.amberAccent)),
            ),
            TextButton.icon(
              onPressed: () { ref.read(taskNotifierProvider.notifier).bulkBin(selected); onDone(); },
              icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent), label: const Text("Bin", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends ConsumerStatefulWidget {
  final AetherTask task;
  final int index;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const _TaskCard({
    required this.task, 
    required this.index, 
    required this.isSelectionMode, 
    required this.isSelected, 
    required this.onToggle, 
    required this.onEdit
  });
  
  @override ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool _isExpanded = false;
  final _quickSubtaskController = TextEditingController();

  @override void dispose() { _quickSubtaskController.dispose(); super.dispose(); }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Color _getCardColor(AetherTask task, DateTime now) {
    if (task.lifecycle == 'deleted') return const Color(0xFF1E1E1E); 
    if (task.isCompleted) return const Color(0xFF0D1F15); 
    if (task.dueDate != null) {
      if (task.dueDate!.isBefore(now) && !_isSameDay(task.dueDate!, now)) return const Color(0xFF2A0D0D); 
      if (_isSameDay(task.dueDate!, now)) return const Color(0xFF24180A); 
      return const Color(0xFF0A1929); 
    }
    return const Color(0xFF1A202C); 
  }

  void _deleteWithUndo() {
    final snapshot = widget.task.copyWith();
    ref.read(taskNotifierProvider.notifier).moveToBin(widget.task);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Moved '${widget.task.title}' to bin"), backgroundColor: const Color(0xFF1E1E1E), behavior: SnackBarBehavior.floating, action: SnackBarAction(label: "Undo", textColor: taskPrimary, onPressed: () => ref.read(taskNotifierProvider.notifier).restoreFromBin(snapshot))));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final totalSubtasks = t.subtasks.length;
    final completedSubtasks = t.subtasks.where((st) => st.isCompleted).length;
    double progress = totalSubtasks > 0 ? completedSubtasks / totalSubtasks : 0.0;
    final now = DateTime.now();

    Color cardBgColor = _getCardColor(t, now);
    Color edgeColor = Colors.white24;
    String dateLabel = "";
    Color dateColor = Colors.white54;
    
    if (t.lifecycle == 'deleted') {
      edgeColor = Colors.grey; dateLabel = "In Bin";
    } else if (t.dueDate != null) {
      final diff = t.dueDate!.difference(now);
      if (!t.isCompleted && diff.isNegative && !_isSameDay(t.dueDate!, now)) {
        edgeColor = Colors.redAccent; dateLabel = "Overdue"; dateColor = Colors.redAccent;
      } else if (_isSameDay(t.dueDate!, now)) {
        edgeColor = Colors.amberAccent; dateLabel = "Today, ${DateFormat('h:mm a').format(t.dueDate!)}"; dateColor = Colors.amberAccent;
      } else {
        edgeColor = taskPrimary; dateLabel = DateFormat('MMM d, h:mm a').format(t.dueDate!); dateColor = taskPrimary;
      }
    }

    if (t.isCompleted) { edgeColor = Colors.white10; dateColor = Colors.white24; }
    String priorityEmoji = t.priority == 2 ? "🔥" : t.priority == 1 ? "⭐" : "🧊";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Dismissible(
        key: Key(t.id),
        direction: widget.isSelectionMode || t.lifecycle == 'deleted' ? DismissDirection.none : DismissDirection.horizontal,
        background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.8), borderRadius: BorderRadius.circular(16)), child: Icon(t.isCompleted ? Icons.undo : Icons.check_circle, color: Colors.white)),
        secondaryBackground: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.delete, color: Colors.white)),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) { HapticFeedback.mediumImpact(); ref.read(taskNotifierProvider.notifier).toggleTaskCompletion(t); return false; } 
          else { _deleteWithUndo(); return false; }
        },
        child: GestureDetector(
          onTap: () {
            if (widget.isSelectionMode) widget.onToggle();
            else if (t.lifecycle != 'deleted') {
              HapticFeedback.selectionClick();
              setState(() => _isExpanded = !_isExpanded);
            }
          },
          onLongPress: widget.onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: cardBgColor, 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.isSelected ? taskPrimary : Colors.white12, width: widget.isSelected ? 2 : 1),
              boxShadow: !t.isCompleted && t.priority > 0 ? [BoxShadow(color: edgeColor.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 4))] : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  Positioned(left: 0, top: 0, bottom: 0, width: 4, child: Container(color: edgeColor)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.isSelectionMode)
                              Padding(padding: const EdgeInsets.only(top: 2, right: 12), child: Icon(widget.isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: widget.isSelected ? taskPrimary : Colors.white38, size: 22))
                            else if (t.lifecycle != 'deleted')
                              GestureDetector(
                                onTap: () { HapticFeedback.lightImpact(); ref.read(taskNotifierProvider.notifier).toggleTaskCompletion(t); },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200), width: 22, height: 22, margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: t.isCompleted ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.05), border: Border.all(color: t.isCompleted ? const Color(0xFF10B981) : Colors.white38, width: 2)),
                                  child: t.isCompleted ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                                ),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (t.isPinned) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin, color: Colors.amberAccent, size: 14)),
                                      Expanded(child: Text(t.title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: t.isCompleted ? Colors.white38 : Colors.white, decoration: t.isCompleted ? TextDecoration.lineThrough : null))),
                                    ],
                                  ),
                                  if (t.description.isNotEmpty && !_isExpanded) ...[
                                    const SizedBox(height: 4),
                                    Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.isCompleted ? Colors.white24 : Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(priorityEmoji, style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
                                  child: Text(t.category, style: TextStyle(color: t.isCompleted ? Colors.white24 : Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            )
                          ],
                        ),

                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (dateLabel.isNotEmpty) ...[
                              Icon(Icons.access_time_filled, size: 12, color: dateColor),
                              const SizedBox(width: 4),
                              Text(dateLabel, style: TextStyle(color: dateColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                            if (t.isRecurring) ...[
                              const SizedBox(width: 10),
                              Icon(Icons.repeat, size: 12, color: t.isCompleted ? Colors.white24 : Colors.white54),
                            ],
                            if (t.attachments.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Icon(Icons.attach_file, size: 12, color: t.isCompleted ? Colors.white24 : Colors.white54),
                              const SizedBox(width: 4),
                              Text("${t.attachments.length}", style: TextStyle(color: t.isCompleted ? Colors.white24 : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                            const Spacer(),
                            if (totalSubtasks > 0 && !_isExpanded) ...[
                              Icon(Icons.account_tree_rounded, size: 12, color: t.isCompleted ? Colors.white24 : Colors.white54),
                              const SizedBox(width: 4),
                              Text("$completedSubtasks/$totalSubtasks", style: TextStyle(color: t.isCompleted ? Colors.white24 : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                            if (!widget.isSelectionMode)
                              Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white38, size: 16),
                          ],
                        ),

                        if (totalSubtasks > 0 && !t.isCompleted && !_isExpanded) ...[
                          const SizedBox(height: 8),
                          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 3, backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation<Color>(edgeColor)))
                        ],

                        // =======================================
                        // MINI EXPANDED ACCORDION VIEW
                        // =======================================
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          clipBehavior: Clip.hardEdge,
                          alignment: Alignment.topCenter,
                          child: (!_isExpanded || widget.isSelectionMode) ? const SizedBox.shrink() : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Divider(color: Colors.white12, height: 16),
                                
                                Wrap(
                                  spacing: 6, runSpacing: 6,
                                  children: [
                                    _MiniTag(icon: Icons.add_task, label: "Created ${DateFormat('MMM d').format(t.createdAt)}"),
                                    if (t.isRecurring) _MiniTag(icon: Icons.repeat, label: _kRecurrenceLabels[t.recurrenceRule] ?? ''),
                                    if (t.dueDate != null) _MiniTag(icon: Icons.notifications_active, label: _kReminderOffsetLabels[t.reminderOffsetMinutes] ?? 'Custom Reminder'),
                                  ],
                                ),

                                if (t.description.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(t.description, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                                
                                if (t.notes.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)), child: Text(t.notes, style: const TextStyle(color: Colors.white54, fontSize: 10))),
                                ],

                                // MEDIA ATTACHMENTS PREVIEW
                                if (t.attachments.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text("ATTACHMENTS", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 60,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: t.attachments.length,
                                      itemBuilder: (context, i) {
                                        return Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          width: 60, height: 60,
                                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.file(
                                              File(t.attachments[i]), 
                                              fit: BoxFit.cover,
                                              cacheWidth: 150, 
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24, size: 24),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                ],

                                // MINI SUBTASKS ENGINE WITH DEADLINES
                                if (t.subtasks.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text("ACTION STEPS", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                  const SizedBox(height: 6),
                                  ...t.subtasks.map((st) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () { HapticFeedback.lightImpact(); ref.read(taskNotifierProvider.notifier).toggleSubtaskCompletion(t, st.id); },
                                          child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, color: st.isCompleted ? const Color(0xFF10B981) : Colors.transparent, border: Border.all(color: st.isCompleted ? const Color(0xFF10B981) : Colors.white38, width: 1.5)), child: st.isCompleted ? const Icon(Icons.check, size: 10, color: Colors.white) : null),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(st.title, style: TextStyle(color: st.isCompleted ? Colors.white38 : Colors.white70, fontSize: 11, decoration: st.isCompleted ? TextDecoration.lineThrough : null)),
                                              if (st.deadline != null && !st.isCompleted) 
                                                Text("Due: ${DateFormat('MMM d, h:mm a').format(st.deadline!)}", style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                            ],
                                          )
                                        ),
                                        if (st.isCompleted) Text(
                                          st.completedAt != null ? "(Done ${DateFormat('h:mm a').format(st.completedAt!)})" : "(Done)", 
                                          style: const TextStyle(color: Colors.white24, fontSize: 9, fontStyle: FontStyle.italic)
                                        ),
                                      ],
                                    ),
                                  )),
                                ],

                                if (!t.isCompleted) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.add, color: Colors.white24, size: 14),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _quickSubtaskController,
                                          style: const TextStyle(color: Colors.white, fontSize: 11),
                                          decoration: const InputDecoration(hintText: "Quick add step...", hintStyle: TextStyle(color: Colors.white24), isDense: true, border: InputBorder.none),
                                          onSubmitted: (val) {
                                            if (val.trim().isNotEmpty) {
                                              HapticFeedback.lightImpact();
                                              ref.read(taskNotifierProvider.notifier).addSubtask(t, val.trim());
                                              _quickSubtaskController.clear();
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    icon: const Icon(Icons.edit_note, color: Colors.white54, size: 18),
                                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                    onPressed: widget.onEdit,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: math.min(15, widget.index) * 30)).slideX(begin: 0.05, end: 0),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final IconData icon; final String label;
  const _MiniTag({required this.icon, required this.label});
  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [ Icon(icon, size: 10, color: Colors.white54), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)) ],
      ),
    );
  }
}

// ==========================================
// CENTERED SMART DIALOG (ADD / EDIT TASK)
// ==========================================
class _TaskFormDialog extends ConsumerStatefulWidget {
  final AetherTask? editTask;
  const _TaskFormDialog({this.editTask});
  @override ConsumerState<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<_TaskFormDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _notesController = TextEditingController();
  final _newCategoryController = TextEditingController();
  final _newSubtaskController = TextEditingController();

  int _priority = 0;
  DateTime? _selectedDate;
  String _selectedCategory = 'Work';
  String _recurrence = 'none';
  int _reminderOffset = 0;
  bool _isSaving = false;
  bool _addingCategory = false;
  
  List<AetherSubtask> _localSubtasks = [];
  DateTime? _pendingSubtaskDeadline;
  List<String> _linkedHabitIds = [];
  List<String> _localAttachments = []; // 🌟 Media attachments

  // 🌟 Voice-to-Text State
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  bool get _isEditing => widget.editTask != null;

  @override
  void initState() {
    super.initState();
    final t = widget.editTask;
    if (t != null) {
      _titleController.text = t.title; _descController.text = t.description; _notesController.text = t.notes;
      _priority = t.priority; _selectedDate = t.dueDate; _selectedCategory = t.category;
      _recurrence = t.recurrenceRule ?? 'none'; _reminderOffset = t.reminderOffsetMinutes;
      _localSubtasks = List.from(t.subtasks);
      _linkedHabitIds = List.from(t.linkedHabitIds);
      _localAttachments = List.from(t.attachments);
    }
  }

  @override
  void dispose() { 
    if (_isListening) _speech.stop();
    _titleController.dispose(); 
    _descController.dispose(); 
    _notesController.dispose(); 
    _newCategoryController.dispose(); 
    _newSubtaskController.dispose(); 
    super.dispose(); 
  }

  // 🌟 FEATURE: VOICE TO TEXT
  void _listen(TextEditingController controller) async {
    if (!_isListening) {
      try {
        bool available = await _speech.initialize(onStatus: (val) {
          if (val == 'done' && mounted) setState(() => _isListening = false);
        });
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(onResult: (val) {
            if (mounted) setState(() => controller.text = val.recognizedWords);
          });
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Voice recognition denied or unavailable on this device.")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mic permission missing.")));
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // 🌟 FEATURE: MEDIA ATTACHMENTS
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        setState(() {
          _localAttachments.add(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to access gallery.")));
    }
  }

  Future<void> _pickDateTime() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final initial = _selectedDate != null && _selectedDate!.isAfter(yesterday) ? _selectedDate! : now;

    final DateTime? pickedDate = await showDatePicker(
      context: context, initialDate: initial, firstDate: yesterday, lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: taskPrimary, surface: Color(0xFF1A1A1A))), child: child!),
    );

    if (pickedDate != null) {
      HapticFeedback.selectionClick();
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context, initialTime: _selectedDate != null ? TimeOfDay.fromDateTime(_selectedDate!) : TimeOfDay.now(),
        builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: taskPrimary, surface: Color(0xFF1A1A1A))), child: child!),
      );

      setState(() {
        if (pickedTime != null) _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        else _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickSubtaskDeadline() async {
    final now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: taskPrimary, surface: Color(0xFF1A1A1A))), child: child!),
    );
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context, initialTime: TimeOfDay.now(),
        builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: taskPrimary, surface: Color(0xFF1A1A1A))), child: child!),
      );
      if (pickedTime != null) {
        setState(() {
          _pendingSubtaskDeadline = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  void _addLocalSubtask() {
    final text = _newSubtaskController.text.trim();
    if (text.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() { 
        _localSubtasks.add(AetherSubtask(id: const Uuid().v4(), title: text, deadline: _pendingSubtaskDeadline)); 
        _newSubtaskController.clear(); 
        _pendingSubtaskDeadline = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(taskCategoriesProvider);
    final habitsAsync = ref.watch(habitNotifierProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: const Color(0xFF101012).withValues(alpha: 0.90), border: Border.all(color: Colors.white.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_isEditing ? "EDIT TASK" : "DEPLOY TASK", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => context.pop()),
                  ],
                ),
                const SizedBox(height: 24),

                // 🌟 TITLE FIELD WITH VOICE INPUT
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: _titleController, autofocus: !_isEditing, style: const TextStyle(color: taskPrimary, fontSize: 16, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: "What needs to be done?", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none))),
                      GestureDetector(
                        onTap: () => _listen(_titleController),
                        child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.redAccent : Colors.white54, size: 22).animate(target: _isListening ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.2,1.2)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // 🌟 DESCRIPTION FIELD WITH VOICE INPUT
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: _descController, maxLines: 2, minLines: 1, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: "Description or notes (optional)", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none))),
                      GestureDetector(
                        onTap: () => _listen(_descController),
                        child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.redAccent : Colors.white54, size: 18).animate(target: _isListening ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.2,1.2)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 🌟 ATTACHMENTS (MEDIA) SECTION
                const Text("ATTACHMENTS (OPTIONAL)", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 60, height: 60, margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12, style: BorderStyle.solid)),
                          child: const Icon(Icons.add_a_photo, color: Colors.white54),
                        ),
                      ),
                      ..._localAttachments.asMap().entries.map((e) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 60, height: 60, margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(e.value), fit: BoxFit.cover, cacheWidth: 150, errorBuilder: (ctx, err, st) => const Icon(Icons.broken_image, color: Colors.white24))),
                            ),
                            Positioned(
                              top: -5, right: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => _localAttachments.removeAt(e.key)),
                                child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: Colors.white)),
                              ),
                            )
                          ],
                        );
                      })
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 🌟 SUBTASKS ENGINE WITH DEADLINES
                const Text("ACTION STEPS", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                if (_localSubtasks.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _localSubtasks.length,
                    itemBuilder: (context, index) {
                      final st = _localSubtasks[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.check_box_outline_blank, color: Colors.white24, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(st.title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                if (st.deadline != null) Text("Due: ${DateFormat('MMM d, h:mm a').format(st.deadline!)}", style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            )),
                            IconButton(icon: const Icon(Icons.close, size: 14, color: Colors.redAccent), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () { setState(() { _localSubtasks.removeAt(index); }); })
                          ],
                        ),
                      );
                    },
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newSubtaskController, style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(hintText: "+ Add a subtask...", hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none),
                          onSubmitted: (_) => _addLocalSubtask(),
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickSubtaskDeadline,
                        child: Icon(Icons.access_time, color: _pendingSubtaskDeadline != null ? taskPrimary : Colors.white24, size: 18),
                      ),
                      IconButton(icon: const Icon(Icons.add, color: taskPrimary, size: 18), onPressed: () => _addLocalSubtask()),
                    ],
                  ),
                ),
                if (_pendingSubtaskDeadline != null) Padding(padding: const EdgeInsets.only(top: 4, left: 16), child: Text("Set for: ${DateFormat('MMM d, h:mm a').format(_pendingSubtaskDeadline!)}", style: const TextStyle(color: taskPrimary, fontSize: 9, fontWeight: FontWeight.bold))),
                const SizedBox(height: 20),

                const Text("CATEGORY", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedCategory = cat); },
                            child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: isSelected ? taskPrimary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? taskPrimary : Colors.white12)), child: Center(child: Text(cat, style: TextStyle(color: isSelected ? taskPrimary : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)))),
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: () => setState(() => _addingCategory = true),
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12, style: BorderStyle.solid)), child: const Icon(Icons.add, size: 16, color: Colors.white54)),
                      ),
                    ],
                  ),
                ),
                if (_addingCategory)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(child: TextField(controller: _newCategoryController, autofocus: true, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: const InputDecoration(hintText: "New category name", hintStyle: TextStyle(color: Colors.white24), isDense: true, border: InputBorder.none))),
                        TextButton(onPressed: () { final name = _newCategoryController.text.trim(); if (name.isNotEmpty) { ref.read(taskCategoriesProvider.notifier).addCategory(name); setState(() { _selectedCategory = name; _addingCategory = false; _newCategoryController.clear(); }); } }, child: const Text("Add", style: TextStyle(color: taskPrimary))),
                      ],
                    ),
                  ),

                // 🌟 SECTION: LINK ROUTINES (HABITS)
                const SizedBox(height: 20),
                const Text("LINK ROUTINE (OPTIONAL)", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                habitsAsync.when(
                  data: (habits) {
                    final activeHabits = habits.where((h) => h.lifecycle == 'active').toList();
                    if (activeHabits.isEmpty) return const Text("No routines found.", style: TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic));
                    return Wrap(
                      spacing: 8, runSpacing: 8,
                      children: activeHabits.map((h) {
                        final isSelected = _linkedHabitIds.contains(h.id);
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() { if (isSelected) _linkedHabitIds.remove(h.id); else _linkedHabitIds.add(h.id); });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: isSelected ? taskSecondary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? taskSecondary : Colors.white12)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(h.iconEmoji, style: const TextStyle(fontSize: 10)),
                                const SizedBox(width: 4),
                                Text(h.title, style: TextStyle(color: isSelected ? taskSecondary : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (_, __) => const SizedBox(),
                ),

                const SizedBox(height: 20),
                const Text("PRIORITY & DEADLINE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Wrap(
                      spacing: 6,
                      children: [
                        _buildPriorityChip(0, "🧊 Low", Colors.blueGrey),
                        _buildPriorityChip(1, "⭐ Med", Colors.orangeAccent),
                        _buildPriorityChip(2, "🔥 High", Colors.redAccent),
                      ],
                    ),
                    GestureDetector(
                      onTap: _pickDateTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: _selectedDate != null ? taskPrimary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: _selectedDate != null ? taskPrimary : Colors.white12)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, size: 14, color: _selectedDate != null ? taskPrimary : Colors.white54),
                            const SizedBox(width: 6),
                            Text(_selectedDate != null ? DateFormat('MMM d, h:mm a').format(_selectedDate!) : "Set Deadline", style: TextStyle(color: _selectedDate != null ? taskPrimary : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                if (_selectedDate != null) ...[
                  const SizedBox(height: 20),
                  const Text("REPEAT", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: AetherTask.recurrenceOptions.map((r) => _buildTextChip(r, _kRecurrenceLabels[r]!, _recurrence == r, () => setState(() => _recurrence = r))).toList()),
                  const SizedBox(height: 20),
                  const Text("REMIND ME", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: _kReminderOffsetLabels.entries.map((e) => _buildTextChip(e.key.toString(), e.value, _reminderOffset == e.key, () => setState(() => _reminderOffset = e.key))).toList()),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: taskPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _isSaving ? null : () async {
                      if (_titleController.text.trim().isEmpty) return;
                      HapticFeedback.heavyImpact();
                      setState(() => _isSaving = true);
                      try {
                        final recurrenceRule = _selectedDate != null && _recurrence != 'none' ? _recurrence : null;
                        if (_isEditing) {
                          await ref.read(taskNotifierProvider.notifier).updateTask(widget.editTask!, title: _titleController.text.trim(), description: _descController.text.trim(), priority: _priority, dueDate: _selectedDate, category: _selectedCategory, recurrenceRule: recurrenceRule, reminderOffsetMinutes: _reminderOffset, notes: _notesController.text.trim(), subtasks: _localSubtasks, linkedHabitIds: _linkedHabitIds, attachments: _localAttachments);
                        } else {
                          await ref.read(taskNotifierProvider.notifier).addTask(title: _titleController.text.trim(), description: _descController.text.trim(), priority: _priority, dueDate: _selectedDate, category: _selectedCategory, recurrenceRule: recurrenceRule, reminderOffsetMinutes: _reminderOffset, notes: _notesController.text.trim(), subtasks: _localSubtasks, linkedHabitIds: _linkedHabitIds, attachments: _localAttachments);
                        }
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                      if (!mounted) return;
                      context.pop();
                    },
                    child: Text(_isSaving ? "PROCESSING..." : (_isEditing ? "UPDATE TASK" : "DEPLOY TASK"), style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(int level, String label, Color color) {
    final isSelected = _priority == level;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() => _priority = level); },
      child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? color.withValues(alpha: 0.5) : Colors.white12)), child: Text(label, style: TextStyle(color: isSelected ? color : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildTextChip(String value, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: selected ? taskPrimary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: selected ? taskPrimary : Colors.white12)), child: Text(label, style: TextStyle(color: selected ? taskPrimary : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
    );
  }
}

class TasksDoodleBackground extends StatelessWidget {
  final Widget child;
  const TasksDoodleBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final random = math.Random(42);
    final icons = [Icons.task_alt, Icons.bolt, Icons.check_circle_outline, Icons.flag_outlined, Icons.timer_outlined, Icons.work_outline, Icons.rocket_launch_outlined, Icons.star_border];

    return Stack(
      children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0D0A14), Color(0xFF001A1E)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        Positioned.fill(
          child: RepaintBoundary(
            child: Opacity(
              opacity: 0.02, 
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cols = (constraints.maxWidth / 32.0).ceil() + 2;
                  final rows = (constraints.maxHeight / 32.0).ceil() + 2;
                  List<Widget> doodles = [];
                  for (int r = -1; r < rows; r++) {
                    for (int c = -1; c < cols; c++) {
                      final icon = icons[random.nextInt(icons.length)];
                      double offsetX = c * 32.0 + (r % 2 == 0 ? 16.0 : 0) + (random.nextDouble() - 0.5) * 8;
                      double offsetY = r * 28.0 + (random.nextDouble() - 0.5) * 8;
                      doodles.add(Positioned(left: offsetX, top: offsetY, child: Transform.rotate(angle: random.nextDouble() * 2 * math.pi, child: Icon(icon, size: 16.0 + random.nextDouble() * 12.0, color: Colors.white))));
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