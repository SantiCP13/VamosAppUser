// lib/features/auth/screens/register_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'verification_check_screen.dart';
// Asegúrate de que estas rutas existan
import 'pending_approval_screen.dart';
import 'widgets/corporate_link_widget.dart';
// CORREGIDO: Se eliminó el import de home_screen.dart que no se usaba

class RegisterScreen extends StatefulWidget {
  final String? emailPreIngresado;
  const RegisterScreen({super.key, this.emailPreIngresado});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // --- ESTADO GENERAL ---
  bool _isCorporateUser = false;
  bool _isLoading = false;

  // --- SEGURIDAD ---
  bool _isCorporateVerified = false;
  String? _corporateCompanyName;
  bool _isPhoneVerified = false;
  bool _areDocsUploaded = false;

  // --- CONTROLADORES ---
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
    if (_nombreController.text.isEmpty ||
        _docController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _telefonoController.text.isEmpty) {
      _showError("Completa todos los campos obligatorios");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Validaciones previas
      if (_isCorporateUser) {
        if (!_isCorporateVerified) {
          throw Exception("Debes validar tu correo corporativo.");
        }
      } else {
        if (!_isPhoneVerified) {
          bool phoneSuccess = await _showPhoneVerificationModal();

          // Verificamos mounted antes de seguir
          if (!mounted) return;

          if (!phoneSuccess) {
            setState(() => _isLoading = false);
            return;
          }
          setState(() => _isPhoneVerified = true);
        }

        if (!mounted) return;

        if (!_areDocsUploaded) {
          bool docsSuccess = await _showIdentityVerificationModal();

          if (!mounted) return;

          if (!docsSuccess) {
            setState(() => _isLoading = false);
            return;
          }
          setState(() => _areDocsUploaded = true);
        }
      }

      final payload = {
        'tipo_persona': _isCorporateUser ? 'EMPLEADO' : 'NATURAL',
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'nombre': _nombreController.text.trim(),
        'documento': _docController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
        if (_isCorporateUser) 'nombre_empresa': _corporateCompanyName,
      };

      // 2. Registro en AuthService
      bool success = await AuthService.registerPassenger(payload);

      if (!mounted) return;

      if (success) {
        if (_isCorporateUser) {
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
          _showValidationInfoDialog();
        }
      } else {
        throw Exception("No se pudo completar el registro.");
      }
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      // CORREGIDO: Eliminada la condición compleja que causaba error.
      // Solo verificamos 'mounted' y si aún está cargando.
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showValidationInfoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read, color: Colors.orange, size: 60),
            const SizedBox(height: 15),
            Text(
              "Solicitud Recibida",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Hemos recibido tus documentos. Estamos verificando tu identidad. Podrás acceder a la App para ver el estado.",
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VerificationCheckScreen(),
                    ),
                    (r) => false,
                  );
                },
                child: const Text(
                  "Entendido",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODALS DE VERIFICACIÓN ---
  Future<bool> _showPhoneVerificationModal() async {
    final otpCtrl = TextEditingController();
    await AuthService.sendPhoneOTP(_telefonoController.text);

    if (!mounted) return false;

    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
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
                const Icon(Icons.sms, size: 40, color: AppColors.primaryGreen),
                const SizedBox(height: 15),
                Text(
                  "Verificación de Celular",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Ingresa el código enviado (Demo: 555555)",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    counterText: "",
                    hintText: "______",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (otpCtrl.text.length == 6) {
                        // 1. Llamada asíncrona
                        bool valid = await AuthService.verifyPhoneOTP(
                          _telefonoController.text,
                          otpCtrl.text,
                        );

                        // 2. Si es válido, usamos 'ctx' (el contexto del Modal)
                        if (valid) {
                          // Verificamos si el Modal aún existe
                          if (ctx.mounted) {
                            Navigator.pop(ctx, true);
                          }
                        }
                        // 3. Si falla, usamos 'context' (el contexto de la Pantalla)
                        else {
                          // Verificamos si la Pantalla aún existe
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Código inválido"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                    ),
                    child: const Text(
                      "Verificar",
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

  Future<bool> _showIdentityVerificationModal() async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
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
                      "Validación de Identidad",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDocUploadItem("Cédula (Frente)", Icons.credit_card),
                    _buildDocUploadItem("Cédula (Reverso)", Icons.credit_card),
                    _buildDocUploadItem("Selfie", Icons.face),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await AuthService.uploadIdentityDocuments(
                            frontIdPath: "x",
                            backIdPath: "y",
                            selfiePath: "z",
                          );

                          // CORREGIDO: Verificar contexto tras await
                          if (!context.mounted) return;

                          Navigator.pop(ctx, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          "Enviar Documentos",
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

  Widget _buildDocUploadItem(String title, IconData icon) {
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
          const Icon(Icons.check_circle, color: AppColors.primaryGreen),
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
            children: [
              // Toggle Corporativo
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isCorporateUser = !_isCorporateUser;
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
                      const Text("Soy Empleado Corporativo"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Campos del formulario
              _input(_nombreController, "Nombre Completo", Icons.person),
              const SizedBox(height: 15),
              _input(
                _docController,
                "Cédula",
                Icons.badge,
                type: TextInputType.number,
              ),
              const SizedBox(height: 15),
              _input(
                _telefonoController,
                "Celular (+57)",
                Icons.phone,
                type: TextInputType.phone,
              ),
              const SizedBox(height: 15),
              _input(_direccionController, "Dirección", Icons.map),
              const SizedBox(height: 15),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                readOnly: _isCorporateVerified,
                decoration: InputDecoration(
                  labelText: "Correo",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: _isCorporateVerified,
                ),
              ),
              const SizedBox(height: 15),

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
                          _isCorporateUser
                              ? "Solicitar Acceso"
                              : "Completar Registro",
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
}
