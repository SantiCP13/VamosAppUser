import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../services/mapbox_search_service.dart';

class SearchDestinationScreen extends StatefulWidget {
  final LatLng? currentPosition;
  const SearchDestinationScreen({super.key, this.currentPosition});

  @override
  State<SearchDestinationScreen> createState() =>
      _SearchDestinationScreenState();
}

class _SearchDestinationScreenState extends State<SearchDestinationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapboxSearchService _mapboxSearch = MapboxSearchService();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  // --- ESTO ES LO QUE FALTABA (Mocks) ---
  final List<Map<String, dynamic>> _mockPlaces = [
    {
      "name": "Parque Principal Cajicá",
      "address": "Cra. 6, Cajicá",
      "mapbox_id": "mock_1",
    },
    {
      "name": "Fontanar Centro Comercial",
      "address": "Km 2.5 Vía Cajicá",
      "mapbox_id": "mock_2",
    },
    {
      "name": "Aeropuerto El Dorado",
      "address": "Bogotá",
      "mapbox_id": "mock_3",
    },
  ];

  @override
  void initState() {
    super.initState();
    _mapboxSearch.startNewSession();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- ESTO ES LO QUE FALTABA (Estilo del Input) ---
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

  // lib/features/home/screens/search_destination_screen.dart

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Usamos widget.currentPosition que viene de la pantalla anterior
        final results = await _mapboxSearch.searchPlaces(
          query,
          proximity: widget.currentPosition,
        );

        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _isLoading = false; // Detenemos el círculo de carga
        });
      } catch (e) {
        debugPrint("Error en pantalla de búsqueda: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _handleResultTap(Map<String, dynamic> place) async {
    // Si es un mock (ejemplo), lo manejamos manual para pruebas
    if (place['mapbox_id'].toString().startsWith('mock_')) {
      // Coordenadas fijas para los ejemplos si no quieres llamar a la API
      Navigator.pop(context, {
        "name": place['name'],
        "lat": 4.9183,
        "lng": -74.0258,
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final coords = await _mapboxSearch.getCoords(place['mapbox_id']);
      if (coords != null && mounted) {
        Navigator.pop(context, {
          "name": place['name'],
          "address": place['address'],
          "lat": coords['lat'],
          "lng": coords['lng'],
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: _getInputStyle(
                      label: "Dirección de destino",
                      icon: Icons.search,
                      suffixIcon: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.location_on,
                color: AppColors.primaryGreen,
              ),
              title: const Text("Fijar en el mapa"),
              onTap: () => Navigator.pop(context, {'isMapPick': true}),
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                itemCount: listToShow.length,
                separatorBuilder: (context, i) => const Divider(),
                itemBuilder: (ctx, index) {
                  final place = listToShow[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 4.0,
                    ),
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: Colors.grey,
                    ),
                    // NOMBRE DEL LUGAR (Ej: Cajicá)
                    title: Text(
                      place['name'] ?? "Cargando...",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    // DIRECCIÓN (Ej: Cundinamarca, Colombia)
                    subtitle: Text(
                      place['address'] ?? "",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _handleResultTap(place),
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
