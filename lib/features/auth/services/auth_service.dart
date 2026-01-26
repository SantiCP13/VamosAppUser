// lib/features/auth/services/auth_service.dart
import 'package:flutter/foundation.dart';

class AuthService {
  // --- SIMULACIÓN DE SESIÓN (Persistencia en memoria) ---
  static Map<String, dynamic> currentUser = {
    'nombre': 'Usuario Invitado',
    'email': 'usuario@vamos.com',
    'telefono': '+57 000 000 0000',
    'verificado': true,
  };

  static final List<String> _emailsRegistrados = [
    'hola@vamos.com',
    'admin@test.com',
  ];

  static Future<bool> checkEmailExists(String email) async {
    await Future.delayed(const Duration(seconds: 1));
    return _emailsRegistrados.contains(email);
  }

  static Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    // Simulamos cargar datos del backend al loguear
    currentUser = {
      'nombre': 'Santi Castillo', // Esto vendría de la DB
      'email': email,
      'telefono': '+55 3167970360',
      'verificado': true,
    };
    return true;
  }

  static Future<bool> register(Map<String, dynamic> datos) async {
    await Future.delayed(const Duration(seconds: 2));
    debugPrint("--- ENVIANDO A LARAVEL ---");
    debugPrint("Datos: $datos");

    // GUARDAMOS LOS DATOS EN MEMORIA PARA MOSTRARLOS EN EL PERFIL
    String nombre = datos['tipo_persona'] == 'JURIDICA'
        ? datos['contratante']['nombre'] // Razón social
        : datos['contratante']['nombre']; // Nombre persona

    currentUser = {
      'nombre': nombre,
      'email': datos['email'],
      'telefono': datos['contratante']['telefono'],
      'verificado': false, // Recién registrado
    };

    _emailsRegistrados.add(datos['email']);
    return true;
  }

  static Future<bool> sendReferralCode(String code) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}
