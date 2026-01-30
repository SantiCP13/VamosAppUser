import 'package:flutter/foundation.dart';

// Enum para manejar estados de respuesta de forma limpia
enum AuthStatus {
  active,
  pending,
  rejected,
  revoked, // Estado para usuarios bloqueados/despedidos
  notFound,
  wrongPassword,
  error,
}

class AuthService {
  // Simulación de base de datos local
  static Map<String, dynamic> currentUser = {};

  // Base de datos simulada de usuarios con sus estados
  static final List<Map<String, dynamic>> _dbUsuarios = [
    {
      'email': 'admin@vamos.com',
      'password': '123',
      'status': 'ACTIVE',
      'nombre': 'Admin',
      'empresa': 'VAMOS Internal',
    },
    {
      'email': 'empleado@bancolombia.com',
      'password': '123',
      'status': 'PENDING', // Usuario esperando aprobación
      'nombre': 'Empleado Nuevo',
      'empresa': 'Bancolombia S.A.',
    },
    // --- USUARIO NUEVO PARA PRUEBAS (REVOCADO) ---
    {
      'email': 'ex_empleado@bancolombia.com',
      'password': '123',
      'status': 'REVOKED', // <--- Este usuario ya no tiene acceso
      'nombre': 'Juan Despedido',
      'empresa': 'Bancolombia S.A.',
    },
  ];

  static final List<String> _emailsRegistrados = ['hola@vamos.com'];

  // Simulación: Dominios permitidos
  static final Map<String, String> _dominiosCorporativos = {
    'bancolombia.com': 'Bancolombia S.A.',
    'argos.co': 'Grupo Argos',
    'vamos.com': 'VAMOS App Internal',
    'tech.co': 'Tech Solutions',
  };

  // ---------------------------------------------------------------------------
  // 1. MÉTODOS DE VALIDACIÓN Y LOGIN
  // ---------------------------------------------------------------------------

  static Future<bool> checkEmailExists(String email) async {
    await Future.delayed(const Duration(milliseconds: 800));
    // Revisa tanto en la lista simple como en la DB compleja
    bool inSimpleList = _emailsRegistrados.contains(email);
    bool inDb = _dbUsuarios.any((u) => u['email'] == email);
    return inSimpleList || inDb;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(seconds: 1));

    try {
      final user = _dbUsuarios.firstWhere(
        (u) => u['email'] == email,
        orElse: () => {},
      );

      if (user.isEmpty) {
        // Fallback para usuarios simples (legacy)
        if (_emailsRegistrados.contains(email) && password == "123") {
          return {'status': AuthStatus.active};
        }
        return {'status': AuthStatus.notFound};
      }

      if (user['password'] != password) {
        return {'status': AuthStatus.wrongPassword};
      }

      final String estadoDb = user['status'];

      // --- MANEJO DE ESTADOS ---
      if (estadoDb == 'PENDING') {
        return {'status': AuthStatus.pending, 'empresa': user['empresa']};
      } else if (estadoDb == 'REJECTED') {
        return {'status': AuthStatus.rejected};
      } else if (estadoDb == 'REVOKED') {
        return {'status': AuthStatus.revoked}; // <--- Retorna estado revocado
      }

      // Si es ACTIVE
      currentUser = user;
      return {'status': AuthStatus.active, 'user': user};
    } catch (e) {
      return {'status': AuthStatus.error};
    }
  }

  // ---------------------------------------------------------------------------
  // 2. MÉTODOS DE SEGURIDAD CORPORATIVA
  // ---------------------------------------------------------------------------

  static Future<String?> checkCorporateDomain(String email) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final parts = email.split('@');
    if (parts.length != 2) return null;

    final domain = parts.last.toLowerCase();

    if (_dominiosCorporativos.containsKey(domain)) {
      return _dominiosCorporativos[domain];
    }
    return null;
  }

  static Future<bool> sendCorporateOTP(String email) async {
    await Future.delayed(const Duration(seconds: 1));
    debugPrint("--- 🔐 OTP ENVIADO A $email : 123456 ---");
    return true;
  }

  static Future<bool> verifyCorporateOTP(String email, String otp) async {
    await Future.delayed(const Duration(seconds: 1));
    return otp == "123456";
  }

  // ---------------------------------------------------------------------------
  // 3. MÉTODOS DE REGISTRO
  // ---------------------------------------------------------------------------

  static Future<bool> registerPassenger(Map<String, dynamic> datos) async {
    await Future.delayed(const Duration(seconds: 2));
    debugPrint("--- NUEVO REGISTRO ---");
    debugPrint("Data: $datos");

    _dbUsuarios.add({
      'email': datos['email'],
      'password': datos['password'],
      'status': datos['tipo_persona'] == 'EMPLEADO' ? 'PENDING' : 'ACTIVE',
      'nombre': datos['nombre'],
      'empresa': datos['nombre_empresa'] ?? '',
    });

    _emailsRegistrados.add(datos['email']);

    currentUser = {
      'nombre': datos['nombre'],
      'email': datos['email'],
      'tipo': datos['tipo_persona'],
    };
    return true;
  }

  // ---------------------------------------------------------------------------
  // 4. MÉTODOS DE REFERIDOS
  // ---------------------------------------------------------------------------

  static Future<bool> sendReferralCode(String code) async {
    await Future.delayed(const Duration(seconds: 1));
    if (code.toUpperCase() == "ERROR") return false;
    debugPrint("Referido canjeado: $code");
    return true;
  }

  // ---------------------------------------------------------------------------
  // 5. MÉTODOS DE AFILIACIÓN EMPRESAS
  // ---------------------------------------------------------------------------

  static Future<bool> requestCompanyAffiliation(
    Map<String, dynamic> requestData,
  ) async {
    await Future.delayed(const Duration(seconds: 2));
    debugPrint("--- SOLICITUD EMPRESA RECIBIDA ---");
    debugPrint("Empresa: ${requestData['empresa']['razon_social']}");
    return true;
  }
}
