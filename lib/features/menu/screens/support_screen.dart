// lib/features/menu/screens/support_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> faqs = [
      "¿Puedo pagar en efectivo?",
      "¿Cómo selecciono la forma de pago?",
      "Tengo problemas con el registro",
      "Olvidé un artículo en el vehículo",
      "¿Qué debo hacer en caso de emergencia?",
      "¿Cómo solicito un viaje?",
      "¿Puedo subir a mi mascota?",
      "¿Qué vehículos están permitidos?",
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Ayuda",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CONTACTO ---
            _buildSectionHeader("Contacto"),
            _buildListItem(
              "Llamar a soporte VamosApp",
              Icons.headset_mic_outlined,
            ),
            _buildListItem(
              "Whatsapp a soporte VamosApp",
              Icons.chat_bubble_outline,
            ),

            const SizedBox(height: 20),
            // --- PREGUNTAS FRECUENTES ---
            _buildSectionHeader("Preguntas frecuentes"),

            ...faqs.map((q) => _buildFAQItem(q)),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey.shade100,
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildListItem(String text, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(text, style: GoogleFonts.poppins(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    );
  }

  Widget _buildFAQItem(String text) {
    return Column(
      children: [
        ListTile(
          title: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade800,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {},
        ),
        const Divider(height: 1),
      ],
    );
  }
}
