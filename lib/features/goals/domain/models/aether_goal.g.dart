// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aether_goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AetherGoalAdapter extends TypeAdapter<AetherGoal> {
  @override
  final int typeId = 4;

  @override
  AetherGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AetherGoal(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String,
      category: fields[3] as String,
      targetAmount: fields[4] as double,
      currentAmount: fields[5] as double,
      targetDate: fields[6] as DateTime,
      autoSyncWealth: fields[7] as bool,
      createdAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AetherGoal obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.targetAmount)
      ..writeByte(5)
      ..write(obj.currentAmount)
      ..writeByte(6)
      ..write(obj.targetDate)
      ..writeByte(7)
      ..write(obj.autoSyncWealth)
      ..writeByte(8)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AetherGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
