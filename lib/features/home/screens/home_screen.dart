import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// Ajusta estos imports a tu estructura real
import '../../../core/theme/app_colors.dart';
import '../widgets/side_menu.dart';
import '../services/route_service.dart';
import 'search_destination_screen.dart';

// --- GESTIÓN DE ESTADOS DEL VIAJE ---
enum TripState {
  IDLE, // 1. Mapa libre
  CALCULATING, // 2. Cargando ruta
  ROUTE_PREVIEW, // 3. Confirmar precio y ruta
  SEARCHING_DRIVER, // 4. Radar buscando
  DRIVER_ON_WAY, // 5. Conductor en camino (Monitoreo)
  IN_TRIP, // 6. En viaje (Opcional por ahora)
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // --- CONTROLADORES ---
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final RouteService _routeService = RouteService();

  // --- ESTADO GENERAL ---
  TripState _tripState = TripState.IDLE;
  LatLng? _currentPosition;
  final LatLng _defaultLocation = const LatLng(
    4.6768,
    -74.0483,
  ); // Bogotá Default

  // --- DATOS DEL VIAJE ---
  String? _destinationName;
  LatLng? _destinationCoordinates;
  List<LatLng> _routePoints = [];

  // --- TARIFA Y TIEMPOS ---
  double _tripPrice = 0;
  String _tripDistance = "";
  String _tripDuration = "";

  // --- CONDUCTOR Y SIMULACIÓN ---
  LatLng? _driverPosition;
  Timer? _simulationTimer;
  String _driverEta = "5 min";

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  // ===============================================================
  // 1. LÓGICA DE MAPA Y GPS
  // ===============================================================

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      // Solo movemos la cámara si estamos libres, para no interrumpir otros estados
      if (_tripState == TripState.IDLE) {
        _mapController.move(_currentPosition!, 15.0);
      }
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _moveToCurrentPosition() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 16.0);
    } else {
      _determinePosition();
    }
  }

  void _fitCameraToRoute() {
    if (_routePoints.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(
          top: 100,
          bottom: 250,
          left: 50,
          right: 50,
        ),
      ),
    );
  }

  // ===============================================================
  // 2. LÓGICA DE NEGOCIO (RUTAS Y PRECIOS)
  // ===============================================================

  Future<void> _calculateRouteAndPrice(LatLng destination) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Esperando ubicación GPS...")),
      );
      return;
    }

    setState(() => _tripState = TripState.CALCULATING);

    // Llamada al servicio OSRM
    final result = await _routeService.getRoute(_currentPosition!, destination);

    if (result != null) {
      setState(() {
        _routePoints = result.points;

        // Cálculos
        double km = result.distanceMeters / 1000;
        double minutes = result.durationSeconds / 60;

        _tripDistance = "${km.toStringAsFixed(1)} km";
        _tripDuration = "${minutes.round()} min";

        // --- FÓRMULA DE PRECIO COLOMBIA (Ejemplo) ---
        // Base: $3.800 + (Km * $1.100) + (Min * $250)
        double base = 3800;
        double valKm = km * 1100;
        double valMin = minutes * 250;
        double total = base + valKm + valMin;

        // Redondeo a la centena más cercana (ej. 12.340 -> 12.400)
        _tripPrice = (total / 100).ceil() * 100;

        _tripState = TripState.ROUTE_PREVIEW;
      });

      _fitCameraToRoute();
    } else {
      setState(() => _tripState = TripState.IDLE);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo trazar la ruta.")),
      );
    }
  }

  // ===============================================================
  // 3. SIMULACIÓN DE CONDUCTOR (SOCKET MOCK)
  // ===============================================================

  void _startSearchingDriver() {
    setState(() => _tripState = TripState.SEARCHING_DRIVER);

    // Simulamos 3 segundos de búsqueda en la red
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _assignDriverAndSimulateMovement();
    });
  }

  void _assignDriverAndSimulateMovement() {
    // 1. Crear conductor ficticio cerca
    final startDriverPos = LatLng(
      _currentPosition!.latitude - 0.005, // Un poco al sur
      _currentPosition!.longitude - 0.005, // Un poco al oeste
    );

    setState(() {
      _tripState = TripState.DRIVER_ON_WAY;
      _driverPosition = startDriverPos;
    });

    // 2. Enfocar mapa para ver al conductor y al usuario
    final bounds = LatLngBounds.fromPoints([
      _currentPosition!,
      _driverPosition!,
    ]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
    );

    // 3. Timer para mover el carrito (Esto reemplaza al WebSocket por ahora)
    int steps = 0;
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      steps++;

      // Interpolación lineal (Lerp) manual al 5% por segundo
      double newLat =
          _driverPosition!.latitude +
          (_currentPosition!.latitude - _driverPosition!.latitude) * 0.05;
      double newLng =
          _driverPosition!.longitude +
          (_currentPosition!.longitude - _driverPosition!.longitude) * 0.05;

      setState(() {
        _driverPosition = LatLng(newLat, newLng);
        // Calcular tiempo falso
        int minutesLeft = (8 - (steps / 3)).round();
        _driverEta = minutesLeft > 0 ? "$minutesLeft min" : "Llegando";
      });

      if (steps > 100) timer.cancel(); // Safety stop
    });
  }

  void _resetApp() {
    _simulationTimer?.cancel();
    setState(() {
      _tripState = TripState.IDLE;
      _routePoints = [];
      _destinationCoordinates = null;
      _driverPosition = null;
    });
    _moveToCurrentPosition();
  }

  // ===============================================================
  // 4. UI PRINCIPAL (BUILD)
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    // Detectar tema para cambiar el color del mapa si quisieras
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideMenu(),
      body: Stack(
        children: [
          // -------------------------------------------
          // CAPA 1: MAPA
          // -------------------------------------------
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultLocation,
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.all &
                    ~InteractiveFlag.rotate, // Evitar rotación accidental
              ),
            ),
            children: [
              // TILES (Estilo CartoDB Voyager - Muy limpio)
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),

              // RUTA (Línea Azul Oscura / Negra)
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: AppColors.primaryGreen,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    ),
                  ],
                ),

              // MARCADORES
              MarkerLayer(
                markers: [
                  // A. Mi Ubicación
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 25,
                      height: 25,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen, // Tu color corporativo
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(blurRadius: 5, color: Colors.black26),
                          ],
                        ),
                      ),
                    ),

                  // B. Destino (Solo si hay ruta)
                  if (_destinationCoordinates != null &&
                      _tripState != TripState.IDLE)
                    Marker(
                      point: _destinationCoordinates!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                    ),

                  // C. Conductor (Auto)
                  if (_driverPosition != null &&
                      _tripState == TripState.DRIVER_ON_WAY)
                    Marker(
                      point: _driverPosition!,
                      width: 50,
                      height: 50,
                      // Intenta usar una imagen asset, si no, usa icono
                      child: Image.asset(
                        'assets/images/car_icon.png',
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.directions_car_filled,
                          size: 40,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // -------------------------------------------
          // CAPA 2: BOTÓN MENÚ (Superior Izq)
          // -------------------------------------------
          Positioned(
            top: 50,
            left: 20,
            child: _buildCircleButton(
              icon: Icons.menu,
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),

          // -------------------------------------------
          // CAPA 3: CONTROLES MAPA (Superior Der)
          // -------------------------------------------
          Positioned(
            top: 100, // Debajo de un posible AppBar invisible
            right: 20,
            child: Column(
              children: [
                _buildMapControlBtn(
                  icon: Icons.my_location,
                  onPressed: _moveToCurrentPosition,
                ),
                const SizedBox(height: 15),
                _buildMapControlBtn(icon: Icons.add, onPressed: _zoomIn),
                const SizedBox(height: 5),
                _buildMapControlBtn(icon: Icons.remove, onPressed: _zoomOut),
              ],
            ),
          ),

          // -------------------------------------------
          // CAPA 4: PANELES INFERIORES (Dinámicos)
          // -------------------------------------------

          // ESTADO: IDLE (Buscador)
          if (_tripState == TripState.IDLE)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: _buildSearchWidget(),
            ),

          // ESTADO: PREVIEW (Confirmar)
          if (_tripState == TripState.ROUTE_PREVIEW)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildPanelContainer(_buildRoutePreviewContent()),
            ),

          // ESTADO: BUSCANDO (Radar)
          if (_tripState == TripState.SEARCHING_DRIVER)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildPanelContainer(_buildSearchingDriverContent()),
            ),

          // ESTADO: CONDUCTOR EN CAMINO (Info)
          if (_tripState == TripState.DRIVER_ON_WAY)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildPanelContainer(_buildDriverOnWayContent()),
            ),

          // LOADING SPINNER GLOBAL
          if (_tripState == TripState.CALCULATING)
            Container(
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  // ===============================================================
  // 5. WIDGETS AUXILIARES Y COMPONENTES UI
  // ===============================================================

  // Contenedor blanco con bordes redondeados arriba
  Widget _buildPanelContainer(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: SafeArea(child: child),
    );
  }

  // Botones cuadrados del mapa (Zoom/GPS)
  Widget _buildMapControlBtn({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.black87, size: 24),
        onPressed: onPressed,
      ),
    );
  }

  // Botón redondo (Menú)
  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: onPressed,
      ),
    );
  }

  // --- CONTENIDO: BUSCADOR ---
  Widget _buildSearchWidget() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchDestinationScreen()),
        );
        if (result != null && result is Map) {
          setState(() {
            _destinationName = result['name'];
            _destinationCoordinates = LatLng(result['lat'], result['lng']);
          });
          _calculateRouteAndPrice(_destinationCoordinates!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 12, color: AppColors.primaryGreen),
            const SizedBox(width: 15),
            Text(
              "¿A dónde vas?",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            const Icon(Icons.search, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // --- CONTENIDO: PREVIEW ---
  Widget _buildRoutePreviewContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Container(width: 40, height: 4, color: Colors.grey[300])),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Vamos Clásico",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "\$ ${_formatCurrency(_tripPrice)}",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          "$_tripDistance • $_tripDuration aprox.",
          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
        ),

        const Divider(height: 30),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startSearchingDriver,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Solicitar Viaje",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),

        Center(
          child: TextButton(
            onPressed: _resetApp,
            child: Text(
              "Cancelar",
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  // --- CONTENIDO: BUSCANDO ---
  Widget _buildSearchingDriverContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LinearProgressIndicator(
          color: AppColors.primaryGreen,
          backgroundColor: Colors.white,
        ),
        const SizedBox(height: 20),
        Text(
          "Buscando conductor...",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          "No cierres esta pantalla",
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => setState(() => _tripState = TripState.ROUTE_PREVIEW),
          child: const Text("Cancelar solicitud"),
        ),
      ],
    );
  }

  // --- CONTENIDO: CONDUCTOR EN CAMINO ---
  Widget _buildDriverOnWayContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TITULO Y ETA
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Llegada en $_driverEta",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Conductor en camino",
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // PLACA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                "WCM 987",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 30),

        // INFO CONDUCTOR
        Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.person, size: 30, color: Colors.grey),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Carlos Andres",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Chevrolet Beat • Rojo",
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const Spacer(),
            Column(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                Text(
                  "4.9",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 25),

        // ACCIONES
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionIcon(Icons.call, "Llamar"),
            _buildActionIcon(Icons.chat_bubble_outline, "Chat"),
            _buildActionIcon(Icons.share, "Compartir"),
            GestureDetector(
              onTap: _resetApp,
              child: _buildActionIcon(
                Icons.cancel,
                "Cancelar",
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionIcon(
    IconData icon,
    String label, {
    Color color = Colors.black87,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}
