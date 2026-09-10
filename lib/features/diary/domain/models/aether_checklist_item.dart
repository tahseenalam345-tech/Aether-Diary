import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'aether_checklist_item.g.dart';

@HiveType(typeId: 7)
class AetherChecklistItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String text;

  @HiveField(2)
  final bool isCompleted;

  AetherChecklistItem({
    String? id,
    required this.text,
    this.isCompleted = false,
  }) : id = id ?? const Uuid().v4();

  AetherChecklistItem copyWith({String? text, bool? isCompleted}) {
    return AetherChecklistItem(
      id: id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}