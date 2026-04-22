class Passenger {
  final String? id; // Útil para favoritos
  final String name;
  final String nationalId;
  final String documentType; // CC, CE, TI, PP, etc.

  Passenger({
    this.id,
    required this.name,
    required this.nationalId,
    this.documentType = 'CC',
  });

  Map<String, dynamic> toJson() {
    return {
      'nombre_completo': name,
      'numero_documento': nationalId,
      'tipo_documento': documentType,
    };
  }

  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(
      id: json['id']?.toString() ?? '',
      name: json['nombre_completo'] ?? json['name'] ?? '',
      nationalId: json['numero_documento'] ?? json['national_id'] ?? '',
      documentType: json['tipo_documento'] ?? 'CC',
    );
  }
}
