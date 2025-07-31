import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'preview.dart';
import 'settings.dart';
import 'models/pdfsettings.dart';
import 'dart:html' as html;
import 'package:hive/hive.dart';
import 'models/image_data_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  List<String> tabNames = ['Unsorted'];
  Map<String, List<Uint8List>> tabImages = {'Unsorted': []};
  Map<String, List<double>> zoomValues = {}; // To store zoom per image
  bool isLoading = true;
  late PdfSettings pdfSettings;

  late TabController _tabController;

  @override
  @override
  void initState() {
    super.initState();

    tabNames = [];
    tabImages = {};
    zoomValues = {};

    _tabController = TabController(length: tabNames.length, vsync: this);

    // Set default in case Hive is empty
    loadPdfSettings();
    loadSavedTabs();
    loadSavedPdfSettings(); // 👈 Load PDF settings from Hive
  }

  Future<void> _pickMultipleImages() async {
    final List<XFile> pickedImages = await _picker.pickMultiImage();
    if (pickedImages.isNotEmpty) {
      final imageBytesList = await Future.wait(
        pickedImages.map((xfile) => xfile.readAsBytes()),
      );

      // Update state firstload
      setState(() {
        tabImages['Unsorted']?.addAll(imageBytesList);
        zoomValues.putIfAbsent('Unsorted', () => []);
        zoomValues['Unsorted']
            ?.addAll(List.generate(imageBytesList.length, (index) => 1.0));
      });

      // Save to Hive outside setState
      await saveTabToHive('Unsorted');
    }
  }

  Future<void> loadPdfSettings() async {
    final box = await Hive.openBox<PdfSettings>('pdf_settings');
    pdfSettings = box.get('layout') ??
        PdfSettings(
          rows: 2,
          columns: 2,
          spacing: 10.0,
          margin: 20.0,
          shrinkToFit: true,
          pageFormatName: 'a4',
        );
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _confirmDeleteImage(String tabName, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        tabImages[tabName]?.removeAt(index);
        zoomValues[tabName]?.removeAt(index);
      });

      await saveTabToHive(tabName); // Move this outside setState
    }
  }

  Future<void> _generatePdfFromTabs({
    required Map<String, List<Uint8List>> tabImages,
    required List<String> tabNames,
    required PdfSettings settings,
  }) async {
    final pdf = pw.Document();
    final int imagesPerPage = settings.rows * settings.columns;

    for (final tab in tabNames) {
      final images = tabImages[tab] ?? [];
      if (images.isEmpty) continue;

      final totalPages = (images.length / imagesPerPage).ceil();

      for (int page = 0; page < totalPages; page++) {
        final start = page * imagesPerPage;
        final end = (start + imagesPerPage).clamp(0, images.length);
        final pageImages = images.sublist(start, end);

        pdf.addPage(
          pw.Page(
            pageFormat: settings.pageFormat,
            margin: pw.EdgeInsets.all(settings.margin),
            build: (context) {
              return pw.Column(
                children: [
                  pw.Wrap(
                    spacing: settings.spacing,
                    runSpacing: settings.spacing,
                    children: pageImages.map((bytes) {
                      return pw.Container(
                        width: (settings.pageFormat.availableWidth -
                                (settings.columns - 1) * settings.spacing) /
                            settings.columns,
                        height: (settings.pageFormat.availableHeight -
                                (settings.rows - 1) * settings.spacing -
                                settings.margin * 2) /
                            settings.rows,
                        child: pw.Image(
                          pw.MemoryImage(bytes),
                          fit: settings.shrinkToFit
                              ? pw.BoxFit.contain
                              : pw.BoxFit.none,
                        ),
                      );
                    }).toList(),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(
                      'Developed by Albin K P',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  )
                ],
              );
            },
          ),
        );
      }
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  String convertUint8ListToUrl(Uint8List bytes, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    return html.Url.createObjectUrlFromBlob(blob);
  }

  Future<void> _cropImage(
    Uint8List imageBytes,
    String tabName,
    int index,
  ) async {
    CroppedFile? croppedFile;

    if (kIsWeb) {
      // Convert Uint8List to Blob URL
      final blob = html.Blob([imageBytes], 'image/jpeg');
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Crop using the Blob URL
      croppedFile = await ImageCropper().cropImage(
        sourcePath: url,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 100,
        uiSettings: _getUiSettings(context),
      );

      html.Url.revokeObjectUrl(url); // Free the memory
    } else {
      final tempDir = Directory.systemTemp;
      final tempFile =
          await File('${tempDir.path}/tempImage.jpg').writeAsBytes(imageBytes);

      croppedFile = await ImageCropper().cropImage(
        sourcePath: tempFile.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 100,
        uiSettings: _getUiSettings(context),
      );
    }

    if (croppedFile != null) {
      Uint8List croppedBytes;

      if (kIsWeb) {
        final response = await html.HttpRequest.request(
          croppedFile.path,
          responseType: 'arraybuffer',
        );
        croppedBytes = Uint8List.view(response.response);
      } else {
        croppedBytes = await File(croppedFile.path).readAsBytes();
      }

      // ✅ First update UI
      setState(() {
        tabImages[tabName]![index] = croppedBytes;
        zoomValues[tabName]![index] = 1.0;
      });

      // ✅ Then save to Hive
      await saveTabToHive(tabName);
    }
  }

  List<PlatformUiSettings> _getUiSettings(BuildContext context) {
    return [
      AndroidUiSettings(
        toolbarTitle: 'Crop Image',
        toolbarColor: const Color.fromARGB(255, 7, 54, 101),
        toolbarWidgetColor: const Color.fromARGB(255, 50, 213, 205),
        initAspectRatio: CropAspectRatioPreset.original,
        lockAspectRatio: false,
        cropFrameColor: const Color.fromARGB(255, 50, 213, 205),
        cropGridColor: const Color.fromARGB(255, 21, 123, 14),
        cropFrameStrokeWidth: 9,
        activeControlsWidgetColor: const Color.fromARGB(255, 93, 183, 174),
        aspectRatioPresets: const [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.ratio16x9,
          CropAspectRatioPreset.ratio4x3,
        ],
      ),
      IOSUiSettings(
        title: 'Crop Image',
        aspectRatioPresets: const [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio4x3,
        ],
      ),
      WebUiSettings(
        context: context,
        presentStyle: WebPresentStyle.page,
        size: const CropperSize(width: 800, height: 600),
        viewwMode: WebViewMode.mode_1,
        dragMode: WebDragMode.crop,
        scalable: true,
        zoomable: true,
        cropBoxMovable: true,
        cropBoxResizable: true,
        background: true,
        center: true,
        highlight: true,
        guides: true,
        movable: true,
        rotatable: true,
        zoomOnWheel: true,
        zoomOnTouch: true,
        wheelZoomRatio: 0.1,
      ),
    ];
  }

  Future<void> _addNewTab() async {
    final controller = TextEditingController();
    final newTab = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Heading/Category Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) {
            Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (newTab != null && newTab.isNotEmpty && !tabNames.contains(newTab)) {
      setState(() {
        tabNames.add(newTab);
        tabImages[newTab] = [];
        zoomValues[newTab] = [];
        _tabController.dispose();
        _tabController = TabController(length: tabNames.length, vsync: this);
      });

      // ✅ Save new tab to Hive
      await saveTabToHive(newTab);
    }
  }

  void _showImageViewer(Uint8List image) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Image.memory(image),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _moveImageToTab(Uint8List image, String fromTab) async {
    final selectedTab = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Tab'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: tabNames
              .where((tab) => tab != fromTab)
              .map((tab) => ListTile(
                    title: Text(tab),
                    onTap: () => Navigator.pop(context, tab),
                  ))
              .toList(),
        ),
      ),
    );

    if (selectedTab != null) {
      setState(() {
        int index = tabImages[fromTab]?.indexOf(image) ?? -1;
        if (index != -1) {
          tabImages[fromTab]?.removeAt(index);
          zoomValues[fromTab]?.removeAt(index);
          tabImages[selectedTab]?.add(image);
          zoomValues[selectedTab]?.add(1.0);
        }
      });

      // ✅ Persist changes to Hive
      await saveTabToHive(fromTab);
      await saveTabToHive(selectedTab);
    }
  }

  //**************************//  hive methods //**************************//
  Future<void> saveTabToHive(String tabName) async {
    final box = Hive.box<List>('tabs');
    final data = List.generate(
      tabImages[tabName]!.length,
      (i) => ImageDataModel(
        imageBytes: tabImages[tabName]![i],
        zoomValue: zoomValues[tabName]![i],
        tabName: tabName,
      ),
    );
    await box.put(tabName, data);
  }

  Future<void> clearAllHiveData() async {
    final box = Hive.box<List>('tabs');
    await box.clear();
    setState(() {
      tabNames = ['Unsorted'];
      tabImages = {'Unsorted': []};
      zoomValues = {'Unsorted': []};
      _tabController.dispose();
      _tabController = TabController(length: tabNames.length, vsync: this);
    });
  }

  PdfPageFormat _getFormatFromName(String name) {
    switch (name.toLowerCase()) {
      case 'letter':
        return PdfPageFormat.letter;
      case 'a4':
      default:
        return PdfPageFormat.a4;
    }
  }

  Future<void> loadSavedPdfSettings() async {
    final box = await Hive.openBox<PdfSettings>('pdf_settings');
    final saved = box.get('settings');
    if (saved != null) {
      setState(() {
        pdfSettings = saved;
      });
    } else {
      pdfSettings = PdfSettings.from(
        rows: 2,
        columns: 2,
        spacing: 10,
        margin: 20,
        shrinkToFit: true,
        format: PdfPageFormat.a4,
      );
    }
  }

  Future<void> loadSavedTabs() async {
    final box = Hive.box<List>('tabs');
    final savedTabs = box.keys.cast<String>();

    // Reset state to avoid duplication
    tabNames.clear();
    tabImages.clear();
    zoomValues.clear();

    if (savedTabs.isEmpty) {
      // Add Unsorted tab if nothing is saved
      tabNames.add('Unsorted');
      tabImages['Unsorted'] = [];
      zoomValues['Unsorted'] = [];
    } else {
      for (var tab in savedTabs) {
        final dataList = box.get(tab)!.cast<ImageDataModel>();
        tabNames.add(tab);
        tabImages[tab] = dataList.map((e) => e.imageBytes).toList();
        zoomValues[tab] = dataList.map((e) => e.zoomValue).toList();
      }
    }

    // Always refresh controller AFTER tabNames is populated
    setState(() {
      _tabController.dispose();
      _tabController = TabController(length: tabNames.length, vsync: this);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: tabNames.length,
      child: Scaffold(
        backgroundColor: Color(0xFFFDF6F0),
        appBar: AppBar(
          backgroundColor: Color.fromARGB(255, 45, 165, 216), // Navbar green
          iconTheme: const IconThemeData(
              color: Color.fromRGBO(
            253,
            246,
            236,
            1,
          )),
          centerTitle: true,
          title: const Text('PDF Image Organizer',
              style: TextStyle(
                  color: Color.fromRGBO(18, 17, 17, 0.894),
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  fontFamily: "orbitron")),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: tabNames.map((name) => Tab(text: name)).toList(),
            labelColor: Color(0xFFF1F1F1),
            unselectedLabelColor: const Color.fromARGB(255, 0, 0, 0),
            indicatorColor: const Color.fromARGB(255, 11, 25, 92),
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 5,
            splashBorderRadius: BorderRadius.circular(20),
            labelStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              color: const Color.fromARGB(255, 0, 0, 0),
              onPressed: _addNewTab,
              icon: const Icon(Icons.add),
              iconSize: 50,
              tooltip: 'Add New Tab',
            ),
            IconButton(
              color: const Color.fromARGB(255, 0, 0, 0),
              onPressed: _pickMultipleImages,
              icon: const Icon(Icons.image),
              iconSize: 50,
              tooltip: 'Add Images',
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: tabNames.map((tab) {
            final images = tabImages[tab]!;
            return images.isEmpty
                ? const Center(child: Text('Click image icon to add  Images'))
                : GridView.builder(
                    padding: const EdgeInsets.all(5),
                    itemCount: images.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: pdfSettings.columns,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemBuilder: (context, index) {
                      final image = images[index];
                      return RepaintBoundary(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _moveImageToTab(image, tab),
                              onLongPress: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (_) => SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.crop),
                                          title: const Text('Crop'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _cropImage(image, tab, index);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.zoom_in,
                                              color: Colors.black),
                                          title: const Text('View'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _showImageViewer(image);
                                          },
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.delete_forever,
                                              color: Colors.red),
                                          title: const Text('Delete'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _confirmDeleteImage(tab, index);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Image.memory(
                                image,
                                fit: BoxFit.contain,
                                width: 150 * zoomValues[tab]![index],
                                height: 150 * zoomValues[tab]![index],
                                cacheHeight: 300,
                                cacheWidth: 300,
                              ),
                            ),
                            /* Slider(
                              value: zoomValues[tab]![index],
                              min: 0.5,
                              max: 2.0,
                              divisions: 15,
                              label:
                                  '${(zoomValues[tab]![index] * 100).round()}%',
                              onChanged: (value) {
                                setState(() {
                                  zoomValues[tab]![index] = value;
                                });
                              },
                            ),*/
                          ],
                        ),
                      );
                    },
                  );
          }).toList(),
        ),
        floatingActionButton: BottomAppBar(
          color: Color(0xFFFDF6F0),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  backgroundColor: const Color.fromARGB(255, 42, 163, 200),
                  heroTag: 'newPdfFAB',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Start New Project?"),
                        content: const Text("This will delete all saved work."),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancel")),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Confirm")),
                        ],
                      ),
                    );
                    if (confirm == true) await clearAllHiveData();
                  },
                  label: const Text(
                    "New PDF",
                    style: TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  backgroundColor: const Color.fromARGB(255, 42, 163, 200),
                  heroTag: 'settingsFAB',
                  onPressed: () async {
                    final newSettings = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PdfSettingsPage(initialSettings: pdfSettings),
                      ),
                    );
                    if (newSettings != null) {
                      setState(() => pdfSettings = newSettings);
                    }
                  },
                  child: const Icon(Icons.settings,
                      color: Color.fromARGB(255, 0, 0, 0)),
                  tooltip: 'PDF Layout Settings',
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  backgroundColor: const Color.fromARGB(255, 42, 163, 200),
                  heroTag: 'previewFAB',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PdfPreviewScreen(
                          tabImages: tabImages,
                          tabNames: tabNames,
                          settings: pdfSettings,
                        ),
                      ),
                    );
                  },
                  label: const Text(
                    "Preview PDF",
                    style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  ),
                  icon: const Icon(Icons.preview,
                      color: Color.fromARGB(255, 0, 0, 0)),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Developed by Albin K P',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}
