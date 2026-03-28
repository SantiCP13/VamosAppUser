import '../../../core/network/api_client.dart';

class SearchService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.length < 3) return [];

    try {
      final response = await _apiClient.dio.get(
        '/lugares/buscar',
        queryParameters: {'q': query},
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error en búsqueda: $e");
    }
    return [];
  }
}
