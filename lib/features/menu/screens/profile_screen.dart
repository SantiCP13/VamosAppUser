import 'dart:io';
import 'package:flutter/material.dart';
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

  // Controladores
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  // FocusNodes (Para activar el teclado al tocar el lápiz)
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  // Estados de edición individual
  bool _isNameEditable = false;
  bool _isPhoneEditable = false;
  bool _isEmailEditable = false;

  // Estado general
  File? _imageFile;
  bool _isLoading = false;

  User? get user => AuthService.currentUser;

  // Computed property: ¿Hay algo siendo editado?
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

  // ===========================================================================
  // LÓGICA DE FOTO
  // ===========================================================================
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "Cambiar foto de perfil",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.camera_alt, color: Colors.white),
                ),
                title: Text(
                  "Tomar foto (Cámara)",
                  style: GoogleFonts.poppins(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.photo_library, color: Colors.white),
                ),
                title: Text("Galería", style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  // ===========================================================================
  // LÓGICA DE GUARDADO (REAL SAVE)
  // ===========================================================================
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    // Ocultar teclado
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    String? newPhotoUrl;
    // 1. Subir imagen si existe
    if (_imageFile != null) {
      newPhotoUrl = await AuthService.uploadProfileImage(_imageFile!.path);
    }

    // 2. Enviar datos al servicio (Backend Laravel)
    final success = await AuthService.updateUserProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      photoUrl: newPhotoUrl,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Perfil actualizado correctamente"),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      // Bloquear todo de nuevo
      setState(() {
        _isNameEditable = false;
        _isPhoneEditable = false;
        _isEmailEditable = false;
        _imageFile = null;
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error al guardar cambios"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===========================================================================
  // UI PRINCIPAL
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    // CORRECCIÓN 1: Se agregaron las llaves {} al if
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Cargando...")));
    }

    final isCorp = user?.isCorporateMode ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Mi Perfil",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // El botón guardar solo aparece si hay cambios pendientes
          if (_isEditing)
            TextButton(
              onPressed: _isLoading ? null : _saveChanges,
              child: _isLoading
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      "Guardar",
                      style: GoogleFonts.poppins(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildAvatarSection(),
              const SizedBox(height: 30),

              Text(
                "Información Personal",
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),

              // CAMPO: NOMBRE
              _buildEditableField(
                controller: _nameController,
                focusNode: _nameFocus,
                label: "Nombre Completo",
                icon: Icons.person_outline,
                isEditable: _isNameEditable,
                onEditPressed: () {
                  setState(() => _isNameEditable = true);
                  _nameFocus.requestFocus(); // Auto-foco
                },
              ),
              const SizedBox(height: 15),

              // CAMPO: CELULAR
              _buildEditableField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                label: "Celular",
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
                isEditable: _isPhoneEditable,
                onEditPressed: () {
                  setState(() => _isPhoneEditable = true);
                  _phoneFocus.requestFocus();
                },
              ),
              const SizedBox(height: 15),

              // CAMPO: CORREO
              _buildEditableField(
                controller: _emailController,
                focusNode: _emailFocus,
                label: "Correo Electrónico",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                isEditable: _isEmailEditable,
                onEditPressed: () {
                  setState(() => _isEmailEditable = true);
                  _emailFocus.requestFocus();
                },
              ),

              const SizedBox(height: 30),

              // SECCIÓN CORPORATIVA (NO EDITABLE)
              if (isCorp) ...[
                const Divider(),
                const SizedBox(height: 10),
                Text(
                  "Vinculación Corporativa",
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),

                _buildReadOnlyTile(
                  icon: Icons.business,
                  title: user?.empresa ?? "Sin Empresa",
                  subtitle: "Empresa Vinculada",
                  color: Colors.blue.shade700,
                  bgColor: Colors.blue.shade50,
                ),
              ],

              const SizedBox(height: 15),

              _buildReadOnlyTile(
                icon: Icons.verified_user_outlined,
                title: _getStatusText(user?.verificationStatus),
                subtitle: "Estado de la cuenta",
                color: _getStatusColor(user?.verificationStatus),
                // CORRECCIÓN 2: Reemplazo de withOpacity por withValues(alpha: ...)
                bgColor: _getStatusColor(
                  user?.verificationStatus,
                ).withValues(alpha: 0.1),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildAvatarSection() {
    ImageProvider? imageProvider;
    if (_imageFile != null) {
      imageProvider = FileImage(_imageFile!);
    } else if (user?.photoUrl != null && user!.photoUrl!.isNotEmpty) {
      imageProvider = NetworkImage(user!.photoUrl!);
    }

    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: imageProvider == null
                ? Center(
                    child: Text(
                      user?.name[0].toUpperCase() ?? "U",
                      style: GoogleFonts.poppins(
                        fontSize: 40,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _showImagePickerOptions,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// INPUT CON LÁPIZ DE EDICIÓN
  Widget _buildEditableField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    required bool isEditable,
    required VoidCallback onEditPressed,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: !isEditable, // Solo lectura a menos que demos al lápiz
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(
        fontSize: 15,
        color: isEditable
            ? Colors.black87
            : Colors.grey.shade700, // Color visual de activo/inactivo
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
        prefixIcon: Icon(
          icon,
          color: isEditable ? AppColors.primaryGreen : Colors.grey,
          size: 22,
        ),
        // EL LÁPIZ MÁGICO
        suffixIcon: !isEditable
            ? IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                onPressed: onEditPressed,
                tooltip: "Editar $label",
              )
            : null, // Si ya estoy editando, no muestro el lápiz

        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: isEditable
            ? Colors.white
            : Colors.grey.shade50, // Fondo visual de activo/inactivo
      ),
      validator: (v) => v!.isEmpty ? "Campo requerido" : null,
    );
  }

  Widget _buildReadOnlyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  String _getStatusText(UserVerificationStatus? status) {
    switch (status) {
      case UserVerificationStatus.VERIFIED:
        return "Verificado";
      case UserVerificationStatus.UNDER_REVIEW:
        return "En Revisión";
      case UserVerificationStatus.DOCS_UPLOADED:
        return "Documentos subidos";
      case UserVerificationStatus.REJECTED:
        return "Rechazado";
      case UserVerificationStatus.REVOKED:
        return "Suspendido";
      default:
        return "Sin Verificar";
    }
  }

  Color _getStatusColor(UserVerificationStatus? status) {
    switch (status) {
      case UserVerificationStatus.VERIFIED:
        return AppColors.primaryGreen;
      case UserVerificationStatus.UNDER_REVIEW:
        return Colors.orange;
      case UserVerificationStatus.REJECTED:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
