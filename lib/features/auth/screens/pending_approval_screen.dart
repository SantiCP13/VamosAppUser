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
    // Configuración dinámica de textos y colores
    final String titulo = isNatural
        ? "Validando Identidad"
        : "¡Solicitud Enviada!";
    final String validador = isNatural ? "el equipo de VAMOS" : "tu empresa";
    final IconData icono = isNatural
        ? Icons.fingerprint
        : Icons.mark_email_read_outlined;
    final Color colorIcono = isNatural
        ? Colors.purple
        : const Color.fromARGB(255, 7, 32, 56);
    final Color colorFondoIcono = isNatural
        ? Colors.purple.shade50
        : Colors.blue.shade50;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícono Principal
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: colorFondoIcono,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: 60, color: colorIcono),
              ),
              const SizedBox(height: 32),

              // Título
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Descripción
              if (isNatural)
                Text(
                  "Hemos recibido tus documentos y datos biométricos. Nuestro equipo de seguridad está validando tu información para activar tu cuenta.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                )
              else
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: "Tu solicitud para unirte a "),
                      TextSpan(
                        text: empresaNombre ?? "tu empresa",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: " ha sido enviada correctamente."),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Tarjeta de Información
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: isNatural ? Colors.purple : Colors.orange,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Tiempo estimado",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isNatural
                          ? "La validación biométrica suele tomar menos de 24 horas."
                          : "Depende de la aprobación del administrador de $validador.",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Botón Volver
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
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Volver al Inicio",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
