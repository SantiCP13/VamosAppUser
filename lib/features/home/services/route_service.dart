// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';

// 1. Función global para decode (Se mantiene igual)
List<LatLng> _decodePolylineIsolate(Map<String, dynamic> params) {
  String encoded = params['encoded'];
  bool isGoogle = params['isGoogle'];
  double divisor = isGoogle
      ? 100000.0
      : 1000000.0; // Google=5 decimales, Mapbox=6

  List<LatLng> points = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  try {
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        // Validación de seguridad para evitar el "offset" error
        if (index >= len) return points;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        // Validación de seguridad para evitar el "offset" error
        if (index >= len) return points;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      double latFinal = lat / divisor;
      double lngFinal = lng / divisor;
      if (latFinal < -90 ||
          latFinal > 90 ||
          lngFinal < -180 ||
          lngFinal > 180) {
        continue; // Ignorar punto corrupto en lugar de romper el mapa
      }

      points.add(LatLng(latFinal, lngFinal));
    }
  } catch (e) {
    // Si hay un error en un viaje largo, devolvemos lo que alcanzamos a decodificar
    debugPrint("Error decodificando parte de la ruta: $e");
  }
  return points;
}

class RouteService {
  final ApiClient _apiClient = ApiClient();

  Future<RouteResult> getRoute(
    LatLng start,
    LatLng end, {
    int? idContrato,
    String? tipoVehiculo,
  }) async {
    try {
      // --- OPTIMIZACIÓN CLAVE ---
      // Eliminamos el await _osmService.getNearestRoadPoint(...)
      // Enviamos las coordenadas directamente, limpiándolas a 6 decimales.
      // Esto ahorra 2 peticiones HTTP externas y mucha batería.

      double latO = double.parse(start.latitude.toStringAsFixed(6));
      double lngO = double.parse(start.longitude.toStringAsFixed(6));
      double latD = double.parse(end.latitude.toStringAsFixed(6));
      double lngD = double.parse(end.longitude.toStringAsFixed(6));

      final response = await _apiClient.dio.post(
        '/viajes/cotizar',
        data: {
          'lat_origen': latO,
          'lng_origen': lngO,
          'lat_destino': latD,
          'lng_destino': lngD,
          'id_contrato': idContrato,
          'tipo_vehiculo': tipoVehiculo ?? 'CITY CAR',
          'radiuses':
              '1000;1000', // <--- Esto fuerza al backend a buscar vías en un radio de 50 metros
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final String polylineType =
            data['polyline_type'] ?? 'polyline6'; // Viene del Backend

        final geometryData = data['geometry'];
        print("DEBUG GEOMETRY: ${data['geometry']}"); // <-- AÑADE ESTO

        List<LatLng> points = [];
        if (geometryData is String) {
          points = await compute(_decodePolylineIsolate, {
            'encoded': geometryData,
            'isGoogle':
                polylineType == 'polyline5', // Si es 5, usamos divisor 100k
          });
        } else if (geometryData is List) {
          // Eliminamos el (geometryData as List) porque es redundante
          points = geometryData.map((coord) {
            // Aseguramos que cada coordenada sea una lista de números [lng, lat]
            final pair = List<num>.from(coord as List);
            return LatLng(
              pair[1].toDouble(), // Latitud
              pair[0].toDouble(), // Longitud
            );
          }).toList();
        }

        return RouteResult(
          points: points,
          distanceMeters: (data['distancia_km'] * 1000).toDouble(),
          durationSeconds: (data['tiempo_minutos'] * 60).toDouble(),
          price: (data['precio_total'] as num).toDouble(),
          desglose: data['desglose'],
          preciosCategorias: data['precios_categorias'],
        );
      }
      throw Exception("Error en la respuesta del servidor");
      // Busca el catch dentro de getRoute en RouteService y cámbialo por este:
    } catch (e) {
      if (e is DioException && e.response != null) {
        print("🚨 ERROR COMPLETO DEL SERVIDOR: ${e.response?.data}");

        final serverData = e.response?.data;
        if (serverData is Map && serverData['message'] != null) {
          // Lanzamos el mensaje exacto: "Viaje No Permitido: En Modo Personal..."
          throw serverData['message'];
        }
      }
      // Si no es un error controlado del servidor, lanzamos un error de conexión
      throw e.toString().contains("Viaje No Permitido")
          ? e
          : "Error de conexión con el servidor de rutas.";
    }
  }
}

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final double price;
  final dynamic desglose;
  final Map<String, dynamic>? preciosCategorias;

  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.price,
    this.desglose,
    this.preciosCategorias,
  });
}
