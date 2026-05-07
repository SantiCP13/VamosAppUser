import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? emailPreloadded;

  const ForgotPasswordScreen({super.key, this.emailPreloadded});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final PageController _pageController = PageController();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  int _currentStep = 0;
  int _cooldownSeconds = 0;

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

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _cooldownSeconds--);
      return _cooldownSeconds > 0;
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: isError ? Colors.redAccent : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- LÓGICA DE PASOS ---

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack("Ingresa un correo válido", isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.sendPasswordResetCode(email);
      setState(() => _isLoading = false);
      _showSnack("Código enviado a $email");
      _startCooldown();
      if (_currentStep == 0) _nextPage();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      _showSnack("El código debe tener 6 dígitos", isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.verifyPasswordResetCode(
        _emailController.text.trim(),
        code,
      );
      setState(() => _isLoading = false);
      _nextPage();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _changePassword() async {
    final p1 = _passController.text;
    final p2 = _confirmPassController.text;
    if (p1.length < 8) {
      _showSnack(
        "La contraseña debe tener al menos 8 caracteres",
        isError: true,
      );
      return;
    }
    if (p1 != p2) {
      _showSnack("Las contraseñas no coinciden", isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.resetPassword(
        _emailController.text.trim(),
        _otpController.text.trim(),
        p1,
      );
      setState(() => _isLoading = false);
      _showSnack("¡Contraseña actualizada! Inicia sesión.");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutExpo,
    );
    setState(() => _currentStep++);
  }

  // --- ESTILOS VISUALES (IGUAL AL LOGIN DE USUARIO) ---

  InputDecoration _getLightInputStyle({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.montserrat(
        color: Colors.blueGrey.shade300,
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, color: AppColors.primaryGreen, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade100),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.black87,
                size: 18,
              ),
              onPressed: () {
                if (_currentStep > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutExpo,
                  );
                  setState(() => _currentStep--);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. FONDO CON GRADIENTE LIGHT
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [Colors.white, Color(0xFFF1F5F9)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Barra de progreso elegante
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 3,
                      backgroundColor: Colors.grey.shade100,
                      color: AppColors.primaryGreen,
                      minHeight: 6,
                    ),
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStepContainer(_buildEmailStep()),
                      _buildStepContainer(_buildOtpStep()),
                      _buildNewPasswordStep(), // Directo sin container para mejor scroll
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContainer(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40),
      child: child,
    );
  }

  // --- WIDGETS DE PASOS ---

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "RECUPERACIÓN",
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryGreen,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Buscaremos tu cuenta para enviarte un código de seguridad por correo.",
          style: GoogleFonts.montserrat(
            fontSize: 15,
            color: Colors.blueGrey,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: _getLightInputStyle(
            label: "Correo electrónico",
            icon: Icons.alternate_email,
          ),
        ),
        const SizedBox(height: 50),
        _buildActionButton("CONTINUAR", _sendCode),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "VERIFICACIÓN",
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryGreen,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Ingresa el código enviado al correo:",
          style: GoogleFonts.montserrat(fontSize: 14, color: Colors.blueGrey),
        ),
        Text(
          _emailController.text,
          style: GoogleFonts.montserrat(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 28,
            letterSpacing: 10,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
          decoration: _getLightInputStyle(
            label: "Código OTP",
            icon: Icons.security_rounded,
          ).copyWith(counterText: ""),
        ),
        const SizedBox(height: 20),
        Center(
          child: _cooldownSeconds > 0
              ? Text(
                  "Reenviar en $_cooldownSeconds s",
                  style: GoogleFonts.montserrat(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                )
              : TextButton(
                  onPressed: _sendCode,
                  child: Text(
                    "¿No recibiste el código? REENVIAR",
                    style: GoogleFonts.montserrat(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 30),
        _buildActionButton("VERIFICAR CÓDIGO", _verifyCode),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "NUEVA CLAVE",
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryGreen,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Crea una contraseña segura de al menos 8 caracteres.",
            style: GoogleFonts.montserrat(fontSize: 15, color: Colors.blueGrey),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _passController,
            obscureText: _obscurePass,
            decoration: _getLightInputStyle(
              label: "Contraseña nueva",
              icon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePass ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade400,
                ),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _confirmPassController,
            obscureText: _obscurePass,
            decoration: _getLightInputStyle(
              label: "Confirmar contraseña",
              icon: Icons.verified_user_outlined,
            ),
          ),
          const SizedBox(height: 50),
          _buildActionButton("ACTUALIZAR Y ENTRAR", _changePassword),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }
}
