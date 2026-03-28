import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'verification_check_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class RegisterNaturalScreen extends StatefulWidget {
  final String? emailPreIngresado;
  const RegisterNaturalScreen({super.key, this.emailPreIngresado});

  @override
  State<RegisterNaturalScreen> createState() => _RegisterNaturalScreenState();
}

class _RegisterNaturalScreenState extends State<RegisterNaturalScreen> {
  // ignore: prefer_final_fields
  bool _isLoading = false;
  bool _obscurePass = true;

  // Controladores
  late TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _docController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  // 🔥 1. Variables para saber si ya se completó el paso (Las que daban error)
  bool _cedulaUploaded = false;
  bool _biometricVerified = false;

  // 🔥 2. Variables para guardar los archivos reales
  File? _cedulaPdf;
  File? _selfieImage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.emailPreIngresado);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nombreController.dispose();
    _docController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  // --- ESTILOS & UTILIDADES ---

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.cancel_outlined : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.poppins())),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFE53935)
            : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  InputDecoration _getInputStyle({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.grey.shade600,
      ),
      prefixIcon: Icon(icon, size: 20, color: AppColors.primaryGreen),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
    );
  }

  // --- LÓGICA ---

  Future<void> _handleRegister() async {
    // 1. Validaciones de Texto
    if (_nombreController.text.isEmpty ||
        _docController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _telefonoController.text.isEmpty) {
      _showSnack(
        "Por favor completa todos los campos de texto.",
        isError: true,
      );
      return;
    }

    // 2. Validaciones de Biometría y Archivos
    if (_cedulaPdf == null) {
      _showSnack("Debes adjuntar el PDF de tu cédula.", isError: true);
      return;
    }
    if (_selfieImage == null) {
      _showSnack("Debes tomar la foto de verificación facial.", isError: true);
      return;
    }

    // 🔥 3. MOSTRAR PANTALLA DE CARGA (MODAL)
    showDialog(
      context: context,
      barrierDismissible:
          false, // Evita que el usuario lo cierre tocando afuera
      builder: (BuildContext c) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primaryGreen),
                const SizedBox(height: 20),
                Text(
                  "Subiendo documentos...",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Esto puede tardar hasta un minuto dependiendo de tu conexión. Por favor, no cierres la app.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final payload = {
        'tipo_persona': 'NATURAL',
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'nombre': _nombreController.text.trim(),
        'documento': _docController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion': _direccionController.text.trim(),
      };

      // Llamada al servicio (Puede tardar hasta 60s)
      bool success = await AuthService.registerNaturalUser(
        datos: payload,
        cedulaPdf: _cedulaPdf,
        selfieImage: _selfieImage,
      );

      if (!mounted) return;

      // 🔥 CERRAMOS EL MODAL DE CARGA
      Navigator.of(context).pop();

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const VerificationCheckScreen(
              isCorporateRegistration: false, // 🔥 Le avisamos que es Natural
            ),
          ),
        );
      } else {
        throw Exception("No se pudo completar el registro.");
      }
    } catch (e) {
      if (!mounted) return;
      // SI HAY ERROR: Cerramos el modal de carga y mostramos el error rojo
      Navigator.of(context).pop();
      _showSnack(e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  // 📸 FUNCIÓN PARA TOMAR SELFIE
  Future<void> _takeSelfie() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front, // Cámara frontal
      imageQuality: 70, // Comprimir un poco
    );

    if (image != null) {
      setState(() {
        _selfieImage = File(image.path);
        _biometricVerified = true;
      });
      _showSnack("Selfie capturada correctamente");
    }
  }

  // 📄 FUNCIÓN PARA SELECCIONAR PDF
  Future<void> _pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'], // Solo permite PDFs
    );

    if (result != null) {
      setState(() {
        _cedulaPdf = File(result.files.single.path!);
        _cedulaUploaded = true;
      });
      _showSnack("PDF adjuntado: ${result.files.single.name}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Encabezado H1
              Text(
                "Crear cuenta como Natural",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 30),
                child: Text(
                  "Ingresa tus datos y verifica tu identidad para empezar a viajar.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),

              // --- DATOS BÁSICOS ---
              Text(
                "Datos Personales",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.poppins(),
                decoration: _getInputStyle(
                  label: "Nombre Completo",
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _docController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(),
                decoration: _getInputStyle(
                  label: "Número de Cédula",
                  icon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.poppins(),
                decoration: _getInputStyle(
                  label: "Celular",
                  icon: Icons.phone_android_outlined,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _direccionController,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.poppins(),
                decoration: _getInputStyle(
                  label: "Dirección",
                  icon: Icons.map_outlined,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.poppins(),
                decoration: _getInputStyle(
                  label: "Correo Electrónico",
                  icon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePass,
                style: GoogleFonts.poppins(),
                decoration: _getInputStyle(
                  label: "Contraseña",
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              Divider(thickness: 1, color: Colors.grey[200]),
              const SizedBox(height: 20),

              // --- VERIFICACIÓN ---
              Text(
                "Seguridad y Verificación",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Pasos obligatorios para validar tu identidad.",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 15),

              // Tarjeta 1: Cédula
              _buildVerificationCard(
                title: "Documento de Cédula (PDF)", // Cambiamos el texto
                subtitle: _cedulaPdf != null
                    ? "Archivo seleccionado"
                    : "Sube tu cédula en formato PDF",
                icon: Icons.picture_as_pdf,
                isDone: _cedulaUploaded,
                onTap: _pickPDF, // Llama al selector de PDF
              ),

              const SizedBox(height: 12),

              // Tarjeta 2: Biometría (Selfie)
              _buildVerificationCard(
                title: "Verificación Facial",
                subtitle: _selfieImage != null
                    ? "Selfie capturada"
                    : "Selfie para validar que eres tú",
                icon: Icons.face,
                isDone: _biometricVerified,
                onTap: _takeSelfie, // Llama a la cámara real
              ),

              const SizedBox(height: 40),

              // --- BOTÓN FINAL ---
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
                    elevation: 4,
                    shadowColor: AppColors.primaryGreen.withValues(alpha: 0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Crear Cuenta",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? AppColors.primaryGreen : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDone)
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          // Icono Circular
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDone ? Colors.white : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check : icon,
              color: isDone ? AppColors.primaryGreen : Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Textos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDone ? AppColors.primaryGreen : Colors.black87,
                  ),
                ),
                if (!isDone)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Botón de Acción (si no está hecho)
          if (!isDone)
            IconButton(
              onPressed: onTap,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primaryGreen,
              ),
            ),
        ],
      ),
    );
  }
}
