import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models/pdfsettings.dart';
import 'settings.dart'; // This is your PdfSettingsPage

class PdfPreviewScreen extends StatefulWidget {
  final Map<String, List<Uint8List>> tabImages;
  final List<String> tabNames;
  final PdfSettings settings;
  final String pdfFileName;

  const PdfPreviewScreen({
    super.key,
    required this.tabImages,
    required this.tabNames,
    required this.settings,
    this.pdfFileName = "Aligned_Pdf.pdf",
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late PdfSettings currentSettings;
  late String currentFileName;

  @override
  void initState() {
    super.initState();
    currentSettings = widget.settings;
    currentFileName = widget.pdfFileName;
  }

  pw.Document buildPdf() {
    final pdf = pw.Document();

    for (final tab in widget.tabNames) {
      if (!widget.tabImages.containsKey(tab)) continue;

      final validImages = widget.tabImages[tab];
      if (validImages == null || validImages.isEmpty) continue;

      final imagesPerPage = currentSettings.rows * currentSettings.columns;
      final totalPages = (validImages.length / imagesPerPage).ceil();

      for (int page = 0; page < totalPages; page++) {
        final start = page * imagesPerPage;
        final end = (start + imagesPerPage).clamp(0, validImages.length);
        final pageImages = validImages.sublist(start, end);

        pdf.addPage(
          pw.Page(
            pageFormat: currentSettings.pageFormat,
            margin: pw.EdgeInsets.all(currentSettings.margin),
            build: (context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      '${tab.toUpperCase()} - ${page + 1}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 25),
                  pw.Wrap(
                    spacing: currentSettings.spacing,
                    runSpacing: currentSettings.spacing,
                    children: pageImages.map((bytes) {
                      return pw.Container(
                        width: (currentSettings.pageFormat.availableWidth -
                                (currentSettings.columns - 1) *
                                    currentSettings.spacing) /
                            currentSettings.columns,
                        height: (currentSettings.pageFormat.availableHeight -
                                (currentSettings.rows - 1) *
                                    currentSettings.spacing -
                                currentSettings.margin * 2) /
                            currentSettings.rows,
                        child: pw.Image(
                          pw.MemoryImage(bytes),
                          fit: currentSettings.shrinkToFit
                              ? pw.BoxFit.contain
                              : pw.BoxFit.none,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PDF Preview"),
        backgroundColor: const Color.fromARGB(255, 42, 163, 200),
      ),
      body: PdfPreview(
        allowPrinting: true,
        pdfFileName: currentFileName,
        actionBarTheme: const PdfActionBarTheme(
          backgroundColor: Color.fromARGB(255, 42, 163, 200),
          iconColor: Color.fromARGB(255, 0, 0, 0),
          textStyle: TextStyle(color: Colors.white, fontSize: 16),
        ),
        build: (format) async => buildPdf().save(),
        canChangePageFormat: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            color: const Color.fromARGB(255, 0, 0, 0),
            tooltip: 'Layout Settings',
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PdfSettingsPage(initialSettings: currentSettings),
                ),
              );

              if (updated != null && updated is PdfSettings) {
                setState(() => currentSettings = updated);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename PDF',
            onPressed: () async {
              final controller = TextEditingController(
                text: currentFileName.replaceAll('.pdf', ''),
              );
              final newName = await showDialog<String>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Enter new PDF name'),
                  content: TextField(controller: controller),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );

              if (newName != null && newName.isNotEmpty) {
                setState(() {
                  currentFileName =
                      newName.endsWith('.pdf') ? newName : '$newName.pdf';
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
