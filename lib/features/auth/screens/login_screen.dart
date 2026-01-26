import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart'; // Importamos el servicio simulado
import 'register_screen.dart';
import '../../home/screens/home_screen.dart'; // Asegúrate de importar la home

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores de texto
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Variables de estado
  bool _isLoading = false; // Para mostrar ruedita de carga
  bool _emailExists = false; // ¿Ya verificamos que el email existe?

  Future<void> _handleContinue() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) return; // Validación básica

    setState(() => _isLoading = true);

    if (!_emailExists) {
      // FASE 1: VERIFICAR EMAIL
      // Aquí llamamos a nuestro servicio (Simulando Laravel)
      bool exists = await AuthService.checkEmailExists(email);

      if (mounted) {
        setState(() => _isLoading = false);
        if (exists) {
          // Si existe, mostramos el campo de contraseña
          setState(() => _emailExists = true);
        } else {
          // Si NO existe, mandamos a Registro
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegisterScreen(emailPreIngresado: email),
            ),
          );
        }
      }
    } else {
      // FASE 2: INICIAR SESIÓN (Ya mostró contraseña)
      bool loginSuccess = await AuthService.login(
        email,
        _passwordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (loginSuccess) {
          // Navegar al Home y borrar historial para no volver al login
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _emailExists ? "Ingresa tu contraseña" : "¿Cuál es tu e-mail?",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _emailExists
                    ? "Hola de nuevo, $_emailController.text"
                    : "Verificaremos si tienes cuenta.",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // CAMPO EMAIL (Se deshabilita si ya lo encontramos)
              TextField(
                controller: _emailController,
                enabled: !_emailExists, // Bloquear si ya pasamos a contraseña
                decoration: InputDecoration(
                  labelText: "E-mail",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),

              // CAMPO CONTRASEÑA (Solo aparece si el email existe)
              if (_emailExists) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // BOTÓN DE ACCIÓN
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkButton,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _emailExists ? "Iniciar Sesión" : "Continuar",
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
        ),
      ),
    );
  }
}
