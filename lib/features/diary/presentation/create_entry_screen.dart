import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:local_auth/local_auth.dart';

import '../domain/models/diary_entry.dart';
import '../domain/models/aether_attachment.dart';
import '../data/diary_provider.dart';

import 'widgets/aether_drawing_canvas.dart';
import '../../wallet/presentation/widgets/aether_liquid_date_picker.dart';

enum NoteBackground { amoledVoid, obsidianNebula, emeraldAurora, midnightIndigo, sunsetRose, cyberpunkTeal }

// ---------------------------------------------------------------------------
// 🌟 CREATE / EDIT ENTRY SCREEN
// ---------------------------------------------------------------------------
class CreateEntryScreen extends ConsumerStatefulWidget {
  final DiaryEntry? existingEntry;
  final String? initialMood;

  const CreateEntryScreen({
    super.key,
    this.existingEntry,
    this.initialMood,
  });

  @override
  ConsumerState<CreateEntryScreen> createState() => _CreateEntryScreenState();
}

class _CreateEntryScreenState extends ConsumerState<CreateEntryScreen> {
  late TextEditingController _titleController;
  late quill.QuillController _contentController;
  late String _selectedMood;
  late List<AetherAttachment> _attachments;
  late List<String> _tags;
  bool _isPinned = false;
  bool _isLocked = false;
  NoteBackground _bgTheme = NoteBackground.amoledVoid;
  bool _hasSaved = false;

  // Voice to Text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _moods = [
    {'name': 'Happy', 'emoji': '😊', 'color': const Color(0xFFFFD700)},
    {'name': 'Calm', 'emoji': '🌊', 'color': const Color(0xFF4ADE80)},
    {'name': 'Sad', 'emoji': '🌧️', 'color': const Color(0xFF60A5FA)},
    {'name': 'Anxious', 'emoji': '⚡', 'color': const Color(0xFFF472B6)},
    {'name': 'Angry', 'emoji': '🔥', 'color': const Color(0xFFEF4444)},
  ];

  Color get _currentMoodColor =>
      _moods.firstWhere((m) => m['name'] == _selectedMood, orElse: () => _moods[1])['color'] as Color;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingEntry?.title ?? '');

    quill.Document document;
    final existingContent = widget.existingEntry?.content ?? '';
    if (existingContent.isEmpty) {
      document = quill.Document();
    } else {
      try {
        final decoded = jsonDecode(existingContent);
        document = quill.Document.fromJson(decoded);
      } catch (e) {
        document = quill.Document()..insert(0, existingContent);
      }
    }
    _contentController = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    // Pre-select passed mood if creating a new entry
    if (widget.existingEntry != null) {
      _selectedMood = widget.existingEntry!.mood ?? 'Calm';
      _isPinned = widget.existingEntry!.isPinned;
      _tags = List.from(widget.existingEntry!.tags);
      _attachments = List.from(widget.existingEntry!.attachments);
    } else {
      _selectedMood = widget.initialMood ?? 'Calm';
      _tags = ['Personal'];
      _attachments = [];
    }
    
    _contentController.addListener(() { setState(() {}); });
  }

  @override
  void dispose() {
    if (_isListening) _speech.stop();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _autoSaveDraft() async {
    if (_hasSaved) return;
    if (_titleController.text.trim().isEmpty && _contentController.document.isEmpty()) return;

    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : "Draft - ${DateFormat('MMM d, h:mm a').format(DateTime.now())}";
    final content = jsonEncode(_contentController.document.toDelta().toJson());

    if (widget.existingEntry != null) {
      final updated = widget.existingEntry!.copyWith(
        title: title,
        content: content,
        mood: _selectedMood,
        isPinned: _isPinned,
        tags: _tags,
        attachments: _attachments,
      );
      await ref.read(diaryEntriesProvider.notifier).updateEntry(updated);
    } else {
      await ref.read(diaryEntriesProvider.notifier).addEntry(
        title: title,
        content: content,
        mood: _selectedMood,
        isPinned: _isPinned,
        tags: _tags,
        attachments: _attachments,
      );
    }
    _hasSaved = true;
  }

  // 🌟 ADVANCED INSERTIONS: TABLES, SKETCHES, VOICE
  // ---------------------------------------------------------------------------
  void _showTableDialog() {
    int rows = 3;
    int cols = 3;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          backgroundColor: const Color(0xFF0C101E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
          title: const Text("Generate Table", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Columns", style: TextStyle(color: Colors.white70)),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white54), onPressed: cols > 1 ? () => setDState(() => cols--) : null),
                      Text("$cols", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white54), onPressed: cols < 6 ? () => setDState(() => cols++) : null),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Rows", style: TextStyle(color: Colors.white70)),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white54), onPressed: rows > 1 ? () => setDState(() => rows--) : null),
                      Text("$rows", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white54), onPressed: rows < 10 ? () => setDState(() => rows++) : null),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: const Color(0xFF060B14)),
              onPressed: () {
                Navigator.pop(ctx);
                final header = "| ${List.generate(cols, (i) => "Col ${i + 1}").join(" | ")} |\n";
                final sep = "| ${List.generate(cols, (_) => "---").join(" | ")} |\n";
                final body = List.generate(rows, (_) => "| ${List.generate(cols, (_) => "Data").join(" | ")} |").join("\n");
                _insertAtCursor("\n\n$header$sep$body\n\n");
              },
              child: const Text("Insert Table", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _insertAtCursor(String text) {
    final index = _contentController.selection.baseOffset;
    final length = _contentController.selection.extentOffset - index;
    final docLength = _contentController.document.length;
    final safeIndex = (index < 0 || index > docLength - 1) ? (docLength > 0 ? docLength - 1 : 0) : index;
    final safeLength = (length < 0 || safeIndex + length > docLength) ? 0 : length;
    _contentController.replaceText(
      safeIndex,
      safeLength,
      text,
      TextSelection.collapsed(offset: safeIndex + text.length),
    );
  }

  void _openDrawingCanvas() async {
    HapticFeedback.lightImpact();
    final imagePath = await showDialog<String?>(
      context: context,
      builder: (ctx) => const AetherDrawingCanvasDialog(),
    );

    if (imagePath != null && mounted) {
      setState(() {
        _attachments.add(AetherAttachment(
          type: 'image',
          path: imagePath,
          name: 'Whiteboard Sketch',
          createdAt: DateTime.now(),
        ));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Handwritten whiteboard sketch attached! 🎨")),
      );
    }
  }

  void _toggleListening() async {
    if (!_isListening) {
      try {
        bool available = await _speech.initialize(onStatus: (val) {
          if (val == 'done' && mounted) setState(() => _isListening = false);
        });
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(onResult: (val) {
            if (mounted && val.recognizedWords.isNotEmpty) {
              _insertAtCursor(" ${val.recognizedWords}");
            }
          });
        }
      } catch (_) {}
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // ---------------------------------------------------------------------------
  // 🌟 TOP 3-DOTS META-CONTROLS BOTTOM SHEET
  // ---------------------------------------------------------------------------
  void _showMetaControlsSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0C101E).withValues(alpha: 0.95),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Pin Note
                _sheetActionTile(
                  icon: _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: const Color(0xFFFBBF24),
                  label: _isPinned ? "Unpin from Vault" : "Pin Note to Top",
                  onTap: () {
                    setState(() => _isPinned = !_isPinned);
                    Navigator.pop(context);
                  },
                ),

                // 2. Change Canvas Background Theme
                _sheetActionTile(
                  icon: Icons.palette_outlined,
                  color: const Color(0xFF8B5CF6),
                  label: "Canvas Background Theme",
                  onTap: () {
                    Navigator.pop(context);
                    _showBackgroundPicker();
                  },
                ),

                // 3. Biometric Lock Note
                _sheetActionTile(
                  icon: _isLocked ? Icons.lock_rounded : Icons.lock_outline_rounded,
                  color: const Color(0xFFF43F5E),
                  label: _isLocked ? "Unlock Note" : "Lock Note with Biometrics",
                  onTap: () async {
                    Navigator.pop(context);
                    final auth = LocalAuthentication();
                    final canAuth = await auth.canCheckBiometrics;
                    if (canAuth) {
                      final didAuth = await auth.authenticate(localizedReason: "Authenticate to toggle note lock");
                      if (didAuth && mounted) {
                        setState(() => _isLocked = !_isLocked);
                      }
                    } else {
                      setState(() => _isLocked = !_isLocked);
                    }
                  },
                ),

                // 4. Share Note
                _sheetActionTile(
                  icon: Icons.share_outlined,
                  color: const Color(0xFF38BDF8),
                  label: "Share Formatted Note",
                  onTap: () async {
                    Navigator.pop(context);
                    final shareText = "${_titleController.text}\n\n${_contentController.document.toPlainText()}\n\n[Captured in Aether OS Sanctuary]";
                    await Share.share(shareText);
                  },
                ),

                // 5. Set Reminder
                _sheetActionTile(
                  icon: Icons.notifications_active_outlined,
                  color: const Color(0xFF2DD4BF),
                  label: "Schedule Reflection Reminder",
                  onTap: () async {
                    Navigator.pop(context);
                    final picked = await showAetherLiquidDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      accentColor: const Color(0xFF2DD4BF),
                      title: "Reminder Date",
                    );
                    if (picked != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reminder scheduled successfully! 🔔")));
                    }
                  },
                ),

                // 6. Move Note to Tag / Folder
                _sheetActionTile(
                  icon: Icons.folder_open_rounded,
                  color: const Color(0xFFFBBF24),
                  label: "Move to Folder / Tag (${_tags.isNotEmpty ? _tags.first : 'None'})",
                  onTap: () {
                    Navigator.pop(context);
                    _showFolderTagPicker();
                  },
                ),

                // 7. Delete Note (if existing)
                if (widget.existingEntry != null)
                  _sheetActionTile(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    label: "Delete Note",
                    onTap: () async {
                      Navigator.pop(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF131826),
                          title: const Text("Delete Reflection?", style: TextStyle(color: Colors.white)),
                          content: const Text("This action cannot be undone.", style: TextStyle(color: Colors.white54)),
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
                      if (confirm == true && mounted) {
                        _hasSaved = true;
                        await ref.read(diaryEntriesProvider.notifier).deleteEntry(widget.existingEntry!.id);
                        if (mounted) context.pop();
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

  void _showBackgroundPicker() {
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
            const Text("Canvas Background Theme", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: NoteBackground.values.map((bg) {
                final isSel = _bgTheme == bg;
                return GestureDetector(
                  onTap: () {
                    setState(() => _bgTheme = bg);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _getBgColor(bg),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSel ? const Color(0xFF2DD4BF) : Colors.white12, width: isSel ? 2 : 1),
                    ),
                    child: Text(
                      _getBgName(bg),
                      style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderTagPicker() {
    final folders = ['Personal', 'Ideas', 'Work', 'Reflections', 'Gratitude', 'Deep Thoughts'];
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
            const Text("Select Folder / Primary Tag", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: folders.map((f) {
                final isSel = _tags.contains(f);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _tags = [f];
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF38BDF8).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSel ? const Color(0xFF38BDF8) : Colors.white12),
                    ),
                    child: Text(f, style: TextStyle(color: isSel ? const Color(0xFF38BDF8) : Colors.white70, fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetActionTile({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      dense: true,
      onTap: onTap,
    );
  }

  Color _getBgColor(NoteBackground bg) {
    switch (bg) {
      case NoteBackground.amoledVoid: return const Color(0xFF060B14);
      case NoteBackground.obsidianNebula: return const Color(0xFF0F172A);
      case NoteBackground.emeraldAurora: return const Color(0xFF062016);
      case NoteBackground.midnightIndigo: return const Color(0xFF131127);
      case NoteBackground.sunsetRose: return const Color(0xFF240E17);
      case NoteBackground.cyberpunkTeal: return const Color(0xFF051C20);
    }
  }

  String _getBgName(NoteBackground bg) {
    switch (bg) {
      case NoteBackground.amoledVoid: return "AMOLED Void";
      case NoteBackground.obsidianNebula: return "Obsidian Slate";
      case NoteBackground.emeraldAurora: return "Emerald Aurora";
      case NoteBackground.midnightIndigo: return "Midnight Indigo";
      case NoteBackground.sunsetRose: return "Sunset Rose";
      case NoteBackground.cyberpunkTeal: return "Cyberpunk Teal";
    }
  }

  // ---------------------------------------------------------------------------
  // 🌟 BUILD METHOD (WITH POPSCOPE FOR AUTO-DRAFT)
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final bgColor = _getBgColor(_bgTheme);
    final isNewEntry = widget.existingEntry == null;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!_hasSaved) {
          await _autoSaveDraft();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // 🌟 TOP APP BAR
              _buildTopBar(context),

              // 🌟 MAIN NOTE CONTENT CANVAS
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mood Selector Row
                      _buildMoodChipsRow(),

                      const SizedBox(height: 16),

                      // Title Field
                      TextField(
                        controller: _titleController,
                        autofocus: isNewEntry,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: "Untitled Reflection...",
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 26, fontWeight: FontWeight.bold),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Date & Tags Meta Header
                      Row(
                        children: [
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(widget.existingEntry?.createdAt ?? DateTime.now()),
                            style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          if (_tags.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text("#${_tags.first}", style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                      const SizedBox(height: 16),

                      // Rich-Text Body Field
                      Container(
                        constraints: const BoxConstraints(minHeight: 250),
                        child: quill.QuillEditor.basic(
                          controller: _contentController,
                        ),
                      ),

                      // Attached Sketches & Media
                      if (_attachments.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text("ATTACHED WHITEBOARD SKETCHES", style: TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _attachments.length,
                            itemBuilder: (context, index) {
                              final att = _attachments[index];
                              return Container(
                                width: 140,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.file(
                                        File(att.path),
                                        fit: BoxFit.contain,
                                        width: 140,
                                        height: 140,
                                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => _attachments.removeAt(index));
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // 🌟 NOTION / APPLE NOTES FORMATTING TOOLBAR
              _buildNotionFormattingToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 TOP ACTION BAR
  // ---------------------------------------------------------------------------
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button (Auto-saves draft)
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
            onPressed: () async {
              await _autoSaveDraft();
              if (context.mounted) context.pop();
            },
          ),

          // Undo / Redo & Voice
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.undo_rounded, size: 20),
                color: _contentController.hasUndo ? Colors.white : Colors.white24,
                onPressed: _contentController.hasUndo ? () => _contentController.undo() : null,
              ),
              IconButton(
                icon: const Icon(Icons.redo_rounded, size: 20),
                color: _contentController.hasRedo ? Colors.white : Colors.white24,
                onPressed: _contentController.hasRedo ? () => _contentController.redo() : null,
              ),
              IconButton(
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none_rounded, size: 20),
                color: _isListening ? Colors.redAccent : Colors.white70,
                onPressed: _toggleListening,
              ),
            ],
          ),

          // 3-Dots Meta Menu & Save Button
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70),
                onPressed: _showMetaControlsSheet,
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentMoodColor,
                  foregroundColor: const Color(0xFF060B14),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                        HapticFeedback.heavyImpact();
                        setState(() => _isSaving = true);
                        try {
                          await _autoSaveDraft();
                          _hasSaved = true;
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Reflection saved to Sanctuary Vault! ✨")),
                            );
                            context.pop();
                          }
                        } finally {
                          if (mounted) setState(() => _isSaving = false);
                        }
                      },
                child: Text(
                  _isSaving ? "SAVING..." : "SAVE",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 1.0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 MOOD CHIPS SELECTOR ROW
  // ---------------------------------------------------------------------------
  Widget _buildMoodChipsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _moods.map((m) {
          final isSelected = _selectedMood == m['name'];
          final color = m['color'] as Color;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedMood = m['name']);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? color : Colors.white10),
              ),
              child: Row(
                children: [
                  Text(m['emoji'], style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(m['name'], style: TextStyle(color: isSelected ? color : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🌟 NOTION / APPLE NOTES LEVEL RICH FORMATTING TOOLBAR
  // ---------------------------------------------------------------------------
  Widget _buildNotionFormattingToolbar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0C101E).withValues(alpha: 0.96),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Headings
                _formatButton("H1", () => _contentController.formatSelection(quill.Attribute.h1)),
                _formatButton("H2", () => _contentController.formatSelection(quill.Attribute.h2)),
                _formatButton("H3", () => _contentController.formatSelection(quill.Attribute.h3)),
                _formatButton("Body", () => _contentController.formatSelection(quill.Attribute.header)),
                _formatDivider(),

                // Styles
                _formatIconButton(Icons.format_bold_rounded, () => _contentController.formatSelection(quill.Attribute.bold), "Bold"),
                _formatIconButton(Icons.format_italic_rounded, () => _contentController.formatSelection(quill.Attribute.italic), "Italic"),
                _formatIconButton(Icons.format_underlined_rounded, () => _contentController.formatSelection(quill.Attribute.underline), "Underline"),
                _formatIconButton(Icons.format_strikethrough_rounded, () => _contentController.formatSelection(quill.Attribute.strikeThrough), "Strikethrough"),
                _formatDivider(),

                // Lists & Checklists
                _formatIconButton(Icons.checklist_rounded, () => _contentController.formatSelection(quill.Attribute.unchecked), "Checklist"),
                _formatIconButton(Icons.format_list_bulleted_rounded, () => _contentController.formatSelection(quill.Attribute.ul), "Bulleted List"),
                _formatIconButton(Icons.format_quote_rounded, () => _contentController.formatSelection(quill.Attribute.blockQuote), "Quote Block"),
                _formatDivider(),

                // Insertions: Table & Whiteboard Drawing
                _formatIconButton(Icons.table_chart_outlined, _showTableDialog, "Insert Table"),
                _formatIconButton(Icons.draw_rounded, _openDrawingCanvas, "Whiteboard Sketch"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formatButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _formatIconButton(IconData icon, VoidCallback onTap, String tooltip) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }

  Widget _formatDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white12,
    );
  }
}
