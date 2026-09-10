// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aether_subscription.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AetherSubscriptionAdapter extends TypeAdapter<AetherSubscription> {
  @override
  final int typeId = 9;

  @override
  AetherSubscription read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AetherSubscription(
      id: fields[0] as String?,
      name: fields[1] as String,
      amount: fields[2] as double,
      billingCycle: fields[3] as String,
      nextDueDate: fields[4] as DateTime,
      categoryId: fields[5] as String,
      isAutoPay: fields[6] as bool,
      createdAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AetherSubscription obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.billingCycle)
      ..writeByte(4)
      ..write(obj.nextDueDate)
      ..writeByte(5)
      ..write(obj.categoryId)
      ..writeByte(6)
      ..write(obj.isAutoPay)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AetherSubscriptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
