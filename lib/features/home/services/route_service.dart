import 'package:latlong2/latlong.dart';
import '../../../core/network/api_client.dart';

class RouteService {
  final ApiClient _apiClient = ApiClient();

  Future<RouteResult> getRoute(
    LatLng start,
    LatLng end, {
    int? idContrato,
    String? tipoVehiculo,
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
          'tipo_vehiculo': tipoVehiculo ?? 'CITY CAR',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final geometryData = data['geometry'];

        List<LatLng> points = [];
        if (geometryData is String) {
          points = _decodePolyline(geometryData);
        } else if (geometryData is List) {
          points = geometryData
              .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
              .toList();
        }

        return RouteResult(
          points: points,
          distanceMeters: (data['distancia_km'] * 1000).toDouble(),
          durationSeconds: (data['tiempo_minutos'] * 60).toDouble(),
          price: (data['precio_total'] as num).toDouble(),
          desglose: data['desglose'],
          preciosCategorias: data['precios_categorias'], // <--- AGREGADO
        );
      }
      throw Exception("Error en la respuesta del servidor");
    } catch (e) {
      throw Exception("Error al conectar con el servidor: $e");
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      // IMPORTANTE: Mapbox Polyline6 usa precisión de 1/1,000,000 (1e6)
      points.add(LatLng(lat / 1000000.0, lng / 1000000.0));
    }
    return points;
  }
}

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final double price;
  final dynamic desglose;
  final Map<String, dynamic>? preciosCategorias; // <--- AGREGADO

  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.price,
    this.desglose,
    this.preciosCategorias, // <--- AGREGADO
  });
}
