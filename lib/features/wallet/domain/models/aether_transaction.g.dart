// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aether_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AetherTransactionAdapter extends TypeAdapter<AetherTransaction> {
  @override
  final int typeId = 8;

  @override
  AetherTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AetherTransaction(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String?,
      amount: fields[3] as double,
      currency: fields[4] as String,
      exchangeRate: fields[5] as double,
      type: fields[6] as String,
      category: fields[7] as String,
      subcategory: fields[8] as String?,
      accountId: fields[9] as String,
      destinationAccountId: fields[10] as String?,
      tags: (fields[11] as List?)?.cast<String>(),
      labels: (fields[12] as List?)?.cast<String>(),
      notes: fields[13] as String?,
      attachmentPaths: (fields[14] as List?)?.cast<String>(),
      merchant: fields[15] as String?,
      geoLocation: fields[16] as String?,
      mood: fields[17] as String?,
      date: fields[18] as DateTime?,
      reminderDate: fields[19] as DateTime?,
      dueDate: fields[20] as DateTime?,
      transactionStatus: fields[21] as String,
      paymentMethod: fields[22] as String,
      recurringRule: fields[23] as String?,
      installmentPlanId: fields[24] as String?,
      createdAt: fields[25] as DateTime?,
      updatedAt: fields[26] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AetherTransaction obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.currency)
      ..writeByte(5)
      ..write(obj.exchangeRate)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.category)
      ..writeByte(8)
      ..write(obj.subcategory)
      ..writeByte(9)
      ..write(obj.accountId)
      ..writeByte(10)
      ..write(obj.destinationAccountId)
      ..writeByte(11)
      ..write(obj.tags)
      ..writeByte(12)
      ..write(obj.labels)
      ..writeByte(13)
      ..write(obj.notes)
      ..writeByte(14)
      ..write(obj.attachmentPaths)
      ..writeByte(15)
      ..write(obj.merchant)
      ..writeByte(16)
      ..write(obj.geoLocation)
      ..writeByte(17)
      ..write(obj.mood)
      ..writeByte(18)
      ..write(obj.date)
      ..writeByte(19)
      ..write(obj.reminderDate)
      ..writeByte(20)
      ..write(obj.dueDate)
      ..writeByte(21)
      ..write(obj.transactionStatus)
      ..writeByte(22)
      ..write(obj.paymentMethod)
      ..writeByte(23)
      ..write(obj.recurringRule)
      ..writeByte(24)
      ..write(obj.installmentPlanId)
      ..writeByte(25)
      ..write(obj.createdAt)
      ..writeByte(26)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AetherTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
