import 'package:flutter/foundation.dart';
import 'package:loteamento_app/data/models/lot_model.dart';
import 'package:loteamento_app/data/services/csv_service.dart';

class LotProvider with ChangeNotifier {
  final CsvService _csvService;
  List<LotModel> _lots = [];
  bool _isLoading = false;
  String? _error;

  LotProvider(this._csvService);

  List<LotModel> get lots => _lots;
  List<LotModel> get placedLots => _lots.where((l) => l.hasLocation).toList();
  List<LotModel> get unplacedLots => _lots.where((l) => !l.hasLocation).toList();
  
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  void setAdmin(bool value) {
    _isAdmin = value;
    notifyListeners();
  }

  Future<void> fetchLots() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _lots = await _csvService.fetchLots();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLotPosition(String id, double x, double y) async {
    final success = await _csvService.updateLotCoordinates(id, x, y);
    if (success) {
      final index = _lots.indexWhere((l) => l.id == id);
      if (index != -1) {
        final lot = _lots[index];
        _lots[index] = LotModel(
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
        notifyListeners();
      }
    }
  }

  Future<void> placeLot(String matricula, double x, double y) async {
    final success = await _csvService.placeLot(matricula, x, y);
    if (success) {
      await fetchLots(); // Refresh all lots to update placement
    }
  }

  Future<void> removePin(String id) async {
    final success = await _csvService.removePin(id);
    if (success) {
      await fetchLots();
    }
  }

  Future<void> importCsv(String csvContent) async {
    await _csvService.importCsv(csvContent);
    await fetchLots();
  }
  Future<String> uploadPins() async {
    return await _csvService.uploadPins();
  }

  Future<void> resetData() async {
    await _csvService.clearLocalCache();
    await fetchLots();
  }
}
