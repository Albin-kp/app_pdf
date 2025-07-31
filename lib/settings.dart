import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'models/pdfsettings.dart';
import 'package:hive/hive.dart';

class PdfSettingsPage extends StatefulWidget {
  final PdfSettings initialSettings;

  const PdfSettingsPage({super.key, required this.initialSettings});

  @override
  State<PdfSettingsPage> createState() => _PdfSettingsPageState();
}

class _PdfSettingsPageState extends State<PdfSettingsPage> {
  late int rows;
  late int columns;
  late double spacing;
  late double margin;
  late bool shrinkToFit;
  late PdfPageFormat pageFormat;

  final _rowsController = TextEditingController();
  final _columnsController = TextEditingController();
  final _spacingController = TextEditingController();
  final _marginController = TextEditingController();

  @override
  void initState() {
    super.initState();
    rows = widget.initialSettings.rows;
    columns = widget.initialSettings.columns;
    spacing = widget.initialSettings.spacing;
    margin = widget.initialSettings.margin;
    shrinkToFit = widget.initialSettings.shrinkToFit;
    pageFormat = widget.initialSettings.pageFormat;

    _rowsController.text = rows.toString();
    _columnsController.text = columns.toString();
    _spacingController.text = spacing.toString();
    _marginController.text = margin.toString();
  }

  @override
  void dispose() {
    _rowsController.dispose();
    _columnsController.dispose();
    _spacingController.dispose();
    _marginController.dispose();
    super.dispose();
  }

  // ignore: unused_element
  String _getFormatName(PdfPageFormat format) {
    if (format == PdfPageFormat.letter) return 'letter';
    return 'a4';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFDF6F0),
      appBar: AppBar(
        title: const Text('PDF Layout Settings'),
        backgroundColor: const Color.fromARGB(255, 42, 163, 200),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTextField('Rows', _rowsController, (val) {
            rows = int.tryParse(val) ?? rows;
          }),
          _buildTextField('Columns', _columnsController, (val) {
            columns = int.tryParse(val) ?? columns;
          }),
          _buildTextField('Spacing (in mm)', _spacingController, (val) {
            spacing = double.tryParse(val) ?? spacing;
          }),
          _buildTextField('Margin (in mm)', _marginController, (val) {
            margin = double.tryParse(val) ?? margin;
          }),
          const SizedBox(height: 10),
          SwitchListTile(
            activeColor: const Color.fromARGB(255, 50, 166, 202),
            title: const Text("Shrink Images to Fit Page"),
            value: shrinkToFit,
            onChanged: (val) => setState(() => shrinkToFit = val),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<PdfPageFormat>(
            decoration: const InputDecoration(labelText: 'Paper Size'),
            value: pageFormat,
            items: const [
              DropdownMenuItem(value: PdfPageFormat.a4, child: Text("A4")),
              DropdownMenuItem(
                  value: PdfPageFormat.letter, child: Text("Letter")),
            ],
            onChanged: (val) => setState(() => pageFormat = val!),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 42, 163, 200),
            ),
            icon: const Icon(Icons.save, color: Color.fromARGB(255, 0, 0, 0)),
            label: const Text("Save Settings",
                style: TextStyle(color: Color.fromARGB(255, 0, 0, 0))),
            onPressed: () async {
              final settings = PdfSettings.from(
                rows: rows,
                columns: columns,
                spacing: spacing,
                margin: margin,
                shrinkToFit: shrinkToFit,
                format: pageFormat,
              );

              final box = await Hive.openBox<PdfSettings>('pdf_settings');
              await box.put('settings', settings);

              Navigator.pop(context, settings);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }
}
