// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'core/navigation/navigation_service.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  try {
    await initializeDateFormatting('es_ES', null);
  } catch (e) {
    debugPrint("Error inicializando fechas: $e");
  }
  bool isAuthenticated = false;
  try {
    isAuthenticated = await AuthService.checkAuthStatus();
  } catch (e) {
    isAuthenticated = false;
  }

  runApp(
    VamosApp(
      initialScreen: isAuthenticated
          ? const HomeScreen()
          : const WelcomeScreen(),
    ),
  );
}

class VamosApp extends StatelessWidget {
  final Widget initialScreen;
  const VamosApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey, // Tu control remoto
      // Quitamos 'home: initialScreen' y usamos esto:
      initialRoute: initialScreen is HomeScreen ? '/home' : '/',

      routes: {
        '/': (context) => const WelcomeScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
