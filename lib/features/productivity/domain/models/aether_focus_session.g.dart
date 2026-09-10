// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aether_focus_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AetherFocusSessionAdapter extends TypeAdapter<AetherFocusSession> {
  @override
  final int typeId = 5;

  @override
  AetherFocusSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AetherFocusSession(
      id: fields[0] as String?,
      startTime: fields[1] as DateTime,
      durationMinutes: fields[2] as int,
      sessionType: fields[3] as String,
      taskName: fields[4] == null ? 'Deep Work' : fields[4] as String,
      capturedNotes:
          fields[5] == null ? [] : (fields[5] as List?)?.cast<String>(),
      status: fields[6] == null ? 'Completed' : fields[6] as String,
      actualDurationSeconds: fields[7] == null ? 0 : fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AetherFocusSession obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.durationMinutes)
      ..writeByte(3)
      ..write(obj.sessionType)
      ..writeByte(4)
      ..write(obj.taskName)
      ..writeByte(5)
      ..write(obj.capturedNotes)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.actualDurationSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AetherFocusSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
