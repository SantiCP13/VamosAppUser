import '../../../core/models/user_model.dart';
// Asegúrate de que la ruta al user_model sea correcta.

enum AuthResponseStatus {
  active,
  pending, // Para Created (Empresa - Pendiente aprobación)
  underReview, // Para revisión manual (Vamos / Natural)
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

  // ===========================================================================
  // 1. BASES DE DATOS MOCK (Simulación de Escenarios)
  // ===========================================================================

  static final List<Map<String, String>> _mockCompaniesDB = [
    {'nit': '900123456', 'name': 'Transportes Ejecutivos S.A.S'},
    {'nit': '890903938', 'name': 'Bancolombia S.A.'},
    {'nit': '800222333', 'name': 'Ecopetrol'},
    {'nit': '111222333', 'name': 'Vamos App Demo'},
  ];

  // ---------------------------------------------------------------------------
  // LISTA DE USUARIOS DE PRUEBA PARA TODOS LOS ESCENARIOS
  // Contraseña universal: "123"
  // ---------------------------------------------------------------------------
  static final List<Map<String, dynamic>> _dbUsuarios = [
    // ESCENARIO 1: Corporativo VERIFICADO -> Home Screen (Modo Corp)
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
      'status': 'VERIFIED', // Clave para entrar al Home
      'app_mode': 'CORPORATE',
      'beneficiaries': [],
    },

    // ESCENARIO 2: Corporativo PENDIENTE -> Pending Approval Screen
    {
      'id': 'user_corp_pending',
      'id_pasajero': null,
      'id_responsable': 'resp_02',
      'email': 'pendiente@vamos.com',
      'password': '123',
      'nombre': 'Pedro Pendiente',
      'documento': '102',
      'telefono': '3001001002',
      'empresa': 'Bancolombia S.A.',
      'nit_empresa': '890903938',
      'role': 'EMPLEADO',
      'status':
          'CREATED', // Clave para pantalla de "Esperando aprobación empresa"
      'app_mode': 'CORPORATE',
      'beneficiaries': [],
    },

    // ESCENARIO 3: Natural VERIFICADO -> Home Screen (Modo Personal)
    {
      'id': 'user_natural_active',
      'id_pasajero': 'pas_03', // Usuario natural tiene ID pasajero
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
      'status': 'VERIFIED', // Clave para entrar al Home
      'app_mode': 'PERSONAL',
      'beneficiaries': [],
    },

    // ESCENARIO 4: Natural EN REVISIÓN -> Verification Check Screen
    {
      'id': 'user_natural_review',
      'id_pasajero': 'pas_04',
      'email': 'revision@vamos.com',
      'password': '123',
      'nombre': 'Roberto Revisión',
      'documento': '104',
      'role': 'NATURAL',
      'status':
          'UNDER_REVIEW', // Clave para pantalla "Estamos revisando tus docs"
      'app_mode': 'PERSONAL',
      'beneficiaries': [],
    },

    // ESCENARIO 5: Usuario RECHAZADO -> Debe mostrar error/alerta
    {
      'id': 'user_rejected',
      'email': 'rechazado@vamos.com',
      'password': '123',
      'nombre': 'Felipe Fallido',
      'status': 'REJECTED', // Clave para AuthResponseStatus.rejected
      'role': 'NATURAL',
      'beneficiaries': [],
    },

    // ESCENARIO 6: Usuario REVOCADO (Baneado) -> Debe mostrar error/alerta
    {
      'id': 'user_revoked',
      'email': 'baneado@vamos.com',
      'password': '123',
      'nombre': 'Maria Malportada',
      'status': 'REVOKED', // Clave para AuthResponseStatus.revoked
      'role': 'NATURAL',
      'beneficiaries': [],
    },
  ];

  // ===========================================================================
  // 2. MÓDULO B2B (EMPRESAS)
  // ===========================================================================

  static Future<List<Map<String, String>>> searchCompanies(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (query.isEmpty) return _mockCompaniesDB;
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

  // ===========================================================================
  // 3. REGISTROS DE USUARIOS
  // ===========================================================================

  static Future<bool> registerCorporateUser(Map<String, dynamic> datos) async {
    await Future.delayed(const Duration(seconds: 2));
    try {
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
    await Future.delayed(const Duration(seconds: 2));
    try {
      final String newId = DateTime.now().millisecondsSinceEpoch.toString();
      final newUserMap = {
        'id': newId,
        'id_pasajero': newId,
        'id_responsable': newId, // Temporalmente responsable de sí mismo
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

  // ===========================================================================
  // 4. LOGIN & LOGOUT (Lógica Modificada para Test)
  // ===========================================================================

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    await Future.delayed(const Duration(seconds: 1));

    // 1. Buscar usuario
    final userMap = _dbUsuarios.firstWhere(
      (u) => u['email'] == email && u['password'] == password,
      orElse: () => {},
    );

    if (userMap.isEmpty) return {'status': AuthResponseStatus.notFound};

    // 2. Convertir a Modelo
    final tempUser = User.fromMap(userMap);
    _currentUser = tempUser;

    // 3. Evaluar estado (Coincide con UserVerificationStatus en tu user_model)
    switch (tempUser.verificationStatus) {
      case UserVerificationStatus.VERIFIED:
        return {'status': AuthResponseStatus.active, 'user': tempUser};

      case UserVerificationStatus.CREATED:
        // Caso típico: Empleado registrado esperando aprobación de la empresa
        return {'status': AuthResponseStatus.pending};

      case UserVerificationStatus.UNDER_REVIEW:
      case UserVerificationStatus.DOCS_UPLOADED:
        // Caso típico: Natural esperando revisión de Vamos
        return {'status': AuthResponseStatus.underReview};

      case UserVerificationStatus.REJECTED:
        return {'status': AuthResponseStatus.rejected};

      case UserVerificationStatus.REVOKED:
        return {'status': AuthResponseStatus.revoked};

      default:
        return {'status': AuthResponseStatus.incomplete};
    }
  }

  static Future<void> logout() async {
    _currentUser = null;
  }

  // ===========================================================================
  // 5. UTILIDADES
  // ===========================================================================

  static Future<bool> sendReferralCode(String code) async {
    await Future.delayed(const Duration(seconds: 1));
    return code.trim().isNotEmpty;
  }

  static Future<bool> checkEmailExists(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _dbUsuarios.any((u) => u['email'] == email);
  }

  static Future<bool> sendEmailOTP(String email) async => true;
  static Future<bool> verifyEmailOTP(String e, String o) async => o == "123456";

  // ===========================================================================
  // 6. GESTIÓN DE PERFIL Y MODOS
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

    _currentUser!.idPassenger = "pas_${DateTime.now().millisecondsSinceEpoch}";

    // Si estaba CREATED (pendiente empresa), al activar natural pasa a VERIFIED como natural?
    // Esto depende de tu lógica de negocio, asumamos que sí para el test:
    if (_currentUser!.verificationStatus == UserVerificationStatus.CREATED) {
      _currentUser!.verificationStatus = UserVerificationStatus.VERIFIED;
    }

    _currentUser!.appMode = AppMode.PERSONAL;
    return true;
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

  static Future<void> linkCorporateAccount({
    required String nit,
    required String emailCorporativo,
    required String empresaNombre,
  }) async {
    if (_currentUser == null) return;
    await Future.delayed(const Duration(seconds: 1));

    _currentUser!.empresa = empresaNombre;
    _currentUser!.nitEmpresa = nit;
    _currentUser!.idResponsable =
        "resp_${DateTime.now().millisecondsSinceEpoch}";
    _currentUser!.role = UserRole.EMPLEADO;
    _currentUser!.appMode = AppMode.CORPORATE;
  }

  // ===========================================================================
  // 7. GESTIÓN DE BENEFICIARIOS
  // ===========================================================================

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

  static Future<void> removeBeneficiary(String id) async {
    if (_currentUser == null) return;
    _currentUser!.beneficiaries.removeWhere((b) => b.id == id);
  }
  // ===============================================================
  // MÉTODO DE VINCULACIÓN AUTOMÁTICA (Simulación Backend)
  // ===============================================================

  /// Intenta vincular al usuario actual con la empresa seleccionada.
  /// Retorna TRUE si la cédula está en la "base de datos" de la empresa.
  /// Retorna FALSE si no aparece en la lista de empleados.
  static Future<bool> verifyAndLinkCompanyFromBackend({
    required String nit,
    required String companyName,
  }) async {
    if (_currentUser == null) return false;

    // 1. Simular tiempo de espera del servidor (Loading...)
    await Future.delayed(const Duration(seconds: 3));

    // 2. Lógica de Simulación (Backend):
    // Para efectos de prueba, vamos a decir que la vinculación es EXITOSA
    // si el documento del usuario NO está vacío.
    // Si quieres probar el caso de fallo, usa un usuario con documento "0000".
    bool isEmployeeFound =
        _currentUser!.documentNumber.isNotEmpty &&
        _currentUser!.documentNumber != "0000";

    if (isEmployeeFound) {
      // 3. Éxito: Actualizamos el usuario localmente
      _currentUser!.empresa = companyName;
      _currentUser!.nitEmpresa = nit;
      _currentUser!.idResponsable =
          "resp_${DateTime.now().millisecondsSinceEpoch}";
      _currentUser!.role = UserRole.EMPLEADO;
      _currentUser!.appMode = AppMode.CORPORATE;

      // Si estaba pendiente, lo pasamos a verificado
      if (_currentUser!.verificationStatus != UserVerificationStatus.VERIFIED) {
        _currentUser!.verificationStatus = UserVerificationStatus.VERIFIED;
      }
      return true;
    } else {
      // 4. Fallo: No se encontró en la nómina
      return false;
    }
  }

  /// Helper para obtener todas las empresas para el Dropdown
  static Future<List<Map<String, String>>> getAvailableCompanies() async {
    // Simula carga de red
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockCompaniesDB;
  }
}
