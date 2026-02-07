import 'dart:async';
// ignore: unused_import
import 'dart:convert'; // DESCOMENTAR AL TENER BACKEND (Se usa para jsonEncode)
// import 'package:http/http.dart' as http; // DESCOMENTAR AL TENER BACKEND
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/models/user_model.dart';

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
  // ===========================================================================
  // CONFIGURACIÓN API
  // ===========================================================================

  // ignore: unused_field
  static const String _baseUrl = 'http://10.0.2.2:8000/api';

  static const _storage = FlutterSecureStorage();

  static User? _currentUser;
  static User? get currentUser => _currentUser;

  // ignore: unused_field
  static String? _token;

  // ===========================================================================
  // 1. BASES DE DATOS MOCK (DATA FALSA PARA MVP)
  // ===========================================================================

  static final List<Map<String, String>> _mockCompaniesDB = [
    {'nit': '900123456', 'name': 'Transportes Ejecutivos S.A.S'},
    {'nit': '890903938', 'name': 'Bancolombia S.A.'},
    {'nit': '800222333', 'name': 'Ecopetrol'},
    {'nit': '111222333', 'name': 'Vamos App Demo'},
  ];

  static final List<Map<String, dynamic>> _dbUsuarios = [
    // ESCENARIO 1: Corporativo VERIFICADO
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
    // ESCENARIO 2: Corporativo PENDIENTE
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
      'status': 'CREATED',
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
    // ESCENARIO 6: Revocado (Baneado)
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
  // 2. LOGIN
  // ===========================================================================

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      // ----------------------------------------------------
      // [OPCIÓN A] CONEXIÓN REAL A LARAVEL
      // ----------------------------------------------------
      /*
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token']; 
        await _storage.write(key: 'auth_token', value: _token);

        _currentUser = User.fromMap(data['user']);
        return _mapStatus(_currentUser!.verificationStatus);
      } 
      */

      // ----------------------------------------------------
      // [OPCIÓN B] MOCK ACTUAL
      // ----------------------------------------------------
      await Future.delayed(const Duration(seconds: 1));

      final userMap = _dbUsuarios.firstWhere(
        (u) => u['email'] == email && u['password'] == password,
        orElse: () => {},
      );

      if (userMap.isEmpty) {
        return {'status': AuthResponseStatus.notFound};
      }

      final tempUser = User.fromMap(userMap);
      _currentUser = tempUser;

      await _storage.write(key: 'auth_token', value: 'mock_token_123');

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

      // ----------------------------------------------------
      // [OPCIÓN A] VALIDAR TOKEN CON LARAVEL
      // ----------------------------------------------------
      /*
      final response = await http.get(
        Uri.parse('$_baseUrl/user'),
        headers: {
          'Authorization': 'Bearer $storedToken',
          // ...
        },
      );
      if (response.statusCode == 200) return true;
      */

      return false; // Retornamos false para probar MVP
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
  // 4. REGISTRO NATURAL Y CORPORATIVO
  // ===========================================================================

  static Future<bool> registerCorporateUser(Map<String, dynamic> datos) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final String newId = DateTime.now().millisecondsSinceEpoch.toString();
      final newUserMap = {
        'id': newId,
        'id_pasajero': null,
        'id_responsable': 'resp_$newId',
        'email': datos['email'],
        'password': datos['password'],
        'nombre': datos['nombre'],
        'documento': datos['documento'],
        'telefono': datos['telefono'],
        'direccion': datos['direccion'],
        'empresa': datos['nombre_empresa'],
        'nit_empresa': datos['nit_empresa'],
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

  static Future<bool> registerNaturalUser(Map<String, dynamic> datos) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final String newId = DateTime.now().millisecondsSinceEpoch.toString();
      final newUserMap = {
        'id': newId,
        'id_pasajero': newId,
        'id_responsable': newId,
        'email': datos['email'],
        'password': datos['password'],
        'nombre': datos['nombre'],
        'documento': datos['documento'],
        'telefono': datos['telefono'],
        'direccion': datos['direccion'],
        'empresa': null,
        'nit_empresa': null,
        'role': 'NATURAL',
        'status': 'UNDER_REVIEW',
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

  static Future<List<Map<String, String>>> searchCompanies(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (query.isEmpty) {
      return _mockCompaniesDB;
    }
    final q = query.toLowerCase();
    return _mockCompaniesDB
        .where(
          (c) => c['name']!.toLowerCase().contains(q) || c['nit']!.contains(q),
        )
        .toList();
  }

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
        _mockCompaniesDB.add({'nit': nuevoNit, 'name': nuevaRazonSocial});
      }
      return true;
    } catch (e) {
      return false;
    }
  }

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

  static bool toggleAppMode(bool isTargetCorporate) {
    if (_currentUser == null) return false;
    _currentUser!.appMode = isTargetCorporate
        ? AppMode.CORPORATE
        : AppMode.PERSONAL;
    return true;
  }

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
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  static Future<String?> uploadProfileImage(String path) async {
    await Future.delayed(const Duration(seconds: 2));
    return "https://i.pravatar.cc/300?u=${DateTime.now().millisecondsSinceEpoch}";
  }

  static Future<bool> addBeneficiary(String name, String docId) async {
    if (_currentUser == null) return false;
    await Future.delayed(const Duration(milliseconds: 500));
    final newBeneficiary = Beneficiary(
      id: "ben_${DateTime.now().millisecondsSinceEpoch}",
      name: name,
      documentNumber: docId,
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
    // Simular delay de red
    await Future.delayed(const Duration(milliseconds: 800));

    // Retornamos una lista Mock de empresas
    return [
      {'name': 'Tech Solutions SAS', 'nit': '900123456'},
      {'name': 'Constructora Global', 'nit': '900654321'},
      {'name': 'Servicios Médicos Ltda', 'nit': '800987654'},
      {'name': 'Bancolombia', 'nit': '890903938'},
      {'name': 'Ecopetrol', 'nit': '899999068'},
    ];
  }

  /// Simula la verificación y vinculación de un usuario a una empresa
  static Future<bool> verifyAndLinkCompanyFromBackend({
    required String nit,
    required String companyName,
  }) async {
    // 1. Simular delay de procesamiento
    await Future.delayed(const Duration(seconds: 2));

    // 2. Validación Mock:
    // Supongamos que si el NIT termina en '000', falla (para probar errores).
    if (nit.endsWith('000')) {
      return false;
    }

    // 3. ÉXITO: Actualizar el usuario localmente (Lógica Híbrida)
    // Al vincularse, le asignamos un ID de responsable y el nombre de la empresa.
    if (_currentUser != null) {
      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: _currentUser!.name,
        phone: _currentUser!.phone,
        documentNumber: _currentUser!.documentNumber,
        photoUrl: _currentUser!.photoUrl, // Mantenemos la foto si existe
        // --- CORRECCIONES BASADAS EN TU MODELO ---

        // 1. Role: Usamos el Enum, no un String
        role: UserRole.EMPLEADO,

        // 2. Datos de Empresa:
        empresa: companyName,
        nitEmpresa: nit, // Tu modelo tiene este campo, lo llenamos también
        // 3. ID Responsable (Generado Mock)
        idResponsable: 'CORP-${DateTime.now().millisecondsSinceEpoch}',

        // 4. AppMode: Usamos el Enum, no un bool
        appMode: AppMode.CORPORATE,

        // 5. Mantener datos existentes
        verificationStatus: _currentUser!.verificationStatus,
        beneficiaries: _currentUser!.beneficiaries,
        idPassenger: _currentUser!.idPassenger,
        token: _currentUser!.token,
      );
    }

    return true;
  }

  // ===========================================================================
  // 6. RECUPERACIÓN DE CONTRASEÑA (MOCK + PREPARACIÓN LARAVEL)
  // ===========================================================================

  /// 1. Simula el envío de un código al correo
  static Future<bool> sendPasswordRecoveryEmail(String email) async {
    await Future.delayed(const Duration(seconds: 2)); // Simular red

    // VALIDACIÓN MOCK: Verificamos si el correo existe en la BD local
    final userExists = _dbUsuarios.any((u) => u['email'] == email);

    if (!userExists) return false;

    // CONECTAR LARAVEL:
    /*
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/forgot-password'),
      body: jsonEncode({'email': email}),
      headers: ...
    );
    return response.statusCode == 200;
    */

    return true;
  }

  /// 2. Simula la verificación del código (OTP)
  static Future<bool> verifyRecoveryToken(String email, String token) async {
    await Future.delayed(const Duration(seconds: 1));

    // MOCK: Aceptamos el código "1234" como válido para pruebas
    if (token == "1234") return true;

    // CONECTAR LARAVEL:
    /*
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/verify-token'),
      body: jsonEncode({'email': email, 'token': token}),
      ...
    );
    return response.statusCode == 200;
    */

    return false;
  }

  /// 3. Cambia la contraseña en la BD Mock
  static Future<bool> changePassword(String email, String newPassword) async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      // LOGICA MOCK: Buscamos el usuario y actualizamos su password
      final userIndex = _dbUsuarios.indexWhere((u) => u['email'] == email);

      if (userIndex != -1) {
        _dbUsuarios[userIndex]['password'] = newPassword;
        // También actualizamos el currentUser si es el mismo
        if (_currentUser?.email == email) {
          // Nota: En una app real forzaríamos logout, pero aquí actualizamos
          // No podemos actualizar _currentUser directamente porque sus campos son final
          // pero al hacer login de nuevo funcionará.
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }

    // CONECTAR LARAVEL:
    /*
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      body: jsonEncode({
        'email': email, 
        'password': newPassword,
        'password_confirmation': newPassword
      }),
      ...
    );
    return response.statusCode == 200;
    */
  }

  static Map<String, dynamic> _mapStatus(UserVerificationStatus status) {
    switch (status) {
      // 1. Usuario activo y feliz
      case UserVerificationStatus.VERIFIED:
        return {'status': AuthResponseStatus.active, 'user': _currentUser};

      // 2. Usuario nuevo, falta OTP (El caso que daba error)
      case UserVerificationStatus.PENDING:
        return {'status': AuthResponseStatus.incomplete};

      // 3. Usuario verificó email, falta aprobación de Empresa
      case UserVerificationStatus.CREATED:
        return {'status': AuthResponseStatus.pending};

      // 4. Usuario subió papeles, VAMOS está revisando
      case UserVerificationStatus.UNDER_REVIEW:
      case UserVerificationStatus.DOCS_UPLOADED: // Agrupamos ambos aquí
        return {'status': AuthResponseStatus.underReview};

      // 5. Casos tristes
      case UserVerificationStatus.REJECTED:
        return {'status': AuthResponseStatus.rejected};

      case UserVerificationStatus.REVOKED:
        return {'status': AuthResponseStatus.revoked};
    }
  }
}
