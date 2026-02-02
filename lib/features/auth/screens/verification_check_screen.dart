import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../../home/screens/home_screen.dart';
import 'login_screen.dart'; // Asegúrate de tener este import para el logout

class VerificationCheckScreen extends StatefulWidget {
  const VerificationCheckScreen({super.key});

  @override
  State<VerificationCheckScreen> createState() =>
      _VerificationCheckScreenState();
}

class _VerificationCheckScreenState extends State<VerificationCheckScreen> {
  UserVerificationStatus? _status;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() async {
    // Simulamos una pequeña carga para validar sesión
    await Future.delayed(const Duration(milliseconds: 500));

    final user = AuthService.currentUser;

    if (user == null) {
      // Si no hay usuario, volvemos al login
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    setState(() {
      _status = user.verificationStatus;
    });

    // Si ya está verificado, pasamos directo al Home
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
    // Si aún carga o pasa al home
    if (_status == null || _status == UserVerificationStatus.VERIFIED) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    // UI DE BLOQUEO SEGÚN ESTADO
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatusIcon(),
            const SizedBox(height: 30),
            Text(
              _getTitle(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              _getMessage(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // Botón de Acción (Logout o Subir Docs)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // Aquí podrías implementar LogOut real
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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

  Widget _buildStatusIcon() {
    switch (_status) {
      case UserVerificationStatus.UNDER_REVIEW:
        return Icon(Icons.history_edu, size: 80, color: Colors.orange[300]);
      case UserVerificationStatus.CREATED:
      case UserVerificationStatus.DOCS_UPLOADED:
        return Icon(Icons.upload_file, size: 80, color: Colors.blue[300]);
      case UserVerificationStatus.REJECTED:
      case UserVerificationStatus.REVOKED:
        return Icon(Icons.block, size: 80, color: Colors.red[300]);
      default:
        return const Icon(Icons.error, size: 80);
    }
  }

  String _getTitle() {
    switch (_status) {
      case UserVerificationStatus.UNDER_REVIEW:
        return "Perfil en Revisión";
      case UserVerificationStatus.CREATED:
        return "Faltan Documentos";
      case UserVerificationStatus.DOCS_UPLOADED:
        return "Documentos Subidos";
      case UserVerificationStatus.REJECTED:
        return "Solicitud Rechazada";
      case UserVerificationStatus.REVOKED:
        return "Acceso Revocado";
      default:
        return "Estado Desconocido";
    }
  }

  String _getMessage() {
    switch (_status) {
      case UserVerificationStatus.UNDER_REVIEW:
        return "Estamos validando tu identidad. Te notificaremos cuando puedas viajar.";
      case UserVerificationStatus.CREATED:
        return "Para cumplir con la normativa legal, necesitamos copia de tu cédula. Por favor contacta a soporte.";
      case UserVerificationStatus.DOCS_UPLOADED:
        return "Hemos recibido tus documentos. Estamos procesando la validación.";
      case UserVerificationStatus.REJECTED:
        return "Lamentablemente tu perfil no cumple con los requisitos de seguridad de VAMOS.";
      case UserVerificationStatus.REVOKED:
        return "Tu empresa ha desactivado tu cuenta corporativa. Contacta a tu administrador.";
      default:
        return "";
    }
  }
}
