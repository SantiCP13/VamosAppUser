import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/services/auth_service.dart';
import '../../menu/screens/profile_screen.dart';
import '../../menu/screens/history_screen.dart';
import '../../menu/screens/support_screen.dart';
import '../../auth/screens/welcome_screen.dart';

class SideMenu extends StatelessWidget {
  final Function(bool) onToggleMode;

  const SideMenu({super.key, required this.onToggleMode});

  Future<void> _handleLogout(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
    );

    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pop(context);

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const WelcomeScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    // CLAVE: Leemos el estado real del objeto usuario que blindamos en los pasos anteriores
    final bool isCorp = user?.isCorporateMode ?? false;
    final String nombreMostrar = user?.name ?? "Usuario";
    final String inicial = nombreMostrar.isNotEmpty
        ? nombreMostrar[0].toUpperCase()
        : "U";

    // Colores dinámicos según el modo
    final Color activeThemeColor = isCorp
        ? const Color(0xFF0D47A1)
        : AppColors.primaryGreen;

    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        children: [
          // 1. CABECERA PREMIUM
          Container(
            padding: const EdgeInsets.fromLTRB(25, 60, 25, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Avatar con anillo de estado dinámico
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: activeThemeColor, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: activeThemeColor.withValues(alpha: 0.1),
                    backgroundImage:
                        (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: (user?.photoUrl == null || user!.photoUrl!.isEmpty)
                        ? Text(
                            inicial,
                            style: GoogleFonts.montserrat(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: activeThemeColor,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  nombreMostrar,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.darkBlue,
                    letterSpacing: -0.5,
                  ),
                ),
                if (isCorp)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      user?.empresa ?? "Empresa Vinculada",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D47A1),
                      ),
                    ),
                  )
                else
                  Text(
                    user?.email ?? "",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                const SizedBox(height: 25),

                // SWITCHER DE PERFIL TIPO "SEGMENTED"
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      _buildQuickProfileOption(
                        context,
                        label: "Personal",
                        isActive: !isCorp,
                        activeColor: AppColors.primaryGreen,
                        icon: Icons.person_rounded,
                        onTap: () {
                          if (isCorp) {
                            Navigator.pop(context);
                            onToggleMode(false);
                          }
                        },
                      ),
                      _buildQuickProfileOption(
                        context,
                        label: "Empresa",
                        isActive: isCorp,
                        activeColor: const Color(0xFF0D47A1),
                        icon: Icons.business_rounded,
                        onTap: () {
                          if (!isCorp) {
                            Navigator.pop(context);
                            onToggleMode(true);
                          }
                        },
                        isLocked: user?.canUseCorporateMode == false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. OPCIONES DE MENÚ
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 25),
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.person_outline_rounded,
                  text: "Mi Perfil",
                  destinationScreen: const ProfileScreen(),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.history_rounded,
                  text: "Mis Viajes",
                  destinationScreen: const HistoryScreen(),
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.headset_mic_outlined,
                  text: "Soporte VAMOS",
                  destinationScreen: const SupportScreen(),
                ),
              ],
            ),
          ),

          // 3. FOOTER
          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _handleLogout(context),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Cerrar Sesión",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            color: Colors.redAccent,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Opacity(
                  opacity: 0.4,
                  child: Image.asset('assets/images/logo.png', height: 40),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickProfileOption(
    BuildContext context, {
    required String label,
    required bool isActive,
    required Color activeColor,
    required IconData icon,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
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
                isLocked && !isActive ? Icons.lock_outline_rounded : icon,
                size: 16,
                color: isActive ? activeColor : Colors.grey.shade400,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? AppColors.darkBlue : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Widget destinationScreen,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destinationScreen),
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.darkBlue, size: 20),
        ),
        title: Text(
          text,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlue,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 12,
          color: Colors.grey,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
