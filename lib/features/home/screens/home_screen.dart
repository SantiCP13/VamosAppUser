import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart'; // Para formatear moneda (opcional, si no tienes intl, usa .toStringAsFixed)

import '../../../core/theme/app_colors.dart';
import '../widgets/side_menu.dart';
import '../services/route_service.dart'; // IMPORTANTE: Importa tu nuevo servicio
import 'search_destination_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // SERVICIOS Y CONTROLADORES
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final RouteService _routeService = RouteService(); // Instancia del servicio

  // ESTADO DEL MAPA
  LatLng? _currentPosition;
  final LatLng _defaultLocation = const LatLng(4.6768, -74.0483);

  // ESTADO DEL VIAJE
  String? _destinationName;
  LatLng? _destinationCoordinates;
  List<LatLng> _routePoints = [];

  // DATOS DE TARIFA
  bool _isCalculating = false;
  double _tripPrice = 0;
  String _tripDistance = "";
  String _tripDuration = "";

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // --- 1. GPS ---
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    // Solo movemos si no hay ruta activa
    if (_routePoints.isEmpty) {
      _mapController.move(_currentPosition!, 15.0);
    }
  }

  // --- 2. LÓGICA DE CÁLCULO DE RUTA Y PRECIO ---
  Future<void> _calculateRouteAndPrice(LatLng destination) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Necesitamos tu ubicación para calcular la ruta"),
        ),
      );
      return;
    }

    setState(() => _isCalculating = true);

    // 1. Llamar al servicio OSRM
    final result = await _routeService.getRoute(_currentPosition!, destination);

    if (result != null) {
      setState(() {
        // Guardamos la línea azul (Puntos reales de la calle)
        _routePoints = result.points;

        // Formatear datos para mostrar
        double km = result.distanceMeters / 1000;
        double minutes = result.durationSeconds / 60;

        _tripDistance = "${km.toStringAsFixed(1)} km";
        _tripDuration = "${minutes.round()} min";

        // --- MOTOR DE PRECIOS (Algoritmo Básico Colombia) ---
        // Base: $4.500
        // Km: $1.100
        // Minuto: $250
        double basePrice = 4500;
        double pricePerKm = 1100;
        double pricePerMin = 250;

        double calculated =
            basePrice + (km * pricePerKm) + (minutes * pricePerMin);

        // Redondear a la centena más cercana (ej. 12430 -> 12500)
        _tripPrice = (calculated / 100).ceil() * 100;

        _isCalculating = false;
      });

      // Ajustar cámara
      _fitCameraToRoute();

      // Mostrar Modal
      _showTripDetailsModal();
    } else {
      setState(() => _isCalculating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo calcular la ruta. Intenta de nuevo."),
          ),
        );
      }
    }
  }

  void _fitCameraToRoute() {
    if (_routePoints.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideMenu(),
      body: Stack(
        children: [
          // MAPA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultLocation,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vamosapp.colombia',
              ),
              // RUTA (Línea Azul)
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              // MARCADOR DESTINO
              if (_destinationCoordinates != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _destinationCoordinates!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              // MI UBICACIÓN (Punto azul)
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(blurRadius: 5, color: Colors.black26),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // BOTONES SUPERIORES
          Positioned(
            top: 50,
            left: 20,
            child: _buildCircleButton(
              icon: Icons.menu,
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
          Positioned(
            top: 50,
            right: 20,
            child: _buildCircleButton(
              icon: Icons.my_location,
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, 15);
                } else {
                  _determinePosition();
                }
              },
            ),
          ),

          // PANEL INFERIOR (BUSCADOR)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SearchDestinationScreen(),
                  ),
                );

                if (result != null && result is Map) {
                  setState(() {
                    _destinationName = result['name'];
                    _destinationCoordinates = LatLng(
                      result['lat'],
                      result['lng'],
                    );
                  });

                  // INICIAR CÁLCULO
                  _calculateRouteAndPrice(_destinationCoordinates!);
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
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: _destinationName == null
                          ? AppColors.primaryGreen
                          : Colors.blue,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _isCalculating
                          ? const Text(
                              "Calculando ruta óptima...",
                              style: TextStyle(color: Colors.grey),
                            )
                          : Text(
                              _destinationName ?? "¿Dónde te llevamos?",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    if (!_isCalculating)
                      const Icon(Icons.search, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MODAL DE PRECIOS REAL ---
  void _showTripDetailsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el modal ocupe lo necesario
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Row(
              children: [
                const Icon(Icons.directions_car, color: AppColors.primaryGreen),
                const SizedBox(width: 10),
                Text(
                  "Detalles del Viaje",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // INFORMACIÓN DEL VIAJE (Distancia y Tiempo real)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(Icons.timer, _tripDuration, "Tiempo"),
                  Container(width: 1, height: 30, color: Colors.grey.shade300),
                  _buildInfoItem(Icons.straighten, _tripDistance, "Distancia"),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // PRECIO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Estimado",
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  "\$ ${_formatCurrency(_tripPrice)}", // Formato bonito
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Text(
              "Incluye tarifa base y tiempo estimado.",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),

            const SizedBox(height: 20),

            // BOTÓN CONFIRMAR
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // AQUÍ IRÍA LA LÓGICA PARA BUSCAR CONDUCTOR
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Buscando conductor cercano..."),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Confirmar Vamos",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: onPressed,
      ),
    );
  }

  String _formatCurrency(double amount) {
    // Formateador manual simple (para no depender de intl si no quieres)
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}
