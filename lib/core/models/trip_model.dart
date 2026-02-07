// lib/core/models/trip_model.dart
import 'package:intl/intl.dart';

class TripModel {
  final String id;
  final String dateRaw;
  final String destination;
  final double price;
  final String status;
  // Este campo es requerido según tu constructor
  final String origin;

  TripModel({
    required this.id,
    required this.dateRaw,
    required this.destination,
    required this.price,
    required this.status,
    required this.origin,
  });

  // Factory para convertir JSON de Laravel (o Mock) a Objeto Dart
  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id']?.toString() ?? 'Unknown',
      dateRaw: json['date'] ?? DateTime.now().toIso8601String(),

      origin: json['origin'] ?? json['origen'] ?? 'Origen desconocido',

      destination: json['destination'] ?? 'Destino desconocido',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      status: json['status'] ?? 'UNKNOWN',
    );
  }

  String get formattedDate {
    try {
      final date = DateTime.parse(dateRaw);
      final formatter = DateFormat('dd MMM, hh:mm a', 'es_ES');
      String formatted = formatter.format(date);
      return formatted.replaceFirstMapped(
        RegExp(r'\b[a-z]'),
        (match) => match.group(0)!.toUpperCase(),
      );
    } catch (e) {
      final date = DateTime.tryParse(dateRaw);
      if (date != null) {
        return "${date.day}/${date.month}/${date.year}";
      }
      return dateRaw;
    }
  }

  String get formattedPrice {
    final currency = NumberFormat("#,##0", "es_CO");
    return "\$ ${currency.format(price)}";
  }

  bool get isCompleted => status == 'COMPLETED' || status == 'Completado';
  String get statusLabel => isCompleted ? 'Completado' : 'Cancelado';
}
