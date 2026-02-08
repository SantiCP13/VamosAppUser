import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'login_screen.dart';

class PendingApprovalScreen extends StatelessWidget {
  final bool isNatural; // true = valida Vamos, false = valida Empresa
  final String? empresaNombre; // Solo necesario si isNatural es false

  const PendingApprovalScreen({
    super.key,
    this.isNatural = false,
    this.empresaNombre,
  });

  @override
  Widget build(BuildContext context) {
    // --- LÓGICA DE COLORES Y TEXTOS ---

    // Aquí asignamos el color principal según tu solicitud:
    final Color themeColor = isNatural
        ? AppColors.primaryGreen
        : AppColors.bgColor;

    final String titulo = isNatural
        ? "Validando Identidad"
        : "¡Solicitud Enviada!";

    final String validador = isNatural ? "el equipo de VAMOS" : "tu empresa";

    final IconData icono = isNatural
        ? Icons.fingerprint
        : Icons.mark_email_read_outlined;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // ÍCONO PRINCIPAL
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  // Usamos el color del tema con baja opacidad para el fondo del círculo
                  color: themeColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icono,
                  size: 60,
                  color: themeColor, // Color principal
                ),
              ),

              const SizedBox(height: 40),

              // TÍTULO
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: themeColor, // Color principal
                ),
              ),

              // DESCRIPCIÓN
              Padding(
                padding: const EdgeInsets.only(top: 12.0, bottom: 40.0),
                child: isNatural
                    ? Text(
                        "Hemos recibido tus documentos y datos biométricos. Nuestro equipo de seguridad está validando tu información para activar tu cuenta.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      )
                    : RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: "Tu solicitud para unirte a "),
                            TextSpan(
                              text: empresaNombre ?? "tu empresa",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const TextSpan(
                              text: " ha sido enviada correctamente.",
                            ),
                          ],
                        ),
                      ),
              ),

              // TARJETA DE INFORMACIÓN DE TIEMPO
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_filled,
                          color:
                              themeColor, // Icono del reloj con el color del tema
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Tiempo estimado",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isNatural
                            ? "La validación biométrica suele tomar menos de 24 horas."
                            : "Depende de la aprobación del administrador de $validador.",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              // BOTÓN DE VOLVER
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (r) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        themeColor, // Color del texto y efecto ripple
                    side: BorderSide(
                      color: themeColor,
                      width: 2,
                    ), // Color del borde
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Volver al Inicio",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
