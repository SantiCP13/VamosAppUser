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

  // Añade esto a SearchService.dart
  Future<void> saveManualRecent({
    required String name,
    required String address,
    required double lat,
    required double lng,
  }) async {
    try {
      // Reutilizamos el endpoint de recientes o creamos uno para 'guardar'
      await _apiClient.dio.post(
        '/lugares/guardar-reciente',
        data: {'name': name, 'address': address, 'lat': lat, 'lng': lng},
      );
    } catch (e) {
      print("Error guardando reciente manual: $e");
    }
  }

  Future<Map<String, dynamic>?> getReverseGeocode(
    double lat,
    double lng, {
    bool persist = false,
  }) async {
    try {
      final response = await _apiClient.dio
          .get(
            '/maps/reverse',
            queryParameters: {
              'lat': lat,
              'lng': lng,
              'persist': persist ? 1 : 0,
            },
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        // Retornamos el mapa de datos que viene del server
        return Map<String, dynamic>.from(response.data['data']);
      }
    } catch (e) {
      print("❌ Error en SearchService.getReverseGeocode: $e");
    }

    // Fallback de seguridad si falla el internet o el server
    return {
      'name': 'Ubicación seleccionada',
      'address': 'Dirección no disponible',
      'lat': lat,
      'lng': lng,
      'snapped_lat': lat,
      'snapped_lng': lng,
      'municipality_id': null,
      'city': 'Desconocido',
    };
  }

  Future<List<Map<String, dynamic>>> getRecentPlaces() async {
    try {
      final response = await _apiClient.dio.get('/lugares/recientes');
      if (response.statusCode == 200) {
        // Si el servidor ya devuelve la lista limpia, no necesitamos deduplicar tan agresivo
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      print("Error obteniendo recientes: $e");
    }
    return [];
  }

  // NUEVO: Borra un lugar específico por su ID
  Future<bool> deleteRecentPlace(dynamic id) async {
    try {
      final response = await _apiClient.dio.delete('/lugares/recientes/$id');
      if (response.statusCode == 200) {
        print("Lugar reciente eliminado del servidor.");
        return true;
      }
    } catch (e) {
      print("Error borrando lugar reciente en SearchService: $e");
    }
    return false;
  }

  // lib/features/home/services/search_service.dart
  Future<bool> clearRecentHistory() async {
    try {
      final response = await _apiClient.dio.post('/lugares/limpiar-historial');
      return response.statusCode == 200;
    } catch (e) {
      print("Error limpiando historial: $e");
      return false;
    }
  }
}
