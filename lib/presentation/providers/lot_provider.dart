import 'package:flutter/foundation.dart';
import 'package:loteamento_app/data/models/lot_model.dart';
import 'package:loteamento_app/data/services/csv_service.dart';

class LotProvider with ChangeNotifier {
  final CsvService _csvService;
  List<LotModel> _lots = [];
  bool _isLoading = false;
  String? _error;
  final Set<String> _selectedOwners = {};
  final Set<String> _selectedCartorios = {};

  LotProvider(this._csvService);

  List<LotModel> get lots => _lots;
  
  List<LotModel> get placedLots {
    var filtered = _lots.where((l) => l.hasLocation).toList();
    
    if (_selectedOwners.isNotEmpty) {
      filtered = filtered.where((l) => _selectedOwners.contains(l.proprietario)).toList();
    }
    
    if (_selectedCartorios.isNotEmpty) {
      filtered = filtered.where((l) => _selectedCartorios.contains(l.cartorio)).toList();
    }
    
    return filtered;
  }

  List<LotModel> get unplacedLots => _lots.where((l) => !l.hasLocation).toList();
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<String> get selectedOwners => _selectedOwners;
  Set<String> get selectedCartorios => _selectedCartorios;

  List<String> get allOwners {
    return _lots
        .map((l) => l.proprietario)
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get allCartorios {
    return _lots
        .map((l) => l.cartorio)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  void toggleOwnerFilter(String owner) {
    if (_selectedOwners.contains(owner)) {
      _selectedOwners.remove(owner);
    } else {
      _selectedOwners.add(owner);
    }
    notifyListeners();
  }

  void toggleCartorioFilter(String cartorio) {
    if (_selectedCartorios.contains(cartorio)) {
      _selectedCartorios.remove(cartorio);
    } else {
      _selectedCartorios.add(cartorio);
    }
    notifyListeners();
  }

  void clearFilters() {
    _selectedOwners.clear();
    _selectedCartorios.clear();
    notifyListeners();
  }

  void clearOwnerFilter() {
    _selectedOwners.clear();
    notifyListeners();
  }

  void clearCartorioFilter() {
    _selectedCartorios.clear();
    notifyListeners();
  }

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
          cartorio: lot.cartorio,
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
