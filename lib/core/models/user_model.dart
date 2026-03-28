// lib/core/models/user_model.dart

// ignore_for_file: constant_identifier_names

/// ESTADO DE VERIFICACIÓN
///
/// Controla si el usuario puede pedir viajes.
/// Mapea a la columna 'verification_status' en la tabla USERS.
enum UserVerificationStatus {
  PENDING, // Registrado, email no verificado
  CREATED, // Email verificado, faltan datos
  DOCS_UPLOADED, // (Para conductores principalmente)
  UNDER_REVIEW, // (Para conductores o validación manual de empresas)
  VERIFIED, // PUEDE PEDIR VIAJES
  REJECTED, // Rechazado por datos inválidos o falta de documentos
  REVOKED, // BLOQUEADO por mal uso o fraude (Solo admins pueden cambiar a este estado)
}

/// ROL DEL USUARIO
enum UserRole {
  NATURAL, // Usuario particular
  EMPLEADO, // Usuario corporativo (Asociado a una COMPANY)
}

/// MODO DE OPERACIÓN
///
/// Controla la UI y el flujo de pago.
/// PERSONAL: Paga en efectivo/wallet.
/// CORPORATE: El cobro va a la factura de la empresa.
enum AppMode { PERSONAL, CORPORATE }

/// MODELO DE BENEFICIARIO (PASAJERO ADICIONAL)

/// RESPONSABILIDADES:
/// 1. Llenar el 'Manifiesto de Pasajeros'
/// 2. Proveer nombre y CÉDULA para el payload del FUEC.
class Beneficiary {
  final String id; // PK
  final String name;
  final String documentNumber; // Requerido por ley para el FUEC.

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

/// MODELO DE USUARIO

class User {
  final String id; // PK (UUID)

  // Variables mutables (pueden cambiar en edición de perfil)
  String? idPassenger;
  String? idResponsable; // FK manager_id
  String? photoUrl;

  final String email; // Unique Login
  final String name;
  final String phone;

  /// Cédula para FUEC.
  /// Mapea a 'document_number' en USERS.
  final String documentNumber;

  final String address;

  // --- DATOS CORPORATIVOS (RELACIÓN CON COMPANIES) ---

  /// FK: ID de la empresa en BD.
  /// Vital para buscar el 'moviltrack_contract_id' cuando appMode = CORPORATE.
  final String? companyUuid;
  final bool active;
  // Datos visuales de la empresa (Join simple)
  String empresa;
  String nitEmpresa;

  // --- ESTADOS Y CONTROL DE FLUJO ---

  UserRole role;
  UserVerificationStatus verificationStatus;

  /// Define si la solicitud de viaje incluye 'company_uuid' o no.
  AppMode appMode;

  // Lista para selección rápida en "Quién viaja?"
  List<Beneficiary> beneficiaries;

  // Autenticación (No se guarda en BD, solo en sesión local)
  String? token;
  final bool canUseCorporate;

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
    this.companyUuid,
    this.verificationStatus = UserVerificationStatus.CREATED,
    required this.beneficiaries,
    this.appMode =
        AppMode.CORPORATE, // Por defecto intenta ser corporativo si es empleado
    this.token,
    this.active = true,
    this.canUseCorporate = false,
  });

  // Helpers de lógica de negocio
  // 1. Capacidad real de ser corporativo (Tiene empresa vinculada)
  bool get canUseCorporateMode =>
      companyUuid != null && companyUuid != 'null' && companyUuid!.isNotEmpty;

  // 2. ¿Es empleado? (Mantenemos por compatibilidad, pero usamos el de arriba para UI)
  bool get isEmployee => role == UserRole.EMPLEADO && canUseCorporateMode;

  // 3. El modo actual (Switching)
  bool get isCorporateMode =>
      appMode == AppMode.CORPORATE && canUseCorporateMode;

  factory User.fromMap(Map<String, dynamic> map) {
    // Navegación profunda según REGLA DE ORO
    final responsable = map['responsable'];
    final empresaData = responsable != null ? responsable['empresa'] : null;
    String? rawStatus = map['status']?.toString();
    bool isActive = map['active'] == 1 || map['active'] == true;

    if (isActive &&
        (rawStatus == null || rawStatus == 'CREATED' || rawStatus == '')) {
      rawStatus = 'VERIFIED';
    }

    return User(
      id: map['id']?.toString() ?? '',
      idPassenger: map['id_pasajero']?.toString(),
      idResponsable: responsable != null ? responsable['id'].toString() : null,
      email: map['email'] ?? '',
      name: map['name'] ?? map['nombre'] ?? '',
      phone: map['telefono'] ?? map['phone'] ?? '',
      documentNumber: map['numero_documento'] ?? map['documento'] ?? '',
      address: map['direccion'] ?? map['address'] ?? '',
      active: isActive,

      // MAPEADO PROFUNDO SOLICITADO
      empresa: empresaData != null ? empresaData['razon_social'] ?? '' : '',
      nitEmpresa: empresaData != null ? empresaData['nit'] ?? '' : '',
      canUseCorporate: map['can_use_corporate'] ?? (empresaData != null),
      companyUuid: empresaData != null ? empresaData['id'].toString() : null,

      role: (map['id_role'] == 2) ? UserRole.EMPLEADO : UserRole.NATURAL,
      photoUrl: map['foto_perfil'],
      // Corregimos el error del linter usando la función aquí:
      verificationStatus: _parseStatus(rawStatus),

      appMode: (map['app_mode'] == 'PERSONAL' || map['app_mode'] == 'NATURAL')
          ? AppMode.PERSONAL
          : AppMode.CORPORATE,

      beneficiaries:
          (map['beneficiaries'] as List?)
              ?.map((e) => Beneficiary.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      token: map['access_token'],
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => User.fromMap(json);
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
