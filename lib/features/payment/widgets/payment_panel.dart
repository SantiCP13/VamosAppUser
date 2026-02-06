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
    // Pre-seleccionar el método por defecto
    if (widget.methods.isNotEmpty) {
      _selectedMethodId = widget.methods.first.id;
    }
  }

  Future<void> _handlePayment() async {
    if (_selectedMethodId == null) return;

    setState(() => _isProcessing = true);

    bool success = await PaymentService.processPayment(
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

        // TÍTULO Y MONTO
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Resumen de Viaje",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "\$${widget.amount.toStringAsFixed(0)}",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
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

        // LISTA DE MÉTODOS
        SizedBox(
          height: 160, // Altura fija o flexible
          child: ListView.separated(
            itemCount: widget.methods.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                  groupValue: _selectedMethodId,
                  activeColor: Colors.black,
                  onChanged: (val) => setState(() => _selectedMethodId = val),
                  title: Text(
                    method.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: method.type == PaymentMethodType.CARD
                      ? Text(
                          "**** ${method.last4}",
                          style: const TextStyle(fontSize: 12),
                        )
                      : null,
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

        // BOTÓN DE PAGO
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

  IconData _getIconForMethod(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.CASH:
        return Icons.attach_money;
      case PaymentMethodType.CARD:
        return Icons.credit_card;
      case PaymentMethodType.CORPORATE_VOUCHER:
        return Icons.business_center;
    }
  }
}
