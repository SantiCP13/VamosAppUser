// lib/core/models/user_model.dart

// ignore_for_file: constant_identifier_names

enum UserVerificationStatus {
  CREATED, // Recién creado
  DOCS_UPLOADED, // Subió documentos
  UNDER_REVIEW, // En revisión
  VERIFIED, // Aprobado y activo
  REJECTED, // Rechazado
  REVOKED, // Acceso revocado
}

enum UserRole { NATURAL, EMPLEADO }

enum AppMode { PERSONAL, CORPORATE }

class Beneficiary {
  final String id;
  final String name;
  final String documentNumber;

  Beneficiary({
    required this.id,
    required this.name,
    required this.documentNumber,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'documentNumber': documentNumber,
  };

  factory Beneficiary.fromJson(Map<String, dynamic> json) {
    return Beneficiary(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? '',
      documentNumber: json['documentNumber'] ?? '',
    );
  }
}

class User {
  final String id; // El ID único no cambia

  // --- VARIABLES MUTABLES (QUITAMOS 'FINAL') ---
  String? idPassenger;
  String? idResponsable;

  final String email;
  final String name;
  final String phone;
  final String documentNumber;

  // Datos de empresa mutables
  String empresa;
  String nitEmpresa;

  // Enums mutables
  UserRole role;
  UserVerificationStatus verificationStatus;
  AppMode appMode;

  // Lista mutable
  List<Beneficiary> beneficiaries;

  User({
    required this.id,
    this.idPassenger,
    this.idResponsable,
    required this.email,
    required this.name,
    required this.phone,
    this.documentNumber = '',
    required this.role,
    this.empresa = '',
    this.nitEmpresa = '',
    this.verificationStatus = UserVerificationStatus.CREATED,
    required this.beneficiaries, // Quitamos 'const []' para permitir listas mutables
    this.appMode = AppMode.CORPORATE,
  });

  bool get isCorporateMode => appMode == AppMode.CORPORATE;
  bool get isEmployee => role == UserRole.EMPLEADO || idResponsable != null;

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? map['uid'] ?? 'unknown_id',
      idPassenger: map['id_pasajero'],
      idResponsable: map['id_responsable'],
      email: map['email'] ?? '',
      name: map['nombre'] ?? '',
      phone: map['telefono'] ?? map['phone'] ?? '',
      documentNumber: map['documento'] ?? '',
      empresa: map['empresa'] ?? '',
      nitEmpresa: map['nit_empresa'] ?? '',

      role: (map['role'] == 'EMPLEADO' || map['id_responsable'] != null)
          ? UserRole.EMPLEADO
          : UserRole.NATURAL,

      verificationStatus: _parseStatus(map['status']),

      appMode: map['app_mode'] == 'PERSONAL'
          ? AppMode.PERSONAL
          : AppMode.CORPORATE,

      // Aseguramos que sea una lista que se pueda modificar (growable: true)
      beneficiaries:
          (map['beneficiaries'] as List<dynamic>?)
              ?.map((e) => Beneficiary.fromJson(e))
              .toList() ??
          [],
    );
  }

  static UserVerificationStatus _parseStatus(String? status) {
    switch (status) {
      case 'ACTIVE':
      case 'VERIFIED':
        return UserVerificationStatus.VERIFIED;
      case 'UNDER_REVIEW':
      case 'PENDING':
        return UserVerificationStatus.UNDER_REVIEW;
      case 'DOCS_UPLOADED':
        return UserVerificationStatus.DOCS_UPLOADED;
      case 'REJECTED':
        return UserVerificationStatus.REJECTED;
      case 'REVOKED':
        return UserVerificationStatus.REVOKED;
      case 'CREATED':
      default:
        return UserVerificationStatus.CREATED;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_pasajero': idPassenger,
      'id_responsable': idResponsable,
      'email': email,
      'nombre': name,
      'telefono': phone,
      'documento': documentNumber,
      'empresa': empresa,
      'nit_empresa': nitEmpresa,
      'role': role == UserRole.EMPLEADO ? 'EMPLEADO' : 'NATURAL',
      'status': verificationStatus.name,
      'app_mode': appMode == AppMode.CORPORATE ? 'CORPORATE' : 'PERSONAL',
      'beneficiaries': beneficiaries.map((b) => b.toJson()).toList(),
    };
  }
}
