import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  // URL pública de OSRM (Demo Server)
  // NOTA: Para producción masiva, deberías montar tu propio docker de OSRM o usar Google,
  // pero para desarrollo esto funciona perfecto y gratis.
  final String _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  Future<RouteResult?> getRoute(LatLng start, LatLng end) async {
    try {
      // OSRM requiere las coordenadas en formato: Longitud,Latitud
      final String coordinates =
          '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';

      // Solicitamos:
      // - steps=true: instrucciones (opcional)
      // - overview=full: la polilínea completa con todos los detalles
      // - geometries=geojson: formato fácil de leer para nosotros
      final Uri url = Uri.parse(
        '$_baseUrl/$coordinates?steps=true&overview=full&geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          return null;
        }

        final route = data['routes'][0];

        // 1. Extraer Distancia y Duración
        final double distanceMeters = (route['distance'] as num).toDouble();
        final double durationSeconds = (route['duration'] as num).toDouble();

        // 2. Extraer los puntos de la geometría (GeoJSON)
        final geometry = route['geometry'];
        final List<dynamic> coordinatesList = geometry['coordinates'];

        // Convertir [Long, Lat] a LatLng(Lat, Long) para Flutter Map
        final List<LatLng> points = coordinatesList.map((coord) {
          return LatLng(
            (coord[1] as num).toDouble(), // Latitud
            (coord[0] as num).toDouble(), // Longitud
          );
        }).toList();

        return RouteResult(
          points: points,
          distanceMeters: distanceMeters,
          durationSeconds: durationSeconds,
        );
      } else {
        print("Error en OSRM: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error obteniendo ruta: $e");
      return null;
    }
  }
}

// DTO (Clase simple para transportar los datos)
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}
