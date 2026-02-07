import 'dart:async';
import '../../../core/models/user_model.dart'; // Asegura importar tu User Model

// CORRECCIÓN: Dart moderno usa lowerCamelCase para los valores del Enum
enum PaymentMethodType { cash, card, corporateVoucher }

class PaymentMethod {
  final String id;
  final String name;
  final String last4; // Solo para tarjetas
  final PaymentMethodType type;
  final String? iconAsset; // Opcional si usas imágenes
  final bool isDefault;

  PaymentMethod({
    required this.id,
    required this.name,
    this.last4 = "",
    required this.type,
    this.isDefault = false,
    this.iconAsset,
  });
}

class PaymentService {
  // Simula API: Obtener métodos de pago según el modo del usuario
  static Future<List<PaymentMethod>> getPaymentMethods(User user) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Latencia de red

    if (user.isCorporateMode) {
      // MODO CORPORATIVO: Solo Vales Digitales
      return [
        PaymentMethod(
          id: "voucher_corp_01",
          name: "Vale Corporativo - ${user.empresa}",
          // CORRECCIÓN: Actualizado a corporateVoucher
          type: PaymentMethodType.corporateVoucher,
          isDefault: true,
        ),
      ];
    } else {
      // MODO PERSONAL: Efectivo y Tarjetas Simuladas
      return [
        PaymentMethod(
          id: "cash",
          name: "Efectivo",
          // CORRECCIÓN: Actualizado a cash
          type: PaymentMethodType.cash,
          isDefault: true,
        ),
        PaymentMethod(
          id: "card_visa_1234",
          name: "Visa Débito",
          last4: "4242",
          // CORRECCIÓN: Actualizado a card
          type: PaymentMethodType.card,
        ),
        PaymentMethod(
          id: "card_master_9876",
          name: "Mastercard Gold",
          last4: "8899",
          // CORRECCIÓN: Actualizado a card
          type: PaymentMethodType.card,
        ),
      ];
    }
  }

  // Simula API: Procesar el cobro
  static Future<bool> processPayment({
    required String methodId,
    required double amount,
  }) async {
    // Simular tiempo de procesamiento bancario
    await Future.delayed(const Duration(seconds: 2));

    // Aquí podrías poner lógica de fallo aleatorio para probar errores
    return true;
  }
}
