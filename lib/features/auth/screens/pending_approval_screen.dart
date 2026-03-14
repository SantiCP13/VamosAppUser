import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'login_screen.dart';

class PendingApprovalScreen extends StatelessWidget {
  final bool isNatural;
  final String? empresaNombre;

  const PendingApprovalScreen({
    super.key,
    this.isNatural = true,
    this.empresaNombre,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          // Evaluamos cuál diseño mostrar:
          child: isNatural ? _buildNatural(context) : _buildCorporate(context),
        ),
      ),
    );
  }

  // ==========================================
  // 🌿 DISEÑO PARA USUARIO NATURAL (Verde / Biometría)
  // ==========================================
  Widget _buildNatural(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.fingerprint,
            size: 70,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 30),
        Text(
          "Validando Identidad",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 40.0),
          child: Text(
            "Hemos recibido tu documento y fotografía biométrica de forma segura. Nuestro equipo está verificando tus datos para activar tu cuenta.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ),
        _buildInfoCard(
          icon: Icons.shield_outlined,
          color: AppColors.primaryGreen,
          title: "Seguridad VAMOS",
          subtitle:
              "La validación de perfil suele tomar menos de 24 horas hábiles.",
        ),
        const SizedBox(height: 50),
        _buildBackButton(context, AppColors.primaryGreen),
      ],
    );
  }

  // ==========================================
  // 🏢 DISEÑO PARA USUARIO CORPORATIVO (Azul Oscuro / Empresa)
  // ==========================================
  Widget _buildCorporate(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: AppColors.bgColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.business_center_outlined,
            size: 70,
            color: AppColors.bgColor,
          ),
        ),
        const SizedBox(height: 30),
        Text(
          "Solicitud Corporativa",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.bgColor,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 40.0),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              children: [
                const TextSpan(
                  text: "Tu solicitud para vincularte a la empresa\n",
                ),
                TextSpan(
                  text: empresaNombre ?? "tu corporación",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                ),
                const TextSpan(text: "\nha sido notificada con éxito."),
              ],
            ),
          ),
        ),
        _buildInfoCard(
          icon: Icons.access_time_filled,
          color: AppColors.bgColor,
          title: "Aprobación Pendiente",
          subtitle:
              "Tan pronto verifiquemos tu solicitud, podrás acceder a tu cuenta.",
        ),
        const SizedBox(height: 50),
        _buildBackButton(context, AppColors.bgColor),
      ],
    );
  }

  // ==========================================
  // WIDGETS REUTILIZABLES PARA AMBOS DISEÑOS
  // ==========================================
  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (r) => false,
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          "Volver al Inicio",
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
