// lib/features/home/screens/home_screen.dart
// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// --- IMPORTS ---
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../widgets/side_menu.dart';
import '../services/route_service.dart';
import '../../home/screens/search_destination_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../menu/services/menu_service.dart';
import '../services/osm_service.dart';

enum TripState {
  IDLE,
  CALCULATING,
  ROUTE_PREVIEW,
  SEARCHING_DRIVER,
  DRIVER_ON_WAY,
  IN_TRIP,
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
  final LatLng _defaultLocation = const LatLng(4.9183, -74.0258); // Cajicá
  bool _isMapReady = false;
  bool _isPickingLocation = false; // ¿Estamos moviendo el pin?
  LatLng? _mapCenterPicker; // Coordenada central del mapa
  bool _isLoadingAddress = false; // Cargando dirección
  final OsmService _osmService = OsmService(); // Instancia del servicio

  // --- DATOS DEL VIAJE ---
  String? _destinationName;
  LatLng? _destinationCoordinates;
  List<LatLng> _routePoints = [];

  // --- MODO Y PASAJEROS ---
  final Set<String> _selectedPassengerIds = {};
  bool _includeMyself = true; // Por defecto el dueño de la cuenta viaja

  User get _currentUser => AuthService.currentUser!;

  // --- TARIFA Y TIEMPOS ---
  double _tripPrice = 0;
  String _tripDistance = "";
  String _tripDuration = "";

  // --- CONDUCTOR Y SIMULACIÓN ---
  LatLng? _driverPosition;
  Timer? _simulationTimer;
  final String _driverEta = "5 min";

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

  // Helper para obtener la lista real de objetos seleccionados
  List<Beneficiary> get _selectedBeneficiariesList {
    return _currentUser.beneficiaries
        .where((b) => _selectedPassengerIds.contains(b.id))
        .toList();
  }

  // Helper para contar total de personas
  int get _totalPassengers =>
      (_includeMyself ? 1 : 0) + _selectedPassengerIds.length;

  // ===============================================================
  // 1. GEOLOCALIZACIÓN Y VALIDACIÓN
  // ===============================================================

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Verificar si el GPS está prendido
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("GPS Apagado -> Usando Default");
      _useDefaultLocation();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("Permiso denegado -> Usando Default");
        _useDefaultLocation();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Permiso denegado por siempre -> Usando Default");
      _useDefaultLocation();
      return;
    }

    try {
      // --- MEJORA 1: Usar Cache (Last Known Position) ---
      // Esto carga instantáneamente si el GPS ya se usó hace poco
      Position? lastKnown = await Geolocator.getLastKnownPosition();

      if (lastKnown != null && mounted) {
        debugPrint("📍 Usando ubicación en caché (rápida)");
        setState(() {
          _currentPosition = LatLng(lastKnown.latitude, lastKnown.longitude);
        });
        _moveMapToCurrent();
      }

      // --- MEJORA 2: Aumentar Timeout ---
      // 5 segundos es muy poco. Subimos a 15 segundos.
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return;

      debugPrint("📡 Ubicación GPS fresca obtenida");
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      _moveMapToCurrent();
    } catch (e) {
      debugPrint("Error GPS ($e)");
      // Solo usamos la default si NO logramos obtener ni la caché ni la fresca
      if (_currentPosition == null) {
        debugPrint("⚠️ Falló todo -> Usando ubicación por defecto (Cajicá)");
        _useDefaultLocation();
      }
    }
  }

  // Nuevo helper para no repetir código
  void _useDefaultLocation() {
    if (!mounted) return;
    setState(() {
      _currentPosition =
          _defaultLocation; // Usa la coordenada de Cajicá definida arriba
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("⚠️ GPS no detectado. Usando ubicación aproximada."),
        duration: Duration(seconds: 2),
      ),
    );
    _moveMapToCurrent();
  }

  void _moveMapToCurrent() {
    if (_tripState == TripState.IDLE &&
        _isMapReady &&
        _currentPosition != null) {
      _mapController.move(_currentPosition!, 15.0);
    }
  }

  void _toggleAppMode(bool isTargetCorporate) {
    if (_tripState != TripState.IDLE) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No puedes cambiar de modo durante un viaje"),
        ),
      );
      return;
    }

    // --- ESCENARIO 1: Quiere ir a CORPORATIVO ---
    if (isTargetCorporate) {
      // Si no tiene ID de responsable (no está vinculado), mostramos el modal de NIT
      if (_currentUser.idResponsable == null) {
        _showCorporateLinkingModal();
        return;
      }
      // Si ya lo tiene, cambio directo
      AuthService.toggleAppMode(true);
      setState(() {
        _resetTripData();
      });
      return;
    }

    // --- ESCENARIO 2: Quiere ir a PERSONAL ---
    if (!isTargetCorporate) {
      // a. Si YA tiene ID de pasajero (Perfil Natural activo) -> Cambio directo
      if (_currentUser.idPassenger != null) {
        AuthService.toggleAppMode(false);
        setState(() {
          _resetTripData();
        });
      }
      // b. Si NO tiene ID de pasajero (Es corporativo puro) -> Diálogo de activación simple
      else {
        _showActivateNaturalDialog();
      }
    }
  }

  // Helper para limpiar datos al cambiar modo
  void _resetTripData() {
    _routePoints = [];
    _destinationCoordinates = null;
    _destinationName = null;
  }

  // --- NUEVO DIÁLOGO SIMPLE (Reemplaza al _showPersonalKYCModal) ---
  // --- DIÁLOGO DE ACTIVACIÓN SIMPLE (Corregido) ---
  void _showActivateNaturalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Activar Perfil Personal"),
        content: const Text(
          "Como usuario Corporativo verificado, puedes activar tu perfil Personal inmediatamente.\n\n"
          "Esto te permitirá solicitar viajes particulares pagados por ti.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            onPressed: () async {
              // 1. Cerramos el diálogo primero
              Navigator.pop(ctx);

              // 2. Mostrar indicador de carga (Opcional, pero recomendado)
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Procesando solicitud...")),
              );

              // 3. Llamamos al servicio existente
              // (Este método ya existe en tu AuthService y hace lo correcto:
              // genera id_pasajero y cambia el modo a PERSONAL)
              await AuthService.activateNaturalProfile();

              // 4. Verificamos si el widget sigue montado antes de usar setState
              if (!mounted) return;

              // 5. Actualizamos la UI
              setState(() {
                _resetTripData();
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("¡Perfil Personal Activado y en uso!"),
                ),
              );
            },
            child: const Text(
              "Activar Ahora",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _isTripAllowed(LatLng start, LatLng end) async {
    if (_currentUser.isCorporateMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("🏢 Modo Corporativo: Viaje Autorizado."),
          backgroundColor: Colors.blue[800],
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return true;
    }

    String? startCity = await _getCityFromCoordinates(start);
    String? endCity = await _getCityFromCoordinates(end);

    if (!mounted) return false;
    if (startCity == null || endCity == null) return false;

    if (_normalizeString(startCity) == _normalizeString(endCity)) {
      _showRestrictionError(startCity);
      return false;
    }
    return true;
  }

  String _normalizeString(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
  }

  Future<String?> _getCityFromCoordinates(LatLng point) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isNotEmpty) {
        return placemarks.first.locality ??
            placemarks.first.subAdministrativeArea;
      }
    } catch (e) {
      debugPrint("Error Geocoding: $e");
    }
    return null;
  }

  void _showRestrictionError(String city) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Viaje No Permitido"),
        content: Text(
          "Estás en MODO PERSONAL.\n\n"
          "Origen: $city\nDestino: $city\n\n"
          "❌ Viajes urbanos bloqueados en este modo.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // 2. LÓGICA DE RUTAS
  // ===============================================================

  Future<void> _calculateRouteAndPrice(LatLng destination) async {
    if (_currentPosition == null) await _determinePosition();
    if (_currentPosition == null) return;

    bool allowed = await _isTripAllowed(_currentPosition!, destination);
    if (!mounted || !allowed) {
      setState(() {
        _tripState = TripState.IDLE;
        _destinationCoordinates = null;
        _destinationName = null;
      });
      return;
    }

    setState(() => _tripState = TripState.CALCULATING);

    final result = await _routeService.getRoute(_currentPosition!, destination);
    if (!mounted) return;

    if (result != null) {
      setState(() {
        _routePoints = result.points;
        double km = result.distanceMeters / 1000;
        double minutes = result.durationSeconds / 60;

        _tripDistance = "${km.toStringAsFixed(1)} km";
        _tripDuration = "${minutes.round()} min";

        // --- VARIABLES DE PRECIO ---
        double base = 3800; // Precio Base(ejemplo)
        double costoPorKm = 1100; // ValorKm(ejemplo)
        double costoPorMin = 250; // ValorMinuto(ejemplo)
        double valorPeajes =
            0; // <--- Debemos obtener esto de tu API o ponerlo manual
        double valorRecargo = 2500; // Valor del recargo (ejemplo)

        // --- CÁLCULOS BÁSICOS ---
        double valKm = km * costoPorKm;
        double valMin = minutes * costoPorMin;

        // --- LÓGICA DE RECARGO (Nocturno / Dominical) ---
        double recargoTotal = 0;
        DateTime now = DateTime.now();

        // 1. Es de noche? (Ejemplo: de 8:00 PM a 5:00 AM)
        bool esNoche = now.hour >= 20 || now.hour < 5;

        // 2. Es Domingo? (Dart: 7 es Domingo)
        // Nota: Para festivos específicos necesitas una lista de fechas festivas
        bool esDominical = now.weekday == DateTime.sunday;

        if (esNoche || esDominical) {
          recargoTotal = valorRecargo;
        }

        // --- FÓRMULA FINAL (Suma de todo) ---
        double precioBruto = base + valKm + valMin + valorPeajes + recargoTotal;

        // --- REDONDEO A LA CENTENA (Regla de negocio Colombia) ---
        _tripPrice = (precioBruto / 100).ceil() * 100;

        _tripState = TripState.ROUTE_PREVIEW;
      });
      _fitCameraToRoute();
    } else {
      setState(() => _tripState = TripState.IDLE);
    }
  }

  void _fitCameraToRoute() {
    if (_routePoints.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(_routePoints),
        padding: const EdgeInsets.only(
          top: 150,
          bottom: 300,
          left: 50,
          right: 50,
        ),
      ),
    );
  }

  void _zoomIn() {
    final z = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, z + 1);
  }

  void _zoomOut() {
    final z = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, z - 1);
  }

  void _moveToCurrentPosition() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 16.0);
    } else {
      _determinePosition();
    }
  }

  // ===============================================================
  // 3. UI PRINCIPAL
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isCorporate = _currentUser.isCorporateMode;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideMenu(),
      body: Stack(
        children: [
          // ===============================================================
          // 1. CAPA DEL MAPA
          // ===============================================================
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? _defaultLocation,
              initialZoom: 15.0,
              onMapReady: () {
                _isMapReady = true;
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, 15.0);
                }
              },
              // CRÍTICO: Detectar movimiento para el modo "Fijar en Mapa"
              onPositionChanged: (camera, hasGesture) {
                if (_isPickingLocation) {
                  _mapCenterPicker = camera.center;
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),

              // Solo mostramos rutas y marcadores normales SI NO estamos eligiendo en el mapa
              if (!_isPickingLocation) ...[
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 5.0,
                        color: isCorporate
                            ? Colors.blue[800]!
                            : AppColors.primaryGreen,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_currentPosition != null)
                      Marker(
                        point: _currentPosition!,
                        width: 25,
                        height: 25,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isCorporate
                                ? Colors.blue[800]
                                : AppColors.primaryGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(blurRadius: 5, color: Colors.black26),
                            ],
                          ),
                        ),
                      ),
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
                    if (_driverPosition != null)
                      Marker(
                        point: _driverPosition!,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.directions_car_filled,
                          size: 40,
                          color: Colors.black,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),

          // ===============================================================
          // 2. BARRA SUPERIOR (MENÚ Y MODO)
          // ===============================================================
          Positioned(top: 0, left: 0, right: 0, child: _buildTopHybridBar()),

          // ===============================================================
          // 3. CONTROLES DEL MAPA (ZOOM Y CENTRAR)
          // ===============================================================
          Positioned(
            top: 130,
            right: 20,
            child: Column(
              children: [
                _buildMapControlBtn(Icons.my_location, _moveToCurrentPosition),
                const SizedBox(height: 10),
                _buildMapControlBtn(Icons.add, _zoomIn),
                const SizedBox(height: 5),
                _buildMapControlBtn(Icons.remove, _zoomOut),
              ],
            ),
          ),

          // ===============================================================
          // 4. MODO "FIJAR EN MAPA" (PIN CENTRAL + BOTÓN CONFIRMAR)
          // ===============================================================
          if (_isPickingLocation)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 35,
                ), // Levantar para que la punta toque el centro
                child: Icon(Icons.location_on, size: 50, color: Colors.black),
              ),
            ),

          if (_isPickingLocation)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingAddress)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 10),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Obteniendo dirección...",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ElevatedButton(
                      // LLAMA A LA FUNCIÓN NUEVA QUE TE PASÉ ANTES
                      onPressed: _isLoadingAddress
                          ? null
                          : _confirmMapSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Confirmar Ubicación",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isPickingLocation = false;
                          _isLoadingAddress = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Cancelar",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ===============================================================
          // 5. BARRA DE BÚSQUEDA (SOLO SI NO ESTAMOS EN MODO PICKER)
          // ===============================================================
          if (_tripState == TripState.IDLE && !_isPickingLocation)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: _buildSearchWidget(),
            ),

          // ===============================================================
          // 6. PANELES DESLIZANTES (ESTADOS DEL VIAJE)
          // ===============================================================
          if (_tripState == TripState.ROUTE_PREVIEW)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildPanelContainer(_buildRoutePreviewContent()),
            ),

          if (_tripState == TripState.SEARCHING_DRIVER)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildPanelContainer(_buildSearchingDriverContent()),
            ),

          if (_tripState == TripState.DRIVER_ON_WAY)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildPanelContainer(_buildDriverOnWayContent()),
            ),

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
  // 4. WIDGETS Y LÓGICA DE INTERFAZ
  // ===============================================================

  Widget _buildTopHybridBar() {
    bool isCorp = _currentUser.isCorporateMode;
    // bool isEmployee = _currentUser.isEmployee;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
            const SizedBox(width: 12),
            // --- CAMBIO: Siempre mostramos el Switch, la lógica interna decide si permite cambiar ---
            Expanded(
              child: Container(
                height: 45,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Row(
                  children: [
                    _buildModeOption(
                      "Personal",
                      !isCorp,
                      AppColors.primaryGreen,
                    ),
                    _buildModeOption("Corporativo", isCorp, Colors.blue[800]!),
                  ],
                ),
              ),
            ),
            // -------------------------------------------------------------------------------------
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(String label, bool isActive, Color activeColor) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isActive) _toggleAppMode(label == "Corporativo");
        },
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: isActive ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoutePreviewContent() {
    bool isCorp = _currentUser.isCorporateMode;
    // Definimos el color principal dinámicamente
    Color primaryColor = isCorp ? Colors.blue[800]! : AppColors.primaryGreen;
    Color lightColor = isCorp
        ? Colors.blue.withValues(alpha: 0.05)
        : Colors.green.withValues(alpha: 0.05);

    // Construimos string de nombres para mostrar
    List<String> names = [];
    if (_includeMyself) names.add("Yo");
    for (var b in _selectedBeneficiariesList) {
      names.add(b.name.split(" ").first);
    }
    String passengersString = names.join(", ");
    if (passengersString.length > 30) {
      passengersString = "${passengersString.substring(0, 27)}...";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Container(width: 40, height: 4, color: Colors.grey[300])),
        const SizedBox(height: 15),

        // DESTINO
        if (_destinationName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _destinationName!,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // INFO CABECERA
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCorp ? "Viaje Corporativo" : "Viaje Personal",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isCorp ? Colors.blue[900] : Colors.black,
                    ),
                  ),
                  if (isCorp)
                    Text(
                      "FUEC Activo • Servicio Especial",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "\$ ${_formatCurrency(_tripPrice)}",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                if (isCorp)
                  Text(
                    "Pagado por Empresa",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 15),

        // --- SELECTOR DE PASAJEROS (PARA AMBOS MODOS) ---
        const Divider(),
        const SizedBox(height: 5),

        // --- CORRECCIÓN 2: Eliminación de llaves innecesarias en interpolación ---
        Text(
          "Pasajeros ($_totalPassengers)",
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        InkWell(
          onTap: _showBeneficiarySelector,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lightColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCorp ? Colors.blue[100] : Colors.green[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.groups, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passengersString.isEmpty
                            ? "Seleccionar pasajeros"
                            : passengersString,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _totalPassengers == 0
                            ? "⚠️ Selecciona al menos uno"
                            : "Total: $_totalPassengers personas",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _totalPassengers == 0
                              ? Colors.red
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.edit, color: primaryColor, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        Text(
          "$_tripDistance • $_tripDuration",
          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
        ),
        const Divider(height: 30),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            // CAMBIO AQUÍ: Llamamos a _handleTripRequest en lugar de ir directo
            onPressed: _totalPassengers > 0 ? _handleTripRequest : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              disabledBackgroundColor: Colors.grey[300],
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

  // --- NUEVO: MANEJADOR DE SOLICITUD DE VIAJE ---
  void _handleTripRequest() {
    bool isCorp = _currentUser.isCorporateMode;

    // LÓGICA CRÍTICA FUEC
    // Si es corporativo y el titular (yo) NO viaja, lanzamos advertencia.
    if (isCorp && !_includeMyself) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber[800]),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Responsabilidad Legal",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Estás solicitando un servicio Corporativo a nombre de terceros.",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                "Aunque tú no viajes, el FUEC (Contrato de Transporte) se generará con los siguientes datos de responsabilidad:",
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Titular Responsable:",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _currentUser.name,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Empresa Contratante:",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      // Si está vacío muestra "N/A", si no, muestra la empresa
                      _currentUser.empresa.isEmpty
                          ? "N/A"
                          : _currentUser.empresa,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Tú eres el responsable del servicio ante la autoridad de tránsito.",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Volver"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Cierra dialogo
                _startSearchingDriver(); // Continua flujo
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
              ),
              child: const Text(
                "Entendido y Aceptar",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } else {
      // Flujo normal (Personal o Corporativo con titular a bordo)
      _startSearchingDriver();
    }
  }

  void _showBeneficiarySelector() {
    bool isCorp = _currentUser.isCorporateMode;
    Color primaryColor = isCorp ? Colors.blue[800]! : AppColors.primaryGreen;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      color: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "¿Quiénes viajan?",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(context);
                        },
                        child: Text(
                          "Confirmar",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // OPCIÓN: YO
                  Container(
                    decoration: BoxDecoration(
                      color: _includeMyself
                          ? primaryColor.withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _includeMyself
                            ? primaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _includeMyself,
                      activeColor: primaryColor,
                      title: Text(
                        "Viajo yo (${_currentUser.name})",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      subtitle: isCorp
                          ? const Text(
                              "Responsable del FUEC",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            )
                          : null,
                      secondary: const Icon(Icons.person),
                      onChanged: (bool? val) {
                        setModalState(() {
                          _includeMyself = val ?? false;
                        });
                        setState(() {});
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    "Tus Pasajeros Guardados",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: _currentUser.beneficiaries.isEmpty
                        ? Center(
                            child: Text(
                              "No tienes pasajeros agregados",
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _currentUser.beneficiaries.length,
                            // --- CORRECCIÓN 4: Uso de nombres explícitos para evitar warning de guiones bajos ---
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, index) {
                              final b = _currentUser.beneficiaries[index];
                              final isSelected = _selectedPassengerIds.contains(
                                b.id,
                              );

                              return Dismissible(
                                key: Key(b.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                ),
                                confirmDismiss: (_) async {
                                  return await showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("¿Borrar pasajero?"),
                                      content: Text(
                                        "Se eliminará a ${b.name}.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text("Cancelar"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            "Borrar",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (_) async {
                                  await AuthService.removeBeneficiary(b.id);
                                  if (_selectedPassengerIds.contains(b.id)) {
                                    _selectedPassengerIds.remove(b.id);
                                  }
                                  setModalState(() {});
                                  setState(() {});
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor.withValues(alpha: 0.1)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryColor
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    value: isSelected,
                                    activeColor: primaryColor,
                                    title: Text(
                                      b.name,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "CC: ${b.documentNumber}",
                                      style: GoogleFonts.poppins(fontSize: 12),
                                    ),
                                    secondary: const Icon(Icons.person_pin),
                                    onChanged: (bool? val) {
                                      setModalState(() {
                                        if (val == true) {
                                          _selectedPassengerIds.add(b.id);
                                        } else {
                                          _selectedPassengerIds.remove(b.id);
                                        }
                                      });
                                      setState(() {});
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showAddBeneficiaryDialog(setModalState);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Agregar Nuevo Pasajero"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        side: BorderSide(color: primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddBeneficiaryDialog(StateSetter parentModalState) {
    final nameCtrl = TextEditingController();
    final docCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Nuevo Pasajero"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Nombre Completo"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: docCtrl,
              decoration: const InputDecoration(
                labelText: "Identificación (CC)",
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && docCtrl.text.isNotEmpty) {
                await AuthService.addBeneficiary(nameCtrl.text, docCtrl.text);

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);

                parentModalState(() {});
                setState(() {});
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _startSearchingDriver() {
    setState(() => _tripState = TripState.SEARCHING_DRIVER);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _assignDriverAndSimulateMovement();
    });
  }

  void _assignDriverAndSimulateMovement() {
    // 1. Validar que tengamos una posición actual antes de arrancar
    if (_currentPosition == null) {
      debugPrint("⚠️ No se puede simular conductor: _currentPosition es null");
      return;
    }

    // Simulamos que el conductor aparece cerca (0.005 grados de diferencia)
    final startDriverPos = LatLng(
      _currentPosition!.latitude - 0.005,
      _currentPosition!.longitude - 0.005,
    );

    setState(() {
      _tripState = TripState.DRIVER_ON_WAY;
      _driverPosition = startDriverPos;
    });

    // Cancelamos timer anterior si existía para evitar duplicados
    _simulationTimer?.cancel();

    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // GUARDIA 1: ¿El widget sigue vivo?
      if (!mounted) {
        timer.cancel();
        return;
      }

      // GUARDIA 2: Captura segura (Snapshot) del estado actual
      final currentUserPos = _currentPosition;
      final currentDriverPos = _driverPosition;

      // GUARDIA 3: Si alguno es nulo, detenemos la simulación inmediatamente
      if (currentUserPos == null || currentDriverPos == null) {
        debugPrint(
          "Simulación detenida: Posición de usuario o conductor perdidas.",
        );
        timer.cancel();
        return;
      }

      // LÓGICA SEGURA: Usamos las variables locales 'currentUserPos' y 'currentDriverPos'
      // que sabemos que NO son nulas aquí.

      // Interpolación lineal (LERP) simple para mover al conductor 5% hacia el usuario
      double newLat =
          currentDriverPos.latitude +
          (currentUserPos.latitude - currentDriverPos.latitude) * 0.05;

      double newLng =
          currentDriverPos.longitude +
          (currentUserPos.longitude - currentDriverPos.longitude) * 0.05;

      // Verificamos cercanía para "llegar"
      // (Opcional: puedes usar una librería de distancia real aquí)
      final distLat = (currentUserPos.latitude - newLat).abs();
      final distLng = (currentUserPos.longitude - newLng).abs();

      setState(() {
        _driverPosition = LatLng(newLat, newLng);
      });

      // Si está muy cerca, termina la simulación
      if (distLat < 0.0001 && distLng < 0.0001) {
        timer.cancel();

        // Simular pequeño delay de "Viaje en curso" y luego finalizar
        setState(() => _tripState = TripState.IN_TRIP);

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _finishTripAndSave(); // <--- LLAMADA A LA NUEVA FUNCIÓN
        });
      }
    });
  }

  void _finishTripAndSave() {
    // 1. Guardar en el Historial (MenuService)
    if (_destinationName != null) {
      // Instanciamos el servicio y guardamos
      MenuService().addCompletedTrip(_destinationName!, _tripPrice);
    }

    // 2. Mostrar confirmación visual (Recibo simple)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text("¡Llegaste!", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Destino: $_destinationName"),
            const SizedBox(height: 10),
            Text(
              "\$ ${_formatCurrency(_tripPrice)}",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "El viaje se ha guardado en tu historial.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx); // Cerrar diálogo
              _resetApp(); // Reiniciar mapa
            },
            child: const Text("Aceptar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _resetApp() {
    _simulationTimer?.cancel();
    setState(() {
      _tripState = TripState.IDLE;
      _routePoints = [];
      _destinationCoordinates = null;
      _destinationName = null;
      _driverPosition = null;
      _selectedPassengerIds.clear();
      _includeMyself = true;
    });
    _moveToCurrentPosition();
  }

  // --- HELPERS UI ---
  Widget _buildPanelContainer(Widget child) => Container(
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

  Widget _buildMapControlBtn(IconData icon, VoidCallback tap) => Container(
    width: 45,
    height: 45,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
      ],
    ),
    child: IconButton(
      icon: Icon(icon, color: Colors.black87),
      onPressed: tap,
    ),
  );

  Widget _buildSearchWidget() => GestureDetector(
    onTap: () async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchDestinationScreen(
            currentPosition: _currentPosition, // <--- ESTO ES LA CLAVE
          ),
        ),
      );

      if (result != null) {
        // CASO A: El usuario eligió "Fijar en mapa"
        if (result['isMapPick'] == true) {
          setState(() {
            _isPickingLocation = true; // Activamos el modo Picker
            _mapCenterPicker =
                _mapController.camera.center; // Iniciamos donde esté la cámara
          });
        }
        // CASO B: Eligió una dirección de la lista
        else {
          setState(() {
            _destinationName = result['name'];
            _destinationCoordinates = LatLng(result['lat'], result['lng']);
          });
          if (mounted) _calculateRouteAndPrice(_destinationCoordinates!);
        }
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15),
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
            ),
          ),
          const Spacer(),
          const Icon(Icons.search, color: Colors.grey),
        ],
      ),
    ),
  );

  Widget _buildSearchingDriverContent() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      LinearProgressIndicator(
        color: _currentUser.isCorporateMode
            ? Colors.blue[800]
            : AppColors.primaryGreen,
      ),
      const SizedBox(height: 20),
      Text(
        "Buscando conductor...",
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      OutlinedButton(onPressed: _resetApp, child: const Text("Cancelar")),
    ],
  );

  Widget _buildDriverOnWayContent() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        "Conductor en camino",
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      Text(
        "Llegada en $_driverEta",
        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
      ),
      const SizedBox(height: 10),
      const Icon(Icons.local_taxi, size: 50),
      TextButton(
        onPressed: _resetApp,
        child: const Text("Cancelar", style: TextStyle(color: Colors.red)),
      ),
    ],
  );

  String _formatCurrency(double amount) => amount
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );

  // ===============================================================
  // 5. MODAL DE VINCULACIÓN CORPORATIVA (SELECCIÓN SIMPLE)
  // ===============================================================

  void _showCorporateLinkingModal() {
    // Variable para guardar la empresa seleccionada del Dropdown
    Map<String, String>? selectedCompany;

    // Variable para controlar si mostramos el estado de "Verificando..."
    bool isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !isVerifying, // No cerrar mientras verifica
      enableDrag: !isVerifying,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CABECERA ---
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.domain, color: Colors.blue[900]),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Activar Modo Corporativo",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!isVerifying)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 15),

                  // --- CUERPO: CASO 1 (VERIFICANDO) ---
                  if (isVerifying) ...[
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          Text(
                            "Validando con la empresa...",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Consultando cédula ${_currentUser.documentNumber}\nen la base de datos de ${selectedCompany?['name']}...",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),

                    // --- CUERPO: CASO 2 (FORMULARIO) ---
                  ] else ...[
                    Text(
                      "Selecciona la empresa a la que perteneces. Validaremos automáticamente si tu documento está autorizado.",
                      style: GoogleFonts.poppins(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // DROPDOWN CON FUTURE BUILDER
                    const Text(
                      "Empresa",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<Map<String, String>>>(
                      future:
                          AuthService.getAvailableCompanies(), // Método nuevo
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            height: 55,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text("Cargando empresas..."),
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, String>>(
                              isExpanded: true,
                              hint: const Text("Toca para seleccionar..."),
                              value: selectedCompany,
                              items: snapshot.data!.map((company) {
                                return DropdownMenuItem(
                                  value: company,
                                  child: Text(
                                    company['name']!,
                                    style: GoogleFonts.poppins(),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setModalState(() {
                                  selectedCompany = val;
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    // BOTÓN DE ACCIÓN
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        onPressed: selectedCompany == null
                            ? null
                            : () async {
                                // 1. CAMBIAR ESTADO A VERIFICANDO
                                setModalState(() {
                                  isVerifying = true;
                                });

                                // 2. LLAMAR AL SERVICIO
                                bool success =
                                    await AuthService.verifyAndLinkCompanyFromBackend(
                                      nit: selectedCompany!['nit']!,
                                      companyName: selectedCompany!['name']!,
                                    );

                                // 3. MANEJAR RESPUESTA
                                if (!context.mounted) return;

                                // Cerramos el modal de formulario
                                Navigator.pop(context);

                                if (success) {
                                  // ÉXITO
                                  setState(() {
                                    // Forzamos rebuild del Home para ver el cambio de color
                                  });
                                  _showSuccessDialog(selectedCompany!['name']!);
                                } else {
                                  // FALLO
                                  _showRejectionDialog(
                                    selectedCompany!['name']!,
                                  );
                                }
                              },
                        child: Text(
                          "Verificar Vinculación",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- DIÁLOGO DE ÉXITO ---
  void _showSuccessDialog(String companyName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 20),
            Text(
              "¡Bienvenido!",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Tu identidad ha sido verificada correctamente por $companyName.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Ir a Modo Corporativo",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- DIÁLOGO DE RECHAZO ---
  void _showRejectionDialog(String companyName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            const Text("Verificación Fallida"),
          ],
        ),
        content: Text(
          "No encontramos la cédula ${_currentUser.documentNumber} en la lista de empleados activos de $companyName.\n\nPor favor contacta a RRHH de tu empresa.",
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Intentar de nuevo",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmMapSelection() async {
    if (_mapCenterPicker == null) return;

    setState(() => _isLoadingAddress = true);

    // Llamamos al servicio para traducir coordenadas a texto
    String address = await _osmService.getAddressFromCoordinates(
      _mapCenterPicker!,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingAddress = false;
      _isPickingLocation = false; // Salimos del modo picker

      // Seteamos el destino
      _destinationName = address;
      _destinationCoordinates = _mapCenterPicker;
    });

    // Calculamos la ruta inmediatamente
    _calculateRouteAndPrice(_destinationCoordinates!);
  }
}
