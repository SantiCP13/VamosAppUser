// lib/features/menu/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos los datos actuales de la "sesión"
    final user = AuthService.currentUser;

    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco como en la foto
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.close,
            color: AppColors.primaryGreen,
            size: 30,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // --- AVATAR ---
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.deepOrangeAccent.shade100, // Tono naranja
              backgroundImage: const NetworkImage(
                "https://via.placeholder.com/150",
              ),
              // Si no hay imagen, usa un color sólido o iniciales:
              child: user['nombre'] != null
                  ? null
                  : Text(
                      user['nombre'][0],
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 16),

            // --- NOMBRE ---
            Text(
              user['nombre'] ?? "Usuario",
              style: GoogleFonts.poppins(
                fontSize: 22,
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),

            // --- TITULO SECCION ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Mi perfil",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- DATOS TELEFONO ---
            _buildInfoTile(
              icon: Icons.phone,
              text: user['telefono'] ?? "Sin teléfono",
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Verificado",
                    style: GoogleFonts.poppins(
                      color: AppColors.primaryGreen,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
            const Divider(height: 1),

            // --- DATOS EMAIL ---
            _buildInfoTile(
              icon: Icons.email,
              text: user['email'] ?? "Sin email",
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
            const Divider(height: 1),

            const SizedBox(height: 40),

            // --- BOTON ELIMINAR CUENTA ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    // Lógica para eliminar cuenta
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Eliminar cuenta",
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              "100000001", // Versión o ID
              style: GoogleFonts.poppins(color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String text,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
