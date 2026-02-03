import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';

class CompanyRegisterScreen extends StatefulWidget {
  const CompanyRegisterScreen({super.key});

  @override
  State<CompanyRegisterScreen> createState() => _CompanyRegisterScreenState();
}

class _CompanyRegisterScreenState extends State<CompanyRegisterScreen> {
  bool _isLoading = false;

  // ---Controladores Empresa (Información Legal) ---
  final _razonSocialController = TextEditingController();
  final _nitController = TextEditingController();
  final _direccionEmpresaController = TextEditingController();
  final _telefonoEmpresaController = TextEditingController();
  final _emailEmpresaController = TextEditingController();

  // Variable para la Ciudad (Dropdown)
  String? _ciudadSeleccionada;

  // Lista de ciudades de Colombia
  final List<String> _ciudadesColombia = [
    'Bogotá D.C.',
    'Medellín',
    'Cali',
    'Barranquilla',
    'Cartagena',
    'Bucaramanga',
    'Pereira',
    'Manizales',
    'Cúcuta',
    'Ibagué',
    'Santa Marta',
    'Villavicencio',
    'Pasto',
    'Montería',
    'Valledupar',
    'Armenia',
    'Neiva',
    'Popayán',
    'Sincelejo',
    'Tunja',
    'Riohacha',
    'Florencia',
    'Yopal',
    'Quibdó',
    'Arauca',
    'Mocoa',
    'San Andrés',
    'Leticia',
    'Mitú',
    'Puerto Carreño',
    'Inírida',
    'San José del Guaviare',
    'Otras',
  ];

  // --- Controladores Contacto Administrativo ---
  final _nombreContactoController = TextEditingController();
  final _telefonoContactoController = TextEditingController();
  final _emailContactoController = TextEditingController();

  @override
  void dispose() {
    _razonSocialController.dispose();
    _nitController.dispose();
    _direccionEmpresaController.dispose();
    _telefonoEmpresaController.dispose();
    _emailEmpresaController.dispose();
    _nombreContactoController.dispose();
    _telefonoContactoController.dispose();
    _emailContactoController.dispose();
    super.dispose();
  }

  Future<void> _handleCompanyRequest() async {
    // 1. Validaciones con bloques {} para evitar advertencias
    if (_razonSocialController.text.isEmpty) {
      debugPrint("Falta Razón Social");
    }
    if (_nitController.text.isEmpty) {
      debugPrint("Falta NIT");
    }
    if (_ciudadSeleccionada == null) {
      debugPrint("Falta Ciudad");
    }
    if (_direccionEmpresaController.text.isEmpty) {
      debugPrint("Falta Dirección");
    }
    if (_telefonoEmpresaController.text.isEmpty) {
      debugPrint("Falta Tel Empresa");
    }
    if (_emailEmpresaController.text.isEmpty) {
      debugPrint("Falta Email Empresa");
    }
    if (_nombreContactoController.text.isEmpty) {
      debugPrint("Falta Nombre Contacto");
    }
    if (_telefonoContactoController.text.isEmpty) {
      debugPrint("Falta Tel Contacto");
    }
    if (_emailContactoController.text.isEmpty) {
      debugPrint("Falta Email Contacto");
    }

    // Validación general
    if (_razonSocialController.text.isEmpty ||
        _nitController.text.isEmpty ||
        _ciudadSeleccionada == null ||
        _direccionEmpresaController.text.isEmpty ||
        _telefonoEmpresaController.text.isEmpty ||
        _emailEmpresaController.text.isEmpty ||
        _nombreContactoController.text.isEmpty ||
        _telefonoContactoController.text.isEmpty ||
        _emailContactoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Por favor completa todos los campos de la empresa y del encargado.",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> requestPayload = {
        'tipo_solicitud': 'AFILIACION_EMPRESA',
        'empresa': {
          'razon_social': _razonSocialController.text.trim(),
          'nit': _nitController.text.trim(),
          'ciudad': _ciudadSeleccionada,
          'direccion': _direccionEmpresaController.text.trim(),
          'telefono_corporativo': _telefonoEmpresaController.text.trim(),
          'email_corporativo': _emailEmpresaController.text.trim(),
        },
        'contacto_administrativo': {
          'nombre': _nombreContactoController.text.trim(),
          'telefono_personal': _telefonoContactoController.text.trim(),
          'email_personal': _emailContactoController.text.trim(),
        },
        'estado': 'PENDIENTE_REVISION_HUMANA',
        'fecha_solicitud': DateTime.now().toIso8601String(),
      };

      // Llamada al servicio (Ahora sí existe el método)
      bool success = await AuthService.requestCompanyAffiliation(
        requestPayload,
      );

      if (!mounted) return;

      if (success) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.primaryGreen,
              size: 60,
            ),
            const SizedBox(height: 10),
            Text(
              "¡Solicitud Recibida!",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Hemos registrado la solicitud para ${_razonSocialController.text} en la ciudad de $_ciudadSeleccionada.\n\n"
          "Enviaremos la confirmación al correo: ${_emailEmpresaController.text}.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Cierra dialogo
                Navigator.pop(context); // Vuelve atrás
              },
              child: const Text(
                "Entendido",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Afiliación Corporativa",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- DATOS DE LA EMPRESA ---
              Text(
                "Información de la Empresa",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _razonSocialController,
                "Razón Social",
                Icons.domain,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _nitController,
                "NIT",
                Icons.badge,
                type: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Dropdown
              DropdownButtonFormField<String>(
                initialValue: _ciudadSeleccionada,
                icon: const Icon(Icons.keyboard_arrow_down),
                decoration: InputDecoration(
                  labelText: "Ciudad Sede",
                  prefixIcon: const Icon(
                    Icons.location_city,
                    size: 20,
                    color: Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                items: _ciudadesColombia.map((String ciudad) {
                  return DropdownMenuItem<String>(
                    value: ciudad,
                    child: Text(
                      ciudad,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) =>
                    setState(() => _ciudadSeleccionada = newValue),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _direccionEmpresaController,
                "Dirección",
                Icons.map,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _telefonoEmpresaController,
                "Telefono Corporativo",
                Icons.phone_in_talk,
                type: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _emailEmpresaController,
                "Correo de la Empresa",
                Icons.alternate_email,
                type: TextInputType.emailAddress,
              ),

              const SizedBox(height: 30),
              Divider(color: Colors.grey.shade300, thickness: 1),
              const SizedBox(height: 20),

              // --- CONTACTO ---
              Text(
                "Información del Representante",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _nombreContactoController,
                "Nombre Completo",
                Icons.person,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _telefonoContactoController,
                "Celular Encargado",
                Icons.smartphone,
                type: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _emailContactoController,
                "Email Encargado",
                Icons.email_outlined,
                type: TextInputType.emailAddress,
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCompanyRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors.primaryGreen, // Ajuste al color standard
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Enviar Solicitud",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
