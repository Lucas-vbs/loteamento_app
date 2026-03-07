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
  final Set<LotStatus> _selectedStatuses = {};
  final Set<String> _selectedBlocks = {};
  final Set<String> _selectedLotIds = {};
  bool _isSelectionMode = false;

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

    if (_selectedStatuses.isNotEmpty) {
      filtered = filtered.where((l) => _selectedStatuses.contains(l.status)).toList();
    }

    if (_selectedBlocks.isNotEmpty) {
      filtered = filtered.where((l) => _selectedBlocks.contains(l.blockNumber)).toList();
    }
    
    return filtered;
  }

  List<LotModel> get unplacedLots => _lots.where((l) => !l.hasLocation).toList();
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<String> get selectedOwners => _selectedOwners;
  Set<String> get selectedCartorios => _selectedCartorios;
  Set<LotStatus> get selectedStatuses => _selectedStatuses;
  Set<String> get selectedBlocks => _selectedBlocks;
  Set<String> get selectedLotIds => _selectedLotIds;
  bool get isSelectionMode => _isSelectionMode;

  List<LotModel> get selectedLots =>
      _lots.where((l) => _selectedLotIds.contains(l.id)).toList();

  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      _selectedLotIds.clear();
    }
    notifyListeners();
  }

  void toggleLotSelection(String lotId) {
    if (_selectedLotIds.contains(lotId)) {
      _selectedLotIds.remove(lotId);
    } else {
      _selectedLotIds.add(lotId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedLotIds.clear();
    notifyListeners();
  }

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

  List<String> get allBlocks {
    return _lots
        .map((l) => l.blockNumber)
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) {
        // Try numeric sort
        final na = int.tryParse(a);
        final nb = int.tryParse(b);
        if (na != null && nb != null) return na.compareTo(nb);
        return a.compareTo(b);
      });
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

  void toggleStatusFilter(LotStatus status) {
    if (_selectedStatuses.contains(status)) {
      _selectedStatuses.remove(status);
    } else {
      _selectedStatuses.add(status);
    }
    notifyListeners();
  }

  void toggleBlockFilter(String block) {
    if (_selectedBlocks.contains(block)) {
      _selectedBlocks.remove(block);
    } else {
      _selectedBlocks.add(block);
    }
    notifyListeners();
  }

  void clearFilters() {
    _selectedOwners.clear();
    _selectedCartorios.clear();
    _selectedStatuses.clear();
    _selectedBlocks.clear();
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

  void clearStatusFilter() {
    _selectedStatuses.clear();
    notifyListeners();
  }

  void clearBlockFilter() {
    _selectedBlocks.clear();
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
