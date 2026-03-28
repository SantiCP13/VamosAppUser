import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/user_model.dart';

enum PaymentMethodType { cash, card, corporateVoucher, pse }

class PaymentMethod {
  final String id;
  final String name;
  final String last4;
  final String brand;
  final PaymentMethodType type;
  bool isDefault;

  PaymentMethod({
    required this.id,
    required this.name,
    this.last4 = "",
    this.brand = "",
    required this.type,
    this.isDefault = false,
  });

  factory PaymentMethod.fromApi(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'].toString(),
      name: map['tipo'] == 'TARJETA'
          ? "${map['franquicia']} **** ${map['ultimos_cuatro']}"
          : "Efectivo",
      last4: map['ultimos_cuatro'] ?? "",
      brand: map['franquicia'] ?? "",
      type: map['tipo'] == 'TARJETA'
          ? PaymentMethodType.card
          : PaymentMethodType.cash,
      isDefault: map['es_principal'] == 1 || map['es_principal'] == true,
    );
  }
}

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final Dio _dio = ApiClient().dio;

  final String _wompiUrl = "https://sandbox.wompi.co/v1/tokens/cards";
  final String _wompiPublicKey = "pub_test_XXXXXXXXX";

  /// Obtiene todos los métodos habilitados
  /// Obtiene todos los métodos habilitados filtrando estrictamente
  Future<List<PaymentMethod>> getPaymentMethods(User user) async {
    List<PaymentMethod> methods = [];

    // 1. Efectivo: Siempre disponible
    methods.add(
      PaymentMethod(
        id: "cash",
        name: "Efectivo",
        type: PaymentMethodType.cash,
        isDefault: !user.isCorporateMode, // Default solo en modo verde
      ),
    );

    // 2. Pago por Empresa: SOLO si el usuario es EMPLEADO Y está en MODO CORPORATIVO (Azul)
    // isCorporateMode ya verifica internamente: (appMode == CORPORATE && canUseCorporateMode)
    if (user.isCorporateMode) {
      methods.add(
        PaymentMethod(
          id: "corp",
          name: "Pago por Empresa (${user.empresa})",
          type: PaymentMethodType.corporateVoucher,
          isDefault: true, // Siempre es el default si entramos en modo azul
        ),
      );
    }

    try {
      // 3. Tarjetas: Siempre disponibles para ambos perfiles
      final response = await _dio.get('/pagos/metodos');
      if (response.data['status'] == 'success') {
        final List data = response.data['data'];
        methods.addAll(data.map((m) => PaymentMethod.fromApi(m)));
      }
    } catch (e) {
      debugPrint("Error cargando tarjetas: $e");
    }

    return methods;
  }

  /// Obtener lista de bancos PSE (Corregido)
  Future<List<dynamic>> getPseBanks() async {
    try {
      final res = await Dio().get(
        "https://sandbox.wompi.co/v1/financial_institutions",
        options: Options(headers: {"Authorization": "Bearer $_wompiPublicKey"}),
      );
      return res.data['data'];
    } catch (e) {
      debugPrint("Error PSE: $e");
      return [];
    }
  }

  Future<bool> addCardWithWompi({
    required String cardNumber,
    required String cvc,
    required String expMonth,
    required String expYear,
    required String cardHolder,
  }) async {
    try {
      final wompiResponse = await Dio().post(
        _wompiUrl, // <--- AQUÍ SE USA LA VARIABLE
        options: Options(headers: {"Authorization": "Bearer $_wompiPublicKey"}),
        data: {
          "number": cardNumber.replaceAll(' ', ''),
          "cvc": cvc,
          "exp_month": expMonth,
          "exp_year": expYear,
          "card_holder": cardHolder,
        },
      );

      if (wompiResponse.statusCode == 201) {
        final data = wompiResponse.data['data'];
        final apiResponse = await _dio.post(
          '/pagos/metodos',
          data: {
            "tipo": "TARJETA",
            "wompi_token": data['id'],
            "franquicia": data['brand'],
            "ultimos_cuatro": data['last_four'],
          },
        );
        return apiResponse.statusCode == 201;
      }
      return false;
    } catch (e) {
      debugPrint("Error en Wompi: $e");
      return false;
    }
  }

  Future<bool> processPayment({
    required String methodId,
    required double amount,
  }) async {
    try {
      // Lógica de cobro vinculada a ViajeController
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      return false;
    }
  }
}
