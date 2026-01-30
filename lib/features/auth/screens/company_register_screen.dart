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

  // Controladores Empresa
  final _razonSocialController = TextEditingController();
  final _nitController = TextEditingController();
  final _direccionEmpresaController = TextEditingController();

  // Controladores Contacto
  final _nombreContactoController =
      TextEditingController(); // Quien llena el form
  final _telefonoContactoController = TextEditingController();
  final _emailContactoController = TextEditingController();

  Future<void> _handleCompanyRequest() async {
    // Validaciones
    if (_razonSocialController.text.isEmpty ||
        _nitController.text.isEmpty ||
        _nombreContactoController.text.isEmpty ||
        _telefonoContactoController.text.isEmpty ||
        _emailContactoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Por favor completa todos los campos para la solicitud",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> requestPayload = {
        'tipo_solicitud': 'AFILIACION_EMPRESA', // Flag para tu backend
        'empresa': {
          'razon_social': _razonSocialController.text.trim(),
          'nit': _nitController.text.trim(),
          'direccion': _direccionEmpresaController.text.trim(),
        },
        'contacto': {
          'nombre': _nombreContactoController.text.trim(),
          'telefono': _telefonoContactoController.text.trim(),
          'email': _emailContactoController.text.trim(),
        },
        'estado': 'PENDIENTE_REVISION_HUMANA', // Estado inicial
      };

      // Llamamos al servicio (Simulado)
      bool success = await AuthService.requestCompanyAffiliation(
        requestPayload,
      );

      if (success && mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
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
          "Hemos recibido los datos de ${_razonSocialController.text}.\n\n"
          "Un ejecutivo de cuenta de VAMOS APP se contactará contigo al ${_telefonoContactoController.text} en las próximas 24 horas para validar el contrato y habilitar tu acceso corporativo.",
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
                Navigator.pop(context); // Cierra Dialog
                Navigator.pop(context); // Regresa al WelcomeScreen
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
              // Banner Informativo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.business_center,
                      color: Colors.blue.shade700,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Solicitud de Convenio",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          Text(
                            "Este formulario inicia el proceso de validación jurídica. No creará una cuenta inmediata.",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
                "NIT (Sin dígito ver.)",
                Icons.badge,
                type: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _direccionEmpresaController,
                "Dirección Fiscal",
                Icons.map,
              ),

              const SizedBox(height: 30),

              Text(
                "Contacto Administrativo",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "A quién contactaremos para la firma del contrato.",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                _nombreContactoController,
                "Nombre del Encargado",
                Icons.person,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _telefonoContactoController,
                "Celular de Contacto",
                Icons.phone,
                type: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _emailContactoController,
                "Correo Corporativo",
                Icons.email,
                type: TextInputType.emailAddress,
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCompanyRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkButton,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Enviar Solicitud de Afiliación",
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
