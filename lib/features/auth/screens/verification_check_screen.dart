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
    // Solución advertencia async gap: verificar mounted
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
      // MOCK LOCAL (Activo para MVP)
      await Future.delayed(const Duration(seconds: 2));

      if (code == "123456") {
        if (!mounted) return; // Seguridad extra
        setState(() {
          _status = UserVerificationStatus.VERIFIED;
        });
        _goToHome();
      } else {
        throw "Código incorrecto (Prueba con 123456)";
      }
    } catch (e) {
      // ========================================================
      // SOLUCIÓN ADVERTENCIA AZUL:
      // Verificamos si el widget sigue "montado" antes de usar context
      // ========================================================
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resendCode() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Enviando nuevo código...")));

    await Future.delayed(const Duration(seconds: 1));

    // Verificación de seguridad
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Código reenviado (Mock: usa 123456)")),
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

    // AHORA EL ENUM 'PENDING' YA EXISTIRÁ EN TU MODELO
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

    // Fallback
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _buildOtpScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
              Text(
                "Verifica tu correo",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  children: [
                    const TextSpan(text: "Ingresa el código enviado a "),
                    TextSpan(
                      text: _currentUser?.email ?? "tu correo",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "000000",
                  hintStyle: TextStyle(color: Colors.grey[300]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: (_) => _verifyCode(),
              ),

              const SizedBox(height: 40),

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
                          "Verificar Código",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _resendCode,
                  child: Text(
                    "¿No recibiste el código? Reenviar",
                    style: GoogleFonts.poppins(color: AppColors.primaryGreen),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectionScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 80, color: Colors.red[300]),
            const SizedBox(height: 30),
            Text(
              "Acceso Restringido",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "Tu cuenta ha sido rechazada o suspendida.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),
            OutlinedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              },
              child: const Text("Cerrar Sesión"),
            ),
          ],
        ),
      ),
    );
  }
}
