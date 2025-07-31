// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pdfsettings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PdfSettingsAdapter extends TypeAdapter<PdfSettings> {
  @override
  final int typeId = 2;

  @override
  PdfSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PdfSettings(
      rows: fields[0] as int,
      columns: fields[1] as int,
      spacing: fields[2] as double,
      margin: fields[3] as double,
      shrinkToFit: fields[4] as bool,
      pageFormatName: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PdfSettings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.rows)
      ..writeByte(1)
      ..write(obj.columns)
      ..writeByte(2)
      ..write(obj.spacing)
      ..writeByte(3)
      ..write(obj.margin)
      ..writeByte(4)
      ..write(obj.shrinkToFit)
      ..writeByte(5)
      ..write(obj.pageFormatName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
