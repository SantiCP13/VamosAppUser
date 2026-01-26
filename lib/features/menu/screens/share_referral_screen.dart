// lib/features/menu/screens/share_referral_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para copiar al portapapeles
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class ShareReferralScreen extends StatelessWidget {
  const ShareReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const String myReferralCode = "4ce22140";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Comparte y gana",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              "¡Gana Premios Exclusivos con Tu Código de Referido!",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "En VamosApp, ganar premios es fácil. Comparte tu código de referido y acumula referidos para obtener aún más premios.",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 24),

            // --- BOTÓN VERDE CON CÓDIGO ---
            InkWell(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: myReferralCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Código copiado al portapapeles"),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF66BB6A,
                  ), // Verde claro similar a la foto
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      myReferralCode,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.copy, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            // Ilustración (Personas sentadas)
            SizedBox(
              height: 120,
              child: Icon(Icons.groups, size: 100, color: Colors.grey.shade300),
            ),

            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Historial de recompensas",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // --- ESTADISTICAS (CAJAS) ---
            Row(
              children: [
                Expanded(child: _buildStatBox("\$ 0 COP", "Últimos 30 días")),
                const SizedBox(width: 16),
                Expanded(child: _buildStatBox("0", "Total referidos")),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
