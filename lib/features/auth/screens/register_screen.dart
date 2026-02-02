import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'verification_check_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? emailPreIngresado;
  const RegisterScreen({super.key, this.emailPreIngresado});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isLoading = false;

  // Estados de Verificación
  bool _isEmailVerified = false;
  bool _areDocsUploaded = false;

  // Controladores
  late TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _docController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.emailPreIngresado);
  }

  Future<void> _handleRegister() async {
    // 1. Validar Campos
    if (_nombreController.text.isEmpty ||
        _docController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _telefonoController.text.isEmpty) {
      _showError("Por favor completa todos los campos");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Verificar Correo (Si no lo ha hecho)
      if (!_isEmailVerified) {
        bool emailSuccess = await _showEmailVerificationModal();
        if (!mounted) return;

        if (!emailSuccess) {
          setState(() => _isLoading = false);
          return;
        }
        setState(() => _isEmailVerified = true);
      }

      // 3. Subir Documentos (Obligatorio)
      if (!_areDocsUploaded) {
        // Pausamos el loading del botón principal para mostrar el modal
        // (Visualmente queda mejor si el modal maneja su propio loading,
        // pero aquí mantenemos el flujo simple)
        bool docsSuccess = await _showIdentityVerificationModal();
        if (!mounted) return;

        if (!docsSuccess) {
          setState(() => _isLoading = false);
          _showError("La verificación de identidad es obligatoria.");
          return;
        }
        setState(() => _areDocsUploaded = true);
      }

      // 4. Registrar en Backend
      final payload = {
        'tipo_persona': 'NATURAL',
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'nombre': _nombreController.text.trim(),
        'documento': _docController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
        // En un caso real, aquí enviarías las URLs de las fotos
        'docs_uploaded': true,
      };

      bool success = await AuthService.registerPassenger(payload);

      if (!mounted) return;

      if (success) {
        // 5. Redirigir a Pantalla de "Pendiente / Revisión"
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const VerificationCheckScreen()),
          (r) => false,
        );
      } else {
        throw Exception("Error al crear la cuenta.");
      }
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- MODAL OTP CORREO ---
  Future<bool> _showEmailVerificationModal() async {
    final otpCtrl = TextEditingController();
    await AuthService.sendEmailOTP(_emailController.text);

    if (!mounted) return false;

    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          builder: (ctx) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 30,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 50,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(height: 15),
                Text(
                  "Verifica tu Correo",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Enviamos un código a ${_emailController.text}\n(Código Demo: 123456)",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 25),
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 24, letterSpacing: 5),
                  decoration: const InputDecoration(
                    counterText: "",
                    hintText: "000000",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (otpCtrl.text.length == 6) {
                        bool valid = await AuthService.verifyEmailOTP(
                          _emailController.text,
                          otpCtrl.text,
                        );
                        if (ctx.mounted) {
                          if (valid) {
                            Navigator.pop(ctx, true);
                          } else {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text("Código incorrecto"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Validar Correo",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  // --- MODAL DE DOCUMENTOS (KYC) ---
  Future<bool> _showIdentityVerificationModal() async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          builder: (ctx) => StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(width: 40, height: 4, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    Text(
                      "Seguridad ante todo",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Necesitamos validar que eres tú.",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildDocItem(
                      "Cédula (Frente)",
                      Icons.credit_card_outlined,
                    ),
                    _buildDocItem("Cédula (Reverso)", Icons.credit_card),
                    _buildDocItem("Selfie", Icons.face),

                    const Spacer(),
                    const Text(
                      "Tus datos están protegidos y solo se usan para validación legal.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Simular subida
                          Navigator.pop(ctx, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Confirmar y Subir",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ) ??
        false;
  }

  Widget _buildDocItem(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700]),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          // En una app real, aquí mostrarías si ya se tomó la foto
          const Icon(Icons.camera_alt, color: AppColors.primaryGreen),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Widget _input(
    TextEditingController c,
    String label,
    IconData icon, {
    bool isPass = false,
    TextInputType type = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: c,
          obscureText: isPass,
          keyboardType: type,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Crear Cuenta",
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            children: [
              _input(
                _nombreController,
                "Nombre Completo",
                Icons.person_outline,
              ),
              const SizedBox(height: 15),
              _input(
                _docController,
                "Cédula",
                Icons.badge_outlined,
                type: TextInputType.number,
              ),
              const SizedBox(height: 15),
              _input(
                _telefonoController,
                "Celular",
                Icons.phone_android_outlined,
                type: TextInputType.phone,
              ),
              const SizedBox(height: 15),
              _input(_direccionController, "Dirección", Icons.map_outlined),
              const SizedBox(height: 15),
              _input(
                _emailController,
                "Correo Electrónico",
                Icons.email_outlined,
                type: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              _input(
                _passwordController,
                "Contraseña",
                Icons.lock_outline,
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Registrarme",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
}
