// lib/features/auth/services/auth_service.dart

import 'package:flutter/foundation.dart';
import '../../../core/models/user_model.dart';

enum AuthResponseStatus {
  active,
  pending,
  rejected,
  revoked,
  incomplete,
  notFound,
  wrongPassword,
  error,
}

class AuthService {
  static User? _currentUser;
  static User? get currentUser => _currentUser;

  // Mock DB con un usuario demo corregido
  // Mock DB con TODOS los escenarios posibles para QA
  static final List<Map<String, dynamic>> _dbUsuarios = [
    // ---------------------------------------------------------
    // CASO 1: Usuario NATURAL Verificado (Happy Path B2C)
    // - Puede pedir viajes personales.
    // - NO ve el switch corporativo.
    // ---------------------------------------------------------
    {
      'id': 'user_natural_01',
      'email': 'natural@test.com',
      'password': '123',
      'status': 'VERIFIED',
      'nombre': 'Ana Natural',
      'telefono': '3001111111',
      'empresa': '',
      'role': 'NATURAL',
      'beneficiaries': [], // Sin beneficiarios extra
    },

    // ---------------------------------------------------------
    // CASO 2: Usuario CORPORATIVO Verificado (Happy Path B2B)
    // - Tiene switch Personal/Corporativo habilitado.
    // - En modo Corporativo activa lógica FUEC.
    // ---------------------------------------------------------
    {
      'id': 'user_corp_01',
      'email': 'corp@test.com',
      'password': '123',
      'status': 'VERIFIED',
      'nombre': 'Carlos Ejecutivo',
      'telefono': '3002222222',
      'empresa': 'Tech Solutions S.A.S',
      'role': 'EMPLEADO',
      'beneficiaries': [
        // Simulamos un compañero o familiar registrado
        {'id': 'ben_001', 'name': 'Hijo de Carlos', 'documentNumber': '102030'},
      ],
    },

    // ---------------------------------------------------------
    // CASO 3: Usuario PENDIENTE (Recién registrado / En revisión)
    // - Debe redirigir a pantalla de "Esperando Aprobación".
    // ---------------------------------------------------------
    {
      'id': 'user_pending_01',
      'email': 'pendiente@test.com',
      'password': '123',
      'status': 'UNDER_REVIEW',
      'nombre': 'Pedro Pendiente',
      'telefono': '3003333333',
      'empresa': '',
      'role': 'NATURAL',
      'beneficiaries': [],
    },

    // ---------------------------------------------------------
    // CASO 4: Usuario RECHAZADO (Documentos inválidos)
    // - Debe mostrar error o pantalla de contacto a soporte.
    // ---------------------------------------------------------
    {
      'id': 'user_rejected_01',
      'email': 'rechazado@test.com',
      'password': '123',
      'status': 'REJECTED',
      'nombre': 'Roberto Rechazado',
      'telefono': '3004444444',
      'empresa': '',
      'role': 'NATURAL',
      'beneficiaries': [],
    },

    // ---------------------------------------------------------
    // CASO 5: Usuario REVOCADO (Baneado/Ex-empleado)
    // - Acceso denegado totalmente.
    // ---------------------------------------------------------
    {
      'id': 'user_revoked_01',
      'email': 'bloqueado@test.com',
      'password': '123',
      'status': 'REVOKED',
      'nombre': 'Maria Bloqueada',
      'telefono': '3005555555',
      'empresa': 'Empresa X',
      'role': 'NATURAL',
      'beneficiaries': [],
    },

    // ---------------------------------------------------------
    // CASO 6: Usuario INCOMPLETO (Creó cuenta pero no subió docs)
    // - Debe redirigir al flujo de onboarding/subida de fotos.
    // ---------------------------------------------------------
    {
      'id': 'user_incomplete_01',
      'email': 'nuevo@test.com',
      'password': '123',
      'status': 'DOCS_UPLOADED', // O 'DOCS_UPLOADED' dependiendo de tu lógica
      'nombre': 'Nuevo Usuario',
      'telefono': '3006666666',
      'empresa': '',
      'role': 'NATURAL',
      'beneficiaries': [],
    },
  ];

  static final List<String> _emailsRegistrados = ['hola@vamos.com'];

  // --- LOGIN ---
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(seconds: 1));
    try {
      final userMap = _dbUsuarios.firstWhere(
        (u) => u['email'] == email,
        orElse: () => {},
      );

      if (userMap.isEmpty) return {'status': AuthResponseStatus.notFound};
      if (userMap['password'] != password) {
        return {'status': AuthResponseStatus.wrongPassword};
      }

      final tempUser = User.fromMap(userMap);
      _currentUser = tempUser;

      switch (tempUser.verificationStatus) {
        case UserVerificationStatus.VERIFIED:
          return {'status': AuthResponseStatus.active, 'user': tempUser};
        case UserVerificationStatus.UNDER_REVIEW:
          return {
            'status': AuthResponseStatus.pending,
            'empresa': tempUser.empresa,
          };
        case UserVerificationStatus.CREATED:
        case UserVerificationStatus.DOCS_UPLOADED:
          return {'status': AuthResponseStatus.incomplete};
        case UserVerificationStatus.REJECTED:
          return {'status': AuthResponseStatus.rejected};
        case UserVerificationStatus.REVOKED:
          return {'status': AuthResponseStatus.revoked};
      }
    } catch (e) {
      debugPrint("Error Login: $e");
      return {'status': AuthResponseStatus.error};
    }
  }

  // --- REGISTRO ---
  static Future<bool> registerPassenger(Map<String, dynamic> datos) async {
    await Future.delayed(const Duration(seconds: 2));

    // Lógica de estado inicial
    String statusStr;
    if (datos['tipo_persona'] == 'EMPLEADO') {
      statusStr = 'UNDER_REVIEW';
    } else {
      // Usuario natural recién registrado con documentos enviados -> REVISIÓN
      statusStr = 'UNDER_REVIEW';
    }

    // CORRECCIÓN CRÍTICA: Generar ID único simulado
    final String newId = DateTime.now().millisecondsSinceEpoch.toString();

    final newUserMap = {
      'id': newId,
      'email': datos['email'],
      'password': datos['password'],
      'status': statusStr,
      'nombre': datos['nombre'],
      'telefono': datos['telefono'],
      'empresa': datos['nombre_empresa'] ?? '',
      'role': datos['tipo_persona'] == 'EMPLEADO' ? 'EMPLEADO' : 'NATURAL',
      'beneficiaries': [],
    };

    _dbUsuarios.add(newUserMap);

    try {
      _currentUser = User.fromMap(newUserMap);
      debugPrint(
        "Usuario registrado exitosamente: ${_currentUser?.id} - ${_currentUser?.verificationStatus}",
      );
      return true;
    } catch (e) {
      debugPrint("Error creando objeto User en registro: $e");
      return false;
    }
  }

  // --- OTROS MÉTODOS EXISTENTES (Sin cambios mayores) ---
  static Future<bool> checkEmailExists(String email) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _dbUsuarios.any((u) => u['email'] == email) ||
        _emailsRegistrados.contains(email);
  }

  static Future<bool> sendPhoneOTP(String phoneNumber) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  static Future<bool> verifyPhoneOTP(String phoneNumber, String code) async {
    await Future.delayed(const Duration(seconds: 1));
    return code == "555555";
  }

  static Future<bool> uploadIdentityDocuments({
    required String frontIdPath,
    required String backIdPath,
    required String selfiePath,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    return true;
  }

  static bool toggleAppMode(bool isCorporate) {
    if (_currentUser == null) return false;
    if (!_currentUser!.isEmployee && isCorporate) return false;
    _currentUser = _currentUser!.copyWith(
      appMode: isCorporate ? AppMode.CORPORATE : AppMode.PERSONAL,
    );
    return true;
  }

  static Future<bool> addBeneficiary(String name, String docId) async {
    if (_currentUser == null) return false;
    final newBen = Beneficiary(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      documentNumber: docId,
    );
    final updatedList = List<Beneficiary>.from(_currentUser!.beneficiaries)
      ..add(newBen);
    _currentUser = _currentUser!.copyWith(beneficiaries: updatedList);
    return true;
  }

  static Future<void> removeBeneficiary(String id) async {
    if (_currentUser == null) return;
    final updatedList = _currentUser!.beneficiaries
        .where((b) => b.id != id)
        .toList();
    _currentUser = _currentUser!.copyWith(beneficiaries: updatedList);
  }

  static Future<String?> checkCorporateDomain(String email) async {
    if (email.contains('bancolombia')) return 'Bancolombia S.A.';
    return null;
  }

  static Future<bool> requestCompanyAffiliation(
    Map<String, dynamic> data,
  ) async => true;
  static Future<bool> sendCorporateOTP(String email) async => true;
  static Future<bool> verifyCorporateOTP(String e, String o) async =>
      o == "123456";
  static Future<bool> sendReferralCode(String code) async =>
      code.toUpperCase() != "ERROR";
}
