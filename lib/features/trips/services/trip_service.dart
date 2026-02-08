// lib/features/trips/services/trip_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http; // Descomentar con backend real
import 'package:latlong2/latlong.dart';
import '../../../core/models/user_model.dart';

class TripService {
  // final String _baseUrl = 'http://10.0.2.2:8000/api';

  Future<bool> createTripRequest({
    required User currentUser,
    required LatLng origin,
    required LatLng destination,
    required String originAddress,
    required String destinationAddress,
    required String serviceCategory, // 'STANDARD', 'COMFORT'
    required double estimatedPrice,
    required List<String> passengerIds, // IDs de beneficiarios seleccionados
    required bool includeMyself,
  }) async {
    // 1. CÁLCULO DE ASIENTOS (Input Crítico PDF Pág 4)
    final int requiredSeats = (includeMyself ? 1 : 0) + passengerIds.length;

    // 2. REGLA DE NEGOCIO (PDF Pág 5 - Clasificación)
    // Si puestos > 4, la categoría ES 'VAN', ignorando lo que haya seleccionado el usuario
    String finalServiceLevel = serviceCategory;
    if (requiredSeats > 4) {
      finalServiceLevel = 'VAN';
    }

    // 3. CONSTRUCCIÓN DEL PAYLOAD (Alineado a Diagrama ER)
    final Map<String, dynamic> body = {
      // FK: Quién solicita el viaje (Tabla USERS)
      'requested_by_user_id': currentUser.id,

      // FK: Empresa responsable (Tabla COMPANIES).
      // Si es personal, va null. Si es corporativo, va el UUID.
      'company_id': currentUser.isCorporateMode
          ? currentUser.companyUuid
          : null,

      // FK: Pasajero Principal (Tabla TRIPS - ER exige un ID único aquí)
      'passenger_user_id': currentUser.id,

      // LISTA: Para generar el FUEC (El backend procesará esto aparte para Moviltrack)
      'manifest_passenger_ids': passengerIds,
      'include_requester_in_manifest': includeMyself,

      // Ubicaciones
      'origin_address': originAddress,
      'destination_address': destinationAddress,
      'origin_lat': origin.latitude,
      'origin_lng': origin.longitude,
      'dest_lat': destination.latitude,
      'dest_lng': destination.longitude,

      // Datos Financieros y Operativos
      'estimated_price': estimatedPrice,
      'service_level': finalServiceLevel, // STANDARD | COMFORT | VAN
      'required_seats':
          requiredSeats, // Filtro crítico para búsqueda de vehículos
      'app_mode': currentUser.appMode
          .toString()
          .split('.')
          .last, // PERSONAL | CORPORATE
    };

    try {
      // AQUÍ IRÍA LA LLAMADA HTTP: post('$_baseUrl/trips', body: body)...

      debugPrint("📡 ENVIANDO SOLICITUD DE VIAJE (ER Compliant):");
      debugPrint(jsonEncode(body));

      await Future.delayed(const Duration(seconds: 1)); // Simulación
      return true;
    } catch (e) {
      debugPrint("Error creando viaje: $e");
      return false;
    }
  }
}
