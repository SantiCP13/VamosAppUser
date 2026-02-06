import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/osm_service.dart';
import 'package:latlong2/latlong.dart';

class SearchDestinationScreen extends StatefulWidget {
  final LatLng? currentPosition;
  const SearchDestinationScreen({super.key, this.currentPosition});

  @override
  State<SearchDestinationScreen> createState() =>
      _SearchDestinationScreenState();
}

class _SearchDestinationScreenState extends State<SearchDestinationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final OsmService _osmService = OsmService();

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
    _debounce?.cancel();
    super.dispose();
  }

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

      final results = await _osmService.searchPlaces(
        query,
        userLocation: widget.currentPosition,
      );

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    });
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
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "¿A dónde vas?",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. INPUT
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                hintText: "Escribe una dirección...",
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                suffixIcon: _isLoading
                    ? Transform.scale(
                        scale: 0.5,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ),
          ),

          // 2. OPCIÓN: FIJAR EN EL MAPA
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.location_on, color: Colors.black),
            ),
            title: Text(
              "Fijar ubicación en el mapa",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              "Selecciona manualmente",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
            onTap: () {
              // Retornamos una señal especial
              Navigator.pop(context, {'isMapPick': true});
            },
          ),
          const Divider(height: 1),

          // 3. LISTA DE RESULTADOS
          Expanded(
            child: listToShow.isEmpty && isSearching && !_isLoading
                // Mensaje cuando no encuentra nada
                ? Center(
                    child: Text(
                      "No encontramos esa dirección cerca.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: listToShow.length,
                    separatorBuilder: (ctx, i) =>
                        const Divider(height: 1, indent: 70),
                    itemBuilder: (ctx, index) {
                      final place = listToShow[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: Colors.grey,
                        ),
                        title: Text(
                          place['name'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          place['address'] ?? "",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        onTap: () {
                          // Retornamos el lugar seleccionado
                          Navigator.pop(context, place);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
