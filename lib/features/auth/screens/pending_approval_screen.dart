import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
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
    final Color accentColor = isNatural
        ? AppColors.primaryGreen
        : AppColors.darkBlue;
    final IconData mainIcon = isNatural
        ? Icons.fingerprint_rounded
        : Icons.business_center_rounded;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. FONDO RADIAL PREMIUM
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.45),
                radius: 1.8,
                colors: [Color(0xFFFFFFFF), Color(0xFFE6E8EB)],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const Spacer(),

                  // 2. ICONO ANIMADO CON GLASS EFFECT
                  _buildAnimatedIcon(accentColor, mainIcon),

                  const SizedBox(height: 40),

                  // 3. TEXTOS EN MONTSERRAT
                  Text(
                    isNatural ? "Validando Identidad" : "Solicitud Corporativa",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                      letterSpacing: -1,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Text(
                    isNatural
                        ? "Hemos recibido tus documentos de forma segura. Nuestro equipo está verificando tu biometría para activar tu cuenta."
                        : "Tu solicitud para vincularte a ${empresaNombre ?? 'tu empresa'} ha sido enviada al administrador del portal corporativo.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 4. TARJETA DE INFORMACIÓN GLASS
                  _buildGlassInfoCard(accentColor),

                  const Spacer(),

                  // 5. BOTÓN DE RETORNO
                  _buildSubmitButton(context, accentColor),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedIcon(Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(icon, size: 70, color: color),
    );
  }

  Widget _buildGlassInfoCard(Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time_filled_rounded, color: color, size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  "Tiempo estimado de respuesta: 24 horas hábiles.",
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkBlue.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, Color color) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (r) => false,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: Text(
          "ENTENDIDO",
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
