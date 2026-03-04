import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, kDebugMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loteamento_app/data/models/lot_model.dart';

class CsvService {
  static const String _fileName = 'lotes_data.csv';
  static const String _assetPath = 'assets/data/lotes.csv';
  static const String _webKey = 'lotes_csv_data';

  // Cache for web
  String? _webDataCache;

  Future<String> get _localPath async {
    if (kIsWeb) return '';
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File?> get _localFile async {
    if (kIsWeb) return null;
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<void> initDefault() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_webKey)) {
        try {
          final data = await rootBundle.loadString(_assetPath);
          await prefs.setString(_webKey, data);
          _webDataCache = data;
        } catch (e) {
          final header = [
            [
              'id',
              'matricula',
              'lot_number',
              'block_number',
              'Proprietario',
              'price',
              'status',
              'area',
              'x',
              'y',
            ],
          ];
          String csv = const ListToCsvConverter().convert(header);
          await prefs.setString(_webKey, csv);
          _webDataCache = csv;
        }
      } else {
        _webDataCache = prefs.getString(_webKey);
      }
      return;
    }

    final file = await _localFile;
    if (file != null && !await file.exists()) {
      try {
        final data = await rootBundle.loadString(_assetPath);
        await file.writeAsString(data);
      } catch (e) {
        final header = [
          [
            'id',
            'matricula',
            'lot_number',
            'block_number',
            'Proprietario',
            'price',
            'status',
            'area',
            'x',
            'y',
          ],
        ];
        String csv = const ListToCsvConverter().convert(header);
        await file.writeAsString(csv);
      }
    }
  }

  Future<String> _readData() async {
    if (kIsWeb) {
      if (_webDataCache != null) return _webDataCache!;
      final prefs = await SharedPreferences.getInstance();
      _webDataCache = prefs.getString(_webKey) ?? '';
      return _webDataCache!;
    }
    final file = await _localFile;
    if (file == null || !await file.exists()) return '';
    return await file.readAsString();
  }

  Future<void> _writeData(String csvData) async {
    if (kIsWeb) {
      _webDataCache = csvData;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_webKey, csvData);
      return;
    }
    final file = await _localFile;
    if (file != null) {
      await file.writeAsString(csvData);
    }
  }

  Future<List<LotModel>> fetchLots() async {
    try {
      final csvString = await _readData();
      if (csvString.isEmpty) {
        debugPrint('fetchLots: csvString is empty');
        return [];
      }

      final List<List<dynamic>> rows = const CsvToListConverter().convert(
        csvString,
      );
      if (rows.isEmpty || rows.length == 1) {
        debugPrint('fetchLots: rows empty or only header');
        return [];
      }

      final header = rows[0].map((e) => e.toString().trim()).toList();
      final dataRows = rows.sublist(1);

      debugPrint('fetchLots: Processing ${dataRows.length} data rows');

      final List<LotModel> results = [];
      for (var row in dataRows) {
        final map = <String, dynamic>{};
        for (var i = 0; i < header.length; i++) {
          if (i < row.length) {
            map[header[i]] = row[i];
          }
        }

        // Ensure every lot has a unique ID even if not yet placed
        if (map['id'] == null || map['id'].toString().isEmpty) {
          map['id'] =
              'lot_${map['matricula'] ?? map['lot_number'] ?? map['lote']}_${map['block_number'] ?? map['quadra']}';
        }

        results.add(LotModel.fromMap(map));
      }
      return results;
    } catch (e) {
      debugPrint('Error fetching lots from CSV: $e');
      return [];
    }
  }

  Future<bool> saveLots(List<LotModel> lots) async {
    try {
      final List<List<dynamic>> rows = [
        [
          'id',
          'matricula',
          'lot_number',
          'block_number',
          'Proprietario',
          'price',
          'status',
          'area',
          'x',
          'y',
        ],
      ];

      for (var lot in lots) {
        // Format price back to R$ format
        String formattedPrice =
            'R\$ ${lot.price.toStringAsFixed(2).replaceAll('.', ',')}';
        // Add thousands separator if necessary, but keep it simple for now

        // Format area back to comma separator
        String formattedArea = lot.area.toString().replaceAll('.', ',');

        // Map status back to Portuguese caps
        String statusLabel = 'DISPONÍVEL';
        if (lot.status == LotStatus.reserved) statusLabel = 'RESERVADO';
        if (lot.status == LotStatus.unavailable) statusLabel = 'INDISPONÍVEL';

        rows.add([
          lot.id,
          lot.matricula,
          lot.lotNumber,
          lot.blockNumber,
          lot.proprietario,
          formattedPrice,
          statusLabel,
          formattedArea,
          lot.x == -1.0 ? '' : lot.x,
          lot.y == -1.0 ? '' : lot.y,
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);
      await _writeData(csv);

      // Attempt to sync back to asset source if in development local environment
      await _syncToAssetSource(csv);

      return true;
    } catch (e) {
      debugPrint('Error saving lots to CSV: $e');
      return false;
    }
  }

  Future<void> _syncToAssetSource(String csvData) async {
    // This helper only works on desktop platforms with access to the source code folder
    if (!kIsWeb && kDebugMode) {
      try {
        final sourceFile = File(_assetPath);
        if (await sourceFile.exists()) {
          await sourceFile.writeAsString(csvData);
          debugPrint(
            'Sync successful: Updated asset file on disk: ${_assetPath}',
          );
        } else {
          // Alternative attempt: check relative path from root
          final projectFile = File('$_assetPath');
          if (await projectFile.exists()) {
            await projectFile.writeAsString(csvData);
            debugPrint(
              'Sync successful: Updated project asset file: ${_assetPath}',
            );
          }
        }
      } catch (e) {
        debugPrint('Skip asset sync (optional/dev-only): $e');
      }
    }
  }

  Future<String> uploadPins() async {
    final lots = await fetchLots();
    final List<List<dynamic>> rows = [
      [
        'id',
        'matricula',
        'lot_number',
        'block_number',
        'Proprietario',
        'price',
        'status',
        'area',
        'x',
        'y',
      ],
    ];

    for (var lot in lots) {
      String formattedPrice =
          'R\$ ${lot.price.toStringAsFixed(2).replaceAll('.', ',')}';
      String formattedArea = lot.area.toString().replaceAll('.', ',');
      String statusLabel = 'DISPONÍVEL';
      if (lot.status == LotStatus.reserved) statusLabel = 'RESERVADO';
      if (lot.status == LotStatus.unavailable) statusLabel = 'INDISPONÍVEL';

      rows.add([
        lot.id,
        lot.matricula,
        lot.lotNumber,
        lot.blockNumber,
        lot.proprietario,
        formattedPrice,
        statusLabel,
        formattedArea,
        lot.x == -1.0 ? '' : lot.x,
        lot.y == -1.0 ? '' : lot.y,
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    return csv;
  }

  Future<bool> updateLotCoordinates(String id, double x, double y) async {
    final lots = await fetchLots();
    final index = lots.indexWhere((l) => l.id == id);
    if (index != -1) {
      final lot = lots[index];
      lots[index] = LotModel(
        id: lot.id,
        matricula: lot.matricula,
        lotNumber: lot.lotNumber,
        blockNumber: lot.blockNumber,
        proprietario: lot.proprietario,
        price: lot.price,
        status: lot.status,
        area: lot.area,
        x: x,
        y: y,
      );
      return await saveLots(lots);
    }
    return false;
  }

  Future<bool> placeLot(String matricula, double x, double y) async {
    final lots = await fetchLots();
    final index = lots.indexWhere((l) => l.matricula == matricula);
    if (index != -1) {
      final lot = lots[index];
      lots[index] = LotModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        matricula: lot.matricula,
        lotNumber: lot.lotNumber,
        blockNumber: lot.blockNumber,
        proprietario: lot.proprietario,
        price: lot.price,
        status: lot.status,
        area: lot.area,
        x: x,
        y: y,
      );
      return await saveLots(lots);
    }
    return false;
  }

  Future<bool> removePin(String id) async {
    final lots = await fetchLots();
    final index = lots.indexWhere((l) => l.id == id);
    if (index != -1) {
      final lot = lots[index];
      lots[index] = LotModel(
        id: '', // Remove ID
        matricula: lot.matricula,
        lotNumber: lot.lotNumber,
        blockNumber: lot.blockNumber,
        proprietario: lot.proprietario,
        price: lot.price,
        status: lot.status,
        area: lot.area,
        x: -1.0, // Unset coordinates
        y: -1.0,
      );
      return await saveLots(lots);
    }
    return false;
  }

  Future<void> importCsv(String csvContent) async {
    await _writeData(csvContent);
  }

  Future<void> clearLocalCache() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_webKey);
      _webDataCache = null;
    } else {
      final file = await _localFile;
      if (file != null && await file.exists()) {
        await file.delete();
      }
    }
    await initDefault();
  }
}
