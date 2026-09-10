// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aether_budget.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AetherBudgetAdapter extends TypeAdapter<AetherBudget> {
  @override
  final int typeId = 11;

  @override
  AetherBudget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AetherBudget(
      id: fields[0] as String?,
      category: fields[1] as String,
      limitAmount: fields[2] as double,
      period: fields[3] as String,
      createdAt: fields[4] as DateTime?,
      name: fields[5] as String?,
      includePastTransactions: fields[6] as bool? ?? false,
      isActive: fields[7] as bool? ?? true,
      pauseTimestamps: (fields[8] as List?)?.cast<DateTime>() ?? const [],
      resumeTimestamps: (fields[9] as List?)?.cast<DateTime>() ?? const [],
      accountId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AetherBudget obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.limitAmount)
      ..writeByte(3)
      ..write(obj.period)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.name)
      ..writeByte(6)
      ..write(obj.includePastTransactions)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.pauseTimestamps)
      ..writeByte(9)
      ..write(obj.resumeTimestamps)
      ..writeByte(10)
      ..write(obj.accountId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AetherBudgetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
