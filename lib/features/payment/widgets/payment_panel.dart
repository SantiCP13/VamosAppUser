import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/payment_service.dart';

class PaymentPanel extends StatefulWidget {
  final double amount;
  final VoidCallback onPaymentSuccess;
  final List<PaymentMethod> methods;

  const PaymentPanel({
    super.key,
    required this.amount,
    required this.onPaymentSuccess,
    required this.methods,
  });

  @override
  State<PaymentPanel> createState() => _PaymentPanelState();
}

class _PaymentPanelState extends State<PaymentPanel> {
  String? _selectedMethodId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.methods.isNotEmpty) {
      _selectedMethodId = widget.methods.first.id;
    }
  }

  Future<void> _handlePayment() async {
    if (_selectedMethodId == null) return;
    setState(() => _isProcessing = true);

    bool success = await PaymentService().processPayment(
      methodId: _selectedMethodId!,
      amount: widget.amount,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      widget.onPaymentSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error procesando pago. Intente de nuevo."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Container(width: 40, height: 4, color: Colors.grey[300])),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Resumen de Viaje",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 🔥 NUEVA LÍNEA DE TRANSPARENCIA
                Text(
                  "* Incluye peajes y seguros de ley",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            Text(
              "\$${widget.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),
        Text(
          "Método de Pago",
          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180, // Aumentamos un poco para los subtítulos
          child: ListView.separated(
            itemCount: widget.methods.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final method = widget.methods[index];
              final bool isSelected = method.id == _selectedMethodId;

              return Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected ? Colors.grey.shade50 : Colors.white,
                ),
                child: RadioListTile<String>(
                  value: method.id,
                  // ignore: deprecated_member_use
                  groupValue:
                      _selectedMethodId, // El linter puede marcarlo, pero es funcional.
                  activeColor: Colors.black,
                  // ignore: deprecated_member_use
                  onChanged: (String? val) {
                    if (val != null) setState(() => _selectedMethodId = val);
                  },
                  title: Text(
                    method.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: _buildSubtitle(method),
                  secondary: Icon(
                    _getIconForMethod(method.type),
                    color: Colors.black54,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handlePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    "Pagar \$${widget.amount.toStringAsFixed(0)}",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // MÉTODOS DE APOYO (Dentro de la clase, fuera del build)

  Widget? _buildSubtitle(PaymentMethod method) {
    switch (method.type) {
      case PaymentMethodType.card:
        return Text(
          "**** ${method.last4}",
          style: const TextStyle(fontSize: 12),
        );
      case PaymentMethodType.pse:
        return const Text(
          "Transferencia Bancaria",
          style: TextStyle(fontSize: 12),
        );
      case PaymentMethodType.corporateVoucher:
        return const Text(
          "Cargo a cuenta corporativa",
          style: TextStyle(fontSize: 12),
        );
      case PaymentMethodType.cash:
        return const Text(
          "Pago al finalizar viaje",
          style: TextStyle(fontSize: 12),
        );
    }
    // No hace falta default aquí porque el switch es exhaustivo
  }

  IconData _getIconForMethod(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.cash:
        return Icons.attach_money;
      case PaymentMethodType.card:
        return Icons.credit_card;
      case PaymentMethodType.corporateVoucher:
        return Icons.business_center;
      case PaymentMethodType.pse:
        return Icons.account_balance;
    }
  }
}
