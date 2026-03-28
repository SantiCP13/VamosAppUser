import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/payment_service.dart';

class AddCardModal extends StatefulWidget {
  final Color themeColor;
  const AddCardModal({super.key, required this.themeColor});

  @override
  State<AddCardModal> createState() => _AddCardModalState();
}

class _AddCardModalState extends State<AddCardModal> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  bool _isSaving = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Separar MM/YY
    final expiryParts = _expiryController.text.split('/');
    final month = expiryParts[0];
    final year = "20${expiryParts[1]}"; // Wompi pide 4 dígitos para el año

    final success = await PaymentService().addCardWithWompi(
      cardNumber: _numberController.text,
      cvc: _cvcController.text,
      expMonth: month,
      expYear: year,
      cardHolder: _nameController.text,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context, true); // Cerramos y avisamos que hubo éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tarjeta vinculada exitosamente"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error al vincular tarjeta. Verifica los datos."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(
          context,
        ).viewInsets.bottom, // Ajuste para el teclado
        left: 25,
        right: 25,
        top: 25,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Nueva Tarjeta",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Campo Número
            _buildField(
              "Número de Tarjeta",
              _numberController,
              Icons.credit_card,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
              ],
            ),

            const SizedBox(height: 15),

            // Campo Nombre
            _buildField(
              "Nombre del Titular",
              _nameController,
              Icons.person_outline,
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                // Campo Expiración
                Expanded(
                  child: _buildField(
                    "MM/YY",
                    _expiryController,
                    Icons.calendar_today,
                    inputFormatters: [
                      _ExpiryFormatter(),
                      LengthLimitingTextInputFormatter(5),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                // Campo CVC
                Expanded(
                  child: _buildField(
                    "CVC",
                    _cvcController,
                    Icons.lock_outline,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Vincular Tarjeta",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      inputFormatters: inputFormatters,
      keyboardType: label.contains("Nombre")
          ? TextInputType.name
          : TextInputType.number,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
      ),
      validator: (val) => (val == null || val.isEmpty) ? "Requerido" : null,
    );
  }
}

// Formateador automático para la fecha MM/YY
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset)
      // ignore: curly_braces_in_flow_control_structures
      return newValue;
    if (text.length == 2 && !text.contains('/')) text += '/';
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
