import 'dart:io' show File;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, kDebugMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loteamento_app/data/models/lot_model.dart';

class CsvService {
  static const String _fileName = 'lotes_data.csv';
  static const String _assetPath = 'assets/data/lotes.csv';
  static const String _jsonAssetPath = 'assets/data/lotes.json';
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
          // Try loading JSON first (more robust on web)
          try {
            debugPrint('initDefault: Trying JSON asset $_jsonAssetPath');
            final jsonData = await rootBundle.loadString(_jsonAssetPath);
            if (!jsonData.trim().startsWith('{') && !jsonData.trim().startsWith('[')) {
               throw Exception('JSON asset is invalid or HTML 404');
            }
            // Convert JSON to CSV for the internal _webKey if we want to keep consistency,
            // or just store the JSON. Let's convert to CSV for backward compatibility.
            final List<dynamic> jsonList = jsonDecode(jsonData);
            final String csv = _jsonToCsv(jsonList);
            await prefs.setString(_webKey, csv);
            _webDataCache = csv;
            debugPrint('initDefault: Loaded from JSON and converted to CSV cache');
            return;
          } catch (e) {
            debugPrint('initDefault: JSON fallback failed, trying CSV: $e');
          }

          debugPrint('initDefault: Loading asset $_assetPath');
          final data = await rootBundle.loadString(_assetPath);
          
          if (data.trim().startsWith('<!DOCTYPE html>') || data.trim().startsWith('<html')) {
            throw Exception('Asset returned HTML instead of CSV - likely 404');
          }
          
          await prefs.setString(_webKey, data);
          _webDataCache = data;
          debugPrint('initDefault: Asset loaded and cached successfully');
        } catch (e) {
          debugPrint('initDefault: Error loading asset: $e');
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
        debugPrint('initDefault: Using cached data from SharedPreferences');
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

      // Check if it's HTML (common error on web deployment)
      if (csvString.trim().startsWith('<!DOCTYPE html>') || csvString.trim().startsWith('<html')) {
        debugPrint('fetchLots ERROR: Data starts with HTML tags. Resetting cache.');
        await clearLocalCache();
        return await fetchLots();
      }

      final List<List<dynamic>> rows = const CsvToListConverter().convert(
        csvString,
      );
      if (rows.isEmpty || rows.length == 1) {
        debugPrint('fetchLots: rows empty or only header. Header: ${rows.isNotEmpty ? rows[0] : "none"}');
        return [];
      }

      final header = rows[0].map((e) => e.toString().trim()).toList();
      final dataRows = rows.sublist(1);

      debugPrint('fetchLots: Processing ${dataRows.length} data rows. Header: $header');

      final List<LotModel> results = [];
      for (var row in dataRows) {
        // Skip empty rows
        if (row.isEmpty || (row.length == 1 && row[0].toString().isEmpty)) continue;

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

        final lot = LotModel.fromMap(map);
        results.add(lot);
      }
      
      final placed = results.where((l) => l.hasLocation).length;
      debugPrint('fetchLots SUCCESS: ${results.length} total, $placed placed, ${results.length - placed} unplaced');
      
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
        // Sync CSV
        final sourceFile = File(_assetPath);
        if (await sourceFile.exists()) {
          await sourceFile.writeAsString(csvData);
        } else {
          final projectFile = File(_assetPath);
          if (await projectFile.exists()) {
            await projectFile.writeAsString(csvData);
          }
        }

        // Sync JSON
        final lots = await fetchLots();
        final jsonStr = jsonEncode(lots.map((l) => {
          'id': l.id,
          'matricula': l.matricula,
          'lot_number': l.lotNumber,
          'block_number': l.blockNumber,
          'proprietario': l.proprietario,
          'price': 'R\$ ${l.price.toStringAsFixed(2).replaceAll('.', ',')}',
          'status': l.status.label.toUpperCase(),
          'area': l.area.toString().replaceAll('.', ','),
          'x': l.x == -1.0 ? '' : l.x,
          'y': l.y == -1.0 ? '' : l.y,
        }).toList());

        final jsonFile = File(_jsonAssetPath);
        if (await jsonFile.exists()) {
          await jsonFile.writeAsString(jsonStr);
          debugPrint('Sync successful: Updated asset files (CSV & JSON) on disk');
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

  String _jsonToCsv(List<dynamic> jsonList) {
    if (jsonList.isEmpty) return '';
    final List<List<dynamic>> rows = [
       ['id', 'matricula', 'lot_number', 'block_number', 'Proprietario', 'price', 'status', 'area', 'x', 'y']
    ];
    for (var item in jsonList) {
      final map = item as Map<String, dynamic>;
      rows.add([
        map['id'] ?? '',
        map['matricula'] ?? map['Matricula'] ?? '',
        map['lot_number'] ?? map['Lot_number'] ?? map['lote'] ?? '',
        map['block_number'] ?? map['Block_number'] ?? map['quadra'] ?? '',
        map['proprietario'] ?? map['Proprietario'] ?? '',
        map['price'] ?? map['Price'] ?? '',
        map['status'] ?? map['Status'] ?? 'DISPONÍVEL',
        map['area'] ?? map['Area'] ?? '',
        map['x'] ?? '',
        map['y'] ?? '',
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }
}
