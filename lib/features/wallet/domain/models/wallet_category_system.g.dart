// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_category_system.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AetherWalletCategoryAdapter extends TypeAdapter<AetherWalletCategory> {
  @override
  final int typeId = 15;

  @override
  AetherWalletCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AetherWalletCategory(
      id: fields[0] as String?,
      name: fields[1] as String,
      iconEmoji: fields[2] as String,
      colorHex: fields[3] as String,
      subcategories: (fields[4] as List).cast<String>(),
      isHidden: fields[5] as bool,
      nature: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AetherWalletCategory obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconEmoji)
      ..writeByte(3)
      ..write(obj.colorHex)
      ..writeByte(4)
      ..write(obj.subcategories)
      ..writeByte(5)
      ..write(obj.isHidden)
      ..writeByte(6)
      ..write(obj.nature);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AetherWalletCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
