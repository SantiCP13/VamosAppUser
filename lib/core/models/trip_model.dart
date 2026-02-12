// lib/core/models/trip_model.dart
import 'package:intl/intl.dart';
import 'passenger_model.dart';

/// MODELO DE VIAJE (TRIP)
///
/// Representa la entidad central 'TRIPS' del Diagrama ER.
/// Conecta Usuario con Conductor y la Legalidad (Moviltrack).
///
/// RESPONSABILIDADES:
/// 1. Gestionar el estado del viaje (SEARCHING -> ACCEPTED -> IN_PROGRESS).
/// 2. Almacenar la información del Conductor y Vehículo asignado (Relaciones FK).
/// 3. PORTAR EL FUEC: Guarda la URL del PDF y el ID de Moviltrack necesarios para
///    que el conductor cumpla la normativa de transporte especial.
class TripModel {
  // --- DATOS BÁSICOS DE LA SOLICITUD---

  /// PK: UUID único del viaje.
  final String id;

  /// Mapea a 'created_at'. Fecha de solicitud.
  final String dateRaw;

  /// Mapea a 'origin_address'. Dirección de recogida.
  final String origin;

  /// Mapea a 'destination_address'. Dirección de destino.
  final String destination;

  /// Mapea a 'price'. Costo calculado (inicialmente estimado).
  final double price;

  /// Mapea a 'status'. Controla el flujo de la UI:
  /// - SEARCHING: Buscando conductor (User ve radar).
  /// - ACCEPTED: Conductor asignado (User ve info del conductor).
  /// - IN_PROGRESS: Viaje en curso.
  /// - COMPLETED/CANCELLED: Historial.
  final String status;

  // --- DATOS DEL CONDUCTOR Y VEHÍCULO---

  // Estos datos se llenan cuando el estado pasa a 'ACCEPTED'.
  // El backend hace JOIN con las tablas DRIVERS y VEHICLES.

  final String? driverId; // FK Drivers
  final String? driverName; // Para mostrar en UI sin hacer otra petición
  final String?
  driverPhotoUrl; // Foto del conductor para la tarjeta de asignación
  final String? vehicleId; // FK Vehicles
  final String? vehiclePlate; // Placa Blanca - Vital para identificar el carro
  final String? vehicleModel; // Modelo del vehículo para mostrar en UI
  final String? vehicleColor; // Color del vehículo para mostrar en UI

  // --- DATOS LEGALES / FUEC (INTEGRACIÓN MOVILTRACK) ---

  // Campos "Espejo" del Diagrama ER

  /// ID interno de Moviltrack, sirve para auditoría o para cancelar el FUEC externamente si el viaje se cancela.
  final int? externalFuecId;

  /// Link al PDF generado por la API de Moviltrack.
  /// Si este campo es NULL, el viaje es ILEGAL.
  /// La App del Conductor usa esto para el botón "Ver FUEC".
  final String? urlPdfFuec;

  /// Número consecutivo del contrato generado. Se muestra en el PDF.
  final String? contractNumber;

  final List<Passenger>
  passengers; // Lista de pasajeros adicionales (beneficiarios)

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
    required this.passengers,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    // Validación defensiva: Si el backend envía el objeto completo o null
    final driverData = json['driver'] is Map ? json['driver'] : {};
    final vehicleData = json['vehicle'] is Map ? json['vehicle'] : {};

    // --- PARSEO DE LISTA DE PASAJEROS ---
    var passengerList = <Passenger>[];
    if (json['passengers'] != null) {
      json['passengers'].forEach((v) {
        passengerList.add(Passenger.fromJson(v));
      });
    }

    return TripModel(
      id: json['id']?.toString() ?? 'Unknown',
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

      driverId: driverData['id']?.toString(),
      driverName: driverData['name'] ?? json['driver_name'],
      driverPhotoUrl: driverData['photo_url'] ?? json['driver_photo'],

      vehicleId: vehicleData['id']?.toString(),
      vehiclePlate: vehicleData['placa'] ?? json['vehicle_plate'],
      vehicleModel: vehicleData['modelo'] ?? json['vehicle_model'],
      vehicleColor: vehicleData['color'] ?? json['vehicle_color'],

      externalFuecId: int.tryParse(json['external_fuec_id'].toString()),
      urlPdfFuec: json['url_pdf_fuec'],
      contractNumber: json['contract_number_generated'],

      passengers: passengerList, // <--- Asignación
    );
  }

  // --- LOGICA DE VISUALIZACIÓN ---

  /// Formatea la fecha a un formato amigable para el usuario.
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

  String get passengerSummary {
    if (passengers.isEmpty) return 'Sin pasajeros registrados';
    if (passengers.length == 1) return passengers.first.name;
    return '${passengers.first.name} +${passengers.length - 1}';
  }

  /// Formatea el precio a pesos colombianos
  String get formattedPrice {
    final currency = NumberFormat("#,##0", "es_CO");
    return "\$ ${currency.format(price)}";
  }

  // Helpers booleanos para limpiar la lógica en las Vistas (Widgets)
  bool get isCompleted => status == 'COMPLETED' || status == 'Completado';
  bool get isCancelled => status == 'CANCELLED' || status == 'Cancelado';
  bool get isInProgress => status == 'IN_PROGRESS' || status == 'En Curso';

  /// Indica si el viaje ya tiene recursos asignados (No sigue buscando)
  bool get hasDriverAssigned => driverName != null && vehiclePlate != null;

  /// Valida si existe el PDF del FUEC para habilitar el botón de descarga/visualización
  bool get hasLegalDocument => urlPdfFuec != null && urlPdfFuec!.isNotEmpty;

  /// Texto amigable para el usuario según el estado técnico
  String get statusLabel {
    if (isCompleted) return 'Completado';
    if (isCancelled) return 'Cancelado';
    if (isInProgress) return 'En Viaje';
    if (hasDriverAssigned) return 'Conductor en camino';
    return 'Buscando...';
  }
}
