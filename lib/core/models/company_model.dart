/// MODELO DE EMPRESA (CLIENTE CORPORATIVO)
///
/// Representa la entidad 'COMPANIES' del Diagrama ER.
/// Se utiliza cuando el usuario selecciona el Modo "Corporativo".
///
/// RESPONSABILIDADES:
/// 1. Almacenar datos fiscales (NIT) para facturación y validación.
/// 2. Guardar el [contratoMoviltrackId] necesario para la generación del FUEC.
class Company {
  /// PK: Coincide con 'uuid id' en la tabla COMPANIES.
  final String? id;

  /// Identificación Fiscal (Unique). Vital para validar si la empresa existe
  /// y para el 'Modo Dual' (Personal vs Corporativo).
  final String nit;

  /// Mapea a 'business_name' en el ER. Nombre legal para el Manifiesto.
  final String razonSocial;

  /// Parte de la dirección, útil para geolocalización o filtros.
  final String ciudad;

  /// Mapea a 'address' en el ER.
  final String direccion;

  /// Contacto administrativo. Mapea a 'email' en el ER.
  final String email;

  /// Mapea a 'phone' en el ER.
  final String telefono;

  /// Mapea a 'is_verified' en el ER.
  /// Define si la empresa puede operar (pedir viajes).
  final bool isVerified;

  /// Mapea a 'moviltrack_contract_id' en el ER.
  /// Es el ID del contrato legal que Moviltrack exige en el API
  /// para generar el PDF del FUEC. Si es null, no se pueden generar viajes legales.
  final String? contratoMoviltrackId;

  Company({
    this.id,
    required this.nit,
    required this.razonSocial,
    required this.ciudad,
    required this.direccion,
    required this.email,
    required this.telefono,
    this.isVerified = false,
    this.contratoMoviltrackId,
  });

  /// Factory para procesar la respuesta del formulario de registro en la App.
  /// NOTA: Al registrarse desde la App, 'contratoMoviltrackId' llega nulo
  /// porque debe ser asignado manualmente desde el Panel Web Administrativo.
  factory Company.fromRegistrationMap(Map<String, dynamic> map) {
    // Asume que la estructura viene de un formulario anidado bajo 'empresa'
    final datosEmpresa = map['empresa'];
    return Company(
      nit: datosEmpresa['nit'],
      razonSocial: datosEmpresa['razon_social'],
      ciudad: datosEmpresa['ciudad'],
      direccion: datosEmpresa['direccion'],
      email: datosEmpresa['email_corporativo'],
      telefono: datosEmpresa['telefono_corporativo'],
      isVerified: true,
      contratoMoviltrackId: null,
    );
  }

  /// Utilidad para selects o visualización rápida en UI.
  Map<String, String> toSimpleMap() {
    return {'nit': nit, 'name': razonSocial};
  }
}
