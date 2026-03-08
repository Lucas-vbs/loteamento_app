import 'package:flutter/material.dart';

enum LotStatus {
  available,
  unavailable,
  reserved;

  Color get color {
    switch (this) {
      case LotStatus.available:
        return const Color(0xFF4CAF50); // Green
      case LotStatus.unavailable:
        return const Color(0xFFF44336); // Red
      case LotStatus.reserved:
        return const Color(0xFFFFC107); // Amber
    }
  }

  String get label {
    switch (this) {
      case LotStatus.available:
        return 'Disponível';
      case LotStatus.unavailable:
        return 'Indisponível';
      case LotStatus.reserved:
        return 'Reservado';
    }
  }
}

class LotModel {
  final String id;
  final String matricula;
  final String lotNumber;
  final String blockNumber;
  final String proprietario;
  final String cartorio;
  final double price;
  final LotStatus status;
  final double area;
  final double x;
  final double y;

  LotModel({
    required this.id,
    required this.matricula,
    required this.lotNumber,
    required this.blockNumber,
    required this.proprietario,
    required this.cartorio,
    required this.price,
    required this.status,
    required this.area,
    required this.x,
    required this.y,
  });

  factory LotModel.fromMap(Map<String, dynamic> map) {
    // Helper to get value case-insensitively
    dynamic getValue(List<String> keys) {
      for (var key in keys) {
        if (map.containsKey(key)) return map[key];
        // Also check actual keys case-insensitively
        for (var entry in map.entries) {
          if (entry.key.toLowerCase().trim() == key.toLowerCase()) {
            return entry.value;
          }
        }
      }
      return null;
    }

    final propValue = getValue(['proprietario', 'Proprietario']) ?? '';
    final cartorioValue = getValue(['cartorio', 'Cartorio', 'Cartório', 'cartório']) ?? '';
    
    // Parse price string like "R$ 110.000,00"
    double parsedPrice = 0.0;
    final priceStr = getValue(['price', 'Price'])?.toString() ?? '';
    if (priceStr.isNotEmpty) {
      final cleanPrice = priceStr.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
      parsedPrice = double.tryParse(cleanPrice) ?? 0.0;
    }

    // Parse area string like "492,35"
    double parsedArea = 0.0;
    final areaStr = getValue(['area', 'Area'])?.toString() ?? '';
    if (areaStr.isNotEmpty) {
      final cleanArea = areaStr.replaceAll(',', '.').trim();
      parsedArea = double.tryParse(cleanArea) ?? 0.0;
    }

    return LotModel(
      id: map['id']?.toString() ?? '',
      matricula: getValue(['matricula', 'Matricula'])?.toString() ?? '',
      lotNumber: getValue(['lot_number', 'Lot_number', 'lote'])?.toString() ?? '',
      blockNumber: getValue(['block_number', 'Block_number', 'quadra'])?.toString() ?? '',
      proprietario: propValue.toString(),
      cartorio: cartorioValue.toString(),
      price: parsedPrice,
      status: _parseStatus(getValue(['status', 'Status'])?.toString()),
      area: parsedArea,
      x: _parseDouble(map['x']),
      y: _parseDouble(map['y']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return -1.0;
    if (value is num) return value.toDouble();
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return -1.0;
    return double.tryParse(str) ?? -1.0;
  }

  bool get hasLocation => x != -1.0 && y != -1.0;

  static LotStatus _parseStatus(String? status) {
    if (status == null) return LotStatus.available;
    final s = status.toLowerCase();
    if (s.contains('dispon') || s.contains('available')) return LotStatus.available;
    if (s.contains('reserv') || s.contains('reserved')) return LotStatus.reserved;
    if (s.contains('vendid') || s.contains('indispon') || s.contains('unavailable')) return LotStatus.unavailable;
    return LotStatus.available;
  }
}
