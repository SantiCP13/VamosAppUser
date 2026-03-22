// lib/features/auth/services/auth_service.dart

import 'dart:async';
import 'dart:io';
import '../../../core/network/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/models/user_model.dart';
import 'package:dio/dio.dart';

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
          'cedula_contacto':
              payload['contacto_administrativo']['cedula'], // 🔥 Verifica que aquí diga 'cedula'
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

  static bool toggleAppMode(bool isTargetCorporate) {
    if (_currentUser == null) {
      return false;
    }
    _currentUser!.appMode = isTargetCorporate
        ? AppMode.CORPORATE
        : AppMode.PERSONAL;
    return true;
  }

  static Future<bool> activateNaturalProfile() async {
    if (_currentUser == null) {
      return false;
    }
    _currentUser!.appMode = AppMode.PERSONAL;
    return true;
  }

  static Future<void> removeBeneficiary(String id) async {
    if (_currentUser == null) {
      return;
    }
    _currentUser!.beneficiaries.removeWhere((b) => b.id == id);
  }

  static Future<bool> addBeneficiary(String name, String docId) async {
    if (_currentUser == null) {
      return false;
    }
    final newBen = Beneficiary(
      id: DateTime.now().toString(),
      name: name,
      documentNumber: docId,
    );
    _currentUser!.beneficiaries.add(newBen);
    return true;
  }

  static Future<bool> updateUserProfile({
    String? name,
    String? phone,
    String? email,
    String? photoUrl,
  }) async {
    return true;
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
    return true;
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
}
