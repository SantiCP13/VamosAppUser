import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

class CompanySelectorWidget extends StatefulWidget {
  // 🔥 AHORA DEVUELVE EL ID EN LUGAR DEL NIT
  final Function(String name, String idEmpresa) onCompanySelected;

  const CompanySelectorWidget({super.key, required this.onCompanySelected});

  @override
  State<CompanySelectorWidget> createState() => _CompanySelectorWidgetState();
}

class _CompanySelectorWidgetState extends State<CompanySelectorWidget> {
  List<Map<String, String>> _companies = [];
  bool _isLoading = true;
  String? _selectedId; // 🔥 Cambiado para almacenar el ID

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await AuthService.searchCompanies("");
      if (mounted) {
        setState(() {
          _companies = companies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Cargando empresas...",
              style: GoogleFonts.poppins(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    if (_companies.isEmpty) {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          "No hay empresas disponibles.",
          style: GoogleFonts.poppins(color: Colors.red.shade400),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: InputDecoration(
            labelText: "Seleccionar Empresa",
            labelStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            prefixIcon: const Icon(
              Icons.business_center_outlined,
              size: 20,
              color: AppColors.primaryGreen,
            ),
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
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.grey.shade600,
          ),
          initialValue: _selectedId,
          hint: Text(
            "Toca para ver la lista",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
          items: _companies.map((company) {
            return DropdownMenuItem<String>(
              value: company['id'], // 🔥 AHORA EL VALUE ES EL ID
              child: Text(
                company['name'] ?? "Sin Nombre",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              ),
            );
          }).toList(),
          onChanged: (String? newId) {
            setState(() {
              _selectedId = newId;
            });

            if (newId != null) {
              final selectedCompany = _companies.firstWhere(
                (c) => c['id'] == newId,
              );
              // 🔥 Enviamos el nombre y el ID al RegisterScreen
              widget.onCompanySelected(
                selectedCompany['name']!,
                selectedCompany['id']!,
              );
            }
          },
        ),

        if (_selectedId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.primaryGreen,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  "Empresa seleccionada correctamente",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
