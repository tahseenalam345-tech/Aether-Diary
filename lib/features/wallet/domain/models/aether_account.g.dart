// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aether_account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AetherAccountAdapter extends TypeAdapter<AetherAccount> {
  @override
  final int typeId = 10;

  @override
  AetherAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AetherAccount(
      id: fields[0] as String?,
      title: fields[1] as String,
      accountType: fields[2] as String,
      initialBalance: fields[3] as double,
      currency: fields[4] as String,
      colorHex: fields[5] as String,
      iconName: fields[6] as String,
      institutionName: fields[7] as String?,
      maskedAccountNumber: fields[8] as String?,
      isArchived: fields[9] as bool,
      isHiddenFromTotal: fields[10] as bool,
      baseConversionRate: fields[12] as double,
      createdAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AetherAccount obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.accountType)
      ..writeByte(3)
      ..write(obj.initialBalance)
      ..writeByte(4)
      ..write(obj.currency)
      ..writeByte(5)
      ..write(obj.colorHex)
      ..writeByte(6)
      ..write(obj.iconName)
      ..writeByte(7)
      ..write(obj.institutionName)
      ..writeByte(8)
      ..write(obj.maskedAccountNumber)
      ..writeByte(9)
      ..write(obj.isArchived)
      ..writeByte(10)
      ..write(obj.isHiddenFromTotal)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.baseConversionRate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AetherAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
