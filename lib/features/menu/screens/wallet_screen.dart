import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../menu/services/menu_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final MenuService _menuService = MenuService();
  late Future<Map<String, dynamic>> _walletFuture;

  @override
  void initState() {
    super.initState();
    _walletFuture = _menuService.getWalletBalance();
  }

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
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _walletFuture,
        builder: (context, snapshot) {
          // LOADING
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          // DATA
          // Usamos valores por defecto si falla la carga o viene nulo
          final data = snapshot.data ?? {};
          final String balance = data['balance'] ?? '\$ 0 COP';
          // Aquí podríamos sacar tarjetas si el servicio las devuelve
          // final cards = data['cards'] ?? [];

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // --- CABECERA DE SALDO DINÁMICA ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Saldo disponible:",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            balance,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
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
                          Icons.add_card,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          "Recargar",
                          style: GoogleFonts.poppins(
                            color: Colors.white, // <--- COLOR BLANCO APLICADO
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // --- LISTA DE MOVIMIENTOS (A futuro API) ---
                // Aquí podrías poner otro FutureBuilder si tuvieras historial de transacciones separado
                Icon(
                  Icons.receipt_long, // Icono cambiado a recibo
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  "Sin movimientos recientes",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --- MODAL DE RECARGA CON LÓGICA DE PAGO ---
class RechargeModal extends StatefulWidget {
  const RechargeModal({super.key});

  @override
  State<RechargeModal> createState() => _RechargeModalState();
}

class _RechargeModalState extends State<RechargeModal> {
  String amount = "0";
  bool isProcessing = false; // Para evitar doble tap

  void _onKeyPress(String value) {
    setState(() {
      if (amount == "0") {
        amount = value;
      } else {
        // Límite simple para evitar overflow de UI
        if (amount.length < 9) {
          amount += value;
        }
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

  // --- LÓGICA CORE DE PAGO ---
  Future<void> _processPayment() async {
    final int value = int.parse(amount);
    if (value <= 0) return;

    setState(() => isProcessing = true);

    // TODO: CONEXIÓN PASARELA DE PAGOS (STRIPE / WOMPI)
    // 1. Crear Intent de pago en Backend (Laravel) -> POST /api/wallet/deposit-intent
    // 2. Recibir ClientSecret
    // 3. Confirmar pago con SDK de Stripe/Wompi

    // Simulación:
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => isProcessing = false);
      Navigator.pop(context); // Cerrar modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Recarga de \$$amount COP iniciada (Simulación)"),
          backgroundColor: Colors.green,
        ),
      );
      // Aquí deberías llamar a un setState del padre para refrescar el saldo
    }
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
                Expanded(
                  child: Text(
                    "Recargar Saldo",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 48), // Balanceo visual
              ],
            ),
          ),

          const Spacer(flex: 1),
          Text(
            "Monto a ingresar",
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "\$ ",
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                amount,
                style: GoogleFonts.poppins(
                  fontSize: 60,
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.credit_card,
                          color: Colors.black87,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Tarjeta / PSE",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (amount == "0" || isProcessing)
                        ? null
                        : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "Continuar",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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
              color: Colors.grey.shade50,
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
        alignment: Alignment.center,
        child: Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 24,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
