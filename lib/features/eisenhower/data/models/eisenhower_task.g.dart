// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'eisenhower_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EisenhowerTaskAdapter extends TypeAdapter<EisenhowerTask> {
  @override
  final int typeId = 9;

  @override
  EisenhowerTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EisenhowerTask(
      id: fields[0] as String?,
      title: fields[1] as String,
      quadrant: fields[2] as QuadrantType,
      createdAt: fields[3] as DateTime?,
      dueDate: fields[4] as DateTime?,
      priority: fields[5] as int,
      isCompleted: fields[6] == null ? false : fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, EisenhowerTask obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.quadrant)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.dueDate)
      ..writeByte(5)
      ..write(obj.priority)
      ..writeByte(6)
      ..write(obj.isCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EisenhowerTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuadrantTypeAdapter extends TypeAdapter<QuadrantType> {
  @override
  final int typeId = 8;

  @override
  QuadrantType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return QuadrantType.doNow;
      case 1:
        return QuadrantType.schedule;
      case 2:
        return QuadrantType.delegate;
      case 3:
        return QuadrantType.eliminate;
      default:
        return QuadrantType.doNow;
    }
  }

  @override
  void write(BinaryWriter writer, QuadrantType obj) {
    switch (obj) {
      case QuadrantType.doNow:
        writer.writeByte(0);
        break;
      case QuadrantType.schedule:
        writer.writeByte(1);
        break;
      case QuadrantType.delegate:
        writer.writeByte(2);
        break;
      case QuadrantType.eliminate:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuadrantTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
