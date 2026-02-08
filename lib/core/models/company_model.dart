class Company {
  final String? id;
  final String nit;
  final String razonSocial;
  final String ciudad;
  final String direccion;
  final String email;
  final String telefono;
  final bool isVerified;
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

  factory Company.fromRegistrationMap(Map<String, dynamic> map) {
    final datosEmpresa = map['empresa'];
    return Company(
      nit: datosEmpresa['nit'],
      razonSocial: datosEmpresa['razon_social'],
      ciudad: datosEmpresa['ciudad'],
      direccion: datosEmpresa['direccion'],
      email: datosEmpresa['email_corporativo'],
      telefono: datosEmpresa['telefono_corporativo'],
      isVerified: true,
      // En registro manual aun no hay contrato, se asigna luego en administración
      contratoMoviltrackId: null,
    );
  }

  Map<String, String> toSimpleMap() {
    return {'nit': nit, 'name': razonSocial};
  }
}
