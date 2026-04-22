import 'dart:async';
import '../../../core/models/trip_model.dart';
import '../../../core/network/api_client.dart';
import 'package:flutter/foundation.dart';

class MenuService {
  final ApiClient _api = ApiClient();
  // --- MEMORIA TEMPORAL (Solo guarda los viajes hechos en esta sesión) ---
  static final List<TripModel> _localTrips = [];

  // ===========================================================================
  // 1. PERFIL DE USUARIO
  // ===========================================================================
  Future<Map<String, dynamic>> getUserProfile() async {
    await Future.delayed(const Duration(seconds: 1));
    return {
      "name": "Santi",
      "email": "santi@vamosapp.com",
      "phone": "+57 300 123 4567",
      "rating": 5.0, // Rating perfecto para empezar
      // Ahora el contador coincide exactamente con la lista de historial
      "trips_count": _localTrips.length,
      "member_since": "Enero 2024",
    };
  }

  // ===========================================================================
  // 2. HISTORIAL DE VIAJES (Solo Reales)
  // ===========================================================================
  // 2. HISTORIAL DE VIAJES
  Future<List<TripModel>> getTripHistory() async {
    try {
      // 1. Hacemos la petición
      final response = await _api.dio.get('/viajes/historial');

      // 2. DEBUG: Copia lo que salga aquí en la consola para estar seguros
      debugPrint("BODY COMPLETO: ${response.data}");

      if (response.data['status'] == 'success') {
        // 3. LA CLAVE: Acceder a data['data']
        // El primer ['data'] es tu respuesta del controlador.
        // El segundo ['data'] es el array de items del paginador de Laravel.
        final List rawList = response.data['data']['data'];

        return rawList.map((item) => TripModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error en Service: $e");
      return [];
    }
  }

  Future<bool> cancelTrip(String tripId) async {
    try {
      // Llama a la ruta de Laravel que ya configuramos
      final response = await _api.dio.post('/viajes/$tripId/cancelar');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 3. BILLETERA
  Future<Map<String, dynamic>> getWalletBalance() async {
    try {
      // CORRECCIÓN: Usar .dio y luego .data
      final response = await _api.dio.get('/billetera/historial');
      return {"balance": response.data['saldo_actual'] ?? 0, "currency": "COP"};
    } catch (e) {
      return {"balance": 0, "currency": "COP"};
    }
  }

  // --- MÉTODO: GUARDAR VIAJE REAL ---
  void addCompletedTrip(String origin, String destination, double price) {
    final newTrip = TripModel(
      id: "REAL-${DateTime.now().millisecondsSinceEpoch}",
      dateRaw: DateTime.now().toIso8601String(),
      origin: origin,
      destination: destination,
      price: price,
      tolls:
          0.0, // Por ahora, asumimos que no hay peajes en los viajes reales. Esto se puede mejorar luego.
      status: "COMPLETED",
      passengers: [],
    );

    // Lo agregamos al inicio para que salga de primero
    _localTrips.insert(0, newTrip);
  }
}
