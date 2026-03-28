import 'package:latlong2/latlong.dart';
// 1. IMPORTANTE: Verifica que esta ruta a ApiClient sea la correcta en tu proyecto
import '../../../core/network/api_client.dart';

class RouteService {
  final ApiClient _apiClient = ApiClient();

  // Mantenemos el nombre 'getRoute' para que home_screen.dart no de error
  Future<RouteResult> getRoute(
    LatLng start,
    LatLng end, {
    int? idContrato,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/viajes/cotizar',
        data: {
          'lat_origen': start.latitude,
          'lng_origen': start.longitude,
          'lat_destino': end.latitude,
          'lng_destino': end.longitude,
          'id_contrato': idContrato,
          'tipo_vehiculo': 'sedan', // Por defecto
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];

        // Mapeo de la geometría que viene del backend
        List<dynamic> coords = data['geometry'];
        List<LatLng> points = coords
            .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();

        return RouteResult(
          points: points,
          distanceMeters: (data['distancia_km'] * 1000).toDouble(),
          durationSeconds: (data['tiempo_minutos'] * 60).toDouble(),
          price: (data['precio_total'] as num).toDouble(), // <--- AGREGADO
          desglose: data['desglose'], // <--- AGREGADO
        );
      }
      throw Exception("Error en la respuesta del servidor");
    } catch (e) {
      throw Exception("Error al conectar con el servidor: $e");
    }
  }
}

// Clase DTO actualizada con los nuevos campos
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final double price; // <--- NUEVO
  final dynamic desglose; // <--- NUEVO
  final bool isFallback;

  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.price,
    this.desglose,
    this.isFallback = false,
  });
}
