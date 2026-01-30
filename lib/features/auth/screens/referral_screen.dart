import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../../home/screens/home_screen.dart';

class ReferralCodeScreen extends StatefulWidget {
  const ReferralCodeScreen({super.key});

  @override
  State<ReferralCodeScreen> createState() => _ReferralCodeScreenState();
}

class _ReferralCodeScreenState extends State<ReferralCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _goToHome() {
    // Navegamos al Home borrando todo el historial de Auth
    // (El usuario ya está registrado, con o sin código referido)
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _submitCode() async {
    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Escribe un código para continuar")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Llamamos al servicio
      bool success = await AuthService.sendReferralCode(
        _codeController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("¡Código canjeado correctamente!"),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        _goToHome();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("El código no es válido"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Quitamos el botón de atrás (leading: null) para evitar regresar al registro
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _goToHome,
            child: Text(
              "Omitir",
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // 1. Ícono decorativo amigable
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  size: 50,
                  color: AppColors.primaryGreen,
                ),
              ),

              const SizedBox(height: 30),

              // 2. Títulos claros
              Text(
                "¿Tienes un código de amigo?",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Si alguien te invitó a VAMOS, ingresa su código aquí. Si no, puedes omitir este paso.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              // 3. Input de Código
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  textCapitalization:
                      TextCapitalization.characters, // Fuerza mayúsculas
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: "CÓDIGO AQUÍ",
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey.shade400,
                      letterSpacing: 1,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 4. Nota Aclaratoria (IMPORTANTE para tu negocio)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Este NO es el código de empresa/convenio.",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              // 5. Botón de Acción
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.primaryGreen.withOpacity(0.4),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Validar Código",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Botón secundario Omitir
              TextButton(
                onPressed: _goToHome,
                child: Text(
                  "No tengo código, continuar",
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
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
