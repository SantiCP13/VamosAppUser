import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'pending_approval_screen.dart';
import 'widgets/company_selector_widget.dart';
import 'dart:ui';
import 'splash_screen.dart'; // Ajusta la ruta si es necesario

class RegisterScreen extends StatefulWidget {
  final String? emailPreIngresado;
  const RegisterScreen({super.key, this.emailPreIngresado});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isLoading = false;
  bool _obscurePass = true;
  final _scrollController = ScrollController();

  // Controladores
  late TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _docController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  String? _selectedCompanyName;
  String? _selectedCompanyId;
  Map<String, bool> _fieldErrors = {};
  final _confirmPasswordController = TextEditingController(); // Nueva
  String _tipoDocumento = 'CC'; // Valor inicial
  bool _aceptaTerminos = false; // Estado del checkbox legal
  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.emailPreIngresado);
  }

  @override
  void dispose() {
    _confirmPasswordController.dispose();

    _scrollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nombreController.dispose();
    _docController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  Future<void> _handleRegister() async {
    String? errorDetail;
    setState(() => _fieldErrors = {});

    // 1. Validaciones Locales
    if (_nombreController.text.trim().length < 3) {
      _fieldErrors['nombre'] = true;
      errorDetail = "Escribe tu nombre completo.";
    } else if (_docController.text.length < 6) {
      _fieldErrors['documento'] = true;
      errorDetail = "Número de documento inválido.";
    } else if (_telefonoController.text.length != 10) {
      _fieldErrors['telefono'] = true;
      errorDetail = "El celular debe tener 10 dígitos.";
    } else if (!_isValidEmail(_emailController.text)) {
      _fieldErrors['email'] = true;
      errorDetail = "Formato de email inválido.";
    } else if (_passwordController.text.length < 8) {
      _fieldErrors['password'] = true;
      errorDetail = "La contraseña debe tener mínimo 8 caracteres.";
    } else if (_passwordController.text != _confirmPasswordController.text) {
      _fieldErrors['confirmPassword'] = true;
      errorDetail = "Las contraseñas no coinciden.";
    } else if (_selectedCompanyId == null) {
      _fieldErrors['empresa'] = true;
      errorDetail = "Debes seleccionar una empresa.";
    } else if (!_aceptaTerminos) {
      errorDetail = "Debes aceptar los términos y condiciones.";
    }

    if (errorDetail != null) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
      _showSnack(errorDetail, isError: true);
      return;
    }

    // 2. INICIO DE CARGA PREMIUM
    setState(() => _isLoading = true);

    // Lanzamos el Splash como Loader (isDark: false porque es User App)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SplashScreen(
          logoPath: 'assets/images/logo.png',
          isLoader: true,
          isDark: false,
        ),
      ),
    );

    try {
      final payload = {
        'nombre': _nombreController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'documento': _docController.text.trim(),
        'tipo_documento': _tipoDocumento,
        'telefono': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'empresa_id': _selectedCompanyId,
        'role': 2,
      };

      bool success = await AuthService.registerCorporateUser(payload);

      if (!mounted) return;

      // 3. CIERRE DE CARGA
      Navigator.pop(context); // Quitamos el Splash

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PendingApprovalScreen(
              isNatural: false,
              empresaNombre: _selectedCompanyName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Quitar splash si hay error
      _showSnack(e.toString().replaceAll("Exception: ", ""), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFD32F2F) : AppColors.darkBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppColors.darkBlue,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.45),
                radius: 1.8,
                colors: [Color(0xFFFFFFFF), Color(0xFFE6E8EB)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    "Registro Empleado",
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkBlue, // CAMBIADO A DARK BLUE
                      height: 1.1,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Vincula tu cuenta a los beneficios corporativos de tu empresa.",
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildSectionHeader("Información Personal"),
                  const SizedBox(height: 20),
                  _buildPremiumField(
                    _nombreController,
                    "Nombre Completo",
                    Icons.person_pin_rounded,
                    fieldKey: 'nombre',
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SELECTOR DE TIPO
                      Expanded(flex: 2, child: _buildIdTypeDropdown()),
                      const SizedBox(width: 12),
                      // NÚMERO DE DOCUMENTO
                      Expanded(
                        flex: 4,
                        child: _buildPremiumField(
                          _docController,
                          "Número ID",
                          Icons.badge_rounded,
                          type: TextInputType.number,
                          fieldKey: 'documento',
                          maxLength: 10, // <--- AGREGADO
                        ),
                      ),
                    ],
                  ),
                  _buildPremiumField(
                    _telefonoController,
                    "Celular",
                    Icons.phone_android_rounded,
                    type: TextInputType.phone,
                    fieldKey: 'telefono',
                    maxLength: 10, // <--- AGREGADO (Importante para Colombia)
                  ),
                  _buildPremiumField(
                    _direccionController,
                    "Dirección Residencia",
                    Icons.location_on_rounded,
                    fieldKey: 'direccion',
                  ),
                  _buildPremiumField(
                    _emailController,
                    "Correo Electrónico",
                    Icons.email_rounded,
                    type: TextInputType.emailAddress,
                    fieldKey: 'email',
                  ),
                  _buildPremiumField(
                    _passwordController,
                    "Contraseña",
                    Icons.lock_rounded,
                    isPass: true,
                    fieldKey: 'password',
                  ),
                  _buildPremiumField(
                    _confirmPasswordController,
                    "Confirmar Contraseña",
                    Icons.lock_reset_rounded,
                    isPass: true,
                    fieldKey: 'confirmPassword',
                  ),
                  const SizedBox(height: 30),
                  _buildSectionHeader("Vinculación Laboral"),
                  const SizedBox(height: 20),
                  _buildCompanySelectorLabel(),
                  CompanySelectorWidget(
                    onCompanySelected: (name, id) {
                      setState(() {
                        _selectedCompanyName = name;
                        _selectedCompanyId = id;
                        _fieldErrors['empresa'] = false;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _aceptaTerminos,
                          activeColor: AppColors.darkBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          onChanged: (val) =>
                              setState(() => _aceptaTerminos = val ?? false),
                        ),
                        Expanded(
                          child: Text(
                            "Acepto los Términos, Condiciones y la Política de Tratamiento de Datos Personales.",
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                  _buildSubmitButton(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            "Tipo",
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkBlue.withValues(alpha: 0.6),
            ),
          ),
        ),
        Container(
          height: 62, // Alineado con los otros campos
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
          ),
          child: Center(
            child: DropdownButton<String>(
              value: _tipoDocumento,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.darkBlue,
              ),
              items: ['CC', 'CE', 'PPT'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkBlue,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _tipoDocumento = val!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkBlue.withValues(alpha: 0.1), // CAMBIADO A BLUE
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: AppColors.darkBlue, // CAMBIADO A BLUE
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildCompanySelectorLabel() {
    bool hasError = _fieldErrors['empresa'] ?? false;
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        "Selecciona tu Empresa",
        style: GoogleFonts.montserrat(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: hasError
              ? Colors.red
              : AppColors.darkBlue.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildPremiumField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool isPass = false,
    String? fieldKey,
    int? maxLength, // <--- AGREGADO
  }) {
    bool hasError = fieldKey != null && (_fieldErrors[fieldKey] ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: hasError
                  ? Colors.red
                  : AppColors.darkBlue.withValues(alpha: 0.6),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasError
                  ? Colors.red.withValues(alpha: 0.6)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: TextFormField(
                controller: controller,
                obscureText: isPass && _obscurePass,
                keyboardType: type,
                maxLength: maxLength, // <--- VITAL: Esto limita los dígitos
                cursorColor: AppColors.darkBlue,
                onChanged: (val) {
                  if (fieldKey != null && hasError) {
                    setState(() => _fieldErrors[fieldKey] = false);
                  }
                },
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkBlue,
                ),
                decoration: InputDecoration(
                  counterText: "", // Oculta el contador de caracteres feo
                  hintText: "Escribe aquí...",
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: Icon(
                    icon,
                    color: hasError ? Colors.red : AppColors.darkBlue,
                    size: 22,
                  ),
                  suffixIcon: isPass
                      ? IconButton(
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.6),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: AppColors.darkBlue,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                "VINCULAR MI CUENTA",
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }
}
