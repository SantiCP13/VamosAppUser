import 'package:flutter/material.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'core/theme/app_colors.dart';

void main() {
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
