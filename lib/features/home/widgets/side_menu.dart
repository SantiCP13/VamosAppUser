import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/services/auth_service.dart';
import '../../menu/screens/profile_screen.dart';
import '../../menu/screens/history_screen.dart';
import '../../menu/screens/support_screen.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../payment/screens/payment_methods_screen.dart';

class SideMenu extends StatelessWidget {
  final Function(bool) onToggleMode;

  const SideMenu({super.key, required this.onToggleMode});

  Future<void> _handleLogout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final String nombreMostrar = user?.name ?? "Usuario";
    final String inicial = nombreMostrar.isNotEmpty
        ? nombreMostrar[0].toUpperCase()
        : "U";

    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        children: [
          // 1. CABECERA CENTRALIZADA (Header con Logo y Foto)
          Container(
            padding: const EdgeInsets.fromLTRB(24, 50, 24, 25),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade50, width: 1),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO ESTRATÉGICO (Superior Central)

                // FOTO DE PERFIL CENTRADA Y MÁS GRANDE (100x100)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryGreen.withValues(alpha: 0.08),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    image:
                        (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(user.photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                      ? Center(
                          child: Text(
                            inicial,
                            style: GoogleFonts.poppins(
                              fontSize: 40, // Más grande para balancear
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        )
                      : null,
                ),

                const SizedBox(height: 16),

                // NOMBRE DEBAJO DE LA FOTO
                Text(
                  nombreMostrar,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 25),

                // SWITCHER DE PERFIL (Pill Style mejorado)
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildQuickProfileOption(
                        context,
                        label: "Personal",
                        isActive: user?.isCorporateMode == false,
                        activeColor: AppColors.primaryGreen,
                        icon: Icons.person_rounded,
                        onTap: () {
                          Navigator.pop(context);
                          onToggleMode(false);
                        },
                      ),
                      const SizedBox(width: 4),
                      if (user?.canUseCorporateMode == true)
                        _buildQuickProfileOption(
                          context,
                          label: "Corporativo",
                          isActive: user?.isCorporateMode == true,
                          activeColor: const Color(
                            0xFF0D47A1,
                          ), // Azul más profundo
                          icon: Icons.business_center_rounded,
                          onTap: () {
                            Navigator.pop(context);
                            onToggleMode(true);
                          },
                        )
                      else
                        _buildLinkAction(context),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. LISTADO DE OPCIONES
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.account_circle_outlined,
                  text: "Mi Perfil",
                  destinationScreen: const ProfileScreen(),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.local_activity_outlined,
                  text: "Historial de Viajes",
                  destinationScreen: const HistoryScreen(),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.payment_rounded,
                  text: "Métodos de Pago",
                  destinationScreen:
                      const PaymentMethodsScreen(), // Importa la pantalla creada
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.help_outline_rounded,
                  text: "Soporte y Ayuda",
                  destinationScreen: const SupportScreen(),
                ),
              ],
            ),
          ),

          // 3. PIE DE PÁGINA (Branding & Logout)
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 0, 30, 40),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => _handleLogout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(
                        255,
                        33,
                        1,
                        97,
                      ), // Fondo suave
                      foregroundColor: const Color.fromARGB(
                        255,
                        255,
                        255,
                        255,
                      ), // Texto e Icono
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: const Color.fromARGB(255, 1, 169, 23),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          "Cerrar Sesión",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Image.asset(
                  'assets/images/logo.png',
                  height: 75,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(height: 35),
                ),

                const SizedBox(height: 10),
                Text(
                  "VAMOS APP © 2026",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget de Opción de Switcher (Diseño Horizontal Centrado)
  Widget _buildQuickProfileOption(
    BuildContext context, {
    required String label,
    required bool isActive,
    required Color activeColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? activeColor : Colors.grey.shade500,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? Colors.black87 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget del Listado con Hover sutil
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Widget destinationScreen,
  }) {
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationScreen),
        );
      },
      leading: Icon(icon, color: Colors.black45, size: 22),
      title: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    );
  }

  // Widget para Vincular Empresa (Action Style)
  Widget _buildLinkAction(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          onToggleMode(true); // Abrirá el modal en el Home
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 16,
              color: Colors.blue.shade800,
            ),
            const SizedBox(width: 6),
            Text(
              "Vincular",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
