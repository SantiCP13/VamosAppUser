import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'verification_check_screen.dart';
import 'widgets/company_selector_widget.dart';

class RegisterScreen extends StatefulWidget {
  final String? emailPreIngresado;
  const RegisterScreen({super.key, this.emailPreIngresado});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isLoading = false;

  late TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _docController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  String? _selectedCompanyName;
  String? _selectedCompanyNit;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.emailPreIngresado);
  }

  Future<void> _handleRegister() async {
    // 1. Validar Campos Personales
    if (_nombreController.text.isEmpty ||
        _docController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _telefonoController.text.isEmpty) {
      _showError("Por favor completa todos los datos personales.");
      return;
    }

    // 2. Validar Selección de Empresa
    if (_selectedCompanyName == null || _selectedCompanyNit == null) {
      _showError("Es obligatorio seleccionar una empresa.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        'tipo_persona': 'CORPORATIVO',
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'nombre': _nombreController.text.trim(),
        'documento': _docController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'nombre_empresa': _selectedCompanyName,
        'nit_empresa': _selectedCompanyNit,
      };

      // 3. Llamada al Servicio
      bool success = await AuthService.registerCorporateUser(payload);

      if (!mounted) return;

      if (success) {
        // FLUJO CORRECTO: Navegar a VerificationCheckScreen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const VerificationCheckScreen()),
          (route) => false,
        );
      } else {
        throw Exception("Error al procesar el registro corporativo.");
      }
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Widget _input(
    TextEditingController c,
    String label,
    IconData icon, {
    bool isPass = false,
    TextInputType type = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: c,
          obscureText: isPass,
          keyboardType: type,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 15,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Crear Cuenta",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Datos Personales",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 20),

              _input(
                _nombreController,
                "Nombre Completo",
                Icons.person_outline,
              ),
              const SizedBox(height: 15),
              _input(
                _docController,
                "Número de Cédula",
                Icons.badge_outlined,
                type: TextInputType.number,
              ),
              const SizedBox(height: 15),
              _input(
                _telefonoController,
                "Celular",
                Icons.phone_android_outlined,
                type: TextInputType.phone,
              ),
              const SizedBox(height: 15),
              _input(_direccionController, "Dirección", Icons.map_outlined),
              const SizedBox(height: 15),
              _input(
                _emailController,
                "Correo Electrónico",
                Icons.email_outlined,
                type: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              _input(
                _passwordController,
                "Contraseña",
                Icons.lock_outline,
                isPass: true,
              ),

              const SizedBox(height: 30),
              Divider(color: Colors.grey[300], thickness: 1),
              const SizedBox(height: 20),

              Text(
                "Vinculación Laboral",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Selecciona tu empresa para activar tu perfil corporativo.",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 15),

              CompanySelectorWidget(
                onCompanySelected: (name, nit) {
                  setState(() {
                    _selectedCompanyName = name.isNotEmpty ? name : null;
                    _selectedCompanyNit = nit.isNotEmpty ? nit : null;
                  });
                },
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          "Completar Registro",
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
}
