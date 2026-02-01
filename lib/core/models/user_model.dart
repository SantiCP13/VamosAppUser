// lib/core/models/user_model.dart
// ignore_for_file: constant_identifier_names

enum UserVerificationStatus {
  CREATED,
  DOCS_UPLOADED,
  UNDER_REVIEW, // En revisión manual
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
  final String id;
  final String email;
  final String name;
  final String phone;
  final String empresa;
  final UserRole role;
  final UserVerificationStatus verificationStatus;
  final List<Beneficiary> beneficiaries;
  AppMode appMode;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    this.empresa = '',
    this.verificationStatus = UserVerificationStatus.CREATED,
    this.beneficiaries = const [],
    this.appMode = AppMode.PERSONAL,
  });

  bool get isEmployee => role == UserRole.EMPLEADO;
  bool get isCorporateMode => appMode == AppMode.CORPORATE;
  bool get canRequestTrips =>
      verificationStatus == UserVerificationStatus.VERIFIED;

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      // CORRECCIÓN: Asegurar fallback si no hay ID
      id: map['id'] ?? map['uid'] ?? 'unknown_id',
      email: map['email'] ?? '',
      name: map['nombre'] ?? '',
      phone: map['telefono'] ?? map['phone'] ?? '',
      empresa: map['empresa'] ?? '',
      role: map['role'] == 'EMPLEADO' ? UserRole.EMPLEADO : UserRole.NATURAL,
      verificationStatus: _parseStatus(map['status']),
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
      // CORRECCIÓN: Agregado el case 'UNDER_REVIEW' explícito
      case 'UNDER_REVIEW':
      case 'PENDING':
        return UserVerificationStatus.UNDER_REVIEW;
      case 'CREATED':
        return UserVerificationStatus.CREATED;
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
      'nombre': name,
      'telefono': phone,
      'empresa': empresa,
      'role': role == UserRole.EMPLEADO ? 'EMPLEADO' : 'NATURAL',
      'status': verificationStatus.name, // Esto guarda "UNDER_REVIEW"
      'beneficiaries': beneficiaries.map((b) => b.toJson()).toList(),
    };
  }

  User copyWith({
    String? name,
    String? phone,
    AppMode? appMode,
    UserVerificationStatus? verificationStatus,
    List<Beneficiary>? beneficiaries,
  }) {
    return User(
      id: id,
      email: email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role,
      empresa: empresa,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      beneficiaries: beneficiaries ?? this.beneficiaries,
      appMode: appMode ?? this.appMode,
    );
  }
}
