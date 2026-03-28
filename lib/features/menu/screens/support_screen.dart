import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  // Configuración de contacto
  final String whatsappNumber = "+573001234567"; // Número de tu central
  final String supportEmail = "soporte@vamosapp.com";

  Future<void> _launchWhatsApp() async {
    final link =
        "https://wa.me/$whatsappNumber?text=Hola VamosApp, necesito ayuda con mi cuenta.";
    if (!await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    )) {
      throw 'No se pudo abrir WhatsApp';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ayuda y Soporte"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(
              Icons.headset_mic_outlined,
              size: 80,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: 20),
            Text(
              "¿En qué podemos ayudarte?",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),

            _buildSupportCard(
              title: "Chat vía WhatsApp",
              subtitle: "Respuesta inmediata (8am - 10pm)",
              icon: Icons.chat_bubble_outline,
              onTap: _launchWhatsApp,
            ),
            const SizedBox(height: 16),
            _buildSupportCard(
              title: "Correo Electrónico",
              subtitle: supportEmail,
              icon: Icons.email_outlined,
              onTap: () => launchUrl(Uri.parse("mailto:$supportEmail")),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryGreen),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
