// ignore_for_file: constant_identifier_names
enum UserVerificationStatus {
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
  final String id; // ID de Autenticación (Auth0 / Firebase / Laravel Sanctum)

  // ESTRATEGIA ESPEJO (Identidad Unificada)
  final String? idPassenger; // ID del perfil Pasajero (Personal)
  final String?
  idResponsable; // ID del perfil Corporativo (Nulo si no está vinculado)

  final String email;
  final String name;
  final String phone;
  final String documentNumber; // Agregado para persistir la cédula
  final String empresa;
  final UserRole
  role; // Se mantiene por compatibilidad, pero default es NATURAL
  final UserVerificationStatus verificationStatus;
  final List<Beneficiary> beneficiaries;
  AppMode appMode;

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
    this.verificationStatus = UserVerificationStatus.CREATED,
    this.beneficiaries = const [],
    this.appMode = AppMode.PERSONAL,
  });

  bool get isEmployee => role == UserRole.EMPLEADO || idResponsable != null;
  bool get isCorporateMode => appMode == AppMode.CORPORATE;

  // Ahora la validación de solicitar viajes dependerá de si tiene el perfil activo
  bool get canRequestTrips =>
      verificationStatus == UserVerificationStatus.VERIFIED;

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
      // Todos nacen natural, el backend decidirá si cambia a EMPLEADO al vincular
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
      'id_pasajero': idPassenger,
      'id_responsable': idResponsable,
      'email': email,
      'nombre': name,
      'telefono': phone,
      'documento': documentNumber,
      'empresa': empresa,
      'role': role == UserRole.EMPLEADO ? 'EMPLEADO' : 'NATURAL',
      'status': verificationStatus.name,
      'beneficiaries': beneficiaries.map((b) => b.toJson()).toList(),
    };
  }

  User copyWith({
    String? name,
    String? phone,
    String? idResponsable,
    String? empresa, // <--- AGREGAR ESTA LÍNEA
    AppMode? appMode,
    UserVerificationStatus? verificationStatus,
    List<Beneficiary>? beneficiaries,
  }) {
    return User(
      id: id,
      idPassenger: idPassenger,
      idResponsable: idResponsable ?? this.idResponsable,
      email: email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      documentNumber: documentNumber,
      role: role,
      empresa: empresa ?? this.empresa, // <--- AGREGAR ESTA LÍNEA
      verificationStatus: verificationStatus ?? this.verificationStatus,
      beneficiaries: beneficiaries ?? this.beneficiaries,
      appMode: appMode ?? this.appMode,
    );
  }
}
