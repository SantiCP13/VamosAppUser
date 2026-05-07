// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  final String whatsappNumber = "+573001234567";
  final String supportEmail = "soporte@vamosapp.com.co";

  Future<void> _launchWhatsApp() async {
    final link =
        "https://wa.me/$whatsappNumber?text=Hola VAMOS, necesito ayuda con mi cuenta de usuario.";
    if (!await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    )) {
      debugPrint('No se pudo abrir WhatsApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. FONDO GRADIENTE RADIAL
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.5,
                colors: [Colors.white, Color(0xFFF1F5F9)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(context),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // 2. HEADER ILUSTRATIVO
                        _buildSupportHeader(),

                        const SizedBox(height: 40),

                        _sectionLabel("CANALES DE CONTACTO"),
                        const SizedBox(height: 15),

                        // 3. TARJETA WHATSAPP (INSTANTÁNEA)
                        _buildGlassSupportCard(
                          title: "Chat Inmediato",
                          subtitle: "Asistencia vía WhatsApp",
                          caption: "Respuesta en < 5 min",
                          icon: Icons.chat_bubble_rounded,
                          accentColor: AppColors.primaryGreen,
                          onTap: _launchWhatsApp,
                          isLive: true,
                        ),

                        const SizedBox(height: 16),

                        // 4. TARJETA EMAIL
                        _buildGlassSupportCard(
                          title: "Correo Electrónico",
                          subtitle: supportEmail,
                          caption: "Casos administrativos",
                          icon: Icons.alternate_email_rounded,
                          accentColor: AppColors.primaryGreen,
                          onTap: () =>
                              launchUrl(Uri.parse("mailto:$supportEmail")),
                        ),

                        const SizedBox(height: 40),

                        // 5. FOOTER DE SEGURIDAD
                        _buildSecurityNote(),

                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black54,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
          Text(
            "CENTRO DE AYUDA",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 2,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSupportHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
            const Icon(
              Icons.headset_mic_rounded,
              size: 60,
              color: AppColors.primaryGreen,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          "¿Cómo podemos\nayudarte hoy?",
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.darkBlue,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Nuestro equipo está listo para asistirte\nen cada paso de tu viaje.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.blueGrey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryGreen,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildGlassSupportCard({
    required String title,
    required String subtitle,
    required String caption,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    bool isLive = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkBlue,
                            ),
                          ),
                          if (isLive) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF25D366),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                      Text(
                        caption,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.blueGrey.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Nunca solicitaremos tus contraseñas o códigos de seguridad por estos canales.",
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
