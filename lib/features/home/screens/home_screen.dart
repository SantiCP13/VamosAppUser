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
import '../../payment/services/payment_service.dart';
import '../../payment/widgets/payment_panel.dart';
import '../../trips/services/trip_service.dart';
import 'package:flutter/services.dart';
import '../../../core/models/passenger_model.dart';

enum TripState {
  IDLE,
  CALCULATING,
  ROUTE_PREVIEW,
  SEARCHING_DRIVER,
  DRIVER_ON_WAY,
  IN_TRIP,
  PAYMENT,
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
  bool _isPickingLocation = false;
  LatLng? _mapCenterPicker;
  bool _isLoadingAddress = false;
  final OsmService _osmService = OsmService();

  // --- PAGO ---
  List<PaymentMethod> _availablePaymentMethods = [];
  bool _isLoadingPaymentMethods = false;

  // --- DATOS DEL VIAJE ---
  String? _destinationName;
  LatLng? _destinationCoordinates;
  List<LatLng> _routePoints = [];

  // --- MODO Y PASAJEROS ---
  final Set<String> _selectedPassengerIds = {};
  bool _includeMyself = true;

  User get _currentUser => AuthService.currentUser!;

  // --- TARIFA Y TIEMPOS ---
  double _tripPrice = 0;
  String _tripDistance = "";
  String _tripDuration = "";

  // --- CONDUCTOR Y SIMULACIÓN ---
  LatLng? _driverPosition;
  Timer? _simulationTimer;
  final String _driverEta = "5 min";
  int _routeIndex = 0;

  // --- CATEGORÍAS ---
  double _baseRoutePrice = 0;
  String _selectedServiceCategory = 'STANDARD';
  final Map<String, double> _categoryMultipliers = {
    'STANDARD': 1.0,
    'PREMIUM': 1.35,
    'VAN': 1.8,
  };

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

  List<Beneficiary> get _selectedBeneficiariesList {
    return _currentUser.beneficiaries
        .where((b) => _selectedPassengerIds.contains(b.id))
        .toList();
  }

  int get _totalPassengers =>
      (_includeMyself ? 1 : 0) + _selectedPassengerIds.length;

  // ===============================================================
  // 1. GEOLOCALIZACIÓN Y VALIDACIÓN
  // ===============================================================

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _useDefaultLocation();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _useDefaultLocation();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _useDefaultLocation();
      return;
    }

    try {
      Position? lastKnown = await Geolocator.getLastKnownPosition();

      if (lastKnown != null && mounted) {
        setState(() {
          _currentPosition = LatLng(lastKnown.latitude, lastKnown.longitude);
        });
        _moveMapToCurrent();
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      _moveMapToCurrent();
    } catch (e) {
      if (_currentPosition == null) {
        _useDefaultLocation();
      }
    }
  }

  void _useDefaultLocation() {
    if (!mounted) return;
    setState(() {
      _currentPosition = _defaultLocation;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "⚠️ GPS no detectado. Usando ubicación aproximada.",
          style: GoogleFonts.poppins(),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
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
        SnackBar(
          content: Text(
            "No puedes cambiar de modo durante un viaje",
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (isTargetCorporate) {
      if (_currentUser.idResponsable == null) {
        _showCorporateLinkingModal();
        return;
      }
      AuthService.toggleAppMode(true);
      setState(() {
        _resetTripData();
      });
      return;
    }

    if (!isTargetCorporate) {
      if (_currentUser.idPassenger != null) {
        AuthService.toggleAppMode(false);
        setState(() {
          _resetTripData();
        });
      } else {
        _showActivateNaturalDialog();
      }
    }
  }

  void _resetTripData() {
    _routePoints = [];
    _destinationCoordinates = null;
    _destinationName = null;
  }

  void _showActivateNaturalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Activar Perfil Personal",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Como usuario Corporativo verificado, puedes activar tu perfil Personal inmediatamente.\n\n"
          "Esto te permitirá solicitar viajes particulares pagados por ti.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancelar",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Procesando solicitud...",
                    style: GoogleFonts.poppins(),
                  ),
                ),
              );

              await AuthService.activateNaturalProfile();

              if (!mounted) return;
              setState(() {
                _resetTripData();
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "¡Perfil Personal Activado!",
                    style: GoogleFonts.poppins(),
                  ),
                ),
              );
            },
            child: Text(
              "Activar Ahora",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _isTripAllowed(LatLng start, LatLng end) async {
    if (_currentUser.isCorporateMode) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Viaje No Permitido",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Estás en MODO PERSONAL.\n\n"
          "Origen: $city\nDestino: $city\n\n"
          "❌ Viajes urbanos bloqueados en este modo.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "OK",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // 2. LÓGICA DE RUTAS
  // ===============================================================

  void _updateFinalPrice() {
    double multiplier = _categoryMultipliers[_selectedServiceCategory] ?? 1.0;
    double finalRaw = _baseRoutePrice * multiplier;

    setState(() {
      _tripPrice = (finalRaw / 100).ceil() * 100;
    });
  }

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

    // --- CAMBIO: Bloque Try-Catch para manejar la nueva lógica del servicio ---
    try {
      final result = await _routeService.getRoute(
        _currentPosition!,
        destination,
      );

      if (!mounted) return;

      // Asignamos directamente, ya sabemos que result no es nulo
      _routePoints = result.points;

      // Lógica de visualización (Si es fallback, podríamos mostrar alerta aquí)
      if (result.isFallback) {
        debugPrint("⚠️ Usando ruta estimada (Línea recta)");
      }

      double km = result.distanceMeters / 1000;
      double minutes = result.durationSeconds / 60;

      // Corrección de string interpolation innecesaria
      _tripDistance = "${km.toStringAsFixed(1)} km";
      _tripDuration = "${minutes.round()} min";

      // --- CÁLCULO DE PRECIOS (Misma lógica tuya) ---
      double base = 3800;
      double costoPorKm = 1100;
      double costoPorMin = 250;
      double valorRecargo = 2500;

      double valKm = km * costoPorKm;
      double valMin = minutes * costoPorMin;

      double recargoTotal = 0;
      DateTime now = DateTime.now();
      bool esNoche = now.hour >= 20 || now.hour < 5;
      bool esDominical = now.weekday == DateTime.sunday;
      if (esNoche || esDominical) recargoTotal = valorRecargo;

      _baseRoutePrice = base + valKm + valMin + recargoTotal;

      setState(() {
        _tripState = TripState.ROUTE_PREVIEW;
        if (_totalPassengers > 4) {
          _selectedServiceCategory = 'VAN';
        } else {
          _selectedServiceCategory = 'STANDARD';
        }
      });

      _updateFinalPrice();
      _fitCameraToRoute();
    } catch (e) {
      // Manejo de errores (Timeout o fallo total)
      setState(() => _tripState = TripState.IDLE);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "No se pudo calcular la ruta: $e",
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
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
    // Color principal dinámico según el modo
    final Color mainColor = isCorporate
        ? Colors.blue[800]!
        : AppColors.primaryGreen;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideMenu(),
      body: Stack(
        children: [
          // 1. CAPA DEL MAPA
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

              if (!_isPickingLocation) ...[
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 5.0,
                        color: mainColor,
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
                            color: mainColor,
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

          // 2. BARRA SUPERIOR
          Positioned(top: 0, left: 0, right: 0, child: _buildTopHybridBar()),

          // 3. CONTROLES DEL MAPA
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

          // 4. MODO "FIJAR EN MAPA"
          if (_isPickingLocation)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 35),
                child: Icon(Icons.location_on, size: 50, color: mainColor),
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
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 10),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: mainColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Obteniendo dirección...",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // BOTÓN ESTILO NUEVO
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoadingAddress
                            ? null
                            : _confirmMapSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 4,
                          shadowColor: mainColor.withValues(alpha: 0.4),
                        ),
                        child: Text(
                          "Confirmar Ubicación",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Cancelar",
                          style: GoogleFonts.poppins(
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

          // 5. BARRA DE BÚSQUEDA (ESTILO INPUT)
          if (_tripState == TripState.IDLE && !_isPickingLocation)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: _buildSearchWidget(),
            ),

          // 6. PANELES DESLIZANTES
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
              child: Center(child: CircularProgressIndicator(color: mainColor)),
            ),
          if (_tripState == TripState.PAYMENT)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildPanelContainer(
                _isLoadingPaymentMethods
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: mainColor),
                        ),
                      )
                    : PaymentPanel(
                        amount: _tripPrice,
                        methods: _availablePaymentMethods,
                        onPaymentSuccess: _finishTripAndSave,
                      ),
              ),
            ),
        ],
      ),
    );
  }

  // ===============================================================
  // 4. WIDGETS Y LÓGICA DE INTERFAZ
  // ===============================================================
  Widget _buildVehicleSelector() {
    final List<Map<String, dynamic>> options = [
      {
        'id': 'STANDARD',
        'label': 'Económico',
        'icon': Icons.directions_car,
        'capacity': '1-4',
      },
      {
        'id': 'PREMIUM',
        'label': 'Confort',
        'icon': Icons.local_taxi,
        'capacity': '1-4',
      },
      {
        'id': 'VAN',
        'label': 'Van',
        'icon': Icons.airport_shuttle,
        'capacity': '5-10',
      },
    ];

    bool isCorp = _currentUser.isCorporateMode;
    Color activeColor = isCorp ? Colors.blue[800]! : AppColors.primaryGreen;

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final opt = options[index];
          bool isSelected = _selectedServiceCategory == opt['id'];
          bool isDisabled = false;

          if (_totalPassengers > 4 && opt['id'] != 'VAN') {
            isDisabled = true;
          }

          double mult = _categoryMultipliers[opt['id']]!;
          double priceEst = ((_baseRoutePrice * mult) / 100).ceil() * 100;

          // ESTILO CARD SELECCIONABLE
          return GestureDetector(
            onTap: isDisabled
                ? null
                : () {
                    setState(() {
                      _selectedServiceCategory = opt['id'];
                    });
                    _updateFinalPrice();
                  },
            child: Container(
              width: 110,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? activeColor : Colors.grey.shade200,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: [
                  if (!isDisabled)
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Opacity(
                opacity: isDisabled ? 0.5 : 1.0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      opt['icon'],
                      color: isSelected ? activeColor : Colors.grey[600],
                      size: 28,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      opt['label'],
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "\$ ${_formatCurrency(priceEst)}",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "${opt['capacity']} pax",
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopHybridBar() {
    bool isCorp = _currentUser.isCorporateMode;

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
    Color primaryColor = isCorp ? Colors.blue[800]! : AppColors.primaryGreen;

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
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 15),

        // DESTINO
        if (_destinationName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 20,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _destinationName!,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                      fontSize: 15,
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
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
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

        const SizedBox(height: 20),
        Divider(thickness: 1, color: Colors.grey[200]),
        const SizedBox(height: 10),

        // SELECTOR DE PASAJEROS (ESTILO INPUT)
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.groups_outlined, color: primaryColor, size: 22),
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
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_totalPassengers == 0)
                        Text(
                          "Selecciona al menos uno",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),

        const SizedBox(height: 15),
        Text(
          "Vehículo",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        _buildVehicleSelector(),

        const SizedBox(height: 15),
        Row(
          children: [
            Icon(Icons.access_time, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              "$_tripDuration aprox",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(width: 15),
            Icon(Icons.straighten, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              "$_tripDistance",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 25),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _totalPassengers > 0 ? _handleTripRequest : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 4,
              shadowColor: primaryColor.withValues(alpha: 0.4),
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
        const SizedBox(height: 10),
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

  void _handleTripRequest() {
    bool isCorp = _currentUser.isCorporateMode;

    if (isCorp && !_includeMyself) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber[800]),
              const SizedBox(width: 10),
              const Expanded(
                child: Text("Responsabilidad", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Estás solicitando un servicio Corporativo para terceros.",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                "El FUEC se generará a nombre de:",
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Titular:",
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
                      "Empresa:",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _currentUser.empresa.isEmpty
                          ? "N/A"
                          : _currentUser.empresa,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Volver", style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _processTripCreation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Aceptar",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } else {
      _processTripCreation();
    }
  }

  Future<void> _processTripCreation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Conectando con la central...",
          style: GoogleFonts.poppins(),
        ),
      ),
    );

    final tripService = TripService();

    // --- 1. PREPARACIÓN DE DATOS FUEC (CRÍTICO) ---
    // Convertimos los IDs seleccionados (_selectedPassengerIds) en objetos Passenger.
    // IMPORTANTE: Aquí asumo que solo tienes los IDs. Para cumplir la ley,
    // deberás conectar esto con los nombres/cédulas reales de tu lista de contactos.

    List<Passenger> passengersList = _selectedPassengerIds.map((id) {
      // Por ahora, creamos un objeto temporal para que COMPILE y funcione el flujo.
      return Passenger(
        name:
            "Pasajero Invitado", // Reemplázalo con el nombre real de tu variable de UI
        nationalId:
            "000000", // Reemplázalo con la cédula real (Necesario para FUEC)
      );
    }).toList();
    // ----------------------------------------------

    bool success = await tripService.createTripRequest(
      currentUser: _currentUser,
      origin: _currentPosition!,
      destination: _destinationCoordinates!,
      originAddress: "Ubicación Actual",
      destinationAddress: _destinationName!,
      serviceCategory: _selectedServiceCategory,
      estimatedPrice: _tripPrice,

      // --- CAMBIO AQUÍ ---
      passengers: passengersList, // Pasamos la lista de objetos, no los IDs
      // -------------------
      includeMyself: _includeMyself,
    );

    if (!mounted) return;

    if (success) {
      _startSearchingDriver();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "❌ Error al crear la solicitud.",
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBeneficiarySelector() {
    bool isCorp = _currentUser.isCorporateMode;
    Color primaryColor = isCorp ? Colors.blue[800]! : AppColors.primaryGreen;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
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
                          "Listo",
                          style: GoogleFonts.poppins(
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
                          ? primaryColor.withValues(alpha: 0.05)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _includeMyself
                            ? primaryColor
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _includeMyself,
                      activeColor: primaryColor,
                      title: Text(
                        "Viajo yo",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _currentUser.name,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Icon(
                          Icons.person,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      onChanged: (bool? val) {
                        setModalState(() {
                          _includeMyself = val ?? false;
                        });
                        setState(() {
                          if (_totalPassengers > 4) {
                            _selectedServiceCategory = 'VAN';
                          } else if (_selectedServiceCategory == 'VAN' &&
                              _totalPassengers <= 4) {
                            _selectedServiceCategory = 'STANDARD';
                          }
                          _updateFinalPrice();
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    "Tus Pasajeros",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: _currentUser.beneficiaries.isEmpty
                        ? Center(
                            child: Text(
                              "No tienes pasajeros agregados",
                              style: GoogleFonts.poppins(
                                color: Colors.grey[400],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _currentUser.beneficiaries.length,
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
                                    borderRadius: BorderRadius.circular(16),
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
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: Text(
                                        "¿Borrar?",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: Text(
                                        "Se eliminará a ${b.name}.",
                                        style: GoogleFonts.poppins(),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text(
                                            "Cancelar",
                                            style: GoogleFonts.poppins(),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(
                                            "Borrar",
                                            style: GoogleFonts.poppins(
                                              color: Colors.red,
                                            ),
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
                                        ? primaryColor.withValues(alpha: 0.05)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
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
                                    secondary: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.person_outline,
                                        color: Colors.grey[600],
                                        size: 20,
                                      ),
                                    ),
                                    onChanged: (bool? val) {
                                      setModalState(() {
                                        if (val == true) {
                                          _selectedPassengerIds.add(b.id);
                                        } else {
                                          _selectedPassengerIds.remove(b.id);
                                        }
                                      });
                                      setState(() {
                                        if (_totalPassengers > 4) {
                                          _selectedServiceCategory = 'VAN';
                                        }
                                        _updateFinalPrice();
                                      });
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
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showAddBeneficiaryDialog(setModalState);
                      },
                      icon: const Icon(Icons.add),
                      label: Text(
                        "Agregar Nuevo Pasajero",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
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

    // Estilo local para inputs
    InputDecoration inputDeco(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
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
          borderSide: const BorderSide(
            color: AppColors.primaryGreen,
            width: 1.5,
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Nuevo Pasajero",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.poppins(),
              decoration: inputDeco("Nombre Completo"),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: docCtrl,
              style: GoogleFonts.poppins(),
              decoration: inputDeco("Identificación (CC)"),
              keyboardType: TextInputType.number,
              // --- CAMBIO CLAVE: Restricción estricta de Input ---
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, // Solo 0-9
                LengthLimitingTextInputFormatter(
                  10,
                ), // Máx 10 dígitos (CC estándar)
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              "Cancelar",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final doc = docCtrl.text.trim();

              // Validaciones simples antes de enviar
              if (name.isEmpty) return;

              if (doc.isEmpty || doc.length < 6) {
                // Feedback visual si la cédula es muy corta
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Cédula inválida",
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                );
                return;
              }

              await AuthService.addBeneficiary(name, doc);

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              // Actualizamos la UI principal y el Modal padre
              parentModalState(() {});
              setState(() {});
            },
            child: Text(
              "Guardar",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
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
    if (_routePoints.isEmpty) return;

    // 1. SETUP DE LA ANIMACIÓN
    setState(() {
      // Saltamos directo a IN_TRIP para ver al carro recorrer la ruta azul
      _tripState = TripState.IN_TRIP;
      _driverPosition = _routePoints.first; // El carro empieza donde estás tú
      _routeIndex = 0;
    });

    _simulationTimer?.cancel();

    // 2. ANIMACIÓN FLUIDA (Cada 50ms avanza un punto en el mapa)
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Si ya llegamos al final de la lista de puntos
      if (_routeIndex >= _routePoints.length - 1) {
        timer.cancel();
        // Aseguramos que llegue exacto al destino
        setState(() => _driverPosition = _routePoints.last);

        // Esperamos un momento y mostramos pago
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _initiatePaymentFlow();
        });
        return;
      }

      // Avanzamos al siguiente punto
      _routeIndex++;
      setState(() {
        _driverPosition = _routePoints[_routeIndex];
      });
    });
  }

  Future<void> _initiatePaymentFlow() async {
    setState(() {
      _tripState = TripState.PAYMENT;
      _isLoadingPaymentMethods = true;
    });

    try {
      final methods = await PaymentService.getPaymentMethods(_currentUser);
      if (!mounted) return;
      setState(() {
        _availablePaymentMethods = methods;
        _isLoadingPaymentMethods = false;
      });
    } catch (e) {
      setState(() => _isLoadingPaymentMethods = false);
    }
  }

  void _finishTripAndSave() {
    if (_destinationName != null) {
      MenuService().addCompletedTrip(
        "Ubicación Actual",
        _destinationName!,
        _tripPrice,
      );
    }

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
              "¡Pago Exitoso!",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text("Gracias por viajar con VAMOS.", style: GoogleFonts.poppins()),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Total: \$ ${_formatCurrency(_tripPrice)}",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _resetApp();
              },
              child: Text(
                "Finalizar",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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

  // --- WIDGET BUSCADOR ESTILO INPUT ---
  Widget _buildSearchWidget() => GestureDetector(
    onTap: () async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SearchDestinationScreen(currentPosition: _currentPosition),
        ),
      );

      if (result != null) {
        if (result['isMapPick'] == true) {
          setState(() {
            _isPickingLocation = true;
            _mapCenterPicker = _mapController.camera.center;
          });
        } else {
          setState(() {
            _destinationName = result['name'];
            _destinationCoordinates = LatLng(result['lat'], result['lng']);
          });
          if (mounted) _calculateRouteAndPrice(_destinationCoordinates!);
        }
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 12,
            color: _currentUser.isCorporateMode
                ? Colors.blue[800]
                : AppColors.primaryGreen,
          ),
          const SizedBox(width: 15),
          Text(
            "¿A dónde vas?",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
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
        borderRadius: BorderRadius.circular(10),
      ),
      const SizedBox(height: 25),
      Text(
        "Buscando conductor...",
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 5),
      Text(
        "Estamos conectando con los conductores cercanos",
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
      ),
      const SizedBox(height: 25),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: _resetApp,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            "Cancelar Solicitud",
            style: GoogleFonts.poppins(color: Colors.grey[700]),
          ),
        ),
      ),
    ],
  );

  Widget _buildDriverOnWayContent() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        "Conductor en camino",
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      const SizedBox(height: 5),
      Text(
        "Llegada en $_driverEta",
        style: GoogleFonts.poppins(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.local_taxi, size: 40, color: Colors.black87),
      ),
      const SizedBox(height: 20),
      TextButton(
        onPressed: _resetApp,
        child: Text(
          "Cancelar Viaje",
          style: GoogleFonts.poppins(color: Colors.red),
        ),
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
  // 5. MODAL DE VINCULACIÓN CORPORATIVA
  // ===============================================================

  void _showCorporateLinkingModal() {
    Map<String, String>? selectedCompany;
    bool isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !isVerifying,
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
                      Expanded(
                        child: Text(
                          "Modo Corporativo",
                          style: GoogleFonts.poppins(
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
                  const SizedBox(height: 20),

                  if (isVerifying) ...[
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          Text(
                            "Validando...",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Verificando con ${selectedCompany?['name']}",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      "Selecciona tu empresa para validar tu documento.",
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Empresa",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<Map<String, String>>>(
                      future: AuthService.getAvailableCompanies(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }

                        final List<Map<String, String>> companiesList =
                            snapshot.data!;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            // CAMBIO 1: El tipo del Dropdown ahora es String (el NIT), no Map
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: Text(
                                "Toca para seleccionar...",
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              // CAMBIO 2: El valor seleccionado es solo el NIT (String)
                              // Si selectedCompany es nulo, el valor es nulo.
                              value: selectedCompany?['nit'],

                              // CAMBIO 3: Mapeamos los items usando el NIT como valor
                              items: companiesList.map((company) {
                                return DropdownMenuItem<String>(
                                  value:
                                      company['nit'], // El valor interno es el NIT
                                  child: Text(
                                    company['name']!,
                                    style: GoogleFonts.poppins(),
                                  ),
                                );
                              }).toList(),

                              // CAMBIO 4: Al cambiar, buscamos el objeto completo usando el NIT
                              onChanged: (String? newNit) {
                                if (newNit == null) return;

                                // Buscamos el mapa completo en la lista original
                                final fullCompanyObject = companiesList
                                    .firstWhere(
                                      (element) => element['nit'] == newNit,
                                    );

                                setModalState(() {
                                  selectedCompany = fullCompanyObject;
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 4,
                        ),
                        onPressed: selectedCompany == null
                            ? null
                            : () async {
                                setModalState(() {
                                  isVerifying = true;
                                });

                                bool success =
                                    await AuthService.verifyAndLinkCompanyFromBackend(
                                      nit: selectedCompany!['nit']!,
                                      companyName: selectedCompany!['name']!,
                                    );

                                if (!context.mounted) return;
                                Navigator.pop(context);

                                if (success) {
                                  setState(() {});
                                  _showSuccessDialog(selectedCompany!['name']!);
                                } else {
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
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(String companyName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Continuar",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectionDialog(String companyName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Verificación Fallida",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "No encontramos la cédula ${_currentUser.documentNumber} activa en $companyName.",
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Intentar de nuevo",
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmMapSelection() async {
    if (_mapCenterPicker == null) return;
    setState(() => _isLoadingAddress = true);

    String address = await _osmService.getAddressFromCoordinates(
      _mapCenterPicker!,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingAddress = false;
      _isPickingLocation = false;
      _destinationName = address;
      _destinationCoordinates = _mapCenterPicker;
    });

    _calculateRouteAndPrice(_destinationCoordinates!);
  }
}
