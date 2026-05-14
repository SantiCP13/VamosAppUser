// lib/core/network/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../navigation/navigation_service.dart';
import '../di/injection_container.dart';
import '../services/storage_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['API_URL'] ?? 'https://api.vamosapp.com.co/api',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.path != '/login' &&
              options.path != '/register' &&
              options.path != '/check-account') {
            // Bloquea si no hay token y no es una ruta pública
          }
          return handler.next(options);
        },

        // Busca el bloque onError dentro de ApiClient y reemplázalo por este:
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 403) {
            final serverData = e.response?.data;
            String serverMsg = serverData is Map
                ? serverData['message']?.toString().toLowerCase() ?? ''
                : '';

            // Usamos sl<StorageService>() para acceder al storage
            if (serverMsg.contains('acceso denegado') ||
                serverMsg.contains('inactiva')) {
              await sl<StorageService>().deleteAll();
              NavigationService.navigatorKey.currentState
                  ?.pushNamedAndRemoveUntil('/', (route) => false);
              return;
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;

  String get envType => dotenv.env['ENV_TYPE'] ?? 'PROD';

  bool get shouldAttemptRealConnection =>
      envType == 'HYBRID' || envType == 'PROD';

  Future<void> simulateDelay([int milliseconds = 1500]) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }
}
