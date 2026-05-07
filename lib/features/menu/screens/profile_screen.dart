import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <--- IMPORTANTE: Para formatters
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../auth/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  bool _isNameEditable = false;
  bool _isPhoneEditable = false;
  bool _isEmailEditable = false;

  File? _imageFile;
  bool _isLoading = false;

  User? get user => AuthService.currentUser;

  bool get _isEditing =>
      _isNameEditable ||
      _isPhoneEditable ||
      _isEmailEditable ||
      _imageFile != null;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<void> _saveChanges() async {
    // 1. VALIDACIÓN DE FORMULARIO
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final success = await AuthService.updateUserProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      imageFile: _imageFile,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      _showSnack("Perfil actualizado correctamente");
      setState(() {
        _isNameEditable = _isPhoneEditable = _isEmailEditable = false;
        _imageFile = null;
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? Colors.redAccent : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.5,
                colors: [Colors.white, Color(0xFFF1F5F9)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Form(
                      key: _formKey, // <--- ASIGNACIÓN DEL KEY
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildAvatarSection(),
                          const SizedBox(height: 40),

                          _buildGlassContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle("INFORMACIÓN PERSONAL"),
                                const SizedBox(height: 20),

                                // NOMBRE
                                _buildPremiumInput(
                                  controller: _nameController,
                                  focusNode: _nameFocus,
                                  label: "NOMBRE COMPLETO",
                                  icon: Icons.person_outline_rounded,
                                  isEditable: _isNameEditable,
                                  onEdit: () => setState(() {
                                    _isNameEditable = true;
                                    _nameFocus.requestFocus();
                                  }),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'El nombre no puede estar vacío';
                                    }
                                    if (value.trim().length < 3) {
                                      return 'Nombre demasiado corto';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                // TELÉFONO
                                _buildPremiumInput(
                                  controller: _phoneController,
                                  focusNode: _phoneFocus,
                                  label: "NÚMERO CELULAR",
                                  icon: Icons.phone_android_rounded,
                                  keyboardType: TextInputType.phone,
                                  isEditable: _isPhoneEditable,
                                  onEdit: () => setState(() {
                                    _isPhoneEditable = true;
                                    _phoneFocus.requestFocus();
                                  }),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'El celular es obligatorio';
                                    }
                                    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                                      return 'Ingresa 10 dígitos válidos';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                // CORREO
                                _buildPremiumInput(
                                  controller: _emailController,
                                  focusNode: _emailFocus,
                                  label: "CORREO ELECTRÓNICO",
                                  icon: Icons.alternate_email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  isEditable: _isEmailEditable,
                                  onEdit: () => setState(() {
                                    _isEmailEditable = true;
                                    _emailFocus.requestFocus();
                                  }),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'El correo es obligatorio';
                                    }
                                    final emailRegex = RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    );
                                    if (!emailRegex.hasMatch(value)) {
                                      return 'Correo electrónico no válido';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 25),

                          _buildGlassContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle("CUENTA Y SEGURIDAD"),
                                const SizedBox(height: 15),
                                _buildReadOnlyTile(
                                  icon: Icons.verified_user_rounded,
                                  title: "Estado de cuenta",
                                  value: _getStatusText(
                                    user?.verificationStatus,
                                  ),
                                  accentColor: _getStatusColor(
                                    user?.verificationStatus,
                                  ),
                                ),
                                if (user?.companyUuid != null) ...[
                                  const SizedBox(height: 15),
                                  _buildReadOnlyTile(
                                    icon: Icons.business_rounded,
                                    title: "Empresa vinculada",
                                    value: user?.empresa ?? "N/A",
                                    accentColor: const Color(0xFF0D47A1),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isEditing)
            Positioned(
              bottom: 30,
              left: 28,
              right: 28,
              child: _buildSaveButton(),
            ),
        ],
      ),
    );
  }

  // --- WIDGETS DE APOYO CON VALIDACIÓN ---

  Widget _buildPremiumInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required bool isEditable,
    required VoidCallback onEdit,
    String? Function(String?)? validator, // <--- NUEVO
    List<TextInputFormatter>? inputFormatters, // <--- NUEVO
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            color: Colors.blueGrey.shade300,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          readOnly: !isEditable,
          keyboardType: keyboardType,
          validator: validator, // <--- ASIGNACIÓN
          inputFormatters: inputFormatters, // <--- ASIGNACIÓN
          style: GoogleFonts.montserrat(
            color: AppColors.darkBlue,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: isEditable ? AppColors.primaryGreen : Colors.grey.shade400,
              size: 20,
            ),
            suffixIcon: !isEditable
                ? IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    onPressed: onEdit,
                  )
                : null,
            filled: true,
            fillColor: isEditable ? Colors.white : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 15,
              horizontal: 15,
            ),
            errorStyle: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isEditable
                    ? AppColors.primaryGreen.withValues(alpha: 0.5)
                    : Colors.grey.shade100,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // --- LOS DEMÁS WIDGETS SE MANTIENEN IGUAL QUE EN EL PASO ANTERIOR ---
  Widget _buildCustomAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black54,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
          Text(
            "MI PERFIL",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 2,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _pickImage(ImageSource.gallery),
            child: CircleAvatar(
              radius: 65,
              backgroundColor: const Color(0xFFF1F5F9),
              backgroundImage: _imageFile != null
                  ? FileImage(_imageFile!)
                  : (user?.photoUrl != null
                            ? NetworkImage(user!.photoUrl!)
                            : null)
                        as ImageProvider?,
              child: (user?.photoUrl == null && _imageFile == null)
                  ? Icon(
                      Icons.person_rounded,
                      size: 50,
                      color: Colors.grey.shade400,
                    )
                  : null,
            ),
          ),
          Positioned(
            bottom: 5,
            right: 5,
            child: GestureDetector(
              onTap: () => _pickImage(ImageSource.camera),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.darkBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryGreen,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildReadOnlyTile({
    required IconData icon,
    required String title,
    required String value,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  color: Colors.blueGrey.shade300,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkBlue,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFCBD5E1)),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveChanges,
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
                "GUARDAR CAMBIOS",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  String _getStatusText(UserVerificationStatus? status) {
    switch (status) {
      case UserVerificationStatus.VERIFIED:
        return "VERIFICADO";
      case UserVerificationStatus.UNDER_REVIEW:
        return "EN REVISIÓN";
      default:
        return "PENDIENTE";
    }
  }

  Color _getStatusColor(UserVerificationStatus? status) {
    switch (status) {
      case UserVerificationStatus.VERIFIED:
        return AppColors.primaryGreen;
      case UserVerificationStatus.UNDER_REVIEW:
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }
}
