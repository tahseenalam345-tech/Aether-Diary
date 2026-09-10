import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'aether_attachment.dart';
import 'aether_checklist_item.dart';

part 'diary_entry.g.dart'; // Adjust name if your file is named differently

@HiveType(typeId: 0)
class DiaryEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime createdAt;

  // --- NEW: THE MULTIMEDIA VAULT UPGRADES ---
  @HiveField(4)
  final List<AetherAttachment> attachments;

  @HiveField(5)
  final List<AetherChecklistItem> checklists;

  @HiveField(6)
  final List<String> tags;

  @HiveField(7)
  final String? mood; // e.g., 'focused', 'creative', 'calm'

  @HiveField(8)
  final String? location;

  @HiveField(9)
  final bool isPinned;

  @HiveField(10)
  final bool isArchived;

  DiaryEntry({
    String? id,
    required this.title,
    required this.content,
    DateTime? createdAt,
    List<AetherAttachment>? attachments,
    List<AetherChecklistItem>? checklists,
    List<String>? tags,
    this.mood,
    this.location,
    this.isPinned = false,
    this.isArchived = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        attachments = attachments ?? [],
        checklists = checklists ?? [],
        tags = tags ?? [];

  DiaryEntry copyWith({
    String? title,
    String? content,
    List<AetherAttachment>? attachments,
    List<AetherChecklistItem>? checklists,
    List<String>? tags,
    String? mood,
    String? location,
    bool? isPinned,
    bool? isArchived,
  }) {
    return DiaryEntry(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      attachments: attachments ?? this.attachments,
      checklists: checklists ?? this.checklists,
      tags: tags ?? this.tags,
      mood: mood ?? this.mood,
      location: location ?? this.location,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}