import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

// Asegúrate de que la ruta de importación sea la correcta en tu proyecto
import '../../../core/theme/app_colors.dart';
import '../services/osm_service.dart';

class SearchDestinationScreen extends StatefulWidget {
  final LatLng? currentPosition;
  const SearchDestinationScreen({super.key, this.currentPosition});

  @override
  State<SearchDestinationScreen> createState() =>
      _SearchDestinationScreenState();
}

class _SearchDestinationScreenState extends State<SearchDestinationScreen> {
  // CONTROLADORES
  final TextEditingController _searchController = TextEditingController();
  final OsmService _osmService = OsmService();

  // ESTADOS
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  // Mocks para pruebas rápidas
  final List<Map<String, dynamic>> _mockPlaces = [
    {
      "name": "Parque Principal Cajicá",
      "address": "Cra. 6, Cajicá",
      "lat": 4.9183,
      "lng": -74.0258,
    },
    {
      "name": "Fontanar Centro Comercial",
      "address": "Km 2.5 Vía Cajicá",
      "lat": 4.8870,
      "lng": -74.0330,
    },
    {
      "name": "Aeropuerto El Dorado",
      "address": "Bogotá",
      "lat": 4.7011,
      "lng": -74.1469,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Lógica de búsqueda con Debounce (sin cambios funcionales)
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isLoading = false;
          });
        }
        return;
      }

      setState(() => _isLoading = true);

      try {
        final results = await _osmService.searchPlaces(
          query,
          userLocation: widget.currentPosition,
        );

        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    });
  }

  // --- HELPER PARA ESTILOS DE INPUT (COPIADO Y ADAPTADO DEL LOGIN) ---
  InputDecoration _getInputStyle({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: "Ej. Centro Comercial Fontanar",
      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
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

  @override
  Widget build(BuildContext context) {
    final bool isSearching = _searchController.text.isNotEmpty;
    final List<Map<String, dynamic>> listToShow = isSearching
        ? _searchResults
        : _mockPlaces;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Usamos BackButton negro estándar como en el Login
        leading: BackButton(
          color: Colors.black,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CABECERA (ESTILO LOGIN) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "¿A dónde vas?",
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.bgColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Busca una dirección o selecciona en el mapa",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- INPUT DE BÚSQUEDA (ESTILIZADO) ---
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.poppins(color: Colors.black),
                    decoration: _getInputStyle(
                      label: "Dirección de destino",
                      icon: Icons.search,
                      suffixIcon: _isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            )
                          : isSearching
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- OPCIÓN FIJAR EN MAPA ---
            Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => Navigator.pop(context, {'isMapPick': true}),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primaryGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Fijar ubicación en el mapa",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "Selecciona manualmente",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1, thickness: 1),

            // --- LISTA DE RESULTADOS ---
            Expanded(
              child: listToShow.isEmpty && isSearching && !_isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "No encontramos esa dirección.",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 10),
                      itemCount: listToShow.length,
                      separatorBuilder: (ctx, i) => Divider(
                        height: 1,
                        indent: 70,
                        color: Colors.grey.shade100,
                      ),
                      itemBuilder: (ctx, index) {
                        final place = listToShow[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 4.0,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on_outlined,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            place['name'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            place['address'] ?? "",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(context, place),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
