// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aether_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AetherTaskAdapter extends TypeAdapter<AetherTask> {
  @override
  final int typeId = 1;

  @override
  AetherTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AetherTask(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String,
      isCompleted: fields[3] as bool,
      dueDate: fields[4] as DateTime?,
      priority: fields[5] as int,
      category: fields[7] as String,
      subtasks: (fields[8] as List?)?.cast<AetherSubtask>(),
      recurrenceRule: fields[9] as String?,
      orderIndex: fields[10] as int,
      reminderOffsetMinutes: fields[11] == null ? 0 : fields[11] as int,
      notes: fields[12] == null ? '' : fields[12] as String,
      lifecycle: fields[13] == null ? 'active' : fields[13] as String,
      isPinned: fields[14] == null ? false : fields[14] as bool,
      linkedHabitIds:
          fields[15] == null ? [] : (fields[15] as List?)?.cast<String>(),
      attachments:
          fields[16] == null ? [] : (fields[16] as List?)?.cast<String>(),
      createdAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AetherTask obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.isCompleted)
      ..writeByte(4)
      ..write(obj.dueDate)
      ..writeByte(5)
      ..write(obj.priority)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.category)
      ..writeByte(8)
      ..write(obj.subtasks)
      ..writeByte(9)
      ..write(obj.recurrenceRule)
      ..writeByte(10)
      ..write(obj.orderIndex)
      ..writeByte(11)
      ..write(obj.reminderOffsetMinutes)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
      ..write(obj.lifecycle)
      ..writeByte(14)
      ..write(obj.isPinned)
      ..writeByte(15)
      ..write(obj.linkedHabitIds)
      ..writeByte(16)
      ..write(obj.attachments);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AetherTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
