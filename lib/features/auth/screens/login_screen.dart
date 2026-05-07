import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/utils/device_helper.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import '../../home/screens/home_screen.dart';
import 'register_type_screen.dart'; // Verifica que la ruta sea correcta según tu carpeta
import 'dart:ui'; // <--- AGREGAR DE NUEVO (Para ImageFilter)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _rememberMe = false; // <--- AGREGAR ESTA LÍNEA (Faltaba declararla)

  bool _isLoading = false;
  bool _checkingEmail = false;
  bool _isEmailVerified = false;
  bool _isBioAvailable = false;
  bool _hasSavedCredentials = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final isAvailable = await sl<BiometricService>().isAvailable();
    // CAMBIO: Usamos getLastEmail en lugar de getBiometricEmail
    final savedEmail = await sl<StorageService>().getLastEmail();

    if (mounted) {
      setState(() {
        _isBioAvailable = isAvailable;
        if (savedEmail != null && savedEmail.isNotEmpty) {
          _emailController.text = savedEmail;
          _rememberMe = true;
        }
      });
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack("Ingresa tu correo", isError: true);
      return;
    }

    // PASO 1: VERIFICAR CUENTA (Backend)
    // PASO 1: VERIFICAR CUENTA (Backend)
    if (!_isEmailVerified) {
      setState(() => _checkingEmail = true);
      try {
        final deviceId = await DeviceHelper.getId();
        // 1. Verificamos en el servidor (Trae el rol y si el servidor autoriza biometría)
        final data = await AuthService.checkAccount(email, deviceId);

        // Bloqueo de conductor que ya hicimos
        if (data['id_role'] == 3) {
          setState(() => _checkingEmail = false);
          _showSnack(
            "Esta cuenta es de Conductor. Usa la App VAMOS Conductor.",
            isError: true,
          );
          return;
        }

        // 2. VERIFICACIÓN LOCAL DE CREDENCIALES
        final storage = sl<StorageService>();
        // Buscamos si existe una contraseña para ESTE correo específico
        final savedPassForThisEmail = await storage.getAccountPassword(email);
        final bioEnabled = await storage.isBiometricEnabled();

        if (!mounted) return;
        setState(() {
          _isEmailVerified = true;
          _checkingEmail = false;

          // La huella se activa SOLO SI:
          // - El servidor dice que este usuario+dispositivo está autorizado.
          // - El teléfono tiene guardada la contraseña de este correo.
          // - El usuario tiene la biometría habilitada en ajustes.
          _hasSavedCredentials =
              (savedPassForThisEmail != null &&
              data['biometrics_authorized'] == true &&
              bioEnabled == true);
        });

        // No pedimos requestFocus para no abrir el teclado como pediste
      } catch (e) {
        if (mounted) setState(() => _checkingEmail = false);
        _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
      return;
    }

    // PASO 2: LOGIN MANUAL
    if (_passwordController.text.isEmpty) {
      _showSnack("Ingresa tu contraseña", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final deviceId = await DeviceHelper.getId();
      final deviceName = await DeviceHelper.getName();
      final password = _passwordController.text.trim();

      // Ejecutamos login
      await AuthService.login(
        email: email,
        password: password,
        deviceId: deviceId,
        deviceName: deviceName,
      );
      if (AuthService.currentUser?.idRole == 3) {
        await AuthService.logout(); // Lo sacamos de inmediato
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnack(
            "Esta cuenta está registrada como Conductor. Por favor usa la App VAMOS Conductor.",
            isError: true,
          );
        }
        return; // Detenemos la ejecución aquí, no va al Home
      }
      // --- ENROLAMIENTO LOCAL (Lógica Nequi) ---
      final storage = sl<StorageService>();

      if (_rememberMe) {
        // Guardamos la contraseña usando el correo como llave (Paso 1)
        await storage.saveAccountPassword(email, password);
        await storage.setBiometricEnabled(true);
      } else {
        // Si el usuario desmarca "Recordar", borramos su contraseña específica
        await storage.deleteAccountPassword(email);
      }
      if (!mounted) return;

      // Transición suave al Home (Fade)
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Widget _buildLoginForm() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // CAMPO DE EMAIL (Siempre presente)
              _buildLightInput(
                controller: _emailController,
                label: "Correo Electrónico",
                icon: Icons.email_outlined,
                readOnly: _isEmailVerified,
                suffixIcon: _isEmailVerified
                    ? IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () =>
                            setState(() => _isEmailVerified = false),
                      )
                    : null,
              ),

              // PASO 2: SE ACTIVA AL VALIDAR EL EMAIL (Password + Olvido Contraseña)
              if (_isEmailVerified) ...[
                const SizedBox(height: 20),
                _buildLightInput(
                  controller: _passwordController,
                  label: "Contraseña",
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscure: _obscurePassword,
                  focusNode: _passwordFocusNode,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 600),
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  SplashScreen(
                                    logoPath: 'assets/images/logo.png',
                                    nextRoute: '/forgot_password',
                                    email: _emailController.text.trim(),
                                    isDark: false,
                                  ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                        ),
                      );
                    },
                    child: Text(
                      "¿Olvidaste tu contraseña?",
                      style: GoogleFonts.montserrat(
                        color: AppColors.primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              // PASO 1: SOLO SE MUESTRA SI NO TIENE CUENTA O NO SE HA VALIDADO
              if (!_isEmailVerified) ...[
                const SizedBox(height: 15),
                Row(
                  children: [
                    Theme(
                      data: ThemeData(
                        unselectedWidgetColor: Colors.grey.shade300,
                      ),
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: AppColors.primaryGreen,
                        onChanged: (val) => setState(() => _rememberMe = val!),
                      ),
                    ),
                    Text(
                      "Recordar correo",
                      style: GoogleFonts.montserrat(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // SECCIÓN DE REGISTRO: Ahora es dinámica y desaparece al validar email
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterTypeScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: "¿No tienes cuenta? ",
                      style: GoogleFonts.montserrat(
                        color: Colors.blueGrey.shade400,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: "Regístrate aquí",
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    // 🛡️ ESCUDO: Evita el crash "This widget has been unmounted"
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: isError ? Colors.redAccent : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleBiometricLogin() async {
    final email = _emailController.text.trim();
    // 1. Buscamos la contraseña específica para el correo que está en pantalla
    final password = await sl<StorageService>().getAccountPassword(email);

    if (password == null) {
      _showSnack("No se encontraron credenciales para $email", isError: true);
      return;
    }

    // 2. Disparamos la biometría (FaceID/Huella)
    final authenticated = await sl<BiometricService>().authenticate();
    if (authenticated) {
      if (!mounted) return;

      // Mostramos la pantalla de carga (Splash)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SplashScreen(
            logoPath: 'assets/images/logo.png',
            isLoader: true,
            isDark: false,
          ),
        ),
      );

      try {
        final deviceId = await DeviceHelper.getId();
        final deviceName = await DeviceHelper.getName();

        // 3. Iniciamos sesión con la contraseña recuperada del SecureStorage
        await AuthService.login(
          email: email,
          password: password,
          deviceId: deviceId,
          deviceName: deviceName,
        );

        if (!mounted) return;

        // Transición final al Home
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 800),
          ),
          (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Quitar el splash de carga
        _showSnack(
          "Error de acceso rápido: ${e.toString().replaceAll('Exception: ', '')}",
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // FONDO LIGHT PREMIUM
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [Colors.white, Color(0xFFF1F5F9)],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // En login_screen.dart
                    Hero(
                      tag: 'logo',
                      createRectTween: (begin, end) {
                        return MaterialRectArcTween(begin: begin, end: end);
                      },
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 110,
                      ), // Altura más pequeña para el login
                    ),
                    const SizedBox(height: 40),
                    Text(
                      "IDENTIFICACIÓN",
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGreen,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Ingresa tus credenciales para continuar",
                      style: GoogleFonts.montserrat(
                        color: Colors.blueGrey,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildLoginForm(), // <--- REEMPLAZA EL CONTAINER LARGO POR ESTO
                    // CONTENEDOR FORMULARIO (LIGHT STYLE)
                    const SizedBox(height: 40),

                    // BOTONES DE ACCIÓN
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 62,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGreen.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading || _checkingEmail
                                  ? null
                                  : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading || _checkingEmail
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      _isEmailVerified
                                          ? "INICIAR SESIÓN"
                                          : "CONTINUAR",
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        if (_isEmailVerified &&
                            _isBioAvailable &&
                            _hasSavedCredentials) ...[
                          const SizedBox(width: 15),
                          GestureDetector(
                            onTap: _handleBiometricLogin,
                            child: Container(
                              height: 62,
                              width: 62,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primaryGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.fingerprint,
                                color: AppColors.primaryGreen,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // BOTÓN ATRÁS
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.black54,
                size: 22,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLightInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    FocusNode? focusNode,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            color: Colors.blueGrey.shade300,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          focusNode: focusNode,
          readOnly: readOnly,
          style: GoogleFonts.montserrat(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primaryGreen, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: onToggle,
                  )
                : suffixIcon,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 15,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
