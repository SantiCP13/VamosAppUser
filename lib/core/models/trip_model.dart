import 'package:intl/intl.dart';

class TripModel {
  final String id;
  final String dateRaw; // Fecha cruda para ordenamiento si se necesita
  final String destination;
  final double price;
  final String status; // 'COMPLETED', 'CANCELLED' (lo que envía el backend)

  TripModel({
    required this.id,
    required this.dateRaw,
    required this.destination,
    required this.price,
    required this.status,
  });

  // Factory para convertir JSON de Laravel (o Mock) a Objeto Dart
  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id']?.toString() ?? 'Unknown',
      // Laravel suele enviar: "created_at": "2024-01-24T10:30:00Z"
      dateRaw: json['date'] ?? DateTime.now().toIso8601String(),
      destination: json['destination'] ?? 'Destino desconocido',
      // Laravel envía números (15400), Dart debe manejarlos como double
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      status: json['status'] ?? 'UNKNOWN',
    );
  }

  // GETTERS INTELIGENTES (Lógica de presentación)

  // Devuelve fecha bonita: "24 Ene, 10:30 AM"
  String get formattedDate {
    try {
      final date = DateTime.parse(dateRaw);
      // Formato: día mes, hora:minutos AM/PM
      final formatter = DateFormat('dd MMM, hh:mm a', 'es_ES');
      String formatted = formatter.format(date);

      // Truco para poner la primera letra del mes en Mayúscula (ej: "06 feb" -> "06 Feb")
      // Esto es puramente estético
      return formatted.replaceFirstMapped(
        RegExp(r'\b[a-z]'),
        (match) => match.group(0)!.toUpperCase(),
      );
    } catch (e) {
      // Si algo falla, mostramos una fecha numérica simple como respaldo
      final date = DateTime.tryParse(dateRaw);
      if (date != null) {
        return "${date.day}/${date.month}/${date.year}";
      }
      return dateRaw;
    }
  }

  // Devuelve precio formateado: "$ 15.400"
  String get formattedPrice {
    final currency = NumberFormat("#,##0", "es_CO");
    return "\$ ${currency.format(price)}";
  }

  // Devuelve si el viaje fue exitoso para pintar de verde/rojo
  bool get isCompleted => status == 'COMPLETED' || status == 'Completado';

  // Texto amigable del estado
  String get statusLabel => isCompleted ? 'Completado' : 'Cancelado';
}
