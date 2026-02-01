import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchDestinationScreen extends StatefulWidget {
  const SearchDestinationScreen({super.key});

  @override
  State<SearchDestinationScreen> createState() =>
      _SearchDestinationScreenState();
}

class _SearchDestinationScreenState extends State<SearchDestinationScreen> {
  final TextEditingController _searchController = TextEditingController();

  // --- MODIFICACIÓN: Destinos estratégicos para Pruebas de Zona ---
  final List<Map<String, dynamic>> _mockPlaces = [
    // 1. Destinos en BOGOTÁ (Intermunicipal desde Cajicá)
    {
      "name": "WeWork Calle 93 (Bogotá)",
      "address": "Cl. 93 #19-55, Bogotá",
      "icon": "work",
      "lat": 4.6765,
      "lng": -74.0480,
    },
    {
      "name": "Aeropuerto El Dorado (Bogotá)",
      "address": "Av. El Dorado, Bogotá",
      "icon": "flight",
      "lat": 4.7011,
      "lng": -74.1469,
    },

    // 2. Destinos en CAJICÁ (Urbano desde Cajicá -> DEBE BLOQUEARSE para Natural)
    {
      "name": "Parque Principal Cajicá (Prueba Urbano)",
      "address": "Cra. 6, Cajicá, Cundinamarca",
      "icon": "park",
      "lat": 4.9183,
      "lng": -74.0258,
    },
    {
      "name": "Fontanar Centro Comercial (Cajicá/Chía)",
      "address": "Km 2.5 Vía Cajicá, Cundinamarca",
      "icon": "store",
      "lat": 4.8870,
      "lng": -74.0330,
    },

    // 3. Destino en CHÍA (Intermunicipal cercano -> PERMITIDO)
    {
      "name": "Universidad de La Sabana (Chía)",
      "address": "Campus Puente del Común, Chía",
      "icon": "school",
      "lat": 4.8633,
      "lng": -74.0322,
    },
  ];

  List<Map<String, dynamic>> _filteredPlaces = [];

  @override
  void initState() {
    super.initState();
    _filteredPlaces = _mockPlaces;
  }

  void _filterPlaces(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPlaces = _mockPlaces;
      } else {
        _filteredPlaces = _mockPlaces.where((place) {
          final name = place['name'].toString().toLowerCase();
          final address = place['address'].toString().toLowerCase();
          // Normalizamos tildes para búsqueda fácil
          final q = query.toLowerCase();
          return name.contains(q) || address.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          "Selecciona Destino de Prueba",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Selecciona 'Cajicá' para probar bloqueo urbano o 'Bogotá' para viaje permitido.",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _filterPlaces,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                hintText: "Buscar dirección...",
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _filteredPlaces.length,
              separatorBuilder: (ctx, i) =>
                  const Divider(height: 1, indent: 70),
              itemBuilder: (context, index) {
                final place = _filteredPlaces[index];
                IconData iconData = Icons.location_on;
                if (place['icon'] == 'home') iconData = Icons.home;
                if (place['icon'] == 'work') iconData = Icons.work;
                if (place['icon'] == 'flight')
                  iconData = Icons.airplanemode_active;
                if (place['icon'] == 'store') iconData = Icons.store;
                if (place['icon'] == 'school') iconData = Icons.school;
                if (place['icon'] == 'park') iconData = Icons.park;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade100,
                    child: Icon(
                      iconData,
                      color: Colors.grey.shade700,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    place['name'],
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    place['address'],
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () {
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
