// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReminderItemAdapter extends TypeAdapter<ReminderItem> {
  @override
  final int typeId = 0;

  @override
  ReminderItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReminderItem(
      id: fields[0] as String,
      title: fields[1] as String,
      categoryName: fields[2] as String,
      notes: fields[3] as String?,
      nextDueDate: fields[4] as DateTime,
      recurrenceTypeIndex: fields[5] as int,
      recurrenceInterval: fields[6] as int,
      leadTimes: (fields[7] as List).cast<int>(),
      notificationHour: fields[8] as int?,
      notificationMinute: fields[9] as int?,
      isActive: fields[10] as bool,
      lastCompletedDate: fields[11] as DateTime?,
      notificationBaseId: fields[12] as int,
      completions: (fields[13] as List?)?.cast<CompletionRecord>(),
      snoozedUntil: fields[14] as DateTime?,
      escalateWhenOverdue: fields[15] == null ? true : fields[15] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderItem obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.categoryName)
      ..writeByte(3)
      ..write(obj.notes)
      ..writeByte(4)
      ..write(obj.nextDueDate)
      ..writeByte(5)
      ..write(obj.recurrenceTypeIndex)
      ..writeByte(6)
      ..write(obj.recurrenceInterval)
      ..writeByte(7)
      ..write(obj.leadTimes)
      ..writeByte(8)
      ..write(obj.notificationHour)
      ..writeByte(9)
      ..write(obj.notificationMinute)
      ..writeByte(10)
      ..write(obj.isActive)
      ..writeByte(11)
      ..write(obj.lastCompletedDate)
      ..writeByte(12)
      ..write(obj.notificationBaseId)
      ..writeByte(13)
      ..write(obj.completions)
      ..writeByte(14)
      ..write(obj.snoozedUntil)
      ..writeByte(15)
      ..write(obj.escalateWhenOverdue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
