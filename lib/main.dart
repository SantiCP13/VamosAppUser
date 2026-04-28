// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'core/navigation/navigation_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart'; // Importa el nuevo tema
import 'features/auth/screens/splash_screen.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // 1. Cargamos configuración ambiental con seguridad
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Advertencia: Archivo .env no encontrado");
  }

  // 2. Inicializamos formatos de fecha (Vital para recibos y FUEC)
  await initializeDateFormatting('es_ES', null);

  // 3. Verificamos sesión antes de lanzar la UI
  bool isAuthenticated = false;
  try {
    isAuthenticated = await AuthService.checkAuthStatus();
  } catch (e) {
    isAuthenticated = false;
  }

  runApp(VamosApp(initialRoute: isAuthenticated ? '/home' : '/'));
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
      // MODIFICACIÓN AQUÍ:
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => SplashScreen(
          logoPath: 'assets/images/logo.png',
          nextRoute: initialRoute,
          isDark: false, // Fondo blanco para User
        ),
        '/': (context) => const WelcomeScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
