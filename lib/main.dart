import 'package:flutter/material.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'core/theme/app_colors.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(
      "Advertencia: No se encontró el archivo .env. Se usarán valores por defecto.",
    );
    // Aquí podrías definir valores manuales si quieres
    // dotenv.testLoad(fileInput: 'API_URL=http://localhost:8000');
  }

  await initializeDateFormatting('es_ES', null);
  runApp(const VamosApp());
}

class VamosApp extends StatelessWidget {
  const VamosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vamos App',
      debugShowCheckedModeBanner:
          false, // Quita la etiqueta "Debug" de la esquina
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGreen),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const WelcomeScreen(),
    );
  }
}
