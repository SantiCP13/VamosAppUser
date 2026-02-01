// lib/features/menu/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_model.dart'; // Asegúrate de importar tu modelo
import '../../auth/services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    // Valores seguros
    final userName = user?.name ?? "Usuario";
    final userPhone = (user?.phone != null && user!.phone.isNotEmpty)
        ? user.phone
        : "Sin teléfono";
    final userEmail = user?.email ?? "Sin email";
    final userId = user?.id ?? "Unknown";

    final String userInitial = userName.isNotEmpty
        ? userName[0].toUpperCase()
        : "U";

    return Scaffold(
      backgroundColor: Colors.white,
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
              backgroundColor: Colors.deepOrangeAccent.shade100,
              backgroundImage: const NetworkImage(
                "https://via.placeholder.com/150",
              ),
              child: userName != "Usuario"
                  ? null
                  : Text(
                      userInitial,
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 16),

            // --- NOMBRE ---
            Text(
              userName,
              style: GoogleFonts.poppins(
                fontSize: 22,
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),

            // --- TITULO ---
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

            // --- TELEFONO Y ESTADO ---
            _buildInfoTile(
              icon: Icons.phone,
              text: userPhone,
              trailing: _buildVerificationBadge(user?.verificationStatus),
            ),
            const Divider(height: 1),

            // --- EMAIL ---
            _buildInfoTile(
              icon: Icons.email,
              text: userEmail,
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
            const Divider(height: 1),

            const SizedBox(height: 40),

            // --- BOTON ELIMINAR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {},
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
              "ID: $userId",
              style: GoogleFonts.poppins(color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Construye el badge de estado (Verificado, Pendiente, etc.)
  Widget _buildVerificationBadge(UserVerificationStatus? status) {
    String label;
    Color color;

    switch (status) {
      case UserVerificationStatus.VERIFIED:
        label = "Verificado";
        color = AppColors.primaryGreen;
        break;
      case UserVerificationStatus.UNDER_REVIEW:
        label = "En revisión";
        color = Colors.orange;
        break;
      case UserVerificationStatus.DOCS_UPLOADED:
        label = "Docs subidos";
        color = Colors.blue;
        break;
      case UserVerificationStatus.REJECTED:
        label = "Rechazado";
        color = Colors.red;
        break;
      case UserVerificationStatus.REVOKED:
        label = "Revocado";
        color = Colors.red;
        break;
      case UserVerificationStatus.CREATED:
      default:
        label = "Sin verificar";
        color = Colors.grey;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.circle, size: 8, color: color),
      ],
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
