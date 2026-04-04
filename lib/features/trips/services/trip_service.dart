import 'package:latlong2/latlong.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/passenger_model.dart';

class TripService {
  final ApiClient _api = ApiClient();

  Future<String?> createTripRequest({
    required User currentUser,
    required LatLng origin,
    required LatLng destination,
    required String originAddress,
    required String destinationAddress,
    required String serviceCategory,
    required double estimatedPrice,
    required String paymentMethod,
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
    String dbCategory = 'CITY CAR';
    if (serviceCategory == 'PREMIUM') dbCategory = 'SUV';
    if (serviceCategory == 'VAN') dbCategory = 'VAN';

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
      'tipo_viaje': dbCategory,
      'precio_estimado': estimatedPrice,
      'programado_para': scheduledAt?.toIso8601String(),
      'desglose_precio': desglose,
      'pasajeros': pasajerosData,
      'metodo_pago': paymentMethod,
    };

    try {
      final response = await _api.dio.post('/viajes/solicitar', data: body);

      // CAMBIAR EL RETORNO:
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Retornamos el viaje_id que envía Laravel en su respuesta JSON
        return response.data['data']['viaje_id'].toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
