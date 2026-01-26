import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
// Ahora esta ruta funcionará correctamente al mover el archivo:
import '../widgets/side_menu.dart';
import 'search_destination_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Comentamos esto porque sin API Key no cargará
  // final Completer<GoogleMapController> _controller = Completer();

  // ignore: unused_field
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    // _determinePosition(); // Desactivamos el GPS por ahora para no pedir permisos sin mapa
  }

  // ... (puedes dejar la función _determinePosition ahí, no molesta) ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const SideMenu(),
      body: Stack(
        children: [
          // 1. FONDO TEMPORAL (EN LUGAR DEL MAPA)
          Container(
            color: Colors.grey.shade300,
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Aquí irá el Mapa",
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "(Sin API Key configurada)",
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),

          /* 
          --- AQUÍ ESTÁ EL MAPA REAL (COMENTADO POR AHORA) ---
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kInitialPosition,
            // ... resto del código del mapa
          ), 
          */

          // 2. BOTÓN DE MENÚ (Hamburguesa)
          Positioned(
            top: 50,
            left: 20,
            child: Builder(
              builder: (context) => CircleAvatar(
                backgroundColor: Colors.white,
                radius: 25,
                child: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black87),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
            ),
          ),

          // 3. BOTÓN CENTRAR UBICACIÓN
          Positioned(
            top: 50,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 25,
              child: IconButton(
                icon: const Icon(
                  Icons.my_location,
                  color: AppColors.primaryGreen,
                ),
                // onPressed: _determinePosition, // Comentado temporalmente
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("GPS desactivado temporalmente"),
                    ),
                  );
                },
              ),
            ),
          ),

          // 4. PANEL INFERIOR
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchDestinationScreen(),
                  ),
                );
                if (result != null) {
                  debugPrint("Destino: $result");
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 12,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 15),
                    Text(
                      "¿Dónde te llevamos?",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
