import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _biometricEnabledKey = 'use_biometrics';
  static const String _appModeKey = 'preferred_app_mode';

  // Eliminamos la constante fija de password y usamos una dinámica

  final _secureStorage = const FlutterSecureStorage();
  Future<void> saveAppMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appModeKey, mode);
  }

  Future<String?> getAppMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_appModeKey);
  }

  // --- TOKEN (Sesión actual) ---
  Future<void> saveToken(String token) async =>
      await _secureStorage.write(key: _tokenKey, value: token);
  Future<String?> getToken() async => await _secureStorage.read(key: _tokenKey);

  // --- LOGICA MULTI-CUENTA (NUEVO) ---

  // Guarda la contraseña indexada por email
  Future<void> saveAccountPassword(String email, String password) async {
    final key = 'pass_${email.toLowerCase().trim()}';
    await _secureStorage.write(key: key, value: password);
  }

  // Recupera la contraseña de un email específico
  Future<String?> getAccountPassword(String email) async {
    final key = 'pass_${email.toLowerCase().trim()}';
    return await _secureStorage.read(key: key);
  }

  // Borra la contraseña de un email específico (Si el usuario decide no ser recordado)
  Future<void> deleteAccountPassword(String email) async {
    final key = 'pass_${email.toLowerCase().trim()}';
    await _secureStorage.delete(key: key);
  }

  // --- CONFIGURACIÓN GENERAL ---
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  // Limpieza de sesión activa (pero mantiene las contraseñas guardadas en el cel)
  Future<void> deleteSession() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  // Guarda el último correo que inició sesión (para pre-rellenar el formulario)
  Future<void> saveLastEmail(String email) async =>
      await _secureStorage.write(key: 'last_logged_email', value: email);

  // Recupera el último correo usado
  Future<String?> getLastEmail() async =>
      await _secureStorage.read(key: 'last_logged_email');
  Future<void> deleteAll() async {
    await _secureStorage.deleteAll();
    await setBiometricEnabled(false);
  }
}
