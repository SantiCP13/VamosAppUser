import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'login_screen.dart';
import 'company_register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: Stack(
        children: [
          // Decoración de fondo
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 130,
              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.08),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Logo
                  Hero(
                    tag: 'logo',
                    child: Image.asset(
                      'assets/images/logo.png', // Asegúrate de tener este asset
                      width: size.width * 0.65,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.directions_bus,
                        size: 100,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    "Bienvenido a VAMOS",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Movilidad legal y segura bajo la modalidad de Transporte Especial.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),

                  const Spacer(flex: 3),

                  Text(
                    "Selecciona tu perfil para continuar:",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // BOTÓN 1: PASAJERO / EMPLEADO
                  _buildRoleButton(
                    context,
                    label: "Soy Pasajero / Empleado",
                    subLabel: "Viajes particulares o con código corporativo",
                    icon: Icons.person_outline,
                    isPrimary: true,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // BOTÓN 2: EMPRESA (CONTRATANTE)
                  _buildRoleButton(
                    context,
                    label: "Soy Empresa",
                    subLabel: "Quiero contratar servicios para mi personal",
                    icon: Icons.domain,
                    isPrimary: false,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CompanyRegisterScreen(),
                      ),
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(
    BuildContext context, {
    required String label,
    required String subLabel,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppColors.primaryGreen : Colors.white,
          foregroundColor: isPrimary ? Colors.white : AppColors.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          elevation: isPrimary ? 3 : 0,
          side: isPrimary
              ? null
              : const BorderSide(color: AppColors.primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPrimary
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isPrimary
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isPrimary ? Colors.white : AppColors.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }
}
