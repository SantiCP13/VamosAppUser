import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/api_client.dart'; // Importamos tu nuevo cliente
import '../../../core/models/user_model.dart';
import 'dart:developer' as developer;

class TripService {
  // Instancia única del cliente API
  final ApiClient _api = ApiClient();

  /// SOLICITAR UN NUEVO VIAJE (HÍBRIDO)
  Future<bool> createTripRequest({
    required User currentUser,
    required LatLng origin,
    required LatLng destination,
    required String originAddress,
    required String destinationAddress,
    required String serviceCategory,
    required double estimatedPrice,
    required List<String> passengerIds,
    required bool includeMyself,
  }) async {
    // 1. LÓGICA DE NEGOCIO (Igual que antes)
    final int requiredSeats = (includeMyself ? 1 : 0) + passengerIds.length;

    String finalServiceLevel = serviceCategory;
    if (requiredSeats > 4) {
      finalServiceLevel = 'VAN';
      developer.log(
        "🚍 Categoría forzada a VAN por capacidad ($requiredSeats)",
        name: 'TRIP_LOGIC',
      );
    }

    // 2. CONSTRUCCIÓN DEL PAYLOAD
    final Map<String, dynamic> body = {
      'requested_by_user_id': currentUser.id,
      'company_id': currentUser.isCorporateMode
          ? currentUser.companyUuid
          : null,
      'passenger_user_id': currentUser.id,
      'manifest_passenger_ids': passengerIds,
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
      'app_mode': currentUser.appMode.name,
    };

    // 3. INTENTO DE CONEXIÓN REAL (Si aplica)
    if (_api.shouldAttemptRealConnection) {
      try {
        // Usamos api.dio para tener los timeouts configurados
        final response = await _api.dio.post('/trips', data: body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          developer.log(
            "✅ Viaje creado exitosamente en Backend Real",
            name: 'TRIP_SERVICE',
          );
          return true;
        }
      } catch (e) {
        developer.log(
          "⚠️ Falló conexión con Backend: $e",
          name: 'TRIP_SERVICE',
        );

        // Si es PROD, el error es fatal. Si es HYBRID, continuamos al fallback.
        if (_api.envType == 'PROD') {
          return false;
        }
      }
    }

    // 4. FALLBACK / MOCK (Simulación)
    // Si llegamos aquí es porque estamos en modo MOCK o falló el modo HYBRID.
    return _simulateSuccessfulTripCreation(body);
  }

  /// Simula una respuesta exitosa del servidor para demos
  Future<bool> _simulateSuccessfulTripCreation(
    Map<String, dynamic> body,
  ) async {
    developer.log(
      "🎭 Ejecutando SIMULACIÓN de Viaje (Fallback)",
      name: 'TRIP_MOCK',
    );

    // Debug visual del payload
    debugPrint("📦 PAYLOAD SIMULADO:");
    debugPrint(const JsonEncoder.withIndent('  ').convert(body));

    // Usamos el delay centralizado del ApiClient para consistencia
    await _api.simulateDelay(2000);

    return true; // Simula éxito siempre
  }
}
