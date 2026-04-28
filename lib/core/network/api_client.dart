// lib/core/network/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../features/auth/services/auth_service.dart';
import '../navigation/navigation_service.dart';

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
          return handler.next(options);
        },

        // lib/core/network/api_client.dart (InterceptorsWrapper -> onError)
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 403) {
            // 403 es el que envía tu middleware CheckActive

            // 1. Extraemos el mensaje que configuraste en Laravel:
            // "Tu cuenta ha sido desactivada. Contacta al administrador."
            String serverMsg =
                e.response?.data['message'] ??
                'Cuenta inactiva. Contacte a soporte.';

            // 2. Limpiamos la sesión local
            await AuthService.logout();

            // 3. Redirigimos al inicio pasando el mensaje como argumento
            Future.microtask(() {
              NavigationService.navigatorKey.currentState
                  ?.pushNamedAndRemoveUntil(
                    '/', // O la ruta de tu Login/Welcome
                    (route) => false,
                    arguments: serverMsg, // <--- Pasamos el mensaje aquí
                  );
            });
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
