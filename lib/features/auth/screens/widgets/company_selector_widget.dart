import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

class CompanySelectorWidget extends StatefulWidget {
  final Function(String name, String nit) onCompanySelected;

  const CompanySelectorWidget({super.key, required this.onCompanySelected});

  @override
  State<CompanySelectorWidget> createState() => _CompanySelectorWidgetState();
}

class _CompanySelectorWidgetState extends State<CompanySelectorWidget> {
  List<Map<String, String>> _companies = [];
  bool _isLoading = true;
  String? _selectedNit;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    // Llamamos con string vacío para traer todas
    final companies = await AuthService.searchCompanies("");
    if (mounted) {
      setState(() {
        _companies = companies;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: LinearProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: "Seleccionar Empresa",
            prefixIcon: const Icon(Icons.business_outlined, color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: _selectedNit != null
                ? Colors.green.shade50
                : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 15,
            ),
          ),
          icon: const Icon(Icons.arrow_drop_down_circle_outlined),
          initialValue: _selectedNit,
          hint: Text(
            "Toca para ver lista",
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          items: _companies.map((company) {
            return DropdownMenuItem<String>(
              value: company['nit'],
              child: SizedBox(
                width:
                    MediaQuery.of(context).size.width * 0.6, // Evita overflow
                child: Text(
                  company['name']!,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newNit) {
            setState(() {
              _selectedNit = newNit;
            });

            if (newNit != null) {
              final selectedCompany = _companies.firstWhere(
                (c) => c['nit'] == newNit,
              );
              widget.onCompanySelected(
                selectedCompany['name']!,
                selectedCompany['nit']!,
              );
            }
          },
        ),

        if (_selectedNit != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 5),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primaryGreen,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  "Empresa seleccionada correctamente.",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
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
