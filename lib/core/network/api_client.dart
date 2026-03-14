import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer'
    as developer; // Usaremos developer.log para logs más profesionales

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio _dio;
  final _storage = const FlutterSecureStorage();

  // --- CONFIGURACIÓN DE ENTORNO ---
  String get envType => dotenv.env['ENV_TYPE'] ?? 'MOCK';

  // Helpers booleanos para lógica limpia en Servicios
  bool get isMockOnly => envType == 'MOCK';
  bool get shouldAttemptRealConnection =>
      envType == 'HYBRID' || envType == 'PROD';

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: dotenv.env['API_URL'] ?? 'http://192.168.10.3:8000/api',
        // Tiempos de espera ajustados para redes móviles (3G/4G en Colombia)
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(
          seconds: 10,
        ), // Importante para subida de datos
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Log de salida para depuración visual
          developer.log(
            '🚀 [${options.method}] ${options.path}',
            name: 'API_REQ',
          );

          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          developer.log(
            '✅ [${response.statusCode}] ${response.requestOptions.path}',
            name: 'API_RES',
          );
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          developer.log(
            '❌ API Error [$envType]: ${e.type} - ${e.message}',
            name: 'API_ERR',
          );

          if (e.response?.statusCode == 401) {
            developer.log('⚠️ Sesión expirada o no autorizada', name: 'AUTH');
            // Aquí dispararemos el evento de Logout global más adelante
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;

  /// Método auxiliar para simular latencia de red realista en modo MOCK o Fallback.
  /// Ayuda a probar loaders y estados de carga en la UI.
  Future<void> simulateDelay([int milliseconds = 1500]) async {
    if (isMockOnly || envType == 'HYBRID') {
      await Future.delayed(Duration(milliseconds: milliseconds));
    }
  }
}
