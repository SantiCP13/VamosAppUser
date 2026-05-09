import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // <--- 1. AGREGAR IMPORT

import '../../../core/network/api_client.dart';
import '../../../core/models/user_model.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/navigation/navigation_service.dart';

// Busca esta línea y cámbiala:
final String baseUrl =
    dotenv.env['API_URL'] ?? 'https://api.vamosapp.com.co/api';

enum AuthResponseStatus {
  active,
  pending,
  underReview,
  rejected,
  revoked,
  incomplete,
  notFound,
  wrongPassword,
  error,
  networkError,
}

class AuthService {
  static final ApiClient _api = ApiClient();
  static bool isTripActive = false; // <--- AGREGAR ESTA LÍNEA

  static User? _currentUser;
  static User? get currentUser => _currentUser;

  // ===========================================================================
  // 1. SESIÓN Y ESTADO
  // ===========================================================================
  static Future<Map<String, dynamic>> checkAccount(
    String email,
    String deviceId,
  ) async {
    try {
      final response = await ApiClient().dio.post(
        '/check-account',
        data: {'email': email, 'device_id': deviceId},
      );
      return response.data['data'];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('El correo no está registrado en VAMOS.');
      }
      throw Exception(
        e.response?.data['message'] ?? 'Error al verificar cuenta',
      );
    }
  }

  static Future<bool> checkAuthStatus() async {
    try {
      final token = await sl<StorageService>().getToken();
      if (token == null) return false;

      _api.dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _api.dio.get('/me');
      if (response.statusCode == 200) {
        // 1. Cargamos el usuario desde el servidor
        _currentUser = User.fromMap(response.data['data']);

        // --- CAMBIO AQUÍ ---
        // 2. Recuperamos la preferencia guardada en el Paso A
        final storedMode = await sl<StorageService>().getAppMode();

        // 3. Si hay algo guardado, se lo imponemos al usuario ignorando el default del server
        if (storedMode != null && _currentUser != null) {
          _currentUser!.appMode = (storedMode == 'CORPORATE')
              ? AppMode.CORPORATE
              : AppMode.PERSONAL;
        }

        return true;
      }
      return false;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        logout();
      }
      return false;
    }
  }

  static Future<bool> tryAutoLogin() async {
    return await checkAuthStatus();
  }

  static Future<void> logout() async {
    try {
      // Avisar al servidor para invalidar el token
      await ApiClient().dio.post('/logout');
    } catch (e) {
      debugPrint("Error avisando al server: $e");
    } finally {
      // 2. CORRECCIÓN: Usar 'final' en lugar de 'const'
      final storage = FlutterSecureStorage();
      await storage.delete(key: 'auth_token');

      _currentUser = null;
      isTripActive = false;

      // 3. PATEAR AL USUARIO: Si el contexto no está disponible, usamos el NavigatorService
      NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String deviceId,
    required String deviceName,
  }) async {
    try {
      final response = await ApiClient().dio.post(
        '/login',
        data: {
          'email': email,
          'password': password,
          'device_id': deviceId,
          'device_name': deviceName,
        },
      );

      if (response.data['success'] == true) {
        final userData = response.data['data']['user'];
        final token = response.data['data']['token'];
        _currentUser = User.fromMap(userData);

        // --- ENROLAMIENTO DE SEGURIDAD (IGUAL A DRIVER) ---
        // --- ENROLAMIENTO DE SEGURIDAD ACTUALIZADO ---
        final storage = sl<StorageService>();
        await storage.saveToken(token);

        // Guardamos la contraseña asociada a este correo específico
        await storage.saveAccountPassword(email, password);
        // Guardamos que este es el último correo usado para el pre-fill
        await storage.saveLastEmail(email);

        await storage.setBiometricEnabled(true);

        return {'status': AuthResponseStatus.active, 'user': _currentUser};
      }
      return {'status': AuthResponseStatus.error};
    } on DioException catch (e) {
      // Manejo de errores real del servidor
      if (e.response != null && e.response?.data != null) {
        final data = e.response!.data;
        if (e.response!.statusCode == 403 || e.response!.statusCode == 422) {
          // Si el servidor rechaza, limpiamos seguridad local por si acaso
          await sl<StorageService>().deleteAll();
        }
        throw Exception(data['message'] ?? "Error de acceso");
      }
      throw Exception("No hay conexión con el servidor");
    }
  }
  // ===========================================================================
  // 2. REGISTRO REAL (CONEXIÓN BACKEND)
  // ===========================================================================

  // lib/features/auth/services/auth_service.dart
  static Future<String?> requestCompanyAffiliation(
    Map<String, dynamic> data,
  ) async {
    try {
      await _api.dio.post('/empresas/afiliar', data: data);
      return null; // Si no hay error, devolvemos null (Éxito)
    } on DioException catch (e) {
      // Capturamos el mensaje real del servidor (ej: "El correo ya existe")
      if (e.response != null && e.response!.data['message'] != null) {
        return e.response!.data['message'];
      }
      return "Error inesperado en el servidor";
    } catch (e) {
      return "Error de conexión";
    }
  }

  static Future<bool> registerUserAccount({
    required Map<String, dynamic> datos,
    File? cedulaPdf,
    File? selfie,
  }) async {
    try {
      // 1. Creamos el mapa base sin campos nulos
      Map<String, dynamic> body = {
        'nombre': datos['nombre'],
        'email': datos['email'],
        'password': datos['password'],
        'password_confirmation': datos['password'],
        'documento': datos['documento'],
        'tipo_documento': datos['tipo_documento'],
        'telefono': datos['telefono'],
        'direccion': datos['direccion'] ?? '',
        'role': datos['role'] ?? 2,
      };

      // 2. Solo agregamos la empresa si existe
      if (datos['empresa_id'] != null) {
        body['empresa'] = datos['empresa_id'];
      }

      FormData formData = FormData.fromMap(body);

      // 3. Adjuntamos archivos con nombres seguros
      if (cedulaPdf != null) {
        formData.files.add(
          MapEntry(
            'cedula_pdf',
            await MultipartFile.fromFile(
              cedulaPdf.path,
              filename: 'documento.pdf',
            ),
          ),
        );
      }

      if (selfie != null) {
        formData.files.add(
          MapEntry(
            'selfie',
            await MultipartFile.fromFile(selfie.path, filename: 'selfie.jpg'),
          ),
        );
      }

      final response = await ApiClient().dio.post('/register', data: formData);

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Log para debug
        debugPrint("Respuesta del servidor: ${response.data}");

        if (response.data['data'] != null &&
            response.data['data']['user'] != null) {
          _currentUser = User.fromMap(response.data['data']['user']);
          return true;
        }
      }
      return false;
    } on DioException catch (e) {
      debugPrint("Error Dio: ${e.response?.data}");
      final msg = e.response?.data['message'] ?? "Error en validación";
      throw Exception(msg);
    } catch (e) {
      debugPrint("Error Inesperado: $e");
      throw Exception("Error al procesar datos del servidor");
    }
  }

  static Future<bool> registerCorporateUser(Map<String, dynamic> datos) =>
      registerUserAccount(datos: datos);

  static Future<bool> registerNaturalUser({
    required Map<String, dynamic> datos,
    File? cedulaPdf,
    File? selfieImage,
  }) {
    return registerUserAccount(
      datos: datos,
      cedulaPdf: cedulaPdf,
      selfie: selfieImage,
    );
  }

  static void _updateUserPreservingMode(Map<String, dynamic> userData) {
    if (_currentUser == null) {
      _currentUser = User.fromMap(userData);
      return;
    }

    // 1. Guardamos el modo en el que está el usuario justo ahora
    final currentAppMode = _currentUser!.appMode;

    // 2. Creamos el nuevo objeto con la info fresca del servidor
    _currentUser = User.fromMap(userData);

    // 3. LE RESTAURAMOS el modo que tenía antes de la actualización
    _currentUser!.appMode = currentAppMode;

    debugPrint(
      "🔄 Usuario actualizado (Modo preservado: ${currentAppMode.name})",
    );
  }
  // ===========================================================================
  // 3. MÉTODOS DE PERFIL Y BENEFICIARIOS
  // ===========================================================================

  static Future<bool> toggleAppMode(bool isTargetCorporate) async {
    if (_currentUser == null) return false;

    if (isTargetCorporate && !_currentUser!.canUseCorporateMode) return false;

    try {
      final String perfilParaBackend = isTargetCorporate
          ? 'CORPORATIVO'
          : 'NATURAL';

      final response = await ApiClient().dio.post(
        '/user/cambiar-perfil',
        data: {'perfil': perfilParaBackend},
      );

      if (response.data['success'] == true) {
        // --- CAMBIO AQUÍ ---
        // 1. Actualizamos el objeto en memoria
        _currentUser!.appMode = isTargetCorporate
            ? AppMode.CORPORATE
            : AppMode.PERSONAL;

        // 2. GUARDAMOS la preferencia localmente para que no se pierda
        final String modoParaDisco = isTargetCorporate
            ? 'CORPORATE'
            : 'PERSONAL';
        await sl<StorageService>().saveAppMode(modoParaDisco);

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> activateNaturalProfile() async {
    if (_currentUser == null) {
      return false;
    }
    _currentUser!.appMode = AppMode.PERSONAL;
    return true;
  }

  static Future<bool> updateUserAddress({
    required String type,
    required String address,
    required double lat,
    required double lng,
  }) async {
    if (_currentUser == null) return false;
    try {
      final response = await ApiClient().dio.post(
        '/user/favoritos',
        data: {
          'tipo': type,
          'address': address,
          'lat': lat,
          'lng': lng,
          'snapped_lat': lat,
          'snapped_lng': lng,
        },
      );

      if (response.statusCode == 200 && response.data['user'] != null) {
        // --- CAMBIO AQUÍ: Usamos el nuevo escudo en lugar de User.fromMap directo ---
        _updateUserPreservingMode(response.data['user']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeBeneficiary(String id) async {
    if (_currentUser == null) return false;

    try {
      // 1. Avisar al servidor para que lo borre de la DB
      final response = await ApiClient().dio.delete('/beneficiarios/$id');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // 2. Si el servidor confirma, lo borramos de la lista local
        _currentUser!.beneficiaries.removeWhere((b) => b.id == id);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error al borrar beneficiario: $e");
      return false;
    }
  }

  static Future<bool> addBeneficiary(
    String name,
    String doc,
    String type,
  ) async {
    if (_currentUser == null) return false;

    try {
      // LLAMADA REAL AL BACKEND
      final response = await ApiClient().dio.post(
        '/beneficiarios',
        data: {
          'nombre_completo': name,
          'numero_documento': doc,
          'tipo_documento': type, // <--- Enviamos el tipo real
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Si el servidor confirma el guardado, lo agregamos a la lista local
        // Usamos los datos que nos devuelve el servidor (incluyendo el ID real)
        final newBen = Beneficiary.fromJson(response.data['data']);

        _currentUser!.beneficiaries.add(newBen);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error al guardar beneficiario en BD: $e");
      return false;
    }
  }

  static Future<bool> updateUserProfile({
    required String name,
    required String phone,
    required String email,
    File? imageFile, // Cambiamos String? photoUrl por File? imageFile
  }) async {
    try {
      // Para enviar archivos, usamos FormData
      FormData formData = FormData.fromMap({
        'name': name,
        'phone': phone,
        'email': email,
        if (imageFile != null)
          'photo': await MultipartFile.fromFile(
            imageFile.path,
            filename: 'profile_picture.jpg',
          ),
      });

      final response = await _api.dio.post('/me/update', data: formData);

      if (response.data['status'] == 'success' ||
          response.data['success'] == true) {
        _currentUser = User.fromJson(response.data['user']);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error en AuthService: $e");
      return false;
    }
  }

  static Future<String?> uploadProfileImage(String path) async {
    return "https://i.pravatar.cc/300";
  }

  // ===========================================================================
  // 4. BÚSQUEDA Y EMPRESAS
  // ===========================================================================

  static Future<List<Map<String, String>>> searchCompanies(String query) async {
    try {
      final response = await ApiClient().dio.get('/empresas');
      final List data = response.data['data'];
      return data
          .map(
            (e) => {
              'id': e['id'].toString(),
              'name': e['name'].toString(),
              'nit': e['nit'].toString(),
            },
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, String>>> getAvailableCompanies() async {
    return await searchCompanies("");
  }

  static Future<bool> verifyAndLinkCompanyFromBackend({
    required String nit,
    required String companyName,
  }) async {
    try {
      final response = await ApiClient().dio.post(
        '/empresas/vincular-usuario',
        data: {'nit': nit, 'documento': _currentUser?.documentNumber},
      );

      if (response.data['success'] == true) {
        // --- CAMBIO AQUÍ: Usamos el escudo ---
        _updateUserPreservingMode(response.data['data']['user']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  // ===========================================================================
  // 5. CONTRASEÑAS
  // ===========================================================================

  static Future<void> sendPasswordResetCode(String email) async =>
      await ApiClient().dio.post('/password/email', data: {'email': email});

  static Future<void> verifyPasswordResetCode(
    String email,
    String code,
  ) async => await ApiClient().dio.post(
    '/password/code/check',
    data: {'email': email, 'code': code},
  );

  static Future<void> resetPassword(
    String email,
    String code,
    String password,
  ) async => await ApiClient().dio.post(
    '/password/reset',
    data: {
      'email': email,
      'code': code,
      'password': password,
      'password_confirmation': password,
    },
  );
  static void updateLocalUser(Map<String, dynamic> userData) {
    // Usamos fromMap para convertir el JSON del servidor en un objeto User
    _currentUser = User.fromMap(userData);
    debugPrint("Usuario actualizado localmente: ${_currentUser?.homeAddress}");
  }
}
