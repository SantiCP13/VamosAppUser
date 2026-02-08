// lib/core/models/trip_model.dart
import 'package:intl/intl.dart';

class TripModel {
  // --- DATOS BÁSICOS DE LA SOLICITUD (TABLA TRIPS) ---
  final String id;
  final String dateRaw;
  final String origin;
  final String destination;
  final double price;
  final String status; // SEARCHING, ACCEPTED, IN_PROGRESS, COMPLETED, CANCELLED

  // --- DATOS DEL CONDUCTOR Y VEHÍCULO (RELACIONES FK) ---
  // El backend hace JOIN con las tablas DRIVERS y VEHICLES
  final String? driverId; // Guardamos ID por si se requiere lógica interna
  final String? driverName;
  final String? driverPhotoUrl;

  final String? vehicleId; // Guardamos ID por si se requiere lógica interna
  final String? vehiclePlate; // Placa Blanca
  final String? vehicleModel;
  final String? vehicleColor;

  // --- DATOS LEGALES / FUEC (INTEGRACIÓN MOVILTRACK) ---
  // Campos "Espejo" del Diagrama ER (PDF Pág 2 y 5)
  final int? externalFuecId; // ID del FUEC en Moviltrack (ej: 1500)
  final String? urlPdfFuec; // Link para descargar el PDF legal
  final String? contractNumber; // Número de contrato generado

  TripModel({
    required this.id,
    required this.dateRaw,
    required this.origin,
    required this.destination,
    required this.price,
    required this.status,
    this.driverId,
    this.driverName,
    this.driverPhotoUrl,
    this.vehicleId,
    this.vehiclePlate,
    this.vehicleModel,
    this.vehicleColor,
    this.externalFuecId,
    this.urlPdfFuec,
    this.contractNumber,
  });

  // Factory para convertir JSON del Backend a Objeto Dart
  factory TripModel.fromJson(Map<String, dynamic> json) {
    // Extracción segura de objetos anidados
    // (El backend enviará estos objetos cuando status sea ACCEPTED)
    final driverData = json['driver'] is Map ? json['driver'] : {};
    final vehicleData = json['vehicle'] is Map ? json['vehicle'] : {};

    return TripModel(
      id: json['id']?.toString() ?? 'Unknown',

      // Manejo de fechas flexible
      dateRaw:
          json['created_at'] ??
          json['date'] ??
          DateTime.now().toIso8601String(),

      origin: json['origin_address'] ?? json['origin'] ?? 'Origen desconocido',

      destination:
          json['destination_address'] ??
          json['destination'] ??
          'Destino desconocido',

      price: double.tryParse(json['price'].toString()) ?? 0.0,
      status: json['status'] ?? 'SEARCHING',

      // --- MAPEADO DE DATOS OPERATIVOS (JOINs) ---
      driverId: driverData['id']?.toString(), // FK Drivers
      driverName: driverData['name'] ?? json['driver_name'],
      driverPhotoUrl: driverData['photo_url'] ?? json['driver_photo'],

      vehicleId: vehicleData['id']?.toString(), // FK Vehicles
      vehiclePlate: vehicleData['placa'] ?? json['vehicle_plate'],
      vehicleModel: vehicleData['modelo'] ?? json['vehicle_model'],
      vehicleColor: vehicleData['color'] ?? json['vehicle_color'],

      // --- MAPEADO DE DATOS LEGALES (FUEC) ---
      externalFuecId: int.tryParse(json['external_fuec_id'].toString()),
      urlPdfFuec: json['url_pdf_fuec'],
      contractNumber: json['contract_number_generated'],
    );
  }

  // --- LOGICA DE VISUALIZACIÓN ---

  String get formattedDate {
    try {
      final date = DateTime.parse(dateRaw);
      // Nota: Asegúrate de inicializar initializeDateFormatting('es_ES', null) en main.dart
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

  // Estados visuales
  bool get isCompleted => status == 'COMPLETED' || status == 'Completado';
  bool get isCancelled => status == 'CANCELLED' || status == 'Cancelado';
  bool get isInProgress => status == 'IN_PROGRESS' || status == 'En Curso';

  // Validar si ya tenemos conductor asignado
  bool get hasDriverAssigned => driverName != null && vehiclePlate != null;

  // Validar si el FUEC ya está generado para mostrar el botón de descarga
  bool get hasLegalDocument => urlPdfFuec != null && urlPdfFuec!.isNotEmpty;

  String get statusLabel {
    if (isCompleted) return 'Completado';
    if (isCancelled) return 'Cancelado';
    if (isInProgress) return 'En Viaje';
    if (hasDriverAssigned) return 'Conductor en camino';
    return 'Buscando...';
  }
}
