import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

class CompanySelectorWidget extends StatefulWidget {
  final Function(String name, String idEmpresa) onCompanySelected;

  const CompanySelectorWidget({super.key, required this.onCompanySelected});

  @override
  State<CompanySelectorWidget> createState() => _CompanySelectorWidgetState();
}

class _CompanySelectorWidgetState extends State<CompanySelectorWidget> {
  List<Map<String, String>> _companies = [];
  bool _isLoading = true;
  String? _selectedId;

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildGlassContainer(
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppColors.darkBlue, // CAMBIADO A DARK BLUE
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                dropdownColor: Colors.white.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(18),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.darkBlue,
                ),
                style: GoogleFonts.montserrat(
                  color: AppColors.darkBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: "Selecciona tu empresa",
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: const Icon(
                    Icons.business_rounded,
                    color: AppColors.darkBlue, // CAMBIADO A DARK BLUE
                    size: 22,
                  ),
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
                      color: AppColors.darkBlue, // CAMBIADO A DARK BLUE
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                ),
                items: _companies
                    .map(
                      (company) => DropdownMenuItem(
                        value: company['id'],
                        child: Text(company['name'] ?? ""),
                      ),
                    )
                    .toList(),
                onChanged: (newId) {
                  if (newId != null) {
                    setState(() => _selectedId = newId);
                    final sel = _companies.firstWhere((c) => c['id'] == newId);
                    widget.onCompanySelected(sel['name']!, sel['id']!);
                  }
                },
              ),
            ),
          ),
        ),
        if (_selectedId != null)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppColors.darkBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  "Empresa vinculada correctamente",
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkBlue, // CAMBIADO A DARK BLUE
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}
