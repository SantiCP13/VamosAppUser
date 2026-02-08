import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
// Pantallas de navegación según el estado del usuario
import 'register_type_screen.dart';
import 'verification_check_screen.dart';
import '../../home/screens/home_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // CONTROLADORES: Manejan el texto que el usuario escribe
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // FOCUS NODE
  final _passwordFocusNode = FocusNode();

  // ESTADOS DE LA UI
  bool _isLoading = false;
  bool _emailExists = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// LÓGICA CENTRAL DEL LOGIN
  Future<void> _handleContinue() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showSnack("Por favor ingresa un correo válido", isError: true);
      return;
    }

    if (_emailExists && _passwordController.text.isEmpty) {
      _showSnack("Ingresa tu contraseña", isError: true);
      _passwordFocusNode.requestFocus();
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!_emailExists) {
        // FASE 1: Verificar existencia del correo
        bool exists = await AuthService.checkEmailExists(email);

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (exists) {
          setState(() {
            _emailExists = true;
          });
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              FocusScope.of(context).requestFocus(_passwordFocusNode);
            }
          });
        } else {
          _showRegisterDialog(email);
        }
      } else {
        // FASE 2: Iniciar Sesión
        final result = await AuthService.login(email, _passwordController.text);

        if (!mounted) return;
        setState(() => _isLoading = false);

        final status = result['status'];

        switch (status) {
          case AuthResponseStatus.active:
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (r) => false,
            );
            break;
          case AuthResponseStatus.pending:
          case AuthResponseStatus.underReview:
          case AuthResponseStatus.incomplete:
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const VerificationCheckScreen(),
              ),
              (r) => false,
            );
            break;
          case AuthResponseStatus.rejected:
            _showSnack("Tu solicitud ha sido rechazada.", isError: true);
            break;
          case AuthResponseStatus.revoked:
            _showSnack("Acceso revocado. Contacta soporte.", isError: true);
            break;
          case AuthResponseStatus.wrongPassword:
            _showSnack("Contraseña incorrecta", isError: true);
            _passwordController.clear();
            _passwordFocusNode.requestFocus();
            break;
          case AuthResponseStatus.notFound:
            _showSnack("Usuario no encontrado", isError: true);
            setState(() => _emailExists = false);
            break;
          case AuthResponseStatus.networkError:
            _showSnack("Error de conexión.", isError: true);
            break;
          default:
            _showSnack("Ocurrió un error inesperado", isError: true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack("Error crítico: $e", isError: true);
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
            child: const Text(
              "Reintentar",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              elevation: 0,
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
            ? const Color(0xFFE53935) // Un rojo material design suave
            : AppColors.primaryGreen,

        elevation: 6,
        content: Row(
          children: [
            Icon(
              isError ? Icons.cancel_outlined : Icons.check_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- HELPER PARA ESTILOS DE INPUT  ---
  InputDecoration _getInputStyle({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.grey.shade600,
      ),
      prefixIcon: Icon(icon, size: 20, color: AppColors.primaryGreen),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          color: Colors.black,
          onPressed: () {
            if (_emailExists) {
              setState(() {
                _emailExists = false;
                _passwordController.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TÍTULO DINÁMICO
                Text(
                  _emailExists ? "Hola de nuevo!" : "¿Cuál es tu correo?",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),

                // Subtítulo opcional para mostrar el correo si quieres (puedes quitarlo si usas el campo)
                if (_emailExists)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 30),
                    child: Text(
                      "Ingresa tu contraseña para continuar",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 50),

                // --- CAMPO EMAIL (UNIFICADO) ---
                // Usamos un solo TextField y cambiamos sus propiedades según el estado
                TextField(
                  controller: _emailController,
                  // readOnly es MEJOR que enabled:false porque mantiene el estilo visual (no se ve gris/cortado)
                  readOnly: _emailExists,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  style: GoogleFonts.poppins(
                    // Si está en modo lectura, un color gris oscuro, si no, negro
                    color: _emailExists ? Colors.grey.shade700 : Colors.black,
                  ),
                  decoration: _getInputStyle(
                    label: "Correo electrónico",
                    icon: Icons.alternate_email,
                    // AQUÍ ESTÁ LA CLAVE DEL LÁPIZ:
                    suffixIcon: _emailExists
                        ? IconButton(
                            tooltip: "Editar correo",
                            icon: const Icon(
                              Icons.edit,
                              size: 20,
                              color: AppColors.primaryGreen,
                            ),
                            onPressed: () {
                              // Al presionar, simplemente desbloqueamos el campo
                              setState(() {
                                _emailExists = false;
                                _passwordController.clear();
                              });
                            },
                          )
                        : null, // Si está escribiendo, no mostramos nada (o podrías poner un botón de borrar X)
                  ),
                  onSubmitted: (_) {
                    if (!_emailExists) _handleContinue();
                  },
                ),

                // --- CAMPO PASSWORD (ANIMADO) ---
                // Usamos AnimatedCrossFade solo para mostrar/ocultar el password
                AnimatedCrossFade(
                  firstChild: Container(
                    height: 0,
                  ), // Espacio vacío cuando no hay password
                  secondChild: Column(
                    children: [
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        style: GoogleFonts.poppins(),
                        decoration: _getInputStyle(
                          label: "Contraseña",
                          icon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _handleContinue(),
                      ),

                      // LINK: OLVIDÉ MI CONTRASEÑA
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                  emailPreloadded: _emailController.text,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            "¿Olvidaste tu contraseña?",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Lógica de animación
                  crossFadeState: _emailExists
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                  sizeCurve: Curves.easeInOut, // Suaviza el cambio de altura
                ),

                const SizedBox(height: 30),

                // --- BOTÓN DE ACCIÓN PRINCIPAL ---
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
                      elevation: 4,
                      shadowColor: AppColors.primaryGreen.withValues(
                        alpha: 0.4,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _emailExists ? "Iniciar Sesión" : "Continuar",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // --- PIE DE PÁGINA (LINK A REGISTRO) ---
                // Solo mostramos esto si estamos en la fase 1 (ingresar correo)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: !_emailExists ? 1.0 : 0.0,
                  child: !_emailExists
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "¿No tienes cuenta?",
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterTypeScreen(),
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
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
