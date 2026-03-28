import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/services/auth_service.dart';
import '../services/payment_service.dart';
import '../widgets/add_card_modal.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final PaymentService _service = PaymentService();
  List<PaymentMethod> _allMethods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final user = AuthService.currentUser;
    if (user != null) {
      _allMethods = await _service.getPaymentMethods(user);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser!;
    final Color themeColor = user.isCorporateMode
        ? const Color(0xFF0D47A1)
        : AppColors.primaryGreen;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Mis Pagos",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: themeColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeColor))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildWalletBalance(themeColor),
                const SizedBox(height: 30),

                Text(
                  "Métodos Habilitados",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),

                ..._allMethods.map((m) => _buildMethodTile(m, themeColor)),

                const SizedBox(height: 25),
                _buildActionButtons(themeColor),
              ],
            ),
    );
  }

  Widget _buildMethodTile(PaymentMethod m, Color themeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: m.isDefault ? themeColor.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: m.isDefault ? themeColor : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Icon(
          _getIcon(m.type),
          color: m.isDefault ? themeColor : Colors.grey,
        ),
        title: Text(
          m.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: m.isDefault ? themeColor : Colors.black87,
          ),
        ),
        trailing: m.isDefault
            ? Icon(Icons.check_circle, color: themeColor)
            : null,
        onTap: () {
          setState(() {
            for (var element in _allMethods) {
              element.isDefault = false;
            }
            m.isDefault = true;
          });
        },
      ),
    );
  }

  Widget _buildActionButtons(Color color) {
    return Column(
      children: [
        _actionButton(
          Icons.add_card,
          "Vincular Nueva Tarjeta",
          color,
          () => _showAddCardForm(color),
        ),
        const SizedBox(height: 12),
        _actionButton(
          Icons.account_balance,
          "Recargar por PSE",
          color,
          () => _showPseSelector(color),
        ),
      ],
    );
  }

  Widget _actionButton(
    IconData icon,
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          text,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  IconData _getIcon(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.cash:
        return Icons.money;
      case PaymentMethodType.card:
        return Icons.credit_card;
      case PaymentMethodType.corporateVoucher:
        return Icons.business;
      case PaymentMethodType.pse:
        return Icons.account_balance;
    }
  }

  // --- MÉTODOS PARA MODALES ---
  void _showAddCardForm(Color color) async {
    final bool? added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // Para que el teclado no tape el formulario
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => AddCardModal(themeColor: color),
    );

    if (added == true) {
      _loadAll(); // Recargamos la lista si se añadió una tarjeta
    }
  }

  void _showPseSelector(Color color) async {
    // Mostramos un cargando
    showDialog(
      context: context,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    final banks = await _service.getPseBanks();

    if (!mounted) return;
    Navigator.pop(context); // Quitar cargando

    if (banks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo cargar la lista de bancos")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ListView.builder(
        itemCount: banks.length,
        itemBuilder: (context, i) => ListTile(
          leading: const Icon(Icons.account_balance, color: Colors.blue),
          title: Text(
            banks[i]['description'],
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          onTap: () {
            // Aquí llamarías a tu backend: POST /api/billetera/recargar con el bank_code
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Widget _buildWalletBalance(Color color) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Saldo en Billetera",
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
          Text(
            "\$0.00",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 35,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
