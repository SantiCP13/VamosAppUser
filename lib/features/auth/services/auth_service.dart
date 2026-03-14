// lib/features/auth/services/auth_service.dart

import 'dart:async';
import 'dart:io'; // 🔥 ESTA ES LA LÍNEA MÁGICA QUE FALTA
import '../../../core/network/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/models/user_model.dart';
import 'package:dio/dio.dart';

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
  // 2. LOGIN REAL (POST /login)
  // ===========================================================================
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      // 1. Llamamos a nuestro mensajero
      final apiClient = ApiClient();

      // 2. Tocamos la puerta de tu PC (Laravel) y le pasamos el correo y clave
      final response = await apiClient.dio.post(
        '/login',
        data: {'email': email, 'password': password},
      );

      // 3. Si tu Laravel nos responde "success: true" (¡Pase usted!)
      if (response.data['success'] == true) {
        // Sacamos los datos que nos mandó Laravel de su "cajita" llamada data
        final userData = response.data['data']['user'];
        final token = response.data['data']['token'];

        // Guardamos el usuario y su llave de seguridad en el celular
        _currentUser = User.fromMap(userData);
        await _storage.write(key: 'auth_token', value: token);

        return {'status': AuthResponseStatus.active, 'user': _currentUser};
      }

      return {'status': AuthResponseStatus.error};
    } on DioException catch (e) {
      // 1. Atrapamos errores de Validación (422)
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'] as Map<String, dynamic>;
        String errorMessage = '';
        errors.forEach((key, value) {
          errorMessage += "${value[0]}\n";
        });
        throw Exception(errorMessage.trim());
      }

      // 🔥 2. ATRAPAMOS ERRORES FATALES (500) PARA VER EL FALLO SQL DE LARAVEL
      if (e.response?.statusCode == 500) {
        final data = e.response?.data;
        if (data != null && data['message'] != null) {
          // Esto nos mostrará el "Error al registrar usuario: SQLSTATE[...]"
          throw Exception("Backend 500:\n${data['message']}");
        }
      }

      throw Exception("Error de servidor: ${e.response?.statusCode}");
    } catch (e) {
      throw Exception("Error inesperado: $e");
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

  // Registro REAL de EMPLEADO CORPORATIVO
  static Future<bool> registerCorporateUser(Map<String, dynamic> datos) async {
    try {
      final apiClient = ApiClient();

      // Usamos FormData por consistencia con la arquitectura del proyecto
      FormData formData = FormData.fromMap({
        'nombre': datos['nombre'],
        'telefono': datos['telefono'],
        'documento': datos['documento'],
        'email': datos['email'],
        'password': datos['password'],
        'password_confirmation':
            datos['password'], // Laravel exige confirmación
        'direccion': datos['direccion'],
        'empresa':
            datos['empresa_id'], // 🔥 IMPORTANTE: Laravel exige el ID, no el NIT
        'role': 2, // 2 = Role::CLIENTE (Responsable/Empleado) en Laravel
      });

      final response = await apiClient.dio.post(
        '/register',
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Asignamos el usuario a la memoria para que no nos patee al Login
        if (response.data != null && response.data['data'] != null) {
          final userData = response.data['data']['user'];
          _currentUser = User.fromMap(userData);
        }

        // NO guardamos el token localmente (nace inactivo)
        return true;
      }
      return false;
    } on DioException catch (e) {
      // 🔥 ATRAPAMOS LOS ERRORES DE LARAVEL (422)
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'] as Map<String, dynamic>;
        String errorMessage = '';

        errors.forEach((key, value) {
          errorMessage += "${value[0]}\n";
        });

        throw Exception(errorMessage.trim());
      }
      throw Exception("Error de conexión con el servidor.");
    } catch (e) {
      throw Exception("Error inesperado: $e");
    }
  }

  // Registro REAL de USUARIO NATURAL
  static Future<bool> registerNaturalUser({
    required Map<String, dynamic> datos,
    required File? cedulaPdf,
    required File? selfieImage,
  }) async {
    try {
      final apiClient = ApiClient();

      // Cuando enviamos ARCHIVOS, ya no enviamos un Map normal,
      // enviamos un "FormData" (como en Postman).
      FormData formData = FormData.fromMap({
        'nombre': datos['nombre'],
        'telefono': datos['telefono'],
        'documento': datos['documento'],
        'email': datos['email'],
        'password': datos['password'],
        'password_confirmation': datos['password'],
        'direccion': datos['direccion'],
        'role': 2,
        // Aquí adjuntaremos los archivos más adelante
      });

      // 🔥 ADJUNTAMOS EL PDF SI EXISTE
      if (cedulaPdf != null) {
        formData.files.add(
          MapEntry(
            'cedula_pdf', // Mismo nombre que busca Laravel
            await MultipartFile.fromFile(
              cedulaPdf.path,
              filename: 'cedula.pdf',
            ),
          ),
        );
      }

      // 🔥 ADJUNTAMOS LA SELFIE SI EXISTE
      if (selfieImage != null) {
        formData.files.add(
          MapEntry(
            'selfie', // Mismo nombre que busca Laravel
            await MultipartFile.fromFile(
              selfieImage.path,
              filename: 'selfie.jpg',
            ),
          ),
        );
      }

      final response = await apiClient.dio.post(
        '/register',
        data: formData,
        options: Options(
          sendTimeout: const Duration(
            seconds: 60,
          ), // Tiempo máximo para enviar (subir)
          receiveTimeout: const Duration(
            seconds: 60,
          ), // Tiempo máximo para recibir respuesta
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 🔥 SOLUCIÓN: Asignamos el usuario a la memoria temporal de la app
        // para que VerificationCheckScreen no nos devuelva al Login.
        if (response.data != null && response.data['data'] != null) {
          final userData = response.data['data']['user'];
          _currentUser = User.fromMap(userData);
        }

        // ¡OJO! NO guardamos el token en _storage.write('auth_token', token)
        // Así respetamos tu regla de que no persista si el usuario cierra la app.

        return true;
      }
      return false;
    } on DioException catch (e) {
      // 🔥 AQUÍ ATRAPAMOS LOS ERRORES DE LARAVEL (422)
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'] as Map<String, dynamic>;
        String errorMessage = '';

        // Extraemos todos los errores (ej: "El correo ya existe", "Mínimo 8 caracteres")
        errors.forEach((key, value) {
          errorMessage += "${value[0]}\n";
        });

        // Lanzamos el error para que la pantalla lo muestre en el SnackBar
        throw Exception(errorMessage.trim());
      }
      throw Exception("Error de conexión con el servidor.");
    } catch (e) {
      throw Exception("Error inesperado: $e");
    }
  }

  // Búsqueda de Empresas para vinculación
  static Future<List<Map<String, String>>> searchCompanies(String query) async {
    try {
      final apiClient = ApiClient();
      final response = await apiClient.dio.get('/empresas');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];

        // Mapeamos forzando a String para evitar errores de tipo en Flutter
        return data
            .map(
              (e) => {
                'id': e['id'].toString(),
                'name': e['name'].toString(),
                'nit': e['nit'].toString(),
              },
            )
            .toList();
      }
      return [];
    } catch (e) {
      // Si falla, devolvemos una lista vacía para no romper la UI
      return [];
    }
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
}
