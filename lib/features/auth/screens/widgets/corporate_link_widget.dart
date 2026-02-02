import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';

class CorporateLinkWidget extends StatefulWidget {
  final TextEditingController emailController;
  final Function(bool isVerified, String? companyName) onVerificationChanged;

  const CorporateLinkWidget({
    super.key,
    required this.emailController,
    required this.onVerificationChanged,
  });

  @override
  State<CorporateLinkWidget> createState() => _CorporateLinkWidgetState();
}

class _CorporateLinkWidgetState extends State<CorporateLinkWidget> {
  bool _isCheckingDomain = false;
  bool _otpSent = false;
  bool _isVerifyingOtp = false;
  bool _verificationSuccess = false;

  String? _detectedCompanyName;
  final TextEditingController _otpController = TextEditingController();

  Future<void> _validateDomain() async {
    if (widget.emailController.text.isEmpty ||
        !widget.emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa un correo válido primero")),
      );
      return;
    }

    setState(() => _isCheckingDomain = true);

    try {
      final companyName = await AuthService.checkCorporateDomain(
        widget.emailController.text.trim(),
      );

      if (!mounted) return;

      if (companyName != null) {
        bool otpSent = await AuthService.sendCorporateOTP(
          widget.emailController.text.trim(),
        );

        if (!mounted) return;

        if (otpSent) {
          setState(() {
            _detectedCompanyName = companyName;
            _otpSent = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Código enviado a ${widget.emailController.text}"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Este dominio no tiene convenio corporativo activo"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error de conexión")));
      }
    } finally {
      if (mounted) setState(() => _isCheckingDomain = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) return;

    setState(() => _isVerifyingOtp = true);

    try {
      bool isValid = await AuthService.verifyCorporateOTP(
        widget.emailController.text.trim(),
        _otpController.text.trim(),
      );

      if (!mounted) return;

      if (isValid) {
        setState(() => _verificationSuccess = true);
        widget.onVerificationChanged(true, _detectedCompanyName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Código incorrecto"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verificationSuccess) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Vinculación Exitosa",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  Text(
                    _detectedCompanyName ?? "Empresa",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(
                "Validación Corporativa",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _otpSent
                ? "Hemos enviado un código de 6 dígitos a tu correo."
                : "Ingresa tu correo arriba y valida el dominio de tu empresa.",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 15),

          if (!_otpSent)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCheckingDomain ? null : _validateDomain,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: _isCheckingDomain
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Validar Dominio"),
              ),
            ),

          if (_otpSent) ...[
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: "Código OTP (ej: 123456)",
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifyingOtp ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: _isVerifyingOtp
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Verificar Código"),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _otpSent = false),
              child: const Text(
                "Cambiar correo / Reintentar",
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
