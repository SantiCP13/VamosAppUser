import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
// Importamos el servicio (asegúrate de que la ruta sea correcta)
import '../services/auth_service.dart';
import 'referral_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? emailPreIngresado;

  const RegisterScreen({super.key, this.emailPreIngresado});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // --- VARIABLES DE ESTADO ---
  bool isEmpresa = false; // false = Persona Natural, true = Empresa
  bool isLoading = false;

  // --- CONTROLADORES DE TEXTO ---
  // Datos Generales / Contratante
  late TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _nombreContratanteController =
      TextEditingController(); // Nombre o Razón Social
  final _docContratanteController = TextEditingController(); // CC o NIT
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  // Datos del Responsable (Solo para Empresa)
  final _nombreResponsableController = TextEditingController();
  final _docResponsableController = TextEditingController();
  final _telefonoResponsableController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Inicializamos el email con lo que viene de la pantalla anterior
    _emailController = TextEditingController(text: widget.emailPreIngresado);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nombreContratanteController.dispose();
    _docContratanteController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _nombreResponsableController.dispose();
    _docResponsableController.dispose();
    _telefonoResponsableController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // Validaciones básicas (puedes agregar más)
    if (_nombreContratanteController.text.isEmpty ||
        _docContratanteController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor completa los campos obligatorios"),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    // Preparamos los datos para enviar al Backend (Laravel)
    // Aquí estructuramos el JSON según sea Empresa o Persona
    final datosRegistro = {
      'tipo_persona': isEmpresa ? 'JURIDICA' : 'NATURAL',
      'email': _emailController.text,
      'password': _passwordController.text,

      // Datos Contratante (Tabla Contratantes)
      'contratante': {
        'nombre': _nombreContratanteController.text,
        'documento': _docContratanteController.text, // NIT o CC
        'direccion': _direccionController.text,
        'telefono': _telefonoController.text,
      },

      // Datos Responsable (Tabla Responsables)
      // Si es empresa, tomamos los campos extra. Si es natural, repetimos los del contratante.
      'responsable': isEmpresa
          ? {
              'nombre': _nombreResponsableController.text,
              'documento': _docResponsableController.text,
              'telefono': _telefonoResponsableController.text,
            }
          : {
              'nombre': _nombreContratanteController.text,
              'documento': _docContratanteController.text,
              'telefono': _telefonoController.text,
            },
    };

    // Llamamos al servicio
    bool success = await AuthService.register(datosRegistro);

    if (mounted) {
      setState(() => isLoading = false);
      if (success) {
        // Registro exitoso -> Vamos al Home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ReferralCodeScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Error al registrar")));
      }
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
        title: Text(
          "Crear Cuenta",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- TOGGLE: PERSONA NATURAL VS EMPRESA ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    _buildToggleOption("Persona Natural", !isEmpresa),
                    _buildToggleOption("Empresa", isEmpresa),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                isEmpresa
                    ? "Datos de la Empresa (Contratante)"
                    : "Datos Personales (Contratante)",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),

              // --- CAMPOS COMUNES (CONTRATANTE) ---
              // Los labels cambian dinámicamente
              _buildTextField(
                controller: _nombreContratanteController,
                label: isEmpresa ? "Razón Social" : "Nombre Completo",
                icon: isEmpresa ? Icons.business : Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _docContratanteController,
                label: isEmpresa ? "NIT" : "Número de Documento (CC)",
                icon: Icons.badge_outlined,
                inputType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _direccionController,
                label: "Dirección",
                icon: Icons.place_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _telefonoController,
                label: "Teléfono / Celular",
                icon: Icons.phone_outlined,
                inputType: TextInputType.phone,
              ),

              const SizedBox(height: 24),

              // --- SECCIÓN RESPONSABLE (SOLO SI ES EMPRESA) ---
              if (isEmpresa) ...[
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  "Datos del Responsable",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.primaryGreen,
                  ),
                ),
                Text(
                  "Persona natural encargada",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _nombreResponsableController,
                  label: "Nombre del Responsable",
                  icon: Icons.person,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _docResponsableController,
                  label: "Documento (CC)",
                  icon: Icons.badge,
                  inputType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _telefonoResponsableController,
                  label: "Teléfono del Responsable",
                  icon: Icons.phone,
                  inputType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
              ],

              // --- DATOS DE CUENTA ---
              Text(
                "Credenciales de Acceso",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: "E-mail",
                icon: Icons.email_outlined,
                inputType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                label: "Contraseña",
                icon: Icons.lock_outline,
                isPassword: true,
              ),

              const SizedBox(height: 32),

              // --- BOTÓN REGISTRAR ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Crear Cuenta",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para los inputs
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
    );
  }

  // Widget auxiliar para el toggle (botón doble)
  Widget _buildToggleOption(String text, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            // Si hacemos click en Empresa, isEmpresa se vuelve true, y viceversa
            isEmpresa = text == "Empresa";
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
