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

  // Mock DB
  static final List<Map<String, dynamic>> _dbUsuarios = [
    {
      'id': 'user_verified',
      'id_pasajero': 'p_01',
      'id_responsable': null,
      'email': 'test@vamos.com',
      'password': '123',
      'status': 'VERIFIED',
      'nombre': 'Usuario Test',
      'documento': '123456',
      'telefono': '3001234567',
      'role': 'NATURAL',
      'beneficiaries': [],
      'empresa': '',
    },
  ];

  static final List<String> _emailsRegistrados = ['hola@vamos.com'];

  // ===========================================================================
  // 1. MÉTODOS DE AUTENTICACIÓN (LOGIN & REGISTRO NUEVO)
  // ===========================================================================

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

      if (tempUser.verificationStatus == UserVerificationStatus.VERIFIED) {
        return {'status': AuthResponseStatus.active, 'user': tempUser};
      } else if (tempUser.verificationStatus ==
          UserVerificationStatus.UNDER_REVIEW) {
        return {'status': AuthResponseStatus.pending};
      } else {
        return {'status': AuthResponseStatus.incomplete};
      }
    } catch (e) {
      debugPrint("Error Login: $e");
      return {'status': AuthResponseStatus.error};
    }
  }

  // --- REGISTRO SEGURO (CON DOCS) ---
  static Future<bool> registerPassenger(Map<String, dynamic> datos) async {
    await Future.delayed(const Duration(seconds: 3));

    try {
      final String newId = DateTime.now().millisecondsSinceEpoch.toString();

      final newUserMap = {
        'id': newId,
        'id_pasajero': 'pass_$newId',
        'id_responsable': null,
        'email': datos['email'],
        'password': datos['password'],
        'status': 'UNDER_REVIEW',
        'nombre': datos['nombre'],
        'documento': datos['documento'],
        'telefono': datos['telefono'],
        'direccion': datos['direccion'],
        'empresa': '',
        'role': 'NATURAL',
        'beneficiaries': [],
      };

      _dbUsuarios.add(newUserMap);
      _currentUser = User.fromMap(newUserMap);

      return true;
    } catch (e) {
      debugPrint("Error registro: $e");
      return false;
    }
  }

  // ===========================================================================
  // 2. MÉTODOS DE VERIFICACIÓN (OTP & DOCS)
  // ===========================================================================

  static Future<bool> sendEmailOTP(String email) async {
    await Future.delayed(const Duration(seconds: 1));
    debugPrint("📧 Enviando OTP al correo: $email");
    return true;
  }

  static Future<bool> verifyEmailOTP(String email, String otp) async {
    await Future.delayed(const Duration(seconds: 1));
    return otp == "123456";
  }

  // Método legacy para mantener compatibilidad si alguna pantalla vieja llama a phone
  static Future<bool> sendPhoneOTP(String phoneNumber) async => true;
  static Future<bool> verifyPhoneOTP(String phoneNumber, String code) async =>
      code == "555555";

  static Future<bool> uploadIdentityDocuments({
    required String frontIdPath,
    required String backIdPath,
    required String selfiePath,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  // ===========================================================================
  // 3. MÉTODOS DE GESTIÓN DE ESTADO (HOME & PERFIL)
  // ===========================================================================

  // Restaurado para que home_screen.dart no falle
  static bool toggleAppMode(bool isCorporate) {
    if (_currentUser == null) return false;

    // Si quiere ser corporativo pero NO tiene idResponsable (Vinculación)
    if (isCorporate && _currentUser!.idResponsable == null) {
      return false; // El Home deberá detectar este false para mostrar el modal de vinculación
    }

    _currentUser = _currentUser!.copyWith(
      appMode: isCorporate ? AppMode.CORPORATE : AppMode.PERSONAL,
    );
    return true;
  }

  // Restaurado para home_screen.dart
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

  // Restaurado para home_screen.dart
  static Future<void> removeBeneficiary(String id) async {
    if (_currentUser == null) return;
    final updatedList = _currentUser!.beneficiaries
        .where((b) => b.id != id)
        .toList();
    _currentUser = _currentUser!.copyWith(beneficiaries: updatedList);
  }

  // ===========================================================================
  // 4. MÉTODOS DE COMPATIBILIDAD (LEGACY / OTROS SCREENS)
  // ===========================================================================

  // Restaurado para login_screen.dart
  static Future<bool> checkEmailExists(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _dbUsuarios.any((u) => u['email'] == email) ||
        _emailsRegistrados.contains(email);
  }

  // Restaurado para referral_screen.dart
  static Future<bool> sendReferralCode(String code) async {
    await Future.delayed(const Duration(seconds: 1));
    return code.toUpperCase() != "ERROR";
  }

  // Restaurados para corporate_link_widget.dart (Aunque lo borremos después, para que compile hoy)
  static Future<String?> checkCorporateDomain(String email) async {
    if (email.contains('bancolombia')) return 'Bancolombia S.A.';
    return null;
  }

  static Future<bool> sendCorporateOTP(String email) async => true;
  static Future<bool> verifyCorporateOTP(String e, String o) async =>
      o == "123456";

  // Restaurado para company_register_screen.dart
  static Future<bool> requestCompanyAffiliation(
    Map<String, dynamic> data,
  ) async => true;

  // ===========================================================================
  // 5. MÉTODOS DE VINCULACIÓN CORPORATIVA (NUEVO)
  // ===========================================================================

  /// Simula la búsqueda de una empresa por NIT
  static Future<String?> validateCompanyNit(String nit) async {
    await Future.delayed(const Duration(seconds: 2)); // Simular API
    if (nit == "900123456") return "Transportes Ejecutivos S.A.S";
    if (nit == "800") return "Bancolombia S.A.";
    return null; // NIT no encontrado
  }

  /// Vincula la cuenta actual a la empresa y activa el modo corporativo
  static Future<bool> linkCorporateAccount({
    required String nit,
    required String emailCorporativo,
    required String empresaNombre,
  }) async {
    await Future.delayed(const Duration(seconds: 2));

    if (_currentUser == null) return false;

    // 1. Asignamos un ID Responsable (Simulado) y actualizamos la empresa
    // 2. Cambiamos el rol visualmente a EMPLEADO (para que persista el switch)
    // 3. Activamos el modo CORPORATE de inmediato
    _currentUser = _currentUser!.copyWith(
      idResponsable: "resp_${DateTime.now().millisecondsSinceEpoch}",
      empresa: empresaNombre,
      appMode: AppMode.CORPORATE,
      // Nota: En un backend real, el rol cambiaría en base de datos.
      // Aquí forzamos la actualización local para la UI.
    );

    // Hack para simular persistencia en el Mock DB si quisieras
    final index = _dbUsuarios.indexWhere((u) => u['id'] == _currentUser!.id);
    if (index != -1) {
      _dbUsuarios[index]['id_responsable'] = _currentUser!.idResponsable;
      _dbUsuarios[index]['empresa'] = empresaNombre;
    }

    return true;
  }
}
