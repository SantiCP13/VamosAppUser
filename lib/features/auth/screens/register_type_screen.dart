import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'register_screen.dart';
import 'register_natural_screen.dart';

class RegisterTypeScreen extends StatelessWidget {
  final String? emailPreIngresado;

  const RegisterTypeScreen({super.key, this.emailPreIngresado});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.white, // O AppColors.bgColor si prefieres el gris muy suave
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Título Grande Estilo H1
              Text(
                "Elige tu perfil",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 40),
                child: Text(
                  "Selecciona cómo ingresar a la plataforma para personalizar tu experiencia.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),

              // OPCIÓN 1: CORPORATIVO
              _OptionCard(
                icon: Icons.business_center_outlined,
                title: "Empleado Corporativo",
                subtitle:
                    "Vincúlate con tu empresa para gestionar viajes Corporativos.",
                // Usamos un azul corporativo pero suavizado, o podrías usar el Green si prefieres todo verde
                accentColor: const Color(0xFF1976D2),
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

              // OPCIÓN 2: NATURAL
              _OptionCard(
                icon: Icons.person_outline,
                title: "Usuario Natural",
                subtitle:
                    "Viaja por tu cuenta. Gestiona tus propios trayectos.",
                accentColor: AppColors.primaryGreen,
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
      ),
    );
  }
}

// Widget auxiliar rediseñado
class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Sombra suave similar a la elevación de los botones
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          // Efecto visual al presionar usando el color de acento
          splashColor: accentColor.withValues(alpha: 0.1),
          highlightColor: accentColor.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Ícono con fondo circular suave
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 28, color: accentColor),
                ),
                const SizedBox(width: 16),

                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w600, // Semi-bold para jerarquía
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.4, // Mejor legibilidad
                        ),
                      ),
                    ],
                  ),
                ),

                // Flecha indicadora
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
