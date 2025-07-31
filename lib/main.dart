import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart'; // For non-web platforms
import 'package:flutter/foundation.dart' show kIsWeb;

import 'homepage.dart'; // Ensure this is the correct path to your home page
import './models/image_data_model.dart';
import './models/pdfsettings.dart'; // PDF settings model

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Hive initialization
  if (!kIsWeb) {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
  }

  // ✅ Register Hive adapters
  Hive.registerAdapter(ImageDataModelAdapter());
  Hive.registerAdapter(PdfSettingsAdapter());

  // ✅ Open Hive boxes
  await Hive.openBox<List>('tabs'); // Image data storage per tab
  await Hive.openBox<PdfSettings>('pdfsettings'); // PDF layout settings

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Homepage(),
    );
  }
}
