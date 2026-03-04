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
    required this.price,
    required this.status,
    required this.area,
    required this.x,
    required this.y,
  });

  factory LotModel.fromMap(Map<String, dynamic> map) {
    // Handle the case where 'Proprietario' might be capitalized or lowercase
    final propValue = map['Proprietario'] ?? map['proprietario'] ?? '';
    
    // Parse price string like "R$ 110.000,00"
    double parsedPrice = 0.0;
    final priceStr = map['price']?.toString() ?? '';
    if (priceStr.isNotEmpty) {
      final cleanPrice = priceStr.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.').trim();
      parsedPrice = double.tryParse(cleanPrice) ?? 0.0;
    }

    // Parse area string like "492,35"
    double parsedArea = 0.0;
    final areaStr = map['area']?.toString() ?? '';
    if (areaStr.isNotEmpty) {
      final cleanArea = areaStr.replaceAll(',', '.').trim();
      parsedArea = double.tryParse(cleanArea) ?? 0.0;
    }

    return LotModel(
      id: map['id']?.toString() ?? '',
      matricula: map['matricula']?.toString() ?? '',
      lotNumber: map['lot_number']?.toString() ?? '',
      blockNumber: map['block_number']?.toString() ?? '',
      proprietario: propValue.toString(),
      price: parsedPrice,
      status: _parseStatus(map['status']?.toString()),
      area: parsedArea,
      x: double.tryParse(map['x'].toString()) ?? -1.0,
      y: double.tryParse(map['y'].toString()) ?? -1.0,
    );
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
