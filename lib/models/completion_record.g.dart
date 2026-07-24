// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompletionRecordAdapter extends TypeAdapter<CompletionRecord> {
  @override
  final int typeId = 1;

  @override
  CompletionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CompletionRecord(
      completedDate: fields[0] as DateTime,
      dueDate: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CompletionRecord obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.completedDate)
      ..writeByte(1)
      ..write(obj.dueDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompletionRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
