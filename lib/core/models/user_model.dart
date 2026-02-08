// lib/core/models/user_model.dart

// ignore_for_file: constant_identifier_names

enum UserVerificationStatus {
  PENDING,
  CREATED,
  DOCS_UPLOADED,
  UNDER_REVIEW,
  VERIFIED,
  REJECTED,
  REVOKED,
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
    'document_number': documentNumber,
  };

  factory Beneficiary.fromJson(Map<String, dynamic> json) {
    return Beneficiary(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      documentNumber: json['document_number'] ?? json['documentNumber'] ?? '',
    );
  }
}

class User {
  final String id;

  // Variables mutables
  String? idPassenger;
  String? idResponsable;
  String? photoUrl;

  final String email;
  final String name;
  final String phone;
  final String documentNumber;
  final String address;

  // CORRECCIÓN ER: Necesario para relacionar la tabla TRIPS con COMPANIES
  final String? companyUuid;

  // Datos de empresa (Visuales / NIT)
  String empresa;
  String nitEmpresa;

  // Estados y Roles
  UserRole role;
  UserVerificationStatus verificationStatus;
  AppMode appMode;

  // Listas
  List<Beneficiary> beneficiaries;

  // TOKEN JWT
  String? token;

  User({
    required this.id,
    this.idPassenger,
    this.idResponsable,
    required this.email,
    required this.name,
    required this.phone,
    this.documentNumber = '',
    this.address = '',
    this.photoUrl,
    required this.role,
    this.empresa = '',
    this.nitEmpresa = '',
    this.companyUuid, // Nuevo campo
    this.verificationStatus = UserVerificationStatus.CREATED,
    required this.beneficiaries,
    this.appMode = AppMode.CORPORATE,
    this.token,
  });

  bool get isCorporateMode => appMode == AppMode.CORPORATE;
  bool get isEmployee => role == UserRole.EMPLEADO || idResponsable != null;

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id']?.toString() ?? '',
      idPassenger: map['passenger_id']?.toString() ?? map['id_pasajero'],
      idResponsable: map['manager_id']?.toString() ?? map['id_responsable'],

      email: map['email'] ?? '',
      name: map['name'] ?? map['nombre'] ?? '',
      photoUrl: map['photo_url'],
      phone: map['phone'] ?? map['telefono'] ?? '',
      documentNumber: map['document_number'] ?? map['documento'] ?? '',
      address: map['address'] ?? map['direccion'] ?? '',

      // Mapeo de Empresa
      empresa: map['company_name'] ?? map['empresa'] ?? '',
      nitEmpresa: map['company_nit'] ?? map['nit_empresa'] ?? '',
      // CORRECCIÓN: El backend debe devolver el ID de la tabla companies
      companyUuid: map['company_id'],

      role: (map['role'] == 'EMPLEADO' || map['role_id'] == 2)
          ? UserRole.EMPLEADO
          : UserRole.NATURAL,

      verificationStatus: _parseStatus(map['status']),

      appMode: (map['app_mode'] == 'PERSONAL')
          ? AppMode.PERSONAL
          : AppMode.CORPORATE,

      beneficiaries:
          (map['beneficiaries'] as List<dynamic>?)
              ?.map((e) => Beneficiary.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],

      token: map['access_token'],
    );
  }

  static UserVerificationStatus _parseStatus(String? status) {
    if (status == null) return UserVerificationStatus.CREATED;
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'VERIFIED':
        return UserVerificationStatus.VERIFIED;
      case 'PENDING':
      case 'UNVERIFIED':
        return UserVerificationStatus.PENDING;
      case 'UNDER_REVIEW':
        return UserVerificationStatus.UNDER_REVIEW;
      case 'DOCS_UPLOADED':
        return UserVerificationStatus.DOCS_UPLOADED;
      case 'REJECTED':
        return UserVerificationStatus.REJECTED;
      case 'REVOKED':
        return UserVerificationStatus.REVOKED;
      default:
        return UserVerificationStatus.CREATED;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'document_number': documentNumber,
      'address': address,
      'company_name': empresa,
      'company_nit': nitEmpresa,
      'company_id': companyUuid,
      'role': role == UserRole.EMPLEADO ? 'EMPLEADO' : 'NATURAL',
      'status': verificationStatus.name,
      'app_mode': appMode == AppMode.CORPORATE ? 'CORPORATE' : 'PERSONAL',
      'beneficiaries': beneficiaries.map((b) => b.toJson()).toList(),
    };
  }
}
