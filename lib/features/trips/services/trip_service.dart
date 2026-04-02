import 'package:latlong2/latlong.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/passenger_model.dart';

class TripService {
  final ApiClient _api = ApiClient();

  Future<bool> createTripRequest({
    required User currentUser,
    required LatLng origin,
    required LatLng destination,
    required String originAddress,
    required String destinationAddress,
    required String serviceCategory,
    required double estimatedPrice,
    required List<Passenger> passengers,
    required bool includeMyself,
    DateTime? scheduledAt,
    required dynamic desglose,
  }) async {
    final List<Map<String, dynamic>> pasajerosData = [];

    // Agregamos al usuario logueado
    if (includeMyself) {
      pasajerosData.add({
        'nombre_completo': currentUser.name,
        'numero_documento': currentUser.documentNumber.isEmpty
            ? "0"
            : currentUser.documentNumber,
        'tipo_documento': 'CC',
      });
    }

    // Agregamos acompañantes
    for (var p in passengers) {
      pasajerosData.add({
        'nombre_completo': p.name,
        'numero_documento': p.nationalId,
        'tipo_documento': 'CC',
      });
    }

    final Map<String, dynamic> body = {
      // Si está en modo corporativo, enviamos el ID de su empresa (convertido a int)
      // Si es natural, enviamos el contrato global '1'.
      'id_contrato': currentUser.isCorporateMode
          ? (int.tryParse(currentUser.companyUuid ?? '1') ?? 1)
          : 1,
      'origen': originAddress,
      'destino': destinationAddress,
      'lat_origen': origin.latitude,
      'lng_origen': origin.longitude,
      'lat_destino': destination.latitude,
      'lng_destino': destination.longitude,
      'tipo_viaje': serviceCategory.toLowerCase(),
      'precio_estimado': estimatedPrice,
      'programado_para': scheduledAt?.toIso8601String(),
      'desglose_precio': desglose,
      'pasajeros': pasajerosData,
    };

    try {
      // Usamos POST a la ruta correcta
      final response = await _api.dio.post('/viajes/solicitar', data: body);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}
