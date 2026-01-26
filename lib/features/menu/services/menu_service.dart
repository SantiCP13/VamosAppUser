import 'dart:async';

class MenuService {
  // Simula GET /api/user/profile
  Future<Map<String, dynamic>> getUserProfile() async {
    await Future.delayed(const Duration(seconds: 1)); // Simula latencia de red
    return {
      "name": "Santi",
      "email": "santi@vamosapp.com",
      "phone": "+57 300 123 4567",
      "rating": 4.8,
      "trips_count": 124,
      "member_since": "Enero 2024",
    };
  }

  // Simula GET /api/user/history
  Future<List<Map<String, dynamic>>> getTripHistory() async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      {
        "id": "TRIP-883",
        "date": "24 Ene, 10:30 AM",
        "destination": "Centro Comercial Andino",
        "price": "\$15.400",
        "status": "Completado", // Completado, Cancelado
      },
      {
        "id": "TRIP-882",
        "date": "22 Ene, 08:15 AM",
        "destination": "Aeropuerto El Dorado",
        "price": "\$45.000",
        "status": "Cancelado",
      },
      {
        "id": "TRIP-881",
        "date": "20 Ene, 06:00 PM",
        "destination": "Oficina WeWork 93",
        "price": "\$12.200",
        "status": "Completado",
      },
    ];
  }

  // Simula GET /api/user/wallet
  Future<Map<String, dynamic>> getWalletBalance() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return {
      "balance": "\$120.500",
      "currency": "COP",
      "cards": ["**** 4242", "**** 1234"],
    };
  }
}
