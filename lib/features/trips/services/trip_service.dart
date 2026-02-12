import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'dart:developer' as developer;

import '../../../core/network/api_client.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/passenger_model.dart'; // <--- Importar nuevo modelo

class TripService {
  final ApiClient _api = ApiClient();

  /// SOLICITAR UN NUEVO VIAJE (CORREGIDO PARA FUEC)
  Future<bool> createTripRequest({
    required User currentUser,
    required LatLng origin,
    required LatLng destination,
    required String originAddress,
    required String destinationAddress,
    required String serviceCategory,
    required double estimatedPrice,
    required List<Passenger>
    passengers, // <--- CAMBIO CRÍTICO: Recibe objetos completos
    required bool includeMyself,
  }) async {
    // 1. CÁLCULO DE ASIENTOS
    final int requiredSeats = (includeMyself ? 1 : 0) + passengers.length;

    String finalServiceLevel = serviceCategory;
    if (requiredSeats > 4) {
      finalServiceLevel = 'VAN';
      developer.log(
        "🚍 Categoría forzada a VAN ($requiredSeats pax)",
        name: 'TRIP_LOGIC',
      );
    }

    // 2. CONSTRUCCIÓN DEL MANIFIESTO
    // Serializamos la lista de objetos Passenger a JSON para el backend
    final List<Map<String, dynamic>> manifestData = passengers
        .map((p) => p.toJson())
        .toList();

    // Si el usuario solicitante se incluye, debemos asegurarnos que el backend tenga su cédula.
    // Asumimos que el backend toma la cédula del currentUser de su perfil,
    // pero idealmente deberíamos enviarla si no está garantizada en BD.

    final Map<String, dynamic> body = {
      'requested_by_user_id': currentUser.id,
      'company_id': currentUser.isCorporateMode
          ? currentUser.companyUuid
          : null,

      // Enviamos el Array estructurado, NO una lista plana de IDs
      'manifest_passengers': manifestData,

      'include_requester_in_manifest': includeMyself,
      'origin_address': originAddress,
      'destination_address': destinationAddress,
      'origin_lat': origin.latitude,
      'origin_lng': origin.longitude,
      'dest_lat': destination.latitude,
      'dest_lng': destination.longitude,
      'estimated_price': estimatedPrice,
      'service_level': finalServiceLevel,
      'required_seats': requiredSeats,
      'app_mode': currentUser.appMode.name, // 'PERSONAL' o 'CORPORATE'
    };

    // 3. CONEXIÓN (Sin cambios mayores, solo validación del payload)
    if (_api.shouldAttemptRealConnection) {
      try {
        final response = await _api.dio.post('/trips', data: body);
        if (response.statusCode == 200 || response.statusCode == 201) {
          developer.log("✅ Viaje creado (Backend Real)", name: 'TRIP_SERVICE');
          return true;
        }
      } catch (e) {
        developer.log("⚠️ Falló conexión Backend: $e", name: 'TRIP_SERVICE');
        if (_api.envType == 'PROD') return false;
      }
    }

    developer.log('🕵️ [PAYLOAD FINAL FUEC]', name: 'CHECK_DATA');
    debugPrint(const JsonEncoder.withIndent('  ').convert(body));

    return _simulateSuccessfulTripCreation(body);
  }

  Future<bool> _simulateSuccessfulTripCreation(
    Map<String, dynamic> body,
  ) async {
    await _api.simulateDelay(2000);
    return true;
  }
}
