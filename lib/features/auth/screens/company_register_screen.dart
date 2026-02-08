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

  // --- CONTROLADORES ---
  final _razonSocialController = TextEditingController();
  final _nitController = TextEditingController();
  final _direccionEmpresaController = TextEditingController();
  final _telefonoEmpresaController = TextEditingController();
  final _emailEmpresaController = TextEditingController();

  String? _ciudadSeleccionada;

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
    'Otras',
  ];

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
    // Validación básica
    if (_razonSocialController.text.isEmpty ||
        _nitController.text.isEmpty ||
        _ciudadSeleccionada == null ||
        _direccionEmpresaController.text.isEmpty ||
        _telefonoEmpresaController.text.isEmpty ||
        _emailEmpresaController.text.isEmpty ||
        _nombreContactoController.text.isEmpty ||
        _telefonoContactoController.text.isEmpty ||
        _emailContactoController.text.isEmpty) {
      // USAMOS EL NUEVO AVISO
      _showSnack(
        "Por favor completa todos los campos obligatorios.",
        isError: true,
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

      bool success = await AuthService.requestCompanyAffiliation(
        requestPayload,
      );

      if (!mounted) return;

      if (success) {
        _showSuccessDialog();
      } else {
        // USAMOS EL NUEVO AVISO
        _showSnack("Error al enviar solicitud.", isError: true);
      }
    } catch (e) {
      if (mounted) {
        // USAMOS EL NUEVO AVISO
        _showSnack("Error: $e", isError: true);
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
          "Datos registrados correctamente. Un asesor te contactará pronto.",
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
                Navigator.pop(context);
                Navigator.pop(context);
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

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError
            ? const Color(0xFFE53935)
            : AppColors.primaryGreen,
        elevation: 6,
        content: Row(
          children: [
            Icon(
              isError ? Icons.cancel_outlined : Icons.check_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                "Afiliación Corporativa",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Completa el formulario para registrar tu empresa.",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // --- SECCIÓN 1 ---
              _buildSectionTitle("Información Legal"),
              const SizedBox(height: 16),

              _buildTextField(
                _razonSocialController,
                "Razón Social",
                Icons.domain,
                capitalization:
                    TextCapitalization.words, // Mayúsculas automáticas
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _nitController,
                "NIT",
                Icons.badge,
                type: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Dropdown Ciudad - MEJORADO VISUALMENTE
              DropdownButtonFormField<String>(
                initialValue: _ciudadSeleccionada,
                isExpanded:
                    true, // Esto evita errores si el nombre de la ciudad es muy largo
                menuMaxHeight:
                    350, // Limita la altura para que se vea como un menú elegante
                icon: const Icon(
                  Icons
                      .keyboard_arrow_down_rounded, // Icono de flecha más suave
                  color: AppColors.primaryGreen,
                ),
                decoration: _getInputDecoration(
                  "Ciudad Sede",
                  Icons.location_city,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(16),
                items: _ciudadesColombia.map((String ciudad) {
                  return DropdownMenuItem<String>(
                    value: ciudad,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ciudad,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _ciudadSeleccionada = val),
              ),

              const SizedBox(height: 16),
              _buildTextField(
                _direccionEmpresaController,
                "Dirección Principal",
                Icons.map,
                capitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _telefonoEmpresaController,
                "Teléfono Fijo",
                Icons.phone_in_talk,
                type: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _emailEmpresaController,
                "Email Corporativo",
                Icons.alternate_email,
                type: TextInputType.emailAddress,
              ),

              const SizedBox(height: 30),
              Divider(color: Colors.grey.shade200, thickness: 2),
              const SizedBox(height: 30),

              // --- SECCIÓN 2 ---
              _buildSectionTitle("Administrador de Cuenta"),
              const SizedBox(height: 16),

              _buildTextField(
                _nombreContactoController,
                "Nombre Completo",
                Icons.person,
                capitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _telefonoContactoController,
                "Celular Contacto",
                Icons.smartphone,
                type: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _emailContactoController,
                "Email Personal",
                Icons.email_outlined,
                type: TextInputType.emailAddress,
              ),

              const SizedBox(height: 40),

              // BOTÓN (CORREGIDO)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCompanyRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 4,
                    // CORRECCIÓN 2: Se reemplazó .withOpacity() por .withValues(alpha: ...)
                    shadowColor: AppColors.primaryGreen.withValues(alpha: 0.4),
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: Colors.grey.shade500,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      textCapitalization: capitalization,
      textInputAction: TextInputAction.next,
      decoration: _getInputDecoration(label, icon),
    );
  }

  InputDecoration _getInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.grey.shade600,
      ),
      prefixIcon: Icon(icon, size: 20, color: AppColors.primaryGreen),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
