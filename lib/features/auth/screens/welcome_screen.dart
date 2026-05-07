import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../../home/screens/home_screen.dart';
import 'login_screen.dart';
import 'dart:ui'; // Vital para el blur
import 'splash_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Quitamos el Mixin Ticker
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  // Ya no necesitamos dispose() ni variables de animación aquí

  Future<void> _checkSession() async {
    final hasSession = await AuthService.tryAutoLogin();
    if (hasSession && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionDuration: const Duration(milliseconds: 600), // Tiempo ideal
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Usamos solo Fade para que no choque con la animación interna de la Splash
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildLoadingState(),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. FONDO CON GRADIENTE LIGHT PREMIUM
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.45),
                radius: 1.8,
                colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
              ),
            ),
          ),

          // 2. CONTENIDO CENTRADO DINÁMICO (ESTILO DRIVER)
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            const Spacer(flex: 2), // Empuja hacia abajo

                            _buildFadeIn(
                              delay: 0,
                              child: Hero(
                                tag: 'logo',
                                // ESTO ACTIVA EL MOVIMIENTO EN CURVA:
                                createRectTween: (begin, end) {
                                  return MaterialRectArcTween(
                                    begin: begin,
                                    end: end,
                                  );
                                },
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 220,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            _buildFadeIn(
                              delay: 200,
                              child: Text(
                                "Viaja seguro, puntual y con el mejor servicio de movilidad del país.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                  height: 1.6,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 80,
                            ), // Distancia idéntica a Driver

                            Text(
                              "PANEL DE ACCESO",
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                color: const Color(
                                  0xFF64748B,
                                ), // Gris azulado corporativo
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                              ),
                            ),

                            const SizedBox(height: 25),
                            _buildFadeIn(
                              delay: 400,
                              child: _buildRoleButton(
                                label: "Registrar Empresa",
                                subLabel: "Servicios para mi personal",
                                icon: Icons.domain_rounded,
                                isPrimary: false,
                                destination: const SplashScreen(
                                  logoPath: 'assets/images/logo.png',
                                  nextRoute:
                                      '/register', // Esta es la ruta que configuramos en el paso 2
                                  isDark: false,
                                ),
                              ),
                            ),

                            _buildFadeIn(
                              delay: 600,
                              child: _buildRoleButton(
                                label: "Soy Pasajero",
                                subLabel: "Viaja con Nosotros",
                                icon: Icons.person_rounded,
                                isPrimary: true,
                                destination: const LoginScreen(),
                              ),
                            ),

                            const Spacer(
                              flex: 2,
                            ), // Empuja hacia arriba para equilibrar
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton({
    required String label,
    required String subLabel,
    required IconData icon,
    required Widget destination,
    required bool isPrimary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? AppColors.primaryGreen.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isPrimary
                    ? AppColors.primaryGreen.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isPrimary
                    ? [
                        AppColors.primaryGreen.withValues(alpha: 0.9),
                        AppColors.primaryGreen.withValues(alpha: 0.7),
                      ]
                    : [Colors.white, const Color(0xFFF8FAFC)],
              ),
            ),
            child: ElevatedButton(
              onPressed: () => _navigateTo(destination), // Navegación directa
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: isPrimary ? Colors.white : AppColors.darkBlue,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      icon,
                      size: 26,
                      color: isPrimary ? Colors.white : AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 25),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.montserrat(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isPrimary
                                ? Colors.white
                                : AppColors.primaryGreen,
                          ),
                        ),
                        Text(
                          subLabel,
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: isPrimary
                                ? Colors.white.withValues(alpha: 0.8)
                                : const Color.fromARGB(255, 87, 87, 87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppColors.darkBlue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFadeIn({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 800 + delay),
      curve: Curves.easeOutExpo,
      builder: (context, val, child) => Opacity(
        opacity: val,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - val)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/logo.png', width: 150),
          const SizedBox(height: 50),
          SizedBox(
            width: 160,
            child: LinearProgressIndicator(
              color: AppColors.primaryGreen,
              backgroundColor: Colors.grey.withValues(
                alpha: 0.1,
              ), // Corrección sin 'const'
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }
}
