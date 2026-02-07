import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart'; // Asegúrate que la ruta sea correcta
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? emailPreloadded;

  const ForgotPasswordScreen({super.key, this.emailPreloadded});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final PageController _pageController = PageController();

  // Controladores
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  int _currentStep = 0; // 0: Email, 1: OTP, 2: New Password

  @override
  void initState() {
    super.initState();
    if (widget.emailPreloadded != null) {
      _emailController.text = widget.emailPreloadded!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- LOGICA DE PASOS ---

  // PASO 1: Enviar correo
  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack("Ingresa un correo válido", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final success = await AuthService.sendPasswordRecoveryEmail(email);
    setState(() => _isLoading = false);

    if (success) {
      _showSnack("Código enviado. (Para pruebas usa: 1234)");
      _nextPage();
    } else {
      _showSnack("El correo no está registrado.", isError: true);
    }
  }

  // PASO 2: Verificar Código
  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      _showSnack("Código inválido", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final success = await AuthService.verifyRecoveryToken(email, code);
    setState(() => _isLoading = false);

    if (success) {
      _nextPage();
    } else {
      _showSnack("Código incorrecto. Intenta con 1234", isError: true);
    }
  }

  // PASO 3: Cambiar Contraseña
  Future<void> _changePassword() async {
    final p1 = _passController.text;
    final p2 = _confirmPassController.text;

    if (p1.isEmpty || p1.length < 3) {
      _showSnack("La contraseña es muy corta", isError: true);
      return;
    }
    if (p1 != p2) {
      _showSnack("Las contraseñas no coinciden", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final success = await AuthService.changePassword(email, p1);
    setState(() => _isLoading = false);

    if (success) {
      _showSnack("¡Contraseña actualizada! Inicia sesión.");
      if (mounted) Navigator.pop(context); // Vuelve al Login
    } else {
      _showSnack("Error al actualizar. Intenta de nuevo.", isError: true);
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          color: Colors.black,
          onPressed: () {
            if (_currentStep > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          "Recuperar Cuenta",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Indicador de pasos simple
            LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: Colors.grey.shade100,
              color: AppColors.primaryGreen, // Usa tu variable AppColors
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics:
                    const NeverScrollableScrollPhysics(), // Evita deslizar con el dedo
                children: [
                  _buildEmailStep(),
                  _buildOtpStep(),
                  _buildNewPasswordStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET PASO 1
  Widget _buildEmailStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "¿Olvidaste tu contraseña?",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Ingresa tu correo para recibir un código de recuperación.",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(
              "Correo electrónico",
              Icons.email_outlined,
            ),
          ),
          const Spacer(),
          _buildButton("Enviar Código", _sendCode),
        ],
      ),
    );
  }

  // WIDGET PASO 2
  Widget _buildOtpStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Verifica tu identidad",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Hemos enviado un código a ${_emailController.text}",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: _inputDecoration(
              "Código (Ej: 1234)",
              Icons.lock_clock_outlined,
            ).copyWith(counterText: ""),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => _showSnack("Código reenviado (Simulado)"),
              child: Text(
                "¿No recibiste el código?",
                style: TextStyle(color: AppColors.primaryGreen),
              ),
            ),
          ),
          const Spacer(),
          _buildButton("Verificar", _verifyCode),
        ],
      ),
    );
  }

  // WIDGET PASO 3
  Widget _buildNewPasswordStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Nueva Contraseña",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Crea una contraseña segura para tu cuenta.",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _passController,
            obscureText: _obscurePass,
            decoration: _inputDecoration("Nueva contraseña", Icons.lock_outline)
                .copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _confirmPassController,
            obscureText: _obscurePass,
            decoration: _inputDecoration(
              "Confirmar contraseña",
              Icons.verified_user_outlined,
            ),
          ),
          const Spacer(),
          _buildButton("Actualizar Contraseña", _changePassword),
        ],
      ),
    );
  }

  // ESTILOS COMUNES
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
