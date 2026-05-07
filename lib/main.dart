// main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'core/navigation/navigation_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/splash_screen.dart';
import 'package:flutter/services.dart';
import 'core/di/injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await dotenv.load(fileName: ".env");
    await di.init();
  } catch (e) {
    debugPrint("Advertencia: Archivo .env no encontrado");
  }

  await initializeDateFormatting('es_ES', null);

  bool isAuthenticated = false;
  try {
    isAuthenticated = await AuthService.checkAuthStatus();
  } catch (e) {
    isAuthenticated = false;
  }

  runApp(
    // 1. Envolvemos la App con el detector de actividad
    SessionTimeoutListener(
      child: VamosApp(initialRoute: isAuthenticated ? '/home' : '/'),
    ),
  );
}

// --- WIDGET DETECTOR DE INACTIVIDAD ---
class SessionTimeoutListener extends StatefulWidget {
  final Widget child;
  const SessionTimeoutListener({super.key, required this.child});

  @override
  State<SessionTimeoutListener> createState() => _SessionTimeoutListenerState();
}

class _SessionTimeoutListenerState extends State<SessionTimeoutListener> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    // 2. Definimos los 5 minutos (300 segundos)
    _timer = Timer(const Duration(minutes: 5), _handleTimeout);
  }

  void _handleTimeout() {
    // 3. REGLA DE ORO: Solo cerrar sesión si:
    // - Hay un usuario logueado.
    // - NO hay un viaje activo (isTripActive == false).
    if (AuthService.currentUser != null && !AuthService.isTripActive) {
      debugPrint("Cierre de sesión por inactividad detectado.");
      AuthService.logout();
    } else if (AuthService.isTripActive) {
      debugPrint(
        "Inactividad detectada pero hay un viaje activo. No se cierra.",
      );
      _startTimer(); // Reiniciamos para volver a intentar en 5 min
    }
  }

  // Se resetea el timer con cada toque en la pantalla
  void _handleUserInteraction([_]) {
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleUserInteraction,
      onPointerMove: _handleUserInteraction,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class VamosApp extends StatelessWidget {
  final String initialRoute;
  const VamosApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAMOS User',
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      theme: AppTheme.lightTheme,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => SplashScreen(
          logoPath: 'assets/images/logo.png',
          nextRoute: initialRoute,
          isDark: false,
        ),
        '/': (context) => const WelcomeScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
