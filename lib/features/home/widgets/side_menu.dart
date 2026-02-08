import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/services/auth_service.dart';

// --- IMPORTS DE PANTALLAS ---
import '../../menu/screens/profile_screen.dart';
import '../../menu/screens/history_screen.dart';
import '../../menu/screens/support_screen.dart';
import '../../auth/screens/welcome_screen.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final String nombreMostrar = user?.name ?? "Usuario";
    final String inicial = nombreMostrar.isNotEmpty
        ? nombreMostrar[0].toUpperCase()
        : "U";

    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      // Consistencia: Radio de borde alineado al estilo general
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 1. CABECERA PERSONALIZADA
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 40, 24, 30),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar con estilo similar a los iconos del WelcomeScreen
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      inicial,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Textos de usuario
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hola,",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            // Mismo gris que el subtítulo del Welcome
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          nombreMostrar,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),

                        // Badge Empresa (Mantenemos lógica, ajustamos estilo)
                        if (user?.isCorporateMode == true &&
                            user?.empresa != null &&
                            user!.empresa.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              user.empresa,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.blue[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Separador sutil
            Divider(
              height: 1,
              indent: 28,
              endIndent: 28,
              color: Colors.grey.shade200,
            ),
            const SizedBox(height: 24),

            // 2. OPCIONES DEL MENÚ
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                ), // Margen lateral consistente
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.person_outline,
                    text: "Mi perfil",
                    destinationScreen: const ProfileScreen(),
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    context,
                    icon: Icons.history,
                    text: "Mis viajes",
                    destinationScreen: const HistoryScreen(),
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    context,
                    icon: Icons.help_outline,
                    text: "Ayuda y Soporte",
                    destinationScreen: const SupportScreen(),
                  ),
                ],
              ),
            ),

            // 3. BOTÓN CERRAR SESIÓN
            // Diseño idéntico al botón primario "Soy Pasajero" del WelcomeScreen
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Lógica de logout
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WelcomeScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ), // Padding ajustado
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        16,
                      ), // Radio consistente
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icono con fondo translúcido (Igual que WelcomeScreen)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.logout,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Cerrar Sesión",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Item de Menú
  /// Sigue el estilo visual de los botones "Secundarios" pero sin borde,
  /// usando el icono con fondo verde translúcido.
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Widget destinationScreen,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destinationScreen),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              // Icono en caja (Style System)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primaryGreen, size: 22),
              ),
              const SizedBox(width: 16),

              // Texto
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Flecha sutil
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
