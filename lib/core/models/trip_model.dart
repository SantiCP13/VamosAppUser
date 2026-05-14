import 'package:intl/intl.dart';
import 'passenger_model.dart';

class TripModel {
  final String id;
  final String dateRaw;
  final DateTime? scheduledAt;
  final String origin;
  final String destination;
  final double price;
  final double tolls;
  final String status;

  final String? driverId;
  final String? driverName;
  final String? driverPhotoUrl;
  final String? vehicleId;
  final String? vehiclePlate;
  final String? vehicleModel;
  final String? vehicleColor;

  final List<Passenger> passengers;

  TripModel({
    required this.id,
    required this.dateRaw,
    this.scheduledAt,
    required this.origin,
    required this.destination,
    required this.price,
    required this.tolls,
    required this.status,
    this.driverId,
    this.driverName,
    this.driverPhotoUrl,
    this.vehicleId,
    this.vehiclePlate,
    this.vehicleModel,
    this.vehicleColor,
    required this.passengers,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    final rawDriver = json['conductor'] ?? json['driver'];
    final driverData = rawDriver is Map ? rawDriver : {};
    final rawVehicle = json['vehiculo'] ?? json['vehicle'];
    final vehicleData = rawVehicle is Map ? rawVehicle : {};

    final desglose = json['desglose_precio'] ?? {};
    final double totalPeajes =
        double.tryParse((desglose['total_peajes'] ?? 0).toString()) ?? 0.0;

    var passengerList = <Passenger>[];
    if (json['pasajeros'] != null) {
      json['pasajeros'].forEach(
        (v) => passengerList.add(Passenger.fromJson(v)),
      );
    }

    return TripModel(
      id: json['id']?.toString() ?? 'ID_DESCONOCIDO',
      dateRaw:
          json['solicitado_en'] ??
          json['created_at'] ??
          DateTime.now().toIso8601String(),
      scheduledAt: json['programado_para'] != null
          ? DateTime.parse(json['programado_para'])
          : null,
      origin: json['origen'] ?? 'Origen desconocido',
      destination: json['destino'] ?? 'Destino desconocido',
      price:
          double.tryParse(
            (json['precio_estimado'] ?? json['monto_final'] ?? 0).toString(),
          ) ??
          0.0,
      status:
          json['status'] ??
          (json['finalizado_en'] != null
              ? 'COMPLETED'
              : (json['cancelado_en'] != null ? 'CANCELLED' : 'PENDING')),
      driverId: driverData['id']?.toString(),
      driverName: driverData['name'] ?? driverData['nombre'] ?? 'Sin nombre',
      driverPhotoUrl: driverData['foto_perfil'] ?? driverData['photo_url'],
      vehicleId: vehicleData['id']?.toString(),
      vehiclePlate: vehicleData['placa'] ?? vehicleData['plate'],
      vehicleModel: vehicleData['modelo'] ?? vehicleData['model'],
      vehicleColor: vehicleData['color'],
      passengers: passengerList,
      tolls: totalPeajes,
    );
  }

  // --- GETTERS DE ESTADO UNIFICADOS ---
  bool get isCompleted =>
      status.toUpperCase() == 'COMPLETED' || status == 'Completado';
  bool get isCancelled =>
      status.toUpperCase() == 'CANCELLED' || status == 'Cancelado';

  bool get isUpcoming =>
      scheduledAt != null &&
      scheduledAt!.isAfter(DateTime.now()) &&
      !isCancelled &&
      !isCompleted;

  bool get hasDriverAssigned =>
      driverName != null && driverName != 'Sin nombre';

  bool get canCancelProgrammed {
    if (isCancelled || isCompleted) return false;
    if (scheduledAt == null) return true;
    if (!hasDriverAssigned) return true;
    return scheduledAt!.difference(DateTime.now()).inHours >= 24;
  }

  String get formattedPrice {
    final currency = NumberFormat("#,##0", "es_CO");
    return "\$ ${currency.format(price)}";
  }

  String get statusLabel {
    if (isCancelled) return 'Cancelado';
    if (isCompleted) return 'Completado';
    if (status == 'SEARCHING_DRIVER') return 'Buscando conductor';
    if (status == 'ACCEPTED') return 'Chofer Asignado';
    if (status == 'PENDING_SCHEDULED') return 'Programado';
    return 'En curso';
  }
  // --- Dentro de class TripModel en trip_model.dart ---

  // Verifica si estamos a menos de 24 horas de la fecha programada
  bool get isWithinPenaltyPeriod {
    if (scheduledAt == null) return false;
    final difference = scheduledAt!.difference(DateTime.now());
    return difference.inHours < 24 && difference.inHours >= 0;
  }

  // Mensaje dinámico según el tiempo
  String get cancelationWarning {
    if (isWithinPenaltyPeriod) {
      return "¿Estás seguro? Estás a menos de 24 horas. Se aplicará una multa por cancelación.";
    }
    return "¿Estás seguro de cancelar este viaje programado?";
  }
}
