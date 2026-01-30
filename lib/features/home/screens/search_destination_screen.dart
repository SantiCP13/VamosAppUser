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

  // --- CAMBIO 1: Agregamos lat/lng a la data Mock ---
  final List<Map<String, dynamic>> _mockPlaces = [
    {
      "name": "Casa (Simulada)",
      "address": "Calle 123 # 45-67",
      "icon": "home",
      "lat": 4.6950, // Coordenadas ejemplo Bogotá norte
      "lng": -74.0300,
    },
    {
      "name": "Trabajo (WeWork 93)",
      "address": "Cl. 93 #19-55",
      "icon": "work",
      "lat": 4.6765, // Parque 93
      "lng": -74.0480,
    },
    {
      "name": "Aeropuerto El Dorado",
      "address": "Av. El Dorado #103-9",
      "icon": "flight",
      "lat": 4.7011,
      "lng": -74.1469,
    },
    {
      "name": "Centro Comercial Andino",
      "address": "Cra 11 # 82-71",
      "icon": "store",
      "lat": 4.6668,
      "lng": -74.0526,
    },
    {
      "name": "Movistar Arena",
      "address": "Dg. 61c #26-36",
      "icon": "park",
      "lat": 4.6488,
      "lng": -74.0784,
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
          return name.contains(query.toLowerCase()) ||
              address.contains(query.toLowerCase());
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
          "¿A dónde vas?",
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
                hintText: "Buscar dirección",
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
                    // --- CAMBIO 2: Devolvemos el objeto completo (con lat/lng) ---
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
