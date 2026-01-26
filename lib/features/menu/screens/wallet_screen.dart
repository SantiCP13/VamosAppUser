// lib/features/menu/screens/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Monedero",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // --- CABECERA DE SALDO ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tiene disponible:",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "\$ 0 COP",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Abrir pantalla de recarga
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const RechargeModal(),
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_downward,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text("Ingresar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF66BB6A), // Verde claro
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // --- ESTADO VACÍO ---
            Icon(
              Icons.person,
              size: 100,
              color: Colors.blueGrey.shade800,
            ), // Placeholder ilustracion
            const SizedBox(height: 16),
            Text(
              "Sin movimientos",
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// --- MODAL DE RECARGA (CALCULADORA) ---
class RechargeModal extends StatefulWidget {
  const RechargeModal({super.key});

  @override
  State<RechargeModal> createState() => _RechargeModalState();
}

class _RechargeModalState extends State<RechargeModal> {
  String amount = "0";

  void _onKeyPress(String value) {
    setState(() {
      if (amount == "0") {
        amount = value;
      } else {
        amount += value;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (amount.length > 1) {
        amount = amount.substring(0, amount.length - 1);
      } else {
        amount = "0";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header Modal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(), // Título centrado si se requiere
                const SizedBox(width: 48), // Balanceo
              ],
            ),
          ),

          const Spacer(flex: 1),
          Text(
            "Monto a recargar",
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
          ),
          Text(
            amount,
            style: GoogleFonts.poppins(
              fontSize: 60,
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(flex: 2),

          // Selector Metodo y Boton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text("Transferencia", style: GoogleFonts.poppins()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Lógica de backend para recargar
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF66BB6A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      "Continuar",
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          // Teclado Numérico
          Expanded(
            flex: 6,
            child: Container(
              color: Colors.grey.shade100,
              child: GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 1.8,
                padding: const EdgeInsets.all(0),
                children: [
                  _buildKey("1"), _buildKey("2"), _buildKey("3"),
                  _buildKey("4"), _buildKey("5"), _buildKey("6"),
                  _buildKey("7"), _buildKey("8"), _buildKey("9"),
                  const SizedBox(), // Vacío
                  _buildKey("0"),
                  // Botón Borrar
                  InkWell(
                    onTap: _onBackspace,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.backspace_outlined,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String value) {
    return InkWell(
      onTap: () => _onKeyPress(value),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          value,
          style: GoogleFonts.poppins(fontSize: 24, color: Colors.black54),
        ),
      ),
    );
  }
}
