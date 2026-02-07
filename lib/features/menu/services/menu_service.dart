import 'dart:async';
import '../../../core/models/trip_model.dart';

class MenuService {
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
  Future<List<TripModel>> getTripHistory() async {
    // Simula una pequeña carga de red
    await Future.delayed(const Duration(milliseconds: 500));

    // Retorna una copia de la lista local.
    // Si no has hecho viajes, devolverá una lista vacía [].
    return [..._localTrips];
  }

  // --- MÉTODO: GUARDAR VIAJE REAL ---
  void addCompletedTrip(String origin, String destination, double price) {
    final newTrip = TripModel(
      id: "REAL-${DateTime.now().millisecondsSinceEpoch}",
      dateRaw: DateTime.now().toIso8601String(),
      origin: origin,
      destination: destination,
      price: price,
      status: "COMPLETED",
    );

    // Lo agregamos al inicio para que salga de primero
    _localTrips.insert(0, newTrip);
  }

  // ===========================================================================
  // 3. BILLETERA
  // ===========================================================================
  Future<Map<String, dynamic>> getWalletBalance() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return {
      "balance": "\$120.500",
      "currency": "COP",
      "cards": ["**** 4242", "**** 1234"],
    };
  }
}
