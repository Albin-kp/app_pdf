// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_data_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ImageDataModelAdapter extends TypeAdapter<ImageDataModel> {
  @override
  final int typeId = 0;

  @override
  ImageDataModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ImageDataModel(
      tabName: fields[0] as String,
      imageBytes: fields[1] as Uint8List,
      zoomValue: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ImageDataModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.tabName)
      ..writeByte(1)
      ..write(obj.imageBytes)
      ..writeByte(2)
      ..write(obj.zoomValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageDataModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
