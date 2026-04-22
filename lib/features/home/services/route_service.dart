// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';

// 1. Función global para decode (Se mantiene igual)
List<LatLng> _decodePolylineIsolate(String encoded) {
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

    points.add(LatLng(lat / 1000000.0, lng / 1000000.0));
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
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final geometryData = data['geometry'];

        List<LatLng> points = [];
        if (geometryData is String) {
          points = await compute(_decodePolylineIsolate, geometryData);
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
          preciosCategorias: data['precios_categorias'],
        );
      }
      throw Exception("Error en la respuesta del servidor");
    } catch (e) {
      if (e is DioException && e.response != null) {
        final serverData = e.response?.data;
        if (serverData is Map && serverData['message'] != null) {
          throw serverData['message'];
        }
      }
      throw "No se pudo calcular la ruta. Verifica tu conexión.";
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
