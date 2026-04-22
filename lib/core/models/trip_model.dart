import 'package:intl/intl.dart';
import 'passenger_model.dart';

class TripModel {
  final String id;
  final String dateRaw;
  final DateTime? scheduledAt; // Fecha programada
  final String origin;
  final String destination;
  final double price;
  final double tolls; // <--- AGREGA ESTA LÍNEA

  final String status;

  // Datos del Conductor y Vehículo
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
    required this.tolls, // <--- AGREGA ESTA LÍNEA

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

    // --- NUEVA LÓGICA DE PEAJES PARA EL USUARIO ---
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

      // 🔥 Precio total oficial (Viene del Backend)
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

      // Guardamos los peajes para que el usuario sepa qué pagó
      tolls: totalPeajes,
    );
  }

  // --- LÓGICA DE VISUALIZACIÓN ---

  String get formattedDate {
    try {
      // Si scheduledAt no es nulo, usamos ese, si no, parseamos dateRaw
      final DateTime date = scheduledAt ?? DateTime.parse(dateRaw);

      // Usamos DateFormat para quitar los ceros de más (.00000Z)
      // El formato 'dd MMM, hh:mm a' dejará algo como: 26 MAR, 01:10 PM
      final formatter = DateFormat('dd MMM, hh:mm a', 'es_ES');
      return formatter.format(date).toUpperCase();
    } catch (e) {
      // Si falla el parseo, al menos cortamos la cadena para no ver los ceros
      if (dateRaw.length > 16) return dateRaw.substring(0, 16);
      return dateRaw;
    }
  }

  String get formattedPrice {
    final currency = NumberFormat("#,##0", "es_CO");
    return "\$ ${currency.format(price)}";
  }

  bool get isCompleted => status == 'COMPLETED' || status == 'Completado';
  bool get isCancelled => status == 'CANCELLED' || status == 'Cancelado';
  bool get isUpcoming =>
      scheduledAt != null &&
      scheduledAt!.isAfter(DateTime.now()) &&
      !isCancelled &&
      !isCompleted;
  bool get hasDriverAssigned =>
      driverName != null && driverName != 'Sin nombre';

  // Lógica de las 24 horas para habilitar el botón de cancelar
  bool get canCancelProgrammed {
    if (scheduledAt == null)
      // ignore: curly_braces_in_flow_control_structures
      return true; // Viaje inmediato: siempre puede intentar cancelar
    if (!hasDriverAssigned)
      // ignore: curly_braces_in_flow_control_structures
      return true; // Si no hay chofer asignado, puede cancelar siempre

    // Si hay chofer, solo puede cancelar si faltan más de 24 horas
    final diferencia = scheduledAt!.difference(DateTime.now());
    return diferencia.inHours >= 24;
  }

  // QUITAMOS EL @override QUE DABA ERROR
  String get statusLabel {
    if (isCompleted) return 'Completado';
    if (isCancelled) return 'Cancelado';
    if (isUpcoming) {
      return hasDriverAssigned ? 'Chofer Asignado' : 'Programado';
    }
    return 'En curso';
  }
}
