// lib/features/auth/services/auth_service.dart

import 'dart:async';
// ignore: unused_import
import 'dart:convert'; // DESCOMENTAR AL TENER BACKEND REAL
// import 'package:http/http.dart' as http; // DESCOMENTAR AL TENER BACKEND REAL
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/models/user_model.dart';

/// ESTADOS DE RESPUESTA DE AUTENTICACIÓN

/// Normaliza las respuestas del backend para que la UI sepa qué pantalla mostrar.
enum AuthResponseStatus {
  active, // Login exitoso -> Home
  pending, // Email verificado pero faltan datos -> CompleteProfile
  underReview, // Esperando aprobación manual (Aprobación Conductores/Empresas)
  rejected, // Bloqueado
  revoked, // Baneado
  incomplete, // Registro a medias
  notFound, // Usuario no existe
  wrongPassword, // Contraseña incorrecta
  error, // Error genérico
  networkError, // Sin internet
}

/// SERVICIO DE AUTENTICACIÓN (MOCK MVP)

/// Simula el comportamiento del Backend Laravel + Sanctum.
/// Gestiona Login, Registro, Recuperación de contraseña y Sesión.
class AuthService {
  // ===========================================================================
  // CONFIGURACIÓN API
  // ===========================================================================

  // ignore: unused_field

  // static const String _baseUrl = 'http://10.0.2.2:8000/api'; // Descomentar con backend real

  // Almacenamiento seguro para el Token JWT
  static const _storage = FlutterSecureStorage();

  // Usuario en memoria (Sesión actual)
  static User? _currentUser;
  static User? get currentUser => _currentUser;

  // ignore: unused_field
  static String? _token;

  // ===========================================================================
  // 1. BASES DE DATOS MOCK (DATA FALSA PARA MVP)
  // ===========================================================================

  /// SIMULACIÓN TABLA COMPANIES
  ///
  /// Contiene los 'contract_id' necesarios para el FUEC.
  static final List<Map<String, dynamic>> _mockCompaniesDB = [
    // CLIENTES (Corporativos que piden viajes)
    {
      'nit': '890903938',
      'name': 'Bancolombia S.A.',
      'type': 'CLIENT',
      'contract_id': 'AB-100', // Contrato Moviltrack (Vital para PDF FUEC)
    },
    {
      'nit': '800222333',
      'name': 'Ecopetrol',
      'type': 'CLIENT',
      'contract_id': 'AB-200',
    },
    // TRANSPORTADORAS (Dueños de los vehículos - FUEC)
    {
      'nit': '900123456',
      'name': 'Transportes Ejecutivos S.A.S',
      'type': 'PROVIDER',
      'contract_id': 'TRANS-99',
    },
  ];

  /// SIMULACIÓN TABLA USERS (App Usuario)
  ///
  static final List<Map<String, dynamic>> _dbUsuarios = [
    // ESCENARIO 1: Corporativo VERIFICADO (Puede pedir viajes de empresa)
    {
      'id': 'user_corp_active',
      'id_pasajero': null,
      'id_responsable': 'resp_01',
      'email': 'corp@vamos.com',
      'password': '123',
      'nombre': 'Carlos Corporativo',
      'documento': '101',
      'telefono': '3001001001',
      'direccion': 'Oficina Central',
      'empresa': 'Transportes Ejecutivos S.A.S',
      'nit_empresa': '900123456',
      'role': 'EMPLEADO',
      'status': 'VERIFIED',
      'app_mode': 'CORPORATE',
      'beneficiaries': [],
    },
    // ESCENARIO 2: Corporativo PENDIENTE (Registrado, esperando aprobación de RRHH)
    {
      'id': 'user_corp_pending',
      'id_pasajero': null,
      'id_responsable': 'resp_02',
      'email': 'pendiente@vamos.com',
      'password': '123',
      'nombre': 'Pedro Pendiente',
      'documento': '102',
      'telefono': '3001001002',
      'direccion': 'Calle Falsa 123',
      'empresa': 'Bancolombia S.A.',
      'nit_empresa': '890903938',
      'role': 'EMPLEADO',
      'status': 'CREATED', // Aún no verificado
      'app_mode': 'CORPORATE',
      'beneficiaries': [],
    },
    // ESCENARIO 3: Natural VERIFICADO
    {
      'id': 'user_natural_active',
      'id_pasajero': 'pas_03',
      'id_responsable': null,
      'email': 'natural@vamos.com',
      'password': '123',
      'nombre': 'Ana Natural',
      'documento': '103',
      'telefono': '3001001003',
      'direccion': 'Casa 1',
      'empresa': null,
      'nit_empresa': null,
      'role': 'NATURAL',
      'status': 'VERIFIED',
      'app_mode': 'PERSONAL',
      'beneficiaries': [],
    },
    // ESCENARIO 4: Natural EN REVISIÓN
    {
      'id': 'user_natural_review',
      'id_pasajero': 'pas_04',
      'email': 'revision@vamos.com',
      'password': '123',
      'nombre': 'Roberto Revisión',
      'documento': '104',
      'role': 'NATURAL',
      'status': 'UNDER_REVIEW',
      'app_mode': 'PERSONAL',
      'beneficiaries': [],
    },
    // ESCENARIO 5: Rechazado
    {
      'id': 'user_rejected',
      'email': 'rechazado@vamos.com',
      'password': '123',
      'nombre': 'Felipe Fallido',
      'status': 'REJECTED',
      'role': 'NATURAL',
      'beneficiaries': [],
    },
    // ESCENARIO 6: Revocado
    {
      'id': 'user_revoked',
      'email': 'baneado@vamos.com',
      'password': '123',
      'nombre': 'Maria Malportada',
      'status': 'REVOKED',
      'role': 'NATURAL',
      'beneficiaries': [],
    },
  ];

  // ===========================================================================
  // 2. LOGIN (POST /login)
  // ===========================================================================

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      // Simula delay de red
      await Future.delayed(const Duration(seconds: 1));

      // Busca en la "BD" local
      final userMap = _dbUsuarios.firstWhere(
        (u) => u['email'] == email && u['password'] == password,
        orElse: () => {},
      );

      if (userMap.isEmpty) {
        return {'status': AuthResponseStatus.notFound};
      }

      // Crea el objeto User desde el mapa
      final tempUser = User.fromMap(userMap);
      _currentUser = tempUser;

      // Guarda el token (Simulación de Laravel Sanctum)
      await _storage.write(key: 'auth_token', value: 'mock_token_123');

      // Devuelve estado normalizado
      return _mapStatus(tempUser.verificationStatus);
    } catch (e) {
      return {'status': AuthResponseStatus.networkError};
    }
  }

  // ===========================================================================
  // 3. PERSISTENCIA DE SESIÓN
  // ===========================================================================

  static Future<bool> tryAutoLogin() async {
    try {
      final storedToken = await _storage.read(key: 'auth_token');
      if (storedToken == null) return false;

      // Aquí se llamaría a GET /user para validar el token real
      return false; // Retornamos false para forzar login en MVP
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await _storage.delete(key: 'auth_token');
  }

  // ===========================================================================
  // 4. REGISTRO (POST /register)
  // ===========================================================================

  // Registro de EMPLEADO (Requiere validación de NIT Empresa)
  static Future<bool> registerCorporateUser(Map<String, dynamic> datos) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final String newId = DateTime.now().millisecondsSinceEpoch.toString();

      final newUserMap = {
        'id': newId,
        'id_pasajero': null,
        'id_responsable': 'resp_$newId', // Manager ID
        'email': datos['email'],
        'password': datos['password'],
        'nombre': datos['nombre'],
        'documento': datos['documento'], // Vital FUEC
        'telefono': datos['telefono'],
        'direccion': datos['direccion'] ?? 'Dirección Pendiente',
        'empresa': datos['nombre_empresa'],
        'nit_empresa': datos['nit_empresa'], // Vinculación
        'role': 'EMPLEADO',
        'status': 'CREATED',
        'app_mode': 'CORPORATE',
        'beneficiaries': [],
      };

      _dbUsuarios.add(newUserMap);
      _currentUser = User.fromMap(newUserMap);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Registro de USUARIO NATURAL
  static Future<bool> registerNaturalUser(Map<String, dynamic> datos) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final String newId = DateTime.now().millisecondsSinceEpoch.toString();

      final newUserMap = {
        'id': newId,
        'id_pasajero': newId,
        'id_responsable': newId, // Él mismo es su responsable
        'email': datos['email'],
        'password': datos['password'],
        'nombre': datos['nombre'],
        'documento': datos['documento'],
        'telefono': datos['telefono'],
        'direccion': datos['direccion'] ?? 'Dirección Pendiente',
        'empresa': null,
        'nit_empresa': null,
        'role': 'NATURAL',
        'status': 'UNDER_REVIEW', // Pasa a revisión básica
        'app_mode': 'PERSONAL',
        'beneficiaries': [],
      };

      _dbUsuarios.add(newUserMap);
      _currentUser = User.fromMap(newUserMap);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Búsqueda de Empresas para vinculación (Autocompletado por NIT)
  static Future<List<Map<String, String>>> searchCompanies(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (query.isEmpty) {
      return _mockCompaniesDB
          .map(
            (c) => {'nit': c['nit'].toString(), 'name': c['name'].toString()},
          )
          .toList();
    }

    final q = query.toLowerCase();

    return _mockCompaniesDB
        .where(
          (c) =>
              c['name'].toString().toLowerCase().contains(q) ||
              c['nit'].toString().contains(q),
        )
        .map((c) => {'nit': c['nit'].toString(), 'name': c['name'].toString()})
        .toList();
  }

  // Solicitud de Alta de Empresa (Si no existe en la BD)
  static Future<bool> requestCompanyAffiliation(
    Map<String, dynamic> payload,
  ) async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final datosEmpresa = payload['empresa'];
      final String nuevoNit = datosEmpresa['nit'];
      final String nuevaRazonSocial = datosEmpresa['razon_social'];

      final existe = _mockCompaniesDB.any((c) => c['nit'] == nuevoNit);
      if (!existe) {
        // En backend real esto iría a una tabla 'pending_companies'
        _mockCompaniesDB.add({'nit': nuevoNit, 'name': nuevaRazonSocial});
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Validación rápida de NIT (Check existence)
  static Future<String?> validateCompanyNit(String nit) async {
    await Future.delayed(const Duration(milliseconds: 800));
    try {
      final company = _mockCompaniesDB.firstWhere(
        (c) => c['nit'] == nit,
        orElse: () => {},
      );
      return company.isNotEmpty ? company['name'] : null;
    } catch (e) {
      return null;
    }
  }

  // ===========================================================================
  // 5. PERFIL Y UTILIDADES
  // ===========================================================================

  /// CAMBIO DE MODO (PERSONAL <-> CORPORATIVO)

  static bool toggleAppMode(bool isTargetCorporate) {
    if (_currentUser == null) return false;
    _currentUser!.appMode = isTargetCorporate
        ? AppMode.CORPORATE
        : AppMode.PERSONAL;
    return true;
  }

  // Activa el modo personal si solo tenía perfil corporativo
  static Future<bool> activateNaturalProfile() async {
    if (_currentUser == null) return false;
    await Future.delayed(const Duration(milliseconds: 500));

    if (_currentUser!.idPassenger == null) {
      _currentUser!.idPassenger =
          "pas_${DateTime.now().millisecondsSinceEpoch}";
    }

    _currentUser!.appMode = AppMode.PERSONAL;
    return true;
  }

  static Future<bool> updateUserProfile({
    String? name,
    String? phone,
    String? email,
    String? photoUrl,
  }) async {
    if (_currentUser == null) return false;
    // Simula PUT /user/profile
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  static Future<String?> uploadProfileImage(String path) async {
    await Future.delayed(const Duration(seconds: 2));
    // Simula upload a S3/MinIO
    return "https://i.pravatar.cc/300?u=${DateTime.now().millisecondsSinceEpoch}";
  }

  /// GESTIÓN DE BENEFICIARIOS

  static Future<bool> addBeneficiary(String name, String docId) async {
    if (_currentUser == null) return false;
    await Future.delayed(const Duration(milliseconds: 500));

    final newBeneficiary = Beneficiary(
      id: "ben_${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      documentNumber: docId, // Cédula obligatoria
    );
    _currentUser!.beneficiaries.add(newBeneficiary);
    return true;
  }

  static Future<bool> sendReferralCode(String code) async {
    await Future.delayed(const Duration(seconds: 2));
    if (code.toUpperCase() == "ERROR") {
      return false;
    }
    return true;
  }

  static Future<void> removeBeneficiary(String id) async {
    if (_currentUser == null) return;
    _currentUser!.beneficiaries.removeWhere((b) => b.id == id);
  }

  static Future<bool> checkEmailExists(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _dbUsuarios.any((u) => u['email'] == email);
  }

  static Future<List<Map<String, String>>> getAvailableCompanies() async {
    await Future.delayed(const Duration(milliseconds: 800));

    final rawList = [
      {'name': 'Tech Solutions SAS', 'nit': '900123456'},
      {'name': 'Constructora Global', 'nit': '900654321'},
      {'name': 'Servicios Médicos Ltda', 'nit': '800987654'},
      {'name': 'Bancolombia', 'nit': '890903938'},
      {'name': 'Ecopetrol', 'nit': '899999068'},
    ];

    // Convertimos explícitamente
    return rawList.map((e) => Map<String, String>.from(e)).toList();
  }

  /// Simula la verificación y vinculación de un usuario a una empresa
  static Future<bool> verifyAndLinkCompanyFromBackend({
    required String nit,
    required String companyName,
    String?
    backendCompanyId, // <--- AGREGAR ESTO (Simulación del UUID que devuelve el backend)
  }) async {
    await Future.delayed(const Duration(seconds: 2));

    if (nit.endsWith('000')) return false; // Lógica mock de error

    if (_currentUser != null) {
      // Simulación: En un entorno real, el backend te devuelve el ID de la empresa en la tabla COMPANIES
      final String simulatedCompanyUuid =
          backendCompanyId ?? "comp_uuid_${nit}_mock";

      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: _currentUser!.name,
        phone: _currentUser!.phone,
        documentNumber: _currentUser!.documentNumber,
        address: _currentUser!.address,
        photoUrl: _currentUser!.photoUrl,

        // --- CORRECCIÓN CRÍTICA ---
        companyUuid: simulatedCompanyUuid, // <--- AHORA SÍ HAY RELACIÓN FK
        empresa: companyName,
        nitEmpresa: nit,

        role: UserRole.EMPLEADO,
        idResponsable: 'CORP-${DateTime.now().millisecondsSinceEpoch}',
        appMode: AppMode.CORPORATE,
        verificationStatus: _currentUser!.verificationStatus,
        beneficiaries: _currentUser!.beneficiaries,
        idPassenger: _currentUser!.idPassenger,
        token: _currentUser!.token,
      );
    }
    return true;
  }

  // ===========================================================================
  // 6. RECUPERACIÓN DE CONTRASEÑA
  // ===========================================================================

  static Future<bool> sendPasswordRecoveryEmail(String email) async {
    await Future.delayed(const Duration(seconds: 2));
    final userExists = _dbUsuarios.any((u) => u['email'] == email);
    if (!userExists) return false;
    return true;
  }

  static Future<bool> verifyRecoveryToken(String email, String token) async {
    await Future.delayed(const Duration(seconds: 1));
    if (token == "123456") return true;
    return false;
  }

  static Future<bool> changePassword(String email, String newPassword) async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final userIndex = _dbUsuarios.indexWhere((u) => u['email'] == email);
      if (userIndex != -1) {
        _dbUsuarios[userIndex]['password'] = newPassword;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Helper para convertir el Enum de modelo a Estado de respuesta simple
  static Map<String, dynamic> _mapStatus(UserVerificationStatus status) {
    switch (status) {
      case UserVerificationStatus.VERIFIED:
        return {'status': AuthResponseStatus.active, 'user': _currentUser};
      case UserVerificationStatus.PENDING:
        return {'status': AuthResponseStatus.incomplete};
      case UserVerificationStatus.CREATED:
        return {'status': AuthResponseStatus.pending};
      case UserVerificationStatus.UNDER_REVIEW:
      case UserVerificationStatus.DOCS_UPLOADED:
        return {'status': AuthResponseStatus.underReview};
      case UserVerificationStatus.REJECTED:
        return {'status': AuthResponseStatus.rejected};
      case UserVerificationStatus.REVOKED:
        return {'status': AuthResponseStatus.revoked};
    }
  }
}
