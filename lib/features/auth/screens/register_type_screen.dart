import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'register_screen.dart'; // Tu registro corporativo actual
import 'register_natural_screen.dart'; // El nuevo registro natural

class RegisterTypeScreen extends StatelessWidget {
  final String? emailPreIngresado;

  const RegisterTypeScreen({super.key, this.emailPreIngresado});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Elige tu perfil",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              "¿Cómo deseas registrarte en Vamos?",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[700]),
            ),
            const SizedBox(height: 30),

            // OPCIÓN 1: CORPORATIVO (Existente)
            _OptionCard(
              icon: Icons.business_center_outlined,
              title: "Empleado Corporativo",
              subtitle:
                  "Vincúlate con el código o NIT de tu empresa para viajes de negocios.",
              color: Colors.blue.shade50,
              iconColor: Colors.blue.shade800,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RegisterScreen(emailPreIngresado: emailPreIngresado),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // OPCIÓN 2: NATURAL (Nuevo)
            _OptionCard(
              icon: Icons.person_outline,
              title: "Usuario Particular",
              subtitle:
                  "Viaja por tu cuenta. Necesitarás tu cédula para validar tu identidad.",

              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              iconColor: AppColors.primaryGreen,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterNaturalScreen(
                      emailPreIngresado: emailPreIngresado,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Widget auxiliar para las tarjetas
class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              // CORRECCIÓN 2: Usar withValues(alpha: ...)
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
