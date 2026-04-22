import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
// 1. IMPORTA TU API CLIENT (Asegúrate de que la ruta sea correcta)
import '../../../core/network/api_client.dart';

class OsmService {
  final Dio _dio = Dio();
  // 2. DECLARA E INSTANCIA EL API CLIENT
  final ApiClient _apiClient = ApiClient();

  // 1. Buscador de direcciones (Photon) - Se mantiene igual
  Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    LatLng? userLocation,
  }) async {
    if (query.length < 3) return [];

    String urlString =
        'https://photon.komoot.io/api/?q=$query&limit=10&lang=es';
    if (userLocation != null) {
      urlString +=
          '&lat=${userLocation.latitude}&lon=${userLocation.longitude}';
    }

    try {
      final response = await http.get(Uri.parse(urlString));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        return features.map((feature) {
          final props = feature['properties'];
          final coords = feature['geometry']['coordinates'];
          String name = props['name'] ?? props['street'] ?? "Ubicación";

          List<String> parts = [];

          // --- CORRECCIÓN DE LLAVES (Lints) ---
          if (props['housenumber'] != null) {
            parts.add("#${props['housenumber']}");
          }

          if (props['city'] != null) {
            parts.add(props['city']);
          }

          if (props['state'] != null) {
            parts.add(props['state']);
          }

          String details = "";
          if (name == props['street']) {
            details = parts.join(", ");
          } else {
            List<String> addressParts = [];
            if (props['street'] != null) addressParts.add(props['street']);
            addressParts.addAll(parts);
            details = addressParts.join(", ");
          }

          return {
            "name": name,
            "address": details,
            "lat": coords[1].toDouble(),
            "lng": coords[0].toDouble(),
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Error buscando en OSM: $e");
    }
    return [];
  }

  // 2. Obtener dirección simple (Texto) - Nominatim
  Future<String> getAddressFromCoordinates(LatLng point) async {
    final url =
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1';
    try {
      final response = await _dio.get(
        url,
        options: Options(headers: {'User-Agent': 'VamosApp_Dev/1.0'}),
      );
      if (response.statusCode == 200) {
        final addr = response.data['address'];
        String road = addr['road'] ?? "";
        String house = addr['house_number'] ?? "";
        String city = addr['city'] ?? addr['town'] ?? addr['village'] ?? "";

        String result = "$road $house".trim();
        if (city.isNotEmpty) {
          result += ", $city";
        }
        return result.isEmpty ? "Ubicación en mapa" : result;
      }
    } catch (e) {
      debugPrint("Error Reverse Geocoding: $e");
    }
    return "Ubicación seleccionada";
  }

  // 3. SNAPPING + DIRECCIÓN (Ahora usa tu servidor con CACHÉ)
  // lib/features/home/services/osm_service.dart

  Future<Map<String, dynamic>> getSnappedAddress(LatLng point) async {
    try {
      final response = await _apiClient.dio.get(
        '/maps/reverse',
        queryParameters: {'lat': point.latitude, 'lng': point.longitude},
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final data = response.data['data'];
        return {
          'name': data['name'],
          'address': data['address'],
          'es_interior': data['es_interior'] ?? false,
          // Usamos snapped_lat/lng si vienen del servidor, si no, el punto original
          'snappedPoint': LatLng(
            double.parse((data['snapped_lat'] ?? data['lat']).toString()),
            double.parse((data['snapped_lng'] ?? data['lng']).toString()),
          ),
        };
      }
    } catch (e) {
      debugPrint("Error consultando caché del servidor: $e");
    }
    return {
      'name': "Ubicación en mapa",
      'address': "Seleccionada manualmente",
      'snappedPoint': point,
    };
  }

  // 4. Obtener punto de calle más cercano (OSRM directo)
  Future<LatLng> getNearestRoadPoint(LatLng point) async {
    try {
      final url =
          'https://router.project-osrm.org/nearest/v1/driving/'
          '${point.longitude},${point.latitude}?number=1&radiuses=1000';

      final response = await _dio.get(url);

      if (response.statusCode == 200 &&
          response.data['waypoints'] != null &&
          (response.data['waypoints'] as List).isNotEmpty) {
        final List coords = response.data['waypoints'][0]['location'];
        return LatLng(coords[1].toDouble(), coords[0].toDouble());
      }
      return point;
    } catch (e) {
      debugPrint("Error al ajustar coordenada: $e");
      return point;
    }
  }
}
