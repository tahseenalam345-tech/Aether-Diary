import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'aether_focus_session.g.dart';

@HiveType(typeId: 5)
class AetherFocusSession extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final DateTime startTime;
  @HiveField(2) final int durationMinutes; // Kitne time ka set kiya tha
  @HiveField(3) final String sessionType; 
  @HiveField(4, defaultValue: 'Deep Work') final String taskName;
  @HiveField(5, defaultValue: []) final List<String> capturedNotes;
  
  // 🌟 NEW: Track Aborted/Failed vs Completed
  @HiveField(6, defaultValue: 'Completed') final String status; 
  @HiveField(7, defaultValue: 0) final int actualDurationSeconds; // Asal mein kitni der chala

  AetherFocusSession({
    String? id,
    required this.startTime,
    required this.durationMinutes,
    this.sessionType = "Focus",
    this.taskName = 'Deep Work',
    List<String>? capturedNotes,
    this.status = 'Completed',
    this.actualDurationSeconds = 0,
  })  : id = id ?? const Uuid().v4(),
        capturedNotes = capturedNotes ?? [];
}