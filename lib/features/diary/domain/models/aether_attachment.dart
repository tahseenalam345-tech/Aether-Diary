import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'aether_attachment.g.dart';

@HiveType(typeId: 6)
class AetherAttachment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; // 'image', 'video', 'audio', 'document', 'link'

  @HiveField(2)
  final String path; // Local path or URL

  @HiveField(3)
  final String name; // Filename or Link Title

  @HiveField(4)
  final int byteSize; // File size for rendering badges

  @HiveField(5)
  final String? thumbnailPath; // Extracted thumbnail for videos/pdfs

  @HiveField(6)
  final DateTime createdAt;

  AetherAttachment({
    String? id,
    required this.type,
    required this.path,
    required this.name,
    this.byteSize = 0,
    this.thumbnailPath,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
}