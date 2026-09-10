// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aether_habit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AetherHabitAdapter extends TypeAdapter<AetherHabit> {
  @override
  final int typeId = 3;

  @override
  AetherHabit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AetherHabit(
      id: fields[0] as String?,
      title: fields[1] == null ? '' : fields[1] as String,
      iconEmoji: fields[2] == null ? '🔥' : fields[2] as String,
      createdAt: fields[3] as DateTime?,
      habitType: fields[4] == null ? 'simple' : fields[4] as String,
      target: fields[5] == null ? 1.0 : fields[5] as double,
      unit: fields[6] == null ? 'times' : fields[6] as String,
      activeDays: fields[7] == null
          ? [1, 2, 3, 4, 5, 6, 7]
          : (fields[7] as List?)?.cast<int>(),
      schedule: fields[8] == null ? [] : (fields[8] as List?)?.cast<String>(),
      history:
          fields[9] == null ? {} : (fields[9] as Map?)?.cast<String, String>(),
      lifecycle: fields[10] == null ? 'active' : fields[10] as String,
      startDate: fields[11] as DateTime?,
      endDate: fields[12] as DateTime?,
      priority: fields[13] == null ? 1 : fields[13] as int,
      isPinned: fields[14] == null ? false : fields[14] as bool,
      reminders:
          fields[15] == null ? [] : (fields[15] as List?)?.cast<String>(),
      lastMovedToTop: fields[16] as DateTime?,
      category: fields[17] == null ? 'General' : fields[17] as String,
      description: fields[18] == null ? '' : fields[18] as String,
      linkedTaskIds:
          fields[19] == null ? [] : (fields[19] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, AetherHabit obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.iconEmoji)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.habitType)
      ..writeByte(5)
      ..write(obj.target)
      ..writeByte(6)
      ..write(obj.unit)
      ..writeByte(7)
      ..write(obj.activeDays)
      ..writeByte(8)
      ..write(obj.schedule)
      ..writeByte(9)
      ..write(obj.history)
      ..writeByte(10)
      ..write(obj.lifecycle)
      ..writeByte(11)
      ..write(obj.startDate)
      ..writeByte(12)
      ..write(obj.endDate)
      ..writeByte(13)
      ..write(obj.priority)
      ..writeByte(14)
      ..write(obj.isPinned)
      ..writeByte(15)
      ..write(obj.reminders)
      ..writeByte(16)
      ..write(obj.lastMovedToTop)
      ..writeByte(17)
      ..write(obj.category)
      ..writeByte(18)
      ..write(obj.description)
      ..writeByte(19)
      ..write(obj.linkedTaskIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AetherHabitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
