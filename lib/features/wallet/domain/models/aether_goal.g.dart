// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aether_goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AetherGoalAdapter extends TypeAdapter<AetherGoal> {
  @override
  final int typeId = 12;

  @override
  AetherGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AetherGoal(
      id: fields[0] as String?,
      title: fields[1] as String,
      targetAmount: fields[2] as double,
      savedAmount: fields[3] as double,
      deadline: fields[4] as DateTime?,
      colorHex: fields[5] as String,
      iconName: fields[6] as String,
      createdAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AetherGoal obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.targetAmount)
      ..writeByte(3)
      ..write(obj.savedAmount)
      ..writeByte(4)
      ..write(obj.deadline)
      ..writeByte(5)
      ..write(obj.colorHex)
      ..writeByte(6)
      ..write(obj.iconName)
      ..writeByte(7)
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
