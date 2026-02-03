import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final user = AuthService.currentUser;

    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    setState(() {
      _currentUser = user;
      _status = user.verificationStatus;
    });

    if (_status == UserVerificationStatus.VERIFIED) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Cargando
    if (_status == null || _status == UserVerificationStatus.VERIFIED) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    // 2. CASOS DE PENDIENTES (LÓGICA DIVIDIDA)

    // Caso A: Empleado Nuevo (Espera a la empresa)
    if (_status == UserVerificationStatus.CREATED) {
      return PendingApprovalScreen(
        isNatural: false,
        empresaNombre: _currentUser?.empresa ?? "Tu Empresa",
      );
    }

    // Caso B: Natural Nuevo (Espera a VAMOS - Biometría)
    if (_status == UserVerificationStatus.UNDER_REVIEW) {
      return const PendingApprovalScreen(isNatural: true);
    }

    // 3. CASOS DE RECHAZO
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
              _status == UserVerificationStatus.REVOKED
                  ? "Acceso Revocado"
                  : "Solicitud Rechazada",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "Tu perfil no cumple con los requisitos o ha sido desactivado.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.red),
                ),
                child: Text(
                  "Cerrar Sesión",
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
