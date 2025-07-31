import 'package:hive/hive.dart';
import 'package:pdf/pdf.dart';

part 'pdfsettings.g.dart'; // required for Hive code generation

@HiveType(typeId: 2)
class PdfSettings extends HiveObject {
  @HiveField(0)
  final int rows;

  @HiveField(1)
  final int columns;

  @HiveField(2)
  final double spacing;

  @HiveField(3)
  final double margin;

  @HiveField(4)
  final bool shrinkToFit;

  @HiveField(5)
  final String pageFormatName; // Store page format name (e.g. "a4")

  PdfSettings({
    required this.rows,
    required this.columns,
    required this.spacing,
    required this.margin,
    required this.shrinkToFit,
    required this.pageFormatName,
  });

  // Convert to actual PdfPageFormat when needed
  PdfPageFormat get pageFormat {
    switch (pageFormatName.toLowerCase()) {
      case 'a4':
        return PdfPageFormat.a4;
      case 'letter':
        return PdfPageFormat.letter;
      case 'legal':
        return PdfPageFormat.legal;
      default:
        return PdfPageFormat.a4;
    }
  }

  // Optional: Factory constructor from PdfPageFormat object
  factory PdfSettings.from({
    required int rows,
    required int columns,
    required double spacing,
    required double margin,
    required bool shrinkToFit,
    required PdfPageFormat format,
  }) {
    String name;
    if (format == PdfPageFormat.a4) {
      name = 'a4';
    } else if (format == PdfPageFormat.letter) {
      name = 'letter';
    } else if (format == PdfPageFormat.legal) {
      name = 'legal';
    } else {
      name = 'a4';
    }
    return PdfSettings(
      rows: rows,
      columns: columns,
      spacing: spacing,
      margin: margin,
      shrinkToFit: shrinkToFit,
      pageFormatName: name,
    );
  }
}
