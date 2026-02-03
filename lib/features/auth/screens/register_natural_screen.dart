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

  // Lógica de Registro
  Future<void> _handleRegister() async {
    // 1. Validaciones de Texto
    if (_nombreController.text.isEmpty ||
        _docController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showError("Por favor completa todos los campos de texto.");
      return;
    }

    // 2. Validaciones de Biometría
    if (!_cedulaUploaded) {
      _showError("Debes tomar la foto de tu cédula para continuar.");
      return;
    }
    if (!_biometricVerified) {
      _showError("Debes completar la verificación facial.");
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

      // Llamada al servicio (Registro Natural)
      bool success = await AuthService.registerNaturalUser(payload);

      if (!mounted) return;

      if (success) {
        // Éxito -> Ir a verificación (que mostrará pendiente de VAMOS)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const VerificationCheckScreen()),
          (route) => false,
        );
      } else {
        throw Exception("Error al crear la cuenta. Intente nuevamente.");
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // Simulación de Cámara (Aquí integrarías tu SDK de biometría en el futuro)
  Future<void> _simulateCamera(bool isBiometric) async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulando proceso...

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (isBiometric) {
        _biometricVerified = true;
      } else {
        _cedulaUploaded = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isBiometric
              ? "Biometría completada exitosamente"
              : "Cédula guardada correctamente",
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Widget auxiliar para inputs
  Widget _input(
    TextEditingController c,
    String label,
    IconData icon, {
    bool isPass = false,
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: c,
        obscureText: isPass,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  // Widget auxiliar para tarjetas de verificación
  Widget _verificationCard(
    String title,
    String subtitle,
    IconData icon,
    bool isDone,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: isDone ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDone ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDone ? Colors.green : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDone ? Colors.green : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDone ? Icons.check : icon,
                color: isDone ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    isDone ? "Completado" : subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (!isDone)
              const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primaryGreen,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Registro Personal",
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Datos Básicos",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 15),

              _input(
                _nombreController,
                "Nombre Completo",
                Icons.person_outline,
              ),
              _input(
                _docController,
                "Número de Cédula",
                Icons.badge_outlined,
                type: TextInputType.number,
              ),
              _input(
                _telefonoController,
                "Celular",
                Icons.phone_android,
                type: TextInputType.phone,
              ),
              _input(_direccionController, "Dirección", Icons.map_outlined),
              _input(
                _emailController,
                "Correo Electrónico",
                Icons.email_outlined,
                type: TextInputType.emailAddress,
              ),
              _input(
                _passwordController,
                "Contraseña",
                Icons.lock_outline,
                isPass: true,
              ),

              const SizedBox(height: 20),
              Divider(thickness: 1, color: Colors.grey[200]),
              const SizedBox(height: 20),

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
                "Estos pasos son obligatorios para validar tu identidad como particular.",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 15),

              // 1. Tarjeta Cédula
              _verificationCard(
                "Foto de Cédula",
                "Toma una foto clara de tu documento",
                Icons.credit_card,
                _cedulaUploaded,
                () => _simulateCamera(false),
              ),

              // 2. Tarjeta Biometría
              _verificationCard(
                "Verificación Facial",
                "Selfie para validar que eres tú",
                Icons.face,
                _biometricVerified,
                () => _simulateCamera(true),
              ),

              const SizedBox(height: 30),

              // Botón Final
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
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
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
            ],
          ),
        ),
      ),
    );
  }
}
