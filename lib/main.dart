import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:loteamento_app/data/services/csv_service.dart';
import 'package:loteamento_app/presentation/providers/lot_provider.dart';
import 'package:loteamento_app/presentation/pages/main_screen.dart';

import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  // Initialize Services
  final csvService = CsvService();
  await csvService.initDefault();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LotProvider(csvService)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: dotenv.env['APP_TITLE'] ?? 'Loteamento Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
