import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../../home/screens/home_screen.dart';
import 'login_screen.dart';
import 'company_register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Controla la visualización del Splash/Loading mientras verificamos credenciales
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  /// LÓGICA DE NEGOCIO: Verificación de Sesión Persistente
  ///
  /// Antes de mostrar cualquier botón, consultamos al [AuthService] si existe
  /// un token válido (Sanctum) o una sesión Mock guardada.
  /// Esto evita que un usuario logueado tenga que volver a ingresar sus datos.
  Future<void> _checkSession() async {
    // 1. Llama al servicio (actualmente Mock, futuro API Laravel /user)
    final hasSession = await AuthService.tryAutoLogin();

    if (hasSession && mounted) {
      // 2. Si hay sesión, limpiamos el historial de navegación y vamos al Mapa/Home.
      // Esto es vital para evitar que el botón "Atrás" devuelva al usuario al Login.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } else {
      // 3. Si no hay sesión, dejamos de cargar y mostramos la UI de bienvenida.
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

    // ESTADO: CARGANDO
    // Se muestra mientras validamos el token localmente o contra la API.
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgColor,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    // ESTADO: SIN SESIÓN (Mostrar Opciones)
    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: Stack(
        children: [
          // --- CONTENIDO PRINCIPAL ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // 1. BRANDING
                  // El logo debe inspirar confianza (Transporte Legal)
                  Hero(
                    tag: 'logo', // Animación suave al transicionar a Login
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: size.width * 0.65,
                      fit: BoxFit.contain,
                      // Fallback por si no has cargado el asset aún
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.directions_bus,
                        size: 100,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. PROPUESTA DE VALOR
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

                  const Spacer(flex: 3),

                  Text(
                    "SELECCIONA TU PERFIL",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color.fromARGB(255, 141, 141, 141),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- BOTONES DE ACCIÓN (SEGMENTACIÓN DE USUARIO) ---

                  // OPCIÓN A: FLUJO B2B (Empresas)
                  // Este flujo lleva al registro de empresas donde se configura el "contract_id" de Moviltrack. Es para administradores de cuenta.
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

                  // OPCIÓN B: FLUJO USUARIO FINAL / EMPLEADO (Pasajeros)
                  // Este flujo lleva al Login/Registro de personas naturales. Aquí es donde se pedirán los viajes y se generarán los FUEC.
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
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botón de Selección de Rol
  /// Encapsula el diseño repetitivo de los botones grandes con icono y texto.
  Widget _buildRoleButton(
    BuildContext context, {
    required String label,
    required String subLabel,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    // Definimos los colores basados en si es primario o secundario
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
          // Borde solo si no es primario
          side: isPrimary ? null : BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            // Icono con fondo translúcido
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

            // Textos (Título y Subtítulo)
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
                      // Ajuste de contraste para legibilidad
                      color: isPrimary
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Flecha indicadora
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
