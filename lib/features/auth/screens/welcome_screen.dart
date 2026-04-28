import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../../home/screens/home_screen.dart';
import 'login_screen.dart';
import 'company_register_screen.dart';
import 'dart:ui'; // Vital para el blur

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOutCubic,
    );

    _checkSession();
  }

  @override
  void dispose() {
    _expansionController.dispose();
    super.dispose();
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateTo(Widget screen) async {
    setState(() => _isNavigating = true);
    await _expansionController.forward();
    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 700),
        ),
      ).then((_) {
        _expansionController.reverse();
        setState(() => _isNavigating = false);
      });
    }
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Fondo con Gradiente para dar textura al vidrio
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.45),
                radius: 1.8,
                colors: [Color(0xFFFFFFFF), Color.fromARGB(143, 125, 126, 125)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    _buildFadeIn(
                      delay: 0,
                      child: Hero(
                        tag: 'logo',
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 250,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    _buildFadeIn(
                      delay: 150,
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
                    const SizedBox(height: 80),
                    Text(
                      "PANEL DE ACCESO",
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        color: const Color.fromARGB(255, 87, 87, 87),
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
                        destination: const CompanyRegisterScreen(),
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
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),

          // Expansión fluida
          if (_isNavigating)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _expansionAnimation,
                builder: (context, child) {
                  return Container(
                    color: Colors.white.withValues(
                      alpha: _expansionAnimation.value,
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: 1.0 + (_expansionAnimation.value * 12),
                        child: Opacity(
                          opacity: (1.0 - _expansionAnimation.value).clamp(
                            0.0,
                            1.0,
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 150,
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
            // Sombra muy suave para dar profundidad al vidrio
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
          // SUBIMOS EL BLUR: En fondos blancos se necesita más (25) para que se note
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              // BORDE DEFINIDO: Es lo que hace que el vidrio blanco se vea real
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
                    : [
                        // BLANCO TRASLÚCIDO: Ajustado para que el blur "traspase"
                        Colors.white.withValues(alpha: 0.5),
                        Colors.white.withValues(alpha: 0.2),
                      ],
              ),
            ),
            child: ElevatedButton(
              onPressed: () => _navigateTo(destination),
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
                                : AppColors
                                      .primaryGreen, // Puedes poner Colors.black o el que quieras
                          ),
                        ),
                        Text(
                          subLabel,
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: isPrimary
                                ? Colors.white.withValues(alpha: 0.8)
                                : const Color.fromARGB(
                                    255,
                                    87,
                                    87,
                                    87,
                                  ), // Gris oscuro para lectura en vidrio blanco
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppColors
                              .darkBlue, // Puedes poner Colors.grey.shade400 o el que quieras
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
              backgroundColor: const Color(0xFFF5F5F5),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }
}
