import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'referral_screen.dart';
import 'pending_approval_screen.dart'; // Importa la pantalla pendiente
import 'widgets/corporate_link_widget.dart'; // Asegúrate de importar el widget

class RegisterScreen extends StatefulWidget {
  final String? emailPreIngresado;
  const RegisterScreen({super.key, this.emailPreIngresado});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isCorporateUser = false;
  bool _isLoading = false;

  // Seguridad Corporativa
  bool _isCorporateVerified = false;
  String? _corporateCompanyName;

  late TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _docController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  // El companyCodeController ha sido ELIMINADO

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.emailPreIngresado);
  }

  Future<void> _handleRegister() async {
    if (_nombreController.text.isEmpty ||
        _docController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showError("Completa todos los campos obligatorios");
      return;
    }

    // Validación de seguridad para flujo Corporativo
    if (_isCorporateUser && !_isCorporateVerified) {
      _showError("Debes validar tu correo corporativo para continuar.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        'tipo_persona': _isCorporateUser ? 'EMPLEADO' : 'NATURAL',
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'nombre': _nombreController.text.trim(),
        'documento': _docController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
        if (_isCorporateUser)
          'nombre_empresa':
              _corporateCompanyName, // Enviamos el nombre detectado
      };

      bool success = await AuthService.registerPassenger(payload);

      if (success && mounted) {
        if (_isCorporateUser) {
          // Flujo B2B: A espera de aprobación
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => PendingApprovalScreen(
                empresaNombre: _corporateCompanyName ?? "Tu Empresa",
              ),
            ),
            (r) => false,
          );
        } else {
          // Flujo B2C: Referidos (activo)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ReferralCodeScreen()),
            (r) => false,
          );
        }
      }
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Registro Pasajero",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Crea tu cuenta personal",
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),

              // Switch Corporativo
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isCorporateUser = !_isCorporateUser;
                    // Resetear validación si cambia de modo
                    if (!_isCorporateUser) {
                      _isCorporateVerified = false;
                      _corporateCompanyName = null;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isCorporateUser
                        ? const Color(0xFFE8F5E9)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isCorporateUser
                          ? AppColors.primaryGreen
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isCorporateUser
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: _isCorporateUser
                            ? AppColors.primaryGreen
                            : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Soy Empleado Corporativo",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Requiere correo corporativo y validación.",
                              style: GoogleFonts.poppins(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Formulario Datos Básicos
              _input(_nombreController, "Nombre Completo", Icons.person),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _input(
                      _docController,
                      "Cédula",
                      Icons.badge,
                      type: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _input(
                      _telefonoController,
                      "Celular",
                      Icons.phone,
                      type: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _input(_direccionController, "Dirección Residencia", Icons.map),
              const SizedBox(height: 15),

              // Email Input (Controlado también por el widget corporativo)
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                // Si ya verificó, bloqueamos edición para que no cambie el correo verificado
                readOnly: _isCorporateVerified,
                decoration: InputDecoration(
                  labelText: "Correo Electrónico",
                  prefixIcon: const Icon(Icons.email, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: _isCorporateVerified,
                  fillColor: _isCorporateVerified ? Colors.grey.shade100 : null,
                ),
              ),

              const SizedBox(height: 15),

              // === WIDGET DE SEGURIDAD CORPORATIVA ===
              if (_isCorporateUser) ...[
                CorporateLinkWidget(
                  emailController: _emailController,
                  onVerificationChanged: (verified, companyName) {
                    setState(() {
                      _isCorporateVerified = verified;
                      _corporateCompanyName = companyName;
                    });
                  },
                ),
                const SizedBox(height: 15),
              ],

              // =======================================
              _input(
                _passwordController,
                "Contraseña",
                Icons.lock,
                isPass: true,
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isCorporateUser ? "Solicitar Acceso" : "Registrarme",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController c,
    String l,
    IconData i, {
    bool isPass = false,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: c,
      obscureText: isPass,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: l,
        prefixIcon: Icon(i, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
