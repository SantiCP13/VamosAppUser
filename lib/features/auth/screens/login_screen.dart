import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../../home/screens/home_screen.dart';
import 'forgot_password_screen.dart';
import 'register_type_screen.dart';
import 'verification_check_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _storage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _emailExists = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final savedEmail = await _storage.read(key: 'saved_email_user');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
        _emailExists = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showSnack("Por favor ingresa un correo válido", isError: true);
      return;
    }

    if (!_emailExists) {
      setState(() => _emailExists = true);
      Future.delayed(const Duration(milliseconds: 100), () {
        _passwordFocusNode.requestFocus();
      });
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showSnack("Ingresa tu contraseña", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.login(email, _passwordController.text);

      if (_rememberMe) {
        await _storage.write(key: 'saved_email_user', value: email);
      } else {
        await _storage.delete(key: 'saved_email_user');
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      final status = result['status'];
      if (status == AuthResponseStatus.active) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (r) => false,
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VerificationCheckScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final errorMsg = e.toString().replaceFirst('Exception: ', '');

      if (errorMsg.toLowerCase().contains('registrado') ||
          errorMsg.toLowerCase().contains('encontrado')) {
        setState(() => _emailExists = false);
        _showRegisterDialog(email);
      } else {
        _showSnack(errorMsg, isError: true);
        _passwordController.clear();
        _passwordFocusNode.requestFocus();
      }
    }
  }

  void _showRegisterDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cuenta no encontrada"),
        content: Text(
          "El correo $email no está registrado. ¿Deseas crear una cuenta nueva?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Reintentar"),
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
                  builder: (_) => RegisterTypeScreen(emailPreIngresado: email),
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
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 30, left: 40, right: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError
            ? const Color(0xFFE53935)
            : AppColors.primaryGreen,
        content: Text(
          msg,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _emailExists ? "Hola de nuevo!" : "¿Cuál es tu correo?",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                readOnly: _emailExists,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Correo electrónico",
                  prefixIcon: const Icon(
                    Icons.alternate_email,
                    color: AppColors.primaryGreen,
                  ),
                  suffixIcon: _emailExists
                      ? IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => setState(() => _emailExists = false),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_emailExists) ...[
                TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppColors.primaryGreen,
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: AppColors.primaryGreen,
                      onChanged: (val) =>
                          setState(() => _rememberMe = val ?? false),
                    ),
                    Text(
                      "Recordar correo",
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordScreen(
                            emailPreloadded: _emailController.text,
                          ),
                        ),
                      ),
                      child: Text(
                        "¿Olvidaste tu contraseña?",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 30),
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              // --- NUEVA SECCIÓN: BOTÓN DE REGISTRO ---
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "¿No tienes una cuenta? ",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegisterTypeScreen(
                            emailPreIngresado: _emailController.text.trim(),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      "Regístrate",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
