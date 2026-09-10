// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DiaryEntryAdapter extends TypeAdapter<DiaryEntry> {
  @override
  final int typeId = 0;

  @override
  DiaryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DiaryEntry(
      id: fields[0] as String?,
      title: fields[1] as String,
      content: fields[2] as String,
      createdAt: fields[3] as DateTime?,
      attachments: (fields[4] as List?)?.cast<AetherAttachment>(),
      checklists: (fields[5] as List?)?.cast<AetherChecklistItem>(),
      tags: (fields[6] as List?)?.cast<String>(),
      mood: fields[7] as String?,
      location: fields[8] as String?,
      isPinned: fields[9] as bool,
      isArchived: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DiaryEntry obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.attachments)
      ..writeByte(5)
      ..write(obj.checklists)
      ..writeByte(6)
      ..write(obj.tags)
      ..writeByte(7)
      ..write(obj.mood)
      ..writeByte(8)
      ..write(obj.location)
      ..writeByte(9)
      ..write(obj.isPinned)
      ..writeByte(10)
      ..write(obj.isArchived);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
