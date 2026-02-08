import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../../home/screens/home_screen.dart';
import 'login_screen.dart';
import 'pending_approval_screen.dart';
import 'welcome_screen.dart';

class VerificationCheckScreen extends StatefulWidget {
  const VerificationCheckScreen({super.key});

  @override
  State<VerificationCheckScreen> createState() =>
      _VerificationCheckScreenState();
}

class _VerificationCheckScreenState extends State<VerificationCheckScreen> {
  UserVerificationStatus? _status;
  User? _currentUser;

  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isCheckingInit = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _checkStatus() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final user = AuthService.currentUser;

    if (user == null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
      return;
    }

    setState(() {
      _currentUser = user;
      _status = user.verificationStatus;
      _isCheckingInit = false;
    });

    if (_status == UserVerificationStatus.VERIFIED) {
      _goToHome();
    }
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (r) => false,
    );
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa el código completo")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // MOCK LOCAL
      await Future.delayed(const Duration(seconds: 2));

      if (code == "123456") {
        if (!mounted) return;
        setState(() {
          _status = UserVerificationStatus.VERIFIED;
        });
        _goToHome();
      } else {
        throw "Código incorrecto (Prueba con 123456)";
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _resendCode() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Enviando nuevo código...")));

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Código reenviado (Mock: usa 123456)"),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Helper para estilo de inputs consistente
  InputDecoration _getOtpInputStyle() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade50,
      counterText: "",
      hintText: "000000",
      hintStyle: GoogleFonts.poppins(
        color: Colors.grey.shade300,
        letterSpacing: 8,
      ),
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
      contentPadding: const EdgeInsets.symmetric(vertical: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingInit) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    if (_status == UserVerificationStatus.PENDING) {
      return _buildOtpScreen();
    }

    if (_status == UserVerificationStatus.CREATED) {
      return PendingApprovalScreen(
        isNatural: false,
        empresaNombre: _currentUser?.empresa ?? "Tu Empresa",
      );
    }

    if (_status == UserVerificationStatus.UNDER_REVIEW) {
      return const PendingApprovalScreen(isNatural: true);
    }

    if (_status == UserVerificationStatus.REJECTED ||
        _status == UserVerificationStatus.REVOKED) {
      return _buildRejectionScreen();
    }

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  // --- PANTALLA OTP CON ESTILO ACTUALIZADO ---
  Widget _buildOtpScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          color: Colors.black,
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              Text(
                "Verifica tu correo",
                style: GoogleFonts.poppins(
                  fontSize: 28, // Tamaño grande consistente
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 40),
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                        text: "Ingresa el código de 6 dígitos enviado a ",
                      ),
                      TextSpan(
                        text: _currentUser?.email ?? "tu correo",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const TextSpan(text: "."),
                    ],
                  ),
                ),
              ),

              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 8,
                  color: Colors.black87,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _getOtpInputStyle(),
                onSubmitted: (_) => _verifyCode(),
              ),

              const SizedBox(height: 50),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
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
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Verificar Código",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 30),

              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _resendCode,
                  child: Text(
                    "¿No recibiste el código? Reenviar",
                    style: GoogleFonts.poppins(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w600,
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

  // --- PANTALLA REJECTION CON ESTILO ACTUALIZADO ---
  Widget _buildRejectionScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // Ícono consistente con PendingScreen pero rojo
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.block, size: 60, color: Colors.red.shade400),
              ),

              const SizedBox(height: 40),

              Text(
                "Acceso Restringido",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE53935),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 40.0),
                child: Text(
                  "Tu solicitud ha sido rechazada o tu cuenta ha sido suspendida. Por favor contacta a soporte para más información.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE53935)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    "Cerrar Sesión",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE53935),
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
