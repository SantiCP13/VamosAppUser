// lib/features/home/services/mapbox_search_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

class MapboxSearchService {
  final String _baseUrl = "https://api.mapbox.com/search/searchbox/v1/suggest";
  final String _accessToken =
      "pk.eyJ1IjoidmFtb3NhcHBjb2wiLCJhIjoiY21uZGxldzJtMWc3MzJwcHI5YzNmdmQ4ZCJ9.QsTim64a5eVStoAKYk3kcg";

  String? _sessionToken;

  void startNewSession() {
    _sessionToken = const Uuid().v4();
    debugPrint("🔑 Nueva sesión Mapbox: $_sessionToken");
  }

  // lib/features/home/services/mapbox_search_service.dart

  // lib/features/home/services/mapbox_search_service.dart

  // lib/features/home/services/mapbox_search_service.dart

  Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    LatLng? proximity,
  }) async {
    if (query.length < 3) return [];
    if (_sessionToken == null) startNewSession();

    final encodedQuery = Uri.encodeComponent(query);

    // ELIMINAMOS EL BBOX para no restringir.
    // Mantenemos country=co para que no salga nada de otros países.
    String urlString =
        '$_baseUrl?q=$encodedQuery'
        '&language=es'
        '&limit=10'
        '&country=co'
        '&bbox=-79.2778,-4.2294,-66.8472,12.5852' // <--- MAGIA: Solo busca dentro de este cuadrado (Colombia)
        '&types=poi,address' // <--- Limpio: Solo lugares y direcciones
        '&session_token=$_sessionToken'
        '&access_token=$_accessToken';

    if (proximity != null) {
      // ESTO ES LO QUE HACE QUE SALGA CHÍA SI ESTÁS CERCA DE CHÍA
      urlString += '&proximity=${proximity.longitude},${proximity.latitude}';
    }

    try {
      final response = await http.get(Uri.parse(urlString));

      debugPrint("📡 Buscando: $query | Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final suggestions = data['suggestions'] as List;

        return suggestions.map((s) {
          String subTitle = s['full_address'] ?? s['place_formatted'] ?? "";
          return {
            "name": s['name'],
            "address": subTitle,
            "mapbox_id": s['mapbox_id'],
          };
        }).toList();
      } else {
        // Esto nos mostrará si hay otros errores
        debugPrint("❌ Error Mapbox: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Error de conexión: $e");
    }
    return [];
  }

  // El método getCoords también DEBE llevar el mismo session_token
  Future<Map<String, double>?> getCoords(String mapboxId) async {
    if (_sessionToken == null) return null;

    final url = Uri.parse(
      "https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId?session_token=$_sessionToken&access_token=$_accessToken",
    );

    try {
      final response = await http.get(url);

      // Una vez obtenemos las coordenadas, cerramos la sesión para que Mapbox cobre
      _sessionToken = null;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['features'][0]['geometry']['coordinates'];
        return {"lat": coords[1].toDouble(), "lng": coords[0].toDouble()};
      }
    } catch (e) {
      debugPrint("❌ Error Retrieve Mapbox: $e");
    }
    return null;
  }
}
