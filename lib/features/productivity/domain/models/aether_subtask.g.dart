// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aether_subtask.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AetherSubtaskAdapter extends TypeAdapter<AetherSubtask> {
  @override
  final int typeId = 2;

  @override
  AetherSubtask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AetherSubtask(
      id: fields[0] as String,
      title: fields[1] as String,
      isCompleted: fields[2] as bool,
      completedAt: fields[3] as DateTime?,
      deadline: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AetherSubtask obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.isCompleted)
      ..writeByte(3)
      ..write(obj.completedAt)
      ..writeByte(4)
      ..write(obj.deadline);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AetherSubtaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
