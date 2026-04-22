// ignore_for_file: avoid_print

import '../../../core/network/api_client.dart';

class SearchService {
  final ApiClient _apiClient = ApiClient();

  // 1. Busca las sugerencias de direcciones
  // 1. Busca las sugerencias de direcciones
  Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    double? lat,
    double? lng,
    String? sessionToken, // <--- NUEVO
  }) async {
    if (query.length < 3) return [];
    try {
      final response = await _apiClient.dio.get(
        '/lugares/buscar',
        queryParameters: {
          'q': query,
          'lat': lat,
          'lng': lng,
          'session_token': sessionToken, // <--- ENVIAMOS EL TOKEN AL BACKEND
        },
      );
      if (response.statusCode == 200) {
        final List rawData = response.data;
        return rawData.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      print("Error en búsqueda: $e");
    }
    return [];
  }

  // 2. Obtiene latitud y longitud exacta
  Future<Map<String, double>?> getPlaceCoords(
    String placeId,
    String? sessionToken,
  ) async {
    try {
      final response = await _apiClient.dio.get(
        '/lugares/detalles',
        queryParameters: {
          'place_id': placeId,
          'session_token':
              sessionToken, // <--- IMPORTANTE: El mismo token para cerrar la sesión
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return {
          'lat': (response.data['lat'] as num).toDouble(),
          'lng': (response.data['lng'] as num).toDouble(),
        };
      }
    } catch (e) {
      print("Error obteniendo coordenadas: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> getReverseGeocode(
    double lat,
    double lng,
  ) async {
    try {
      // 🔥 Eliminamos la llamada duplicada y dejamos solo la ruta oficial del backend
      final response = await _apiClient.dio.get(
        '/maps/reverse',
        queryParameters: {'lat': lat, 'lng': lng},
      );

      if (response.statusCode == 200) {
        return response.data['data'];
      }
    } catch (e) {
      print("Error en Reverse Geocode: $e");
    }
    return null;
  }

  // NUEVO: Pedir los destinos recientes del usuario al Backend
  Future<List<Map<String, dynamic>>> getRecentPlaces() async {
    try {
      final response = await _apiClient.dio.get('/lugares/recientes');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      print("Error obteniendo recientes: $e");
    }
    return [];
  }
  // lib/features/home/services/search_service.dart

  Future<Map<String, dynamic>?> saveQuickAddress({
    // Cambia bool por Map?
    required String type,
    required String address,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/user/favoritos',
        data: {'tipo': type, 'address': address, 'lat': lat, 'lng': lng},
      );
      if (response.statusCode == 200) {
        return response
            .data['user']; // Devolvemos el objeto usuario actualizado
      }
      return null;
    } catch (e) {
      print("Error guardando favorito: $e");
      return null;
    }
  }
}
