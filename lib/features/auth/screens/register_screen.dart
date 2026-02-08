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
  bool _obscurePass = true; // Agregado para consistencia con otras pantallas

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nombreController.dispose();
    _docController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  // --- ESTILOS VISUALES UNIFICADOS ---

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.cancel_outlined : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.poppins())),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFE53935)
            : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  InputDecoration _getInputStyle({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
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
      suffixIcon: suffixIcon,
    );
  }

  // --- LÓGICA ---

  Future<void> _handleRegister() async {
    // 1. Validar Campos Personales
    if (_nombreController.text.isEmpty ||
        _docController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _telefonoController.text.isEmpty) {
      _showSnack("Completa todos los datos personales.", isError: true);
      return;
    }

    // 2. Validar Selección de Empresa
    if (_selectedCompanyName == null || _selectedCompanyNit == null) {
      _showSnack("Selecciona una empresa.", isError: true);
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const VerificationCheckScreen()),
          (route) => false,
        );
      } else {
        throw Exception("Error al procesar el registro.");
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll("Exception: ", ""), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Encabezado H1
              Text(
                "Crear cuenta como Empleado",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bgColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 30),
                child: Text(
                  "Ingresa tus datos y vincula tu cuenta a tu empresa.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),

              // --- SECCIÓN 1: DATOS PERSONALES ---
              Text(
                "Datos Personales",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bgColor,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _nombreController,
                style: GoogleFonts.poppins(),
                textCapitalization: TextCapitalization.words,
                decoration: _getInputStyle(
                  label: "Nombre Completo",
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _docController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(),
                decoration: _getInputStyle(
                  label: "Número de Cédula",
                  icon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.poppins(),
                decoration: _getInputStyle(
                  label: "Celular",
                  icon: Icons.phone_android_outlined,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _direccionController,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.poppins(),
                decoration: _getInputStyle(
                  label: "Dirección",
                  icon: Icons.map_outlined,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.poppins(),
                decoration: _getInputStyle(
                  label: "Correo Electrónico",
                  icon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePass,
                style: GoogleFonts.poppins(),
                decoration: _getInputStyle(
                  label: "Contraseña",
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              Divider(color: Colors.grey[200], thickness: 2),
              const SizedBox(height: 20),

              // --- SECCIÓN 2: EMPRESA ---
              Text(
                "Vinculación Laboral",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.bgColor,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Busca y selecciona tu empresa:",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 15),

              // Nota: Asegúrate de que el CompanySelectorWidget también use
              // GoogleFonts.poppins internamente para consistencia total.
              CompanySelectorWidget(
                onCompanySelected: (name, nit) {
                  setState(() {
                    _selectedCompanyName = name.isNotEmpty ? name : null;
                    _selectedCompanyNit = nit.isNotEmpty ? nit : null;
                  });
                },
              ),

              const SizedBox(height: 40),

              // --- BOTÓN PRINCIPAL ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.primaryGreen.withValues(alpha: 0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Registrarme",
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
