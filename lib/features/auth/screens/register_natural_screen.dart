import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'dart:io';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'splash_screen.dart';
import 'pending_approval_screen.dart';

class RegisterNaturalScreen extends StatefulWidget {
  final String? emailPreIngresado;
  const RegisterNaturalScreen({super.key, this.emailPreIngresado});

  @override
  State<RegisterNaturalScreen> createState() => _RegisterNaturalScreenState();
}

class _RegisterNaturalScreenState extends State<RegisterNaturalScreen> {
  // Estado y Controladores
  bool _isLoading = false;
  bool _obscurePass = true;
  final _scrollController = ScrollController();
  Map<String, bool> _fieldErrors = {};

  late TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // Nueva
  final _nombreController = TextEditingController();
  final _docController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  String _tipoDocumento = 'CC';
  bool _aceptaTerminos = false;
  File? _cedulaPdf;
  File? _selfieImage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.emailPreIngresado);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nombreController.dispose();
    _docController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  Future<void> _pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() => _cedulaPdf = File(result.files.single.path!));
    }
  }

  Future<void> _takeSelfie() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() => _selfieImage = File(image.path));
    }
  }

  Future<void> _handleRegister() async {
    String? errorDetail;
    setState(() => _fieldErrors = {});

    // 1. Validaciones Premium
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
      errorDetail = "Mínimo 8 caracteres para la contraseña.";
    } else if (_passwordController.text != _confirmPasswordController.text) {
      _fieldErrors['confirmPassword'] = true;
      errorDetail = "Las contraseñas no coinciden.";
    } else if (_cedulaPdf == null) {
      errorDetail = "Sube el PDF de tu cédula.";
    } else if (_selfieImage == null) {
      errorDetail = "La verificación facial es obligatoria.";
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

    // 2. Transición a Splash de Carga
    setState(() => _isLoading = true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SplashScreen(
          logoPath:
              'assets/images/logo.png', // <--- Asegúrate que la ruta sea EXACTA
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
        'empresa_id': null,
      };

      bool success = await AuthService.registerNaturalUser(
        datos: payload,
        cedulaPdf: _cedulaPdf,
        selfieImage: _selfieImage,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cierra Splash

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PendingApprovalScreen(isNatural: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnack(e.toString().replaceAll("Exception: ", ""), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        backgroundColor: isError
            ? const Color(0xFFD32F2F)
            : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
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
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    "Usuario Natural",
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryGreen,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Crea tu cuenta personal y viaja seguro.",
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),

                  _buildSectionHeader("Información Personal"),
                  const SizedBox(height: 20),
                  _buildGlassField(
                    _nombreController,
                    "Nombre Completo",
                    Icons.person_pin_rounded,
                    fieldKey: 'nombre',
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildIdTypeDropdown()),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: _buildGlassField(
                          _docController,
                          "Número ID",
                          Icons.badge_rounded,
                          type: TextInputType.number,
                          fieldKey: 'documento',
                          maxLength: 10,
                        ),
                      ),
                    ],
                  ),

                  _buildGlassField(
                    _telefonoController,
                    "Celular",
                    Icons.phone_android_rounded,
                    type: TextInputType.phone,
                    fieldKey: 'telefono',
                    maxLength: 10,
                  ),
                  _buildGlassField(
                    _direccionController,
                    "Dirección Residencia",
                    Icons.location_on_rounded,
                    fieldKey: 'direccion',
                  ),
                  _buildGlassField(
                    _emailController,
                    "Correo Electrónico",
                    Icons.alternate_email_rounded,
                    type: TextInputType.emailAddress,
                    fieldKey: 'email',
                  ),
                  _buildGlassField(
                    _passwordController,
                    "Contraseña",
                    Icons.lock_rounded,
                    isPass: true,
                    fieldKey: 'password',
                  ),
                  _buildGlassField(
                    _confirmPasswordController,
                    "Confirmar Contraseña",
                    Icons.lock_reset_rounded,
                    isPass: true,
                    fieldKey: 'confirmPassword',
                  ),

                  const SizedBox(height: 30),
                  _buildSectionHeader("Validación de Identidad"),
                  const SizedBox(height: 20),
                  _buildFileCard(
                    "Cédula de Ciudadanía (PDF)",
                    Icons.picture_as_pdf_rounded,
                    _cedulaPdf != null,
                    _pickPDF,
                  ),
                  const SizedBox(height: 12),
                  _buildFileCard(
                    "Verificación Facial (Selfie)",
                    Icons.face_rounded,
                    _selfieImage != null,
                    _takeSelfie,
                  ),

                  const SizedBox(height: 20),
                  _buildAceptacionDatos(),
                  const SizedBox(height: 30),
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

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: AppColors.primaryGreen,
          letterSpacing: 2,
        ),
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
              color: AppColors.primaryGreen.withValues(alpha: 0.6),
            ),
          ),
        ),
        Container(
          height: 62,
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
                color: AppColors.primaryGreen,
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

  Widget _buildGlassField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool isPass = false,
    String? fieldKey,
    int? maxLength,
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
                  : AppColors.primaryGreen.withValues(alpha: 0.6),
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
                controller: ctrl,
                obscureText: isPass && _obscurePass,
                keyboardType: type,
                maxLength: maxLength,
                onTap: () {
                  if (fieldKey != null)
                    // ignore: curly_braces_in_flow_control_structures
                    setState(() => _fieldErrors[fieldKey] = false);
                },
                onChanged: (val) {
                  if (fieldKey != null && hasError)
                    // ignore: curly_braces_in_flow_control_structures
                    setState(() => _fieldErrors[fieldKey] = false);
                },
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkBlue,
                ),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "Escribe aquí...",
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: Icon(
                    icon,
                    color: hasError ? Colors.red : AppColors.primaryGreen,
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
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
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

  Widget _buildFileCard(
    String title,
    IconData icon,
    bool hasFile,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasFile
              ? AppColors.primaryGreen.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasFile
                ? AppColors.primaryGreen
                : Colors.white.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasFile ? Icons.check_circle_rounded : icon,
              color: hasFile ? AppColors.primaryGreen : Colors.grey.shade400,
              size: 30,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      color: AppColors.darkBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    hasFile ? "Cargado correctamente" : "Toca para subir",
                    style: GoogleFonts.montserrat(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!hasFile)
              const Icon(
                Icons.add_a_photo_rounded,
                size: 20,
                color: AppColors.primaryGreen,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAceptacionDatos() {
    return Row(
      children: [
        Checkbox(
          value: _aceptaTerminos,
          activeColor: AppColors.primaryGreen,
          onChanged: (val) => setState(() => _aceptaTerminos = val ?? false),
        ),
        Expanded(
          child: Text(
            "Autorizo el tratamiento de mis datos personales según la Ley 1581.",
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
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
                "CREAR CUENTA",
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
