// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aether_attachment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AetherAttachmentAdapter extends TypeAdapter<AetherAttachment> {
  @override
  final int typeId = 6;

  @override
  AetherAttachment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AetherAttachment(
      id: fields[0] as String?,
      type: fields[1] as String,
      path: fields[2] as String,
      name: fields[3] as String,
      byteSize: fields[4] as int,
      thumbnailPath: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AetherAttachment obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.path)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.byteSize)
      ..writeByte(5)
      ..write(obj.thumbnailPath)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AetherAttachmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
