import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/productivity_providers.dart';
import '../../data/task_category_provider.dart';
import '../../domain/models/aether_task.dart';
import '../../domain/models/aether_subtask.dart';

const Color taskPrimary = Color(0xFF06B6D4);
const Color taskSecondary = Color(0xFF8B5CF6);

const Map<String, String> _kRecurrenceLabels = {
  'none': 'One-time',
  'daily': 'Daily',
  'weekly': 'Weekly',
  'monthly': 'Monthly',
};

const Map<int, String> _kReminderOffsetLabels = {
  0: 'At due time',
  15: '15 min before',
  60: '1 hour before',
  1440: '1 day before',
};

/// 🌟 GLOBAL HELPER TO OPEN THE AUTHENTIC AETHER TASK DEPLOYMENT DIALOG
void showAetherTaskFormDialog(BuildContext context, {AetherTask? editTask}) {
  HapticFeedback.lightImpact();
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (context) => Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Material(
          color: Colors.transparent,
          child: AetherTaskFormDialog(editTask: editTask),
        ),
      ),
    ),
  );
}

class AetherTaskFormDialog extends ConsumerStatefulWidget {
  final AetherTask? editTask;
  const AetherTaskFormDialog({super.key, this.editTask});

  @override
  ConsumerState<AetherTaskFormDialog> createState() => _AetherTaskFormDialogState();
}

class _AetherTaskFormDialogState extends ConsumerState<AetherTaskFormDialog> {
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
  List<String> _localAttachments = [];

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  bool get _isEditing => widget.editTask != null;

  @override
  void initState() {
    super.initState();
    final t = widget.editTask;
    if (t != null) {
      _titleController.text = t.title;
      _descController.text = t.description;
      _notesController.text = t.notes;
      _priority = t.priority;
      _selectedDate = t.dueDate;
      _selectedCategory = t.category;
      _recurrence = t.recurrenceRule ?? 'none';
      _reminderOffset = t.reminderOffsetMinutes;
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
        }
      } catch (_) {}
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        setState(() {
          _localAttachments.add(pickedFile.path);
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDateTime() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: taskPrimary, surface: Color(0xFF1A1A1A)),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDate != null ? TimeOfDay.fromDateTime(_selectedDate!) : TimeOfDay.now(),
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: taskPrimary, surface: Color(0xFF1A1A1A)),
          ),
          child: child!,
        ),
      );

      setState(() {
        if (pickedTime != null) {
          _selectedDate = DateTime(picked.year, picked.month, picked.day, pickedTime.hour, pickedTime.minute);
        } else {
          _selectedDate = picked;
        }
      });
    }
  }

  Future<void> _pickSubtaskDeadline() async {
    HapticFeedback.selectionClick();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: taskPrimary, surface: Color(0xFF1A1A1A))),
        child: child!,
      ),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) => Theme(
          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: taskPrimary, surface: Color(0xFF1A1A1A))),
          child: child!,
        ),
      );
      if (pickedTime != null && mounted) {
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
          decoration: BoxDecoration(
            color: const Color(0xFF101012).withValues(alpha: 0.94),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditing ? "EDIT TASK" : "DEPLOY TASK",
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 🌟 TITLE FIELD WITH VOICE INPUT
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          autofocus: !_isEditing,
                          style: const TextStyle(color: taskPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: "What needs to be done?",
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _listen(_titleController),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.redAccent : Colors.white54,
                          size: 22,
                        ).animate(target: _isListening ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 🌟 DESCRIPTION FIELD WITH VOICE INPUT
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _descController,
                          maxLines: 2,
                          minLines: 1,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: "Description or notes (optional)",
                            hintStyle: TextStyle(color: Colors.white24),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _listen(_descController),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.redAccent : Colors.white54,
                          size: 18,
                        ).animate(target: _isListening ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 🌟 ATTACHMENTS SECTION
                const Text("ATTACHMENTS (OPTIONAL)", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(Icons.add_a_photo, color: Colors.white54),
                        ),
                      ),
                      ..._localAttachments.asMap().entries.map((e) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(e.value),
                                  fit: BoxFit.cover,
                                  cacheWidth: 150,
                                  errorBuilder: (ctx, err, st) => const Icon(Icons.broken_image, color: Colors.white24),
                                ),
                              ),
                            ),
                            Positioned(
                              top: -5,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => _localAttachments.removeAt(e.key)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            )
                          ],
                        );
                      })
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 🌟 SUBTASKS / ACTION STEPS
                const Text("ACTION STEPS", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                if (_localSubtasks.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _localSubtasks.length,
                    itemBuilder: (context, index) {
                      final st = _localSubtasks[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.check_box_outline_blank, color: Colors.white24, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(st.title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  if (st.deadline != null)
                                    Text(
                                      "Due: ${DateFormat('MMM d, h:mm a').format(st.deadline!)}",
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _localSubtasks.removeAt(index);
                                });
                              },
                            )
                          ],
                        ),
                      );
                    },
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newSubtaskController,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
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
                if (_pendingSubtaskDeadline != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 16),
                    child: Text(
                      "Set for: ${DateFormat('MMM d, h:mm a').format(_pendingSubtaskDeadline!)}",
                      style: const TextStyle(color: taskPrimary, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 20),

                // 🌟 CATEGORIES
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
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedCategory = cat);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? taskPrimary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? taskPrimary : Colors.white12),
                              ),
                              child: Center(
                                child: Text(
                                  cat,
                                  style: TextStyle(color: isSelected ? taskPrimary : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: () => setState(() => _addingCategory = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(Icons.add, size: 16, color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_addingCategory)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newCategoryController,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(hintText: "New category name", hintStyle: TextStyle(color: Colors.white24), isDense: true, border: InputBorder.none),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final name = _newCategoryController.text.trim();
                            if (name.isNotEmpty) {
                              ref.read(taskCategoriesProvider.notifier).addCategory(name);
                              setState(() {
                                _selectedCategory = name;
                                _addingCategory = false;
                                _newCategoryController.clear();
                              });
                            }
                          },
                          child: const Text("Add", style: TextStyle(color: taskPrimary)),
                        ),
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
                      spacing: 8,
                      runSpacing: 8,
                      children: activeHabits.map((h) {
                        final isSelected = _linkedHabitIds.contains(h.id);
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (isSelected) _linkedHabitIds.remove(h.id);
                              else _linkedHabitIds.add(h.id);
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? taskSecondary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? taskSecondary : Colors.white12),
                            ),
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
                        decoration: BoxDecoration(
                          color: _selectedDate != null ? taskPrimary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _selectedDate != null ? taskPrimary : Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, size: 14, color: _selectedDate != null ? taskPrimary : Colors.white54),
                            const SizedBox(width: 6),
                            Text(
                              _selectedDate != null ? DateFormat('MMM d, h:mm a').format(_selectedDate!) : "Set Deadline",
                              style: TextStyle(color: _selectedDate != null ? taskPrimary : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
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
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: AetherTask.recurrenceOptions
                        .map((r) => _buildTextChip(r, _kRecurrenceLabels[r]!, _recurrence == r, () => setState(() => _recurrence = r)))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text("REMIND ME", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _kReminderOffsetLabels.entries
                        .map((e) => _buildTextChip(e.key.toString(), e.value, _reminderOffset == e.key, () => setState(() => _reminderOffset = e.key)))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: taskPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _isSaving
                        ? null
                        : () async {
                            if (_titleController.text.trim().isEmpty) return;
                            HapticFeedback.heavyImpact();
                            setState(() => _isSaving = true);
                            try {
                              final recurrenceRule = _selectedDate != null && _recurrence != 'none' ? _recurrence : null;
                              if (_isEditing) {
                                await ref.read(taskNotifierProvider.notifier).updateTask(
                                      widget.editTask!,
                                      title: _titleController.text.trim(),
                                      description: _descController.text.trim(),
                                      priority: _priority,
                                      dueDate: _selectedDate,
                                      category: _selectedCategory,
                                      recurrenceRule: recurrenceRule,
                                      reminderOffsetMinutes: _reminderOffset,
                                      notes: _notesController.text.trim(),
                                      subtasks: _localSubtasks,
                                      linkedHabitIds: _linkedHabitIds,
                                      attachments: _localAttachments,
                                    );
                              } else {
                                await ref.read(taskNotifierProvider.notifier).addTask(
                                      title: _titleController.text.trim(),
                                      description: _descController.text.trim(),
                                      priority: _priority,
                                      dueDate: _selectedDate,
                                      category: _selectedCategory,
                                      recurrenceRule: recurrenceRule,
                                      reminderOffsetMinutes: _reminderOffset,
                                      notes: _notesController.text.trim(),
                                      subtasks: _localSubtasks,
                                      linkedHabitIds: _linkedHabitIds,
                                      attachments: _localAttachments,
                                    );
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
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _priority = level);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color.withValues(alpha: 0.5) : Colors.white12),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? color : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTextChip(String value, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? taskPrimary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? taskPrimary : Colors.white12),
        ),
        child: Text(label, style: TextStyle(color: selected ? taskPrimary : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
