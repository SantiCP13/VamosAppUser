import 'dart:async';
import 'dart:io';
import '../../../core/network/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/models/user_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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

  static const _storage = FlutterSecureStorage();
  static User? _currentUser;
  static User? get currentUser => _currentUser;

  // ===========================================================================
  // 1. SESIÓN Y ESTADO
  // ===========================================================================

  static Future<bool> checkAuthStatus() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        return false;
      }

      final response = await ApiClient().dio.get('/me');
      if (response.statusCode == 200) {
        _currentUser = User.fromMap(response.data['data']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> tryAutoLogin() async {
    return await checkAuthStatus();
  }

  static Future<void> logout() async {
    try {
      await ApiClient().dio.post('/logout');
    } catch (_) {}
    _currentUser = null;
    await _storage.delete(key: 'auth_token');
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await ApiClient().dio.post(
        '/login',
        data: {
          'email': email,
          'password': password,
          'device_name': 'user_app_flutter',
        },
      );

      if (response.data['success'] == true) {
        final userData = response.data['data']['user'];
        final token = response.data['data']['token'];
        _currentUser = User.fromMap(userData);
        await _storage.write(key: 'auth_token', value: token);
        return {'status': AuthResponseStatus.active, 'user': _currentUser};
      }
      return {'status': AuthResponseStatus.error};
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        throw Exception(e.response?.data['message'] ?? "Error de datos");
      }
      if (e.response?.statusCode == 403) {
        throw Exception(e.response?.data['message'] ?? "Cuenta inactiva");
      }
      throw Exception("Error de conexión");
    }
  }

  // ===========================================================================
  // 2. REGISTRO REAL (CONEXIÓN BACKEND)
  // ===========================================================================

  // lib/features/auth/services/auth_service.dart

  static Future<bool> requestCompanyAffiliation(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await ApiClient().dio.post(
        '/empresas/afiliar',
        data: {
          'razon_social': payload['empresa']['razon_social'],
          'nit': payload['empresa']['nit'],
          'ciudad': payload['empresa']['ciudad'],
          'direccion': payload['empresa']['direccion'],
          'telefono': payload['empresa']['telefono_corporativo'],
          'correo': payload['empresa']['email_corporativo'],
          'nombre_contacto': payload['contacto_administrativo']['nombre'],
          'cedula_contacto': payload['contacto_administrativo']['cedula'],
        },
      );
      return response.data['success'] == true;
    } on DioException catch (e) {
      final serverMessage = e.response?.data['message'] ?? "Error desconocido";
      throw Exception(serverMessage);
    }
  }

  static Future<bool> registerUserAccount({
    required Map<String, dynamic> datos,
    File? cedulaPdf,
    File? selfie,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'nombre': datos['nombre'],
        'email': datos['email'],
        'password': datos['password'],
        'password_confirmation': datos['password'],
        'documento': datos['documento'],
        'telefono': datos['telefono'],
        'direccion': datos['direccion'] ?? '',
        'role': 2,
        'empresa': datos['empresa_id'],
      });

      if (cedulaPdf != null) {
        formData.files.add(
          MapEntry('cedula_pdf', await MultipartFile.fromFile(cedulaPdf.path)),
        );
      }

      if (selfie != null) {
        formData.files.add(
          MapEntry('selfie', await MultipartFile.fromFile(selfie.path)),
        );
      }

      final response = await ApiClient().dio.post('/register', data: formData);
      if (response.statusCode == 201 && response.data['data'] != null) {
        _currentUser = User.fromMap(response.data['data']['user']);
        return true;
      }
      return false;
    } on DioException catch (e) {
      final msg = e.response?.data['message'] ?? "Error en el servidor";
      throw Exception(msg);
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

  // ===========================================================================
  // 3. MÉTODOS DE PERFIL Y BENEFICIARIOS
  // ===========================================================================

  static Future<bool> toggleAppMode(bool isTargetCorporate) async {
    if (_currentUser == null) return false;

    // 1. Verificación local rápida
    if (isTargetCorporate && !_currentUser!.canUseCorporateMode) {
      return false;
    }

    try {
      // 2. Avisar al Backend
      final String perfilParaBackend = isTargetCorporate
          ? 'CORPORATIVO'
          : 'NATURAL';

      final response = await ApiClient().dio.post(
        '/user/cambiar-perfil',
        data: {'perfil': perfilParaBackend},
      );

      if (response.data['success'] == true) {
        // 3. Actualizar el modelo local si el servidor confirmó
        _currentUser!.appMode = isTargetCorporate
            ? AppMode.CORPORATE
            : AppMode.PERSONAL;

        // Guardar preferencia localmente
        await _storage.write(
          key: 'preferred_mode',
          value: _currentUser!.appMode.name,
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error al cambiar de modo: $e");
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
        // IMPORTANTE: Actualizamos el usuario local con la nueva info
        // Suponiendo que el backend devuelve el objeto user actualizado
        _currentUser = User.fromMap(response.data['data']['user']);
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
