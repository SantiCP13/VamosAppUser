import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import 'dart:ui';

class CompanyRegisterScreen extends StatefulWidget {
  const CompanyRegisterScreen({super.key});

  @override
  State<CompanyRegisterScreen> createState() => _CompanyRegisterScreenState();
}

class _CompanyRegisterScreenState extends State<CompanyRegisterScreen> {
  bool _isLoading = false;
  final _scrollController = ScrollController();

  // Controladores
  final _razonSocialController = TextEditingController();
  final _nitController = TextEditingController();
  final _nitDvController = TextEditingController();
  final _direccionEmpresaController = TextEditingController();
  final _telefonoEmpresaController = TextEditingController();
  final _emailEmpresaController = TextEditingController();
  final _nombreContactoController = TextEditingController();
  final _telefonoContactoController = TextEditingController();
  final _emailContactoController = TextEditingController();

  String? _ciudadSeleccionada;
  String _tipoDocumentoContacto = 'CC'; // Tipo de ID del representante
  bool _autorizaTratamientoDatos = false; // Checkbox legal
  Map<String, bool> _fieldErrors = {};

  final List<String> _ciudadesColombia = [
    'Bogotá D.C.',
    'Medellín',
    'Cali',
    'Barranquilla',
    'Cartagena',
    'Bucaramanga',
    'Pereira',
    'Manizales',
    'Cúcuta',
    'Ibagué',
    'Santa Marta',
    'Villavicencio',
    'Pasto',
    'Montería',
    'Valledupar',
    'Armenia',
    'Neiva',
    'Popayán',
    'Sincelejo',
    'Tunja',
    'Riohacha',
    'Florencia',
    'Yopal',
    'Quibdó',
    'Otras',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    _razonSocialController.dispose();
    _nitController.dispose();
    _nitDvController.dispose();
    _direccionEmpresaController.dispose();
    _telefonoEmpresaController.dispose();
    _emailEmpresaController.dispose();
    _nombreContactoController.dispose();
    _telefonoContactoController.dispose();
    _emailContactoController.dispose();
    super.dispose();
  }

  String _calcularDV(String nit) {
    if (nit.isEmpty || nit.length < 5) return "";
    try {
      List<int> v = [3, 7, 13, 17, 19, 23, 29, 37, 41, 43, 47, 53, 59, 67, 71];
      int y = 0;
      for (int i = 0; i < nit.length; i++) {
        int x = int.parse(nit.substring(nit.length - 1 - i, nit.length - i));
        y += (x * v[i]);
      }
      int mod = y % 11;
      return (mod > 1) ? (11 - mod).toString() : mod.toString();
    } catch (e) {
      return "";
    }
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  Future<void> _handleCompanyRequest() async {
    String? errorDetail;
    setState(() => _fieldErrors = {});

    if (_razonSocialController.text.trim().length < 3) {
      _fieldErrors['razonSocial'] = true;
      errorDetail = "Razón Social muy corta (mín. 3 caracteres).";
    } else if (_nitController.text.length < 9) {
      _fieldErrors['nit'] = true;
      errorDetail = "El NIT debe tener 9 dígitos.";
    } else if (_ciudadSeleccionada == null) {
      _fieldErrors['ciudad'] = true;
      errorDetail = "Selecciona una ciudad de la lista.";
    } else if (_direccionEmpresaController.text.trim().length < 5) {
      _fieldErrors['direccion'] = true;
      errorDetail = "La dirección es obligatoria.";
    } else if (_telefonoEmpresaController.text.length != 10) {
      _fieldErrors['telefono'] = true;
      errorDetail = "Teléfono corporativo debe ser de 10 dígitos.";
    } else if (!_isValidEmail(_emailEmpresaController.text)) {
      _fieldErrors['email'] = true;
      errorDetail = "Formato de email corporativo inválido.";
    } else if (_nombreContactoController.text.trim().length < 3) {
      _fieldErrors['nombreContacto'] = true;
      errorDetail = "Escribe el nombre del responsable.";
    } else if (_telefonoContactoController.text.length < 7) {
      _fieldErrors['cedula'] = true;
      errorDetail = "Cédula inválida.";
    } else if (!_isValidEmail(_emailContactoController.text)) {
      _fieldErrors['emailPersonal'] = true;
      errorDetail = "Email de contacto inválido.";
    } else if (!_autorizaTratamientoDatos) {
      errorDetail = "Debes autorizar el tratamiento de datos personales.";
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

    setState(() => _isLoading = true);
    try {
      // REEMPLAZA el bloque 'final Map<String, dynamic> requestPayload' por este:
      // Dentro de _handleCompanyRequest:
      final Map<String, dynamic> requestPayload = {
        'razon_social': _razonSocialController.text.trim(),
        'nit': "${_nitController.text.trim()}-${_nitDvController.text}",
        'ciudad': _ciudadSeleccionada,
        'direccion': _direccionEmpresaController.text.trim(),
        'telefono': _telefonoEmpresaController.text.trim(),
        'correo': _emailEmpresaController.text.trim(), // Email de Facturación
        'nombre_contacto': _nombreContactoController.text.trim(),
        'tipo_documento_contacto': _tipoDocumentoContacto,

        'cedula_contacto': _telefonoContactoController.text.trim(),
        'correo_contacto': _emailContactoController.text
            .trim(), // Email del representante
      };
      String? errorMessage = await AuthService.requestCompanyAffiliation(
        requestPayload,
      );

      if (!mounted) return;

      if (errorMessage == null) {
        _showSuccessDialog();
      } else {
        // MOSTRAR EL ERROR REAL DEL SERVIDOR
        _showSnack(errorMessage, isError: true);
      }
    } catch (e) {
      _showSnack("Error de comunicación.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Success",
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        // CORREGIDO: Curves.easeOutBack en lugar de backOut
        final curve = Curves.easeOutBack.transform(anim1.value);
        return Transform.scale(
          scale: curve,
          child: Opacity(
            opacity: anim1.value,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              color: AppColors.primaryGreen,
                              size: 70,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "¡Vamos!",
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: AppColors.darkBlue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: AppColors.darkBlue.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(text: "La solicitud para "),
                                  // NOMBRE DE LA EMPRESA EN NEGRITA
                                  TextSpan(
                                    text: _razonSocialController.text.trim(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.darkBlue,
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        " ha sido recibida. Nuestro equipo contactará a ",
                                  ),
                                  // NOMBRE DEL REPRESENTANTE EN NEGRITA
                                  TextSpan(
                                    text: _nombreContactoController.text.trim(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.darkBlue,
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        " en un plazo de 48 horas para finalizar la vinculación de su empresa",
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  "ENTENDIDO",
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? const Color(0xFFD32F2F)
            : AppColors.primaryGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        duration: const Duration(seconds: 4),
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
                colors: [Color(0xFFFFFFFF), Color.fromARGB(255, 230, 232, 235)],
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
                    "Afiliación Corporativa",
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryGreen,
                      height: 1.1,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Únete a la red corporativa de movilidad más puntual del país.",
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildSectionHeader("Información Legal de la Empresa"),
                  const SizedBox(height: 20),
                  _buildPremiumField(
                    _razonSocialController,
                    "Razón Social",
                    Icons.business_rounded,
                    fieldKey: 'razonSocial',
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: _buildPremiumField(
                          _nitController,
                          "NIT",
                          Icons.badge_rounded,
                          type: TextInputType.number,
                          fieldKey: 'nit',
                          maxLength: 9,
                          onChanged: (val) => setState(
                            () => _nitDvController.text = _calcularDV(val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // DV Corregido: Sin icono, centrado y solo lectura
                      Expanded(
                        flex: 1,
                        child: _buildPremiumField(
                          _nitDvController,
                          "DV",
                          null,
                          enabled: false,
                          isCenter: true,
                        ),
                      ),
                    ],
                  ),
                  _buildPremiumSearchableDropdown(),
                  _buildPremiumField(
                    _direccionEmpresaController,
                    "Dirección de Oficina Sede",
                    Icons.location_on_rounded,
                    fieldKey: 'direccion',
                  ),
                  _buildPremiumField(
                    _telefonoEmpresaController,
                    "Teléfono Corporativo",
                    Icons.phone_android_rounded,
                    type: TextInputType.phone,
                    fieldKey: 'telefono',
                    maxLength: 10,
                  ),
                  _buildPremiumField(
                    _emailEmpresaController,
                    "Email Corporativo",
                    Icons.alternate_email_rounded,
                    type: TextInputType.emailAddress,
                    fieldKey: 'email',
                  ),
                  const SizedBox(height: 30),
                  _buildSectionHeader("Representante de la Cuenta"),
                  const SizedBox(height: 20),
                  _buildPremiumField(
                    _nombreContactoController,
                    "Nombre Completo",
                    Icons.person_pin_rounded,
                    fieldKey: 'nombreContacto',
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SELECTOR TIPO ID
                      Expanded(flex: 2, child: _buildIdTypeDropdown()),
                      const SizedBox(width: 12),
                      // NÚMERO ID
                      Expanded(
                        flex: 4,
                        child: _buildPremiumField(
                          _telefonoContactoController,
                          "Número de Documento",
                          Icons.fingerprint_rounded,
                          type: TextInputType.number,
                          fieldKey: 'cedula',
                          maxLength: 10,
                        ),
                      ),
                    ],
                  ),
                  _buildPremiumField(
                    _emailContactoController,
                    "Email de Contacto Directo",
                    Icons.email_rounded,
                    type: TextInputType.emailAddress,
                    fieldKey: 'emailPersonal',
                  ),
                  // CHECKBOX TRATAMIENTO DE DATOS
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, left: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _autorizaTratamientoDatos,
                            activeColor: AppColors.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            onChanged: (val) => setState(
                              () => _autorizaTratamientoDatos = val ?? false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Autorizo el tratamiento de mis datos personales según la Ley 1581 de 2012.",
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
                  const SizedBox(height: 20),

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
            "Tipo ID",
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkBlue.withValues(alpha: 0.6),
            ),
          ),
        ),
        Container(
          height: 64,
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
              value: _tipoDocumentoContacto,
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
              onChanged: (val) => setState(() => _tipoDocumentoContacto = val!),
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

  Widget _buildPremiumField(
    TextEditingController controller,
    String label,
    IconData? icon, {
    TextInputType type = TextInputType.text,
    bool enabled = true,
    String? fieldKey,
    int? maxLength,
    bool isCenter = false,
    Function(String)? onChanged,
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
              child: TextField(
                controller: controller,
                enabled: enabled,
                maxLength: maxLength,
                keyboardType: type,
                textAlign: isCenter ? TextAlign.center : TextAlign.start,
                cursorColor: AppColors.primaryGreen,
                onTap: () {
                  if (fieldKey != null)
                    // ignore: curly_braces_in_flow_control_structures
                    setState(() => _fieldErrors[fieldKey] = false);
                },
                onChanged: (val) {
                  if (onChanged != null) onChanged(val);
                },
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: enabled ? AppColors.darkBlue : AppColors.primaryGreen,
                ),
                decoration: _getPremiumDecoration(
                  enabled ? "Escribe aquí..." : "",
                  icon,
                  hasError: hasError,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumSearchableDropdown() {
    bool hasError = _fieldErrors['ciudad'] ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            "Ciudad Sede",
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
              child: Autocomplete<String>(
                optionsBuilder: (TextEditingValue val) {
                  if (val.text == '') return const Iterable<String>.empty();
                  return _ciudadesColombia.where(
                    (s) => s.toLowerCase().contains(val.text.toLowerCase()),
                  );
                },
                onSelected: (s) => setState(() {
                  _ciudadSeleccionada = s;
                  _fieldErrors['ciudad'] = false;
                }),
                fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
                  return TextField(
                    controller: ctrl,
                    focusNode: focus,
                    onTap: () => setState(() => _fieldErrors['ciudad'] = false),
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: _getPremiumDecoration(
                      "Escribe para buscar...",
                      Icons.map_rounded,
                      hasError: hasError,
                      onClear: () {
                        ctrl.clear();
                        setState(() => _ciudadSeleccionada = null);
                      },
                    ),
                  );
                },
                optionsViewBuilder: (ctx, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.98),
                      elevation: 8,
                      borderRadius: BorderRadius.circular(18),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: options.length * 55.0 > 250
                              ? 250
                              : options.length * 55.0,
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (c, i) =>
                              const Divider(height: 1, color: Colors.black12),
                          itemBuilder: (c, i) {
                            final o = options.elementAt(i);
                            return ListTile(
                              title: Text(
                                o,
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              onTap: () => onSelected(o),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _getPremiumDecoration(
    String hint,
    IconData? icon, {
    bool hasError = false,
    VoidCallback? onClear,
  }) {
    return InputDecoration(
      hintText: hint,
      counterText: "",
      hintStyle: GoogleFonts.montserrat(
        fontSize: 13,
        color: Colors.grey.shade400,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: icon != null
          ? Icon(
              icon,
              size: 22,
              color: hasError ? Colors.red : AppColors.primaryGreen,
            )
          : null,
      suffixIcon: onClear != null
          ? IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.grey,
              ),
              onPressed: onClear,
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
        borderSide: BorderSide(
          color: hasError ? Colors.red : AppColors.primaryGreen,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
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
            color: AppColors.primaryGreen.withValues(alpha: 0.35),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleCompanyRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  )
                : Text(
                    "ENVIAR SOLICITUD",
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
