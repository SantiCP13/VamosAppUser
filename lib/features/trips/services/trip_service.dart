import 'package:latlong2/latlong.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/passenger_model.dart';
import 'package:dio/dio.dart'; // <--- AGREGA ESTA LÍNEA

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
    // Dentro de createTripRequest...

    final List<Map<String, dynamic>> pasajerosData = [];

    // 1. EL TITULAR (Tú)
    if (includeMyself) {
      if (currentUser.documentNumber.isEmpty) {
        throw "Tu perfil no tiene número de documento. Es obligatorio para el seguro de viaje.";
      }
      pasajerosData.add({
        'nombre_completo': currentUser.name,
        'numero_documento': currentUser.documentNumber,
        'tipo_documento': 'CC', // O el campo que tengas en el UserModel
      });
    }

    // 2. LOS ACOMPAÑANTES
    for (var p in passengers) {
      if (p.nationalId.isEmpty || p.nationalId == "0") {
        throw "El pasajero ${p.name} no tiene un documento válido.";
      }
      pasajerosData.add(p.toJson()); // Ya trae nombre, doc y TIPO
    }
    // 3. MAPEO DE CATEGORÍA PARA EL BACKEND
    String dbCategory = 'CITY CAR';
    if (serviceCategory == 'PREMIUM') dbCategory = 'SUV';
    if (serviceCategory == 'VAN') dbCategory = 'VAN';

    // 4. LÓGICA DE CONTRATO (CLAVE PARA EL FUEC)
    // En modo corporativo, enviamos el id_empresa que Laravel espera para buscar el contrato.
    // En modo natural, enviamos 1 (Contrato de servicios ocasionales).
    int contratoId = 1;
    if (currentUser.isCorporateMode) {
      // Si el companyUuid es un ID numérico en la DB, lo usamos.
      // De lo contrario, el backend debe manejar la asociación por empresa.
      contratoId = int.tryParse(currentUser.companyUuid ?? '1') ?? 1;
    }

    final Map<String, dynamic> body = {
      'id_contrato': contratoId,
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['data']['viaje_id'].toString();
      }
      throw "No se pudo crear la solicitud";
    } catch (e) {
      // Si el servidor responde con un error (ej: 404 conductores), capturamos el mensaje
      if (e is DioException && e.response != null) {
        final serverMessage =
            e.response?.data['message'] ?? "Error en el servidor";
        throw serverMessage;
      }
      throw "Error de conexión: Verifica tu internet";
    }
  }
}
