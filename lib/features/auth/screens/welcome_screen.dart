import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../../home/screens/home_screen.dart';
import 'login_screen.dart';
import 'company_register_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = true;
  // --- EL INTERRUPTOR ---
  bool _hasShownAlert = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _launchWhatsApp() async {
    // Reemplaza el número con el de la empresa (formato internacional sin el +)
    // Ejemplo: 57 es Colombia, seguido del número.
    final String phoneNumber = "573001234567";
    final String message = "Hola Vamos App, necesito soporte con mi cuenta.";

    final Uri url = Uri.parse(
      "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}",
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("No se pudo abrir WhatsApp");
    }
  }

  Future<void> _checkSession() async {
    final hasSession = await AuthService.tryAutoLogin();
    if (hasSession && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // --- LÓGICA DE ALERTA CORREGIDA ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // 1. Leemos los argumentos
      final args = ModalRoute.of(context)?.settings.arguments;

      // 2. Verificamos: ¿Hay mensaje? ¿Y no lo hemos mostrado ya?
      if (args != null && args is String && !_hasShownAlert) {
        // 3. Marcamos que ya se mostró para que no se repita
        _hasShownAlert = true;
        ScaffoldMessenger.of(context).clearSnackBars();
        // 4. Mostramos el cartel
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(args),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                // <--- PERMITE EL DESPLAZAMIENTO
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // <--- IMPORTANTE
                    children: [
                      const SizedBox(height: 40), // CAMBIADO: Antes era Spacer
                      Hero(
                        tag: 'logo',
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: size.width * 0.65,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.directions_bus,
                                size: 100,
                                color: AppColors.primaryGreen,
                              ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Bienvenido a Vamos App",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Viaja seguro, puntual y con el mejor servicio de movilidad del país.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40), // CAMBIADO: Antes era Spacer
                      Text(
                        "SELECCIONA TU PERFIL",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color.fromARGB(255, 141, 141, 141),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildRoleButton(
                        context,
                        label: "Registrar mi Empresa",
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
                      const SizedBox(height: 16),
                      _buildRoleButton(
                        context,
                        label: "Soy Pasajero",
                        subLabel: "Viaja con Nosotros",
                        icon: Icons.person_outline,
                        isPrimary: true,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextButton.icon(
                        onPressed: _launchWhatsApp,
                        icon: const Icon(
                          Icons.chat_bubble_outline, // O Icons.forum
                          color: Color.fromARGB(255, 2, 185, 33),
                          size: 24,
                        ),
                        label: Text(
                          "Soporte Técnico",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color.fromARGB(255, 2, 185, 33),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
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
    final bgColor = isPrimary ? AppColors.primaryGreen : Colors.white;
    final fgColor = isPrimary ? Colors.white : AppColors.primaryGreen;
    final borderColor = isPrimary ? Colors.transparent : AppColors.primaryGreen;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          elevation: isPrimary ? 3 : 0,
          side: isPrimary ? null : BorderSide(color: borderColor, width: 1.5),
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
