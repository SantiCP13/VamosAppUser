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
    required double snappedLatOrigin,
    required double snappedLngOrigin,
    required double snappedLatDestino,
    required double snappedLngDestino,
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
    // 4. LÓGICA DE CONTRATO (CLAVE PARA EL FUEC)
    int contratoId = 1;

    if (currentUser.isCorporateMode) {
      // Buscamos el ID de la empresa vinculada (en tu caso '2' para santi sas)
      // Usamos el campo que contiene ese ID (companyUuid)
      final enterpriseId = int.tryParse(currentUser.companyUuid ?? '');

      if (enterpriseId != null) {
        contratoId = enterpriseId;
        // ignore: avoid_print
        print("🏢 ENVIANDO SOLICITUD PARA EMPRESA ID: $contratoId");
      } else {
        // ignore: avoid_print
        print(
          "⚠️ ADVERTENCIA: Modo corporativo activo pero no se encontró ID de empresa.",
        );
      }
    }

    final Map<String, dynamic> body = {
      'id_contrato': contratoId,
      'origen': originAddress,
      'destino': destinationAddress,
      // Usamos toStringAsFixed(6) y luego parse para asegurar 6 decimales exactos
      'lat_origen': double.parse(origin.latitude.toStringAsFixed(6)),
      'lng_origen': double.parse(origin.longitude.toStringAsFixed(6)),
      'lat_destino': double.parse(destination.latitude.toStringAsFixed(6)),
      'lng_destino': double.parse(destination.longitude.toStringAsFixed(6)),
      'snapped_lat_origen': double.parse(snappedLatOrigin.toStringAsFixed(6)),
      'snapped_lng_origen': double.parse(snappedLngOrigin.toStringAsFixed(6)),
      'snapped_lat_destino': double.parse(snappedLatDestino.toStringAsFixed(6)),
      'snapped_lng_destino': double.parse(snappedLngDestino.toStringAsFixed(6)),
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
