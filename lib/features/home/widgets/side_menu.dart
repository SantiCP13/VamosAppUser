import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

// Importamos el AuthService para sacar el nombre del usuario
import '../../auth/services/auth_service.dart';

// --- IMPORTS DE PANTALLAS ---
import '../../menu/screens/profile_screen.dart';
import '../../menu/screens/history_screen.dart';
import '../../menu/screens/wallet_screen.dart';
import '../../menu/screens/share_referral_screen.dart'; // NUEVO ARCHIVO
import '../../menu/screens/support_screen.dart'; // NUEVO ARCHIVO
import '../../auth/screens/welcome_screen.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos nombre del usuario logueado
    final user = AuthService.currentUser;
    final String nombreMostrar = user['nombre'] ?? "Santi";

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // 1. CABECERA
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hola",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      nombreMostrar,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 2. OPCIONES
          _buildMenuItem(
            context,
            Icons.person_outline,
            "Mi perfil",
            const ProfileScreen(),
          ),

          // "Solicitar viaje" simplemente cierra el menú
          ListTile(
            leading: const Icon(
              Icons.location_on_outlined,
              color: AppColors.primaryGreen,
            ),
            title: Text(
              "Solicitar viaje",
              style: GoogleFonts.poppins(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => Navigator.pop(context),
          ),

          _buildMenuItem(
            context,
            Icons.history,
            "Mis viajes",
            const HistoryScreen(),
          ), // Texto cambiado a "Mis viajes" según foto
          _buildMenuItem(
            context,
            Icons.card_giftcard,
            "Comparte y gana",
            const ShareReferralScreen(),
          ),
          _buildMenuItem(
            context,
            Icons.account_balance_wallet_outlined,
            "Monedero",
            const WalletScreen(),
          ),
          _buildMenuItem(
            context,
            Icons.help_outline,
            "Ayuda",
            const SupportScreen(),
          ),

          const Spacer(),

          // 3. CERRAR SESIÓN
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: () {
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
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                "Cerrar Sesión",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String text,
    Widget destinationScreen,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryGreen),
      title: Text(
        text,
        style: GoogleFonts.poppins(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {
        Navigator.pop(context); // Cierra drawer
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationScreen),
        );
      },
    );
  }
}
