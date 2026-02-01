import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'verification_check_screen.dart';
import '../../home/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _emailExists = false;
  bool _obscurePassword = true;

  Future<void> _handleContinue() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack("Correo inválido", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!_emailExists) {
        // Fase 1: Chequeo de existencia
        bool exists = await AuthService.checkEmailExists(email);
        setState(() => _isLoading = false);

        if (exists) {
          setState(() => _emailExists = true);
        } else {
          _showRegisterDialog(email);
        }
      } else {
        // Fase 2: Login
        final result = await AuthService.login(email, _passwordController.text);

        setState(() => _isLoading = false);

        switch (result['status']) {
          case AuthResponseStatus.active:
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (r) => false,
              );
            }
            break;

          case AuthResponseStatus.pending:
          case AuthResponseStatus.incomplete:
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const VerificationCheckScreen(),
                ),
                (r) => false,
              );
            }
            break;

          case AuthResponseStatus.rejected:
            _showSnack(
              "Tu solicitud fue rechazada por la empresa.",
              isError: true,
            );
            break;

          case AuthResponseStatus.revoked:
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Acceso Revocado"),
                  content: const Text(
                    "Tu empresa ha revocado tus permisos de acceso.\n\n"
                    "Si crees que es un error, contacta a tu administrador.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Entendido",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            }
            break;

          case AuthResponseStatus.wrongPassword:
            _showSnack("Contraseña incorrecta", isError: true);
            break;

          case AuthResponseStatus.notFound:
            _showSnack("Usuario no encontrado", isError: true);
            break;

          default:
            _showSnack("Ocurrió un error inesperado", isError: true);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack("Error de conexión: $e", isError: true);
    }
  }

  void _showRegisterDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cuenta no encontrada"),
        content: const Text(
          "Este correo no está registrado. ¿Deseas crear una cuenta?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RegisterScreen(emailPreIngresado: email),
                ),
              );
            },
            child: const Text(
              "Crear Cuenta",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.black,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // Agregado scroll para evitar overflow en pantallas pequeñas
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _emailExists ? "Hola de nuevo 👋" : "¿Cuál es tu correo?",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 30),

              // --- CAMPO EMAIL ---
              TextField(
                controller: _emailController,
                enabled: !_emailExists,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Correo electrónico",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  suffixIcon: _emailExists
                      ? IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => setState(() {
                            _emailExists = false;
                            _passwordController.clear();
                          }),
                        )
                      : null,
                ),
              ),

              // --- CAMPO PASSWORD ---
              if (_emailExists) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // --- BOTÓN CONTINUAR ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _emailExists ? "Iniciar Sesión" : "Continuar",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              // --- NUEVA SECCIÓN: TEXTO Y BOTÓN DE REGISTRO ---
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "¿No tienes cuenta?",
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                  TextButton(
                    onPressed: () {
                      // Redirige directamente al registro
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          // No pasamos emailPreIngresado porque el usuario quiere empezar de cero
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: Text(
                      "Crea tu cuenta aquí",
                      style: GoogleFonts.poppins(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              // ------------------------------------------------
            ],
          ),
        ),
      ),
    );
  }
}
