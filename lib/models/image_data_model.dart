import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'image_data_model.g.dart';

@HiveType(typeId: 0)
class ImageDataModel extends HiveObject {
  @HiveField(0)
  final String tabName;

  @HiveField(1)
  final Uint8List imageBytes;

  @HiveField(2)
  final double zoomValue;

  ImageDataModel({
    required this.tabName,
    required this.imageBytes,
    required this.zoomValue,
  });
}
