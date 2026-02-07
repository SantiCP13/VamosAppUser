import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
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
  // Controladores y FocusNodes
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode(); // Para mover el foco automáticamente

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

  Future<void> _handleContinue() async {
    // Ocultar teclado para procesar
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();

    // Validación básica
    if (email.isEmpty || !email.contains('@')) {
      _showSnack("Por favor ingresa un correo válido", isError: true);
      return;
    }

    // Si ya validamos el correo y estamos en fase contraseña, validamos que no esté vacía
    if (_emailExists && _passwordController.text.isEmpty) {
      _showSnack("Ingresa tu contraseña", isError: true);
      _passwordFocusNode.requestFocus();
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!_emailExists) {
        // ==========================================
        // FASE 1: Verificar existencia del correo
        // ==========================================
        bool exists = await AuthService.checkEmailExists(email);

        if (!mounted) return; // Seguridad si el widget se desmontó
        setState(() => _isLoading = false);

        if (exists) {
          setState(() {
            _emailExists = true;
          });
          // UX: Mover foco al campo password automáticamente
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              FocusScope.of(context).requestFocus(_passwordFocusNode);
            }
          });
        } else {
          _showRegisterDialog(email);
        }
      } else {
        // ==========================================
        // FASE 2: Iniciar Sesión (Mock o Real)
        // ==========================================
        final result = await AuthService.login(email, _passwordController.text);

        if (!mounted) return;
        setState(() => _isLoading = false);

        switch (result['status']) {
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
            // UX: Volver a enfocar contraseña y limpiar campo
            _passwordController.clear();
            _passwordFocusNode.requestFocus();
            break;

          case AuthResponseStatus.notFound:
            // Caso raro: existía hace un segundo y ahora no (concurrencia)
            _showSnack("Usuario no encontrado", isError: true);
            setState(() => _emailExists = false);
            break;

          case AuthResponseStatus.networkError:
            _showSnack(
              "Error de conexión. Verifica tu internet.",
              isError: true,
            );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definir colores y estilos locales
    const inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Colors.grey),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          color: Colors.black,
          onPressed: () {
            // Si está en paso de contraseña, el "back" vuelve al paso de email
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
            // Permite al celular sugerir correos guardados
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
                if (_emailExists)
                  Text(
                    _emailController.text,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),

                const SizedBox(height: 30),

                // CAMPO EMAIL
                TextField(
                  controller: _emailController,
                  enabled: !_emailExists, // Se bloquea si ya lo encontramos
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: "Correo electrónico",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: inputBorder,
                    enabledBorder: inputBorder.copyWith(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: inputBorder.copyWith(
                      borderSide: BorderSide(color: AppColors.primaryGreen),
                    ),
                    suffixIcon: _emailExists
                        ? IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => setState(() {
                              _emailExists = false;
                              _passwordController.clear();
                            }),
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _handleContinue(),
                ),

                // CAMPO PASSWORD (Animado)
                AnimatedCrossFade(
                  firstChild: Container(), // Espacio vacío cuando no hay pass
                  secondChild: Column(
                    children: [
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: "Contraseña",
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: inputBorder,
                          enabledBorder: inputBorder.copyWith(
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: inputBorder.copyWith(
                            borderSide: BorderSide(
                              color: AppColors.primaryGreen,
                            ),
                          ),
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

                      // Opción de "Olvidé mi contraseña" (Visual por ahora)
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
                  crossFadeState: _emailExists
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),

                const SizedBox(height: 30),

                // BOTÓN PRINCIPAL
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
                      elevation: 2,
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // PIE DE PÁGINA: REGISTRO
                if (!_emailExists)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "¿No tienes cuenta?",
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
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
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
