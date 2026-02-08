import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'verification_check_screen.dart';

class RegisterNaturalScreen extends StatefulWidget {
  final String? emailPreIngresado;
  const RegisterNaturalScreen({super.key, this.emailPreIngresado});

  @override
  State<RegisterNaturalScreen> createState() => _RegisterNaturalScreenState();
}

class _RegisterNaturalScreenState extends State<RegisterNaturalScreen> {
  bool _isLoading = false;
  bool _obscurePass = true;

  // Controladores
  late TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _docController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  // Estados de Validación Visual
  bool _cedulaUploaded = false;
  bool _biometricVerified = false;

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

  // --- ESTILOS & UTILIDADES ---

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
    // 1. Validaciones de Texto
    if (_nombreController.text.isEmpty ||
        _docController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _telefonoController.text.isEmpty) {
      _showSnack(
        "Por favor completa todos los campos de texto.",
        isError: true,
      );
      return;
    }

    // 2. Validaciones de Biometría
    if (!_cedulaUploaded) {
      _showSnack("Debes tomar la foto de tu cédula.", isError: true);
      return;
    }
    if (!_biometricVerified) {
      _showSnack("Debes completar la verificación facial.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        'tipo_persona': 'NATURAL',
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'nombre': _nombreController.text.trim(),
        'documento': _docController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
      };

      // Llamada al servicio
      bool success = await AuthService.registerNaturalUser(payload);

      if (!mounted) return;

      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const VerificationCheckScreen()),
          (route) => false,
        );
      } else {
        throw Exception("No se pudo completar el registro.");
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll("Exception: ", ""), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _simulateCamera(bool isBiometric) async {
    // Simula carga de cámara
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.pop(context); // Cierra loader

    setState(() {
      if (isBiometric) {
        _biometricVerified = true;
      } else {
        _cedulaUploaded = true;
      }
    });

    _showSnack(isBiometric ? "Biometría completada" : "Cédula guardada");
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
                "Crear cuenta como Natural",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 30),
                child: Text(
                  "Ingresa tus datos y verifica tu identidad para empezar a viajar.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),

              // --- DATOS BÁSICOS ---
              Text(
                "Datos Personales",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.poppins(),
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
              Divider(thickness: 1, color: Colors.grey[200]),
              const SizedBox(height: 20),

              // --- VERIFICACIÓN ---
              Text(
                "Seguridad y Verificación",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Pasos obligatorios para validar tu identidad.",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 15),

              // Tarjeta 1: Cédula
              _buildVerificationCard(
                title: "Foto de Cédula",
                subtitle: "Toma una foto clara de tu documento",
                icon: Icons.credit_card,
                isDone: _cedulaUploaded,
                onTap: () => _simulateCamera(false),
              ),

              const SizedBox(height: 12),

              // Tarjeta 2: Biometría
              _buildVerificationCard(
                title: "Verificación Facial",
                subtitle: "Selfie para validar que eres tú",
                icon: Icons.face,
                isDone: _biometricVerified,
                onTap: () => _simulateCamera(true),
              ),

              const SizedBox(height: 40),

              // --- BOTÓN FINAL ---
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
                          "Crear Cuenta",
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

  Widget _buildVerificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? AppColors.primaryGreen : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDone)
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          // Icono Circular
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDone ? Colors.white : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check : icon,
              color: isDone ? AppColors.primaryGreen : Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Textos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDone ? AppColors.primaryGreen : Colors.black87,
                  ),
                ),
                if (!isDone)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Botón de Acción (si no está hecho)
          if (!isDone)
            IconButton(
              onPressed: onTap,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primaryGreen,
              ),
            ),
        ],
      ),
    );
  }
}
