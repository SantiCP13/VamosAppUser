import '../../../core/network/api_client.dart'; // Asegúrate que apunte a network/api_client.dart

class HomeService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>?> getActiveTrip() async {
    try {
      // CAMBIO CLAVE: Se usa _api.dio.get en lugar de _api.get
      final response = await _api.dio.get('/viajes/activo');

      if (response.data != null && response.data['status'] == 'success') {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
