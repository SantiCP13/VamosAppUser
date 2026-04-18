// lib/features/home/screens/home_screen.dart
// ignore_for_file: constant_identifier_names, avoid_print

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

// --- IMPORTS ---
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../widgets/side_menu.dart';
import '../services/route_service.dart';
import '../../home/screens/search_destination_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../menu/services/menu_service.dart';
import '../services/osm_service.dart';
import '../../payment/services/payment_service.dart';

import '../../trips/services/trip_service.dart';
import 'package:flutter/services.dart';
import '../../../core/models/passenger_model.dart';
import '../../home/services/home_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/utils/cached_tile_provider.dart';

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
  final HomeService _homeService = HomeService();
  // --- ESTADO GENERAL ---
  TripState _tripState = TripState.IDLE;
  LatLng? _currentPosition;
  final LatLng _defaultLocation = const LatLng(4.9183, -74.0258); // Cajicá
  bool _isMapReady = false;
  bool _isPickingLocation =
      false; // Controla si el panel de pedido está abierto o minimizado
  LatLng? _mapCenterPicker;
  double _currentSheetExtent = 0.45; // Rastrea el tamaño actual del panel
  bool _isLoadingAddress = false;
  final OsmService _osmService = OsmService();
  bool _isFinishingLock = false; // El Lock anti-polling
  Map<String, dynamic>? _driverData; // Datos del conductor (Vacío 2)
  String? _currentTripId;
  // Cerca de las otras variables booleanas (aprox línea 65)
  bool _isPickingOrigin = false;
  // --- PAGO ---
  List<PaymentMethod> _userMethods = []; // Lista real del service
  PaymentMethod? _selectedMethod;

  // --- DATOS DEL VIAJE ---
  String? _destinationName;
  LatLng? _destinationCoordinates;
  List<LatLng> _routePoints = [];
  String? _originName = "Mi ubicación"; // Valor por defecto
  LatLng? _originCoordinates;

  // --- MODO Y PASAJEROS ---
  final Set<String> _selectedPassengerIds = {};
  bool _includeMyself = true;

  User get _currentUser => AuthService.currentUser!;

  // --- TARIFA Y TIEMPOS ---
  double _tripPrice = 0;
  // ignore: prefer_final_fields
  String _tripDistance = "0 km";
  // ignore: prefer_final_fields
  String _tripDuration = "0 min";
  dynamic _tripDesglose; // <--- AGREGA ESTA LÍNEA
  Timer? _checkStatusTimer;
  String _selectedPaymentMethod = 'EFECTIVO';
  // --- CONDUCTOR Y SIMULACIÓN ---
  LatLng? _driverPosition;
  Timer? _simulationTimer;
  String _driverEta = "5 min";
  int _waitSeconds = 300; // 5 minutos en segundos
  Timer? _waitTimer;
  DateTime? _scheduledAt;
  // --- CATEGORÍAS ---
  double _baseRoutePrice = 0;
  String _selectedServiceCategory = 'STANDARD';
  final Map<String, double> _categoryMultipliers = {
    'STANDARD': 1.0,
    'PREMIUM': 1.35,
    'VAN': 1.8,
  };
  Map<String, dynamic> _categoryPricesFromServer = {};
  final String myMapboxToken = dotenv.env['MAPBOX_TOKEN'] ?? '';
  @override
  void initState() {
    super.initState();

    // Validación de seguridad de último nivel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService.currentUser == null) {
        Navigator.pushReplacementNamed(context, '/');
        return;
      }
      _checkStatusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _verifyUserStatus();
        _checkActiveTrip();
      });
      // Si el usuario está PENDING o UNDER_REVIEW, podrías redirigir aquí también
      if (AuthService.currentUser!.verificationStatus ==
          UserVerificationStatus.PENDING) {
        // Navigator.pushReplacementNamed(context, '/verification_check');
      }
    });
    _initSocketCommunication();
    _determinePosition();
    _checkActiveTrip();
  }

  @override
  void dispose() {
    _checkStatusTimer?.cancel();
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
  Future<void> _verifyUserStatus() async {
    try {
      // Solo con llamar a esto, si el usuario es inactivo,
      // el ApiClient lo detectará y lo sacará automáticamente.
      await AuthService.checkAuthStatus();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _checkActiveTrip() async {
    if (_isFinishingLock) return;
    final tripData = await _homeService.getActiveTrip();
    if (!mounted) return;

    setState(() {
      if (tripData != null) {
        _currentTripId = tripData['id'].toString();
        _driverData = tripData;
        if (tripData['metodo_pago_preferido'] != null) {
          _selectedPaymentMethod = tripData['metodo_pago_preferido'];
        }
        // 1. LLEGADA AL DESTINO / PAGO
        if (tripData['finalizado_en'] != null ||
            tripData['estado'] == 'DROPPED_OFF') {
          _tripState = TripState.PAYMENT;
          _waitTimer?.cancel();
        }
        // 2. EN VIAJE O CONDUCTOR EN SITIO
        else if (tripData['iniciado_en'] != null ||
            tripData['llegado_en'] != null) {
          bool wasInOtherState =
              _tripState != TripState.IN_TRIP &&
              _tripState != TripState.DRIVER_ON_WAY;
          _tripState = (tripData['iniciado_en'] != null)
              ? TripState.IN_TRIP
              : TripState.DRIVER_ON_WAY;

          if (wasInOtherState || _routePoints.isEmpty) {
            if (_destinationCoordinates != null &&
                (_originCoordinates != null || _currentPosition != null)) {
              // <--- Agrega esta seguridad
              _calculateRouteAndPrice(_destinationCoordinates!);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Esperando señal de GPS...")),
              );
            }
          }
          if (tripData['llegado_en'] != null && _waitTimer == null) {
            _startWaitTimer();
          }
          if (tripData['iniciado_en'] != null) _waitTimer?.cancel();
        }
        // 3. CONDUCTOR EN CAMINO (ACCEPTED)
        else if (tripData['id_conductor'] != null) {
          _tripState = TripState.DRIVER_ON_WAY;
          if (tripData['lat_conductor'] != null) {
            LatLng driverPos = LatLng(
              double.parse(tripData['lat_conductor'].toString()),
              double.parse(tripData['lng_conductor'].toString()),
            );
            _driverPosition = driverPos;
            _calculateDriverToPickupRoute(
              driverPos,
            ); // Ruta Conductor -> Usuario
          }
        }

        // Tracking activo
        if (_currentTripId != null &&
            (_tripState == TripState.DRIVER_ON_WAY ||
                _tripState == TripState.IN_TRIP)) {
          _startTrackingListener(_currentTripId!);
        }
      } else {
        if (_tripState == TripState.SEARCHING_DRIVER ||
            _tripState == TripState.DRIVER_ON_WAY ||
            _tripState == TripState.IN_TRIP) {
          _resetApp();
        }
      }
    });
  }

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

  void _toggleAppMode(bool isTargetCorporate) async {
    // 1. Bloqueo de seguridad si hay un viaje en curso
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

    // 2. Lógica para MODO CORPORATIVO
    if (isTargetCorporate) {
      // Si ya tiene empresa vinculada, cambiamos DIRECTO al backend
      if (_currentUser.canUseCorporateMode) {
        bool success = await AuthService.toggleAppMode(true);
        if (success && mounted) {
          setState(() {
            _resetTripData();
          });
          _showModeSnackBar("Modo Corporativo activado", Colors.blue[800]!);
        }
      } else {
        // Solo si NO tiene empresa, mostramos el modal para que la busque
        _showCorporateLinkingModal();
      }
      return;
    }

    // 3. Lógica para MODO NATURAL (Personal)
    // El cambio es directo, ya que todo usuario registrado puede usar el modo personal.
    if (!isTargetCorporate) {
      bool success = await AuthService.toggleAppMode(false);
      if (success && mounted) {
        setState(() {
          _resetTripData();
        });
        _showModeSnackBar("Modo Personal activado", AppColors.primaryGreen);
      }
    }
  }

  // Función auxiliar para feedback visual (opcional, pero recomendada)
  void _showModeSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetTripData() {
    _routePoints = [];
    _destinationCoordinates = null;
    _destinationName = null;
  }

  Future<bool> _isTripAllowed(LatLng start, LatLng end) async {
    if (_currentUser.isCorporateMode) {
      return true;
    }

    try {
      String? startCity = await _getCityFromCoordinates(start);
      String? endCity = await _getCityFromCoordinates(end);

      // LLAVES AÑADIDAS AQUÍ:
      if (startCity == null || endCity == null) {
        return true;
      }

      if (_normalizeString(startCity) == _normalizeString(endCity)) {
        _showRestrictionError(startCity);
        return false;
      }
    } catch (e) {
      return true;
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

  String _getDbCategory(String uiCategory) {
    switch (uiCategory) {
      case 'STANDARD':
        return 'CITY CAR';
      case 'PREMIUM':
        return 'SUV';
      case 'VAN':
        return 'VAN';
      default:
        return 'CITY CAR';
    }
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
    // ignore: duplicate_ignore
    // ignore: avoid_print
    print("DEBUG: Iniciando cálculo de ruta a: $destination");
    // 1. Verificación de seguridad: si no hay posición todavía, la buscamos
    if (_currentPosition == null) {
      await _determinePosition();
    }

    // 2. Si después de buscar sigue siendo nulo, abortamos sin crashear
    final LatLng? startPoint = _originCoordinates ?? _currentPosition;

    if (startPoint == null) {
      if (mounted) {
        setState(() => _tripState = TripState.IDLE);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Error: No se pudo determinar tu ubicación de origen",
            ),
          ),
        );
      }
      return;
    }

    // 3. Validación de zona permitida (Usando startPoint seguro)
    bool allowed = await _isTripAllowed(startPoint, destination);

    if (!mounted) return;
    if (!allowed) {
      setState(() => _tripState = TripState.IDLE);
      return;
    }

    // El resto del código se mantiene igual...
    setState(() => _tripState = TripState.CALCULATING);

    try {
      final LatLng? startPoint = _originCoordinates ?? _currentPosition;

      if (startPoint == null) {
        if (mounted) {
          setState(() => _tripState = TripState.IDLE);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No se pudo obtener tu ubicación de origen"),
            ),
          );
        }
        return;
      }

      final result = await _routeService.getRoute(
        startPoint, // <--- Ahora es seguro
        destination,
        idContrato: _currentUser.isCorporateMode ? 1 : null,
        tipoVehiculo: _getDbCategory(_selectedServiceCategory),
      );
      if (!mounted) return;
      _userMethods = await PaymentService().getPaymentMethods(_currentUser);
      if (!mounted) return;

      setState(() {
        _routePoints = result.points;
        _tripPrice = result.price;
        _categoryPricesFromServer = result.preciosCategorias ?? {};
        _tripDesglose = result.desglose;

        // 🔥 IMPORTANTE: Si la categoría es STANDARD, guardamos esto como base global
        // para que el selector pueda estimar el precio de SUV y VAN correctamente.
        if (_selectedServiceCategory == 'STANDARD') {
          _baseRoutePrice = result.price;
        } else {
          // Si eligió SUV, calculamos hacia atrás cuál sería el precio base
          double mult = _categoryMultipliers[_selectedServiceCategory] ?? 1.0;
          _baseRoutePrice = result.price / mult;
        }

        _tripDistance =
            "${(result.distanceMeters / 1000).toStringAsFixed(1)} km";
        _tripDuration = "${(result.durationSeconds / 60).round()} min";
        _tripState = TripState
            .ROUTE_PREVIEW; // Al cambiar esto, el Stack mostrará el panel
      });

      // 2. LLAMADO PARA QUITAR EL WARNING DE _fitCameraToRoute
      _fitCameraToRoute();
    } catch (e) {
      debugPrint("Error en el proceso de ruta: $e");

      // 🔥 LA SOLUCIÓN AL CUADRO ROJO:
      if (!mounted) return;

      setState(() => _tripState = TripState.IDLE);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al calcular ruta: $e")));
    }
  }

  void _showRequestTripPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _buildRoutePreviewContent(setModalState),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    ).then((wasConfirmed) {
      // Recibimos el valor aquí
      // SOLO reseteamos si wasConfirmed NO es true.
      // Si es true, significa que presionamos "Solicitar" y los datos deben persistir.
      if (wasConfirmed != true && _tripState == TripState.ROUTE_PREVIEW) {
        _resetApp();
      }
    });
  }

  // Dentro de _fitCameraToRoute() (aprox línea 400)
  void _fitCameraToRoute() {
    if (_routePoints.isEmpty) return;

    // Incluimos el origen y destino manualmente para asegurar que los marcadores se vean
    List<LatLng> boundsPoints = List.from(_routePoints);
    if (_originCoordinates != null) boundsPoints.add(_originCoordinates!);
    if (_destinationCoordinates != null)
      // ignore: curly_braces_in_flow_control_structures
      boundsPoints.add(_destinationCoordinates!);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(boundsPoints),
        padding: const EdgeInsets.only(
          top: 150,
          bottom: 300,
          left: 50,
          right: 50,
        ),
      ),
    );
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
    if (AuthService.currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isCorporate = _currentUser.isCorporateMode;

    // Color principal dinámico según el modo
    final Color mainColor = isCorporate
        ? const Color(0xFF1565C0) // Blue 800
        : const Color(0xFF2E7D32); // Green

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(onToggleMode: _toggleAppMode),
      body: Stack(
        children: [
          // 1. CAPA DEL MAPA (Base de todo)
          RepaintBoundary(
            child: FlutterMap(
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
                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                      : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  tileProvider: CachedTileProvider(),
                ),

                // Capas de Ruta y Marcadores (Solo si no estamos eligiendo ubicación manualmente)
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
                          width: 45,
                          height: 45,
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
          ),

          // 2. BOTÓN DE MENÚ (Siempre arriba)
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: IconButton(
                icon: const Icon(Icons.menu, color: Colors.black87),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
          ),

          // 3. BOTÓN MI UBICACIÓN (Solo si no hay viaje activo y no estamos en modo "fijar")
          if (_tripState == TripState.IDLE && !_isPickingLocation)
            Positioned(
              bottom: 110,
              right: 20,
              child: _buildMapControlBtn(
                Icons.my_location,
                _moveToCurrentPosition,
              ),
            ),

          // 4. BARRA DE BÚSQUEDA (Solo en estado inicial y no en modo "fijar")
          if (_tripState == TripState.IDLE && !_isPickingLocation)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: _buildSearchWidget(),
            ),

          // 5. PANEL DINÁMICO DE VIAJE (Solo si hay un proceso de viaje y NO estamos fijando en mapa)
          if (_tripState != TripState.IDLE && !_isPickingLocation)
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                setState(() {
                  _currentSheetExtent = notification.extent;
                });
                return true;
              },
              child: DraggableScrollableSheet(
                key: ValueKey(_tripState),
                initialChildSize: _getInitialSheetSize(),
                minChildSize: 0.12,
                maxChildSize: _getMaxSheetSize(),
                snap: false, // Fluidez total solicitada
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          _buildDynamicSheetContent(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // 6. INTERFAZ DE SELECCIÓN MANUAL (PIN Y BOTONES)
          if (_isPickingLocation) _buildMapPickerUI(),
        ],
      ),
    );
  }

  // --- PEGA ESTE MÉTODO FUERA DEL BUILD (Debajo de él) ---
  Widget _buildMapPickerUI() {
    final bool isCorporate = _currentUser.isCorporateMode;
    final Color mainColor = isCorporate
        ? const Color(0xFF1565C0)
        : const Color(0xFF2E7D32);

    return Stack(
      children: [
        // Pin fijo en el centro de la pantalla
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 35),
            child: Icon(Icons.location_on, size: 50, color: mainColor),
          ),
        ),

        // Controles de confirmación en la parte inferior
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
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoadingAddress ? null : _confirmMapSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 4,
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
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.9),
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
      ],
    );
  }
  // ===============================================================
  // 4. WIDGETS Y LÓGICA DE INTERFAZ
  // ===============================================================

  Widget _buildMinifiedHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: [
          Icon(
            Icons.directions_car,
            color: _currentUser.isCorporateMode
                ? Colors.blue[800]
                : AppColors.primaryGreen,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Viaje a ${_destinationName?.split(',').first ?? 'Destino'}",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Total: \$ ${_formatCurrency(_tripPrice)}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.unfold_more, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }

  Widget _buildVehicleSelector(StateSetter setModalState) {
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

          // 1. TRADUCIR CATEGORÍA (Ej: STANDARD -> CITY CAR)
          String dbKey = _getDbCategory(opt['id']); // <--- CAMBIO

          // 2. OBTENER PRECIO REAL DEL SERVIDOR
          double displayPrice = (_categoryPricesFromServer[dbKey] ?? 0)
              .toDouble(); // <--- CAMBIO

          // 3. SI EL SERVIDOR AÚN NO RESPONDE, USAR EL MULTIPLICADOR COMO RESPALDO
          if (displayPrice <= 0) {
            double mult = _categoryMultipliers[opt['id']]!;
            displayPrice = ((_baseRoutePrice * mult) / 100).ceil() * 100;
          }

          // LÓGICA DE BLOQUEO POR CUPOS
          bool isDisabled = false;
          if (_totalPassengers > 4 &&
              (opt['id'] == 'STANDARD' || opt['id'] == 'PREMIUM')) {
            isDisabled = true;
          }
          if (_totalPassengers <= 4 && opt['id'] == 'VAN') {
            isDisabled = true;
          }

          return GestureDetector(
            onTap: isDisabled
                ? null
                : () async {
                    // SEGURIDAD: Si no hay coordenadas, no intentamos cotizar
                    if (_destinationCoordinates == null) return;

                    setState(() {
                      _selectedServiceCategory = opt['id'];
                      _tripState = TripState.CALCULATING;
                    });

                    // RE-COTIZAR con la nueva categoría
                    await _calculateRouteAndPrice(_destinationCoordinates!);
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
                      ),
                    ),
                    // USAMOS displayPrice EN LUGAR DE priceEst
                    Text(
                      "\$ ${_formatCurrency(displayPrice)}", // <--- CAMBIO
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

  Widget _buildRoutePreviewContent(StateSetter setModalState) {
    final isCorp = _currentUser.isCorporateMode;
    final primaryColor = isCorp
        ? const Color(0xFF1565C0)
        : AppColors.primaryGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTimeSelector(primaryColor, setModalState),
          const SizedBox(height: 15),
          _buildTripDetailsCard(primaryColor, setModalState),
          const SizedBox(height: 15),
          _buildVehicleSelector(setModalState),

          _buildPriceTicket(),
          const SizedBox(height: 10),
          _buildPaymentSelector(setModalState),

          // Selector de pago previo
          const SizedBox(height: 15),
          _buildRequestButton(primaryColor),
          const SizedBox(height: 10),

          // --- BOTÓN NUEVO DE CANCELAR ---
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                _resetApp(); // Limpia el mapa y vuelve al buscador
              },
              child: Text(
                "Cancelar solicitud",
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Determina qué tan abierto empieza el panel según el estado
  double _getInitialSheetSize() {
    switch (_tripState) {
      case TripState.CALCULATING:
        return 0.22;
      case TripState.ROUTE_PREVIEW:
        return 0.45;
      case TripState.SEARCHING_DRIVER:
        return 0.35;
      case TripState.DRIVER_ON_WAY:
        return 0.40;
      case TripState.IN_TRIP:
        return 0.30;
      case TripState.PAYMENT:
        return 0.45;
      default:
        return 0.40;
    }
  }

  double _getMaxSheetSize() {
    switch (_tripState) {
      case TripState.CALCULATING:
        return 0.22;
      case TripState.ROUTE_PREVIEW:
        return 0.85; // El de la selección de vehículo sí es largo
      case TripState.SEARCHING_DRIVER:
        return 0.40; // Buscando conductor es corto
      case TripState.DRIVER_ON_WAY:
        return 0.55; // Info del conductor es mediana
      case TripState.IN_TRIP:
        return 0.40; // En viaje es corto
      case TripState.PAYMENT:
        return 0.50; // Pago es mediano
      default:
        return 0.85;
    }
  }

  // Retorna el contenido correcto para el panel
  Widget _buildDynamicSheetContent() {
    // Aumentamos ligeramente el umbral de 0.13 a 0.16 para que
    // el cambio de cabecera ocurra un poco antes de llegar al fondo total.
    bool isBottom = _currentSheetExtent <= 0.16;

    switch (_tripState) {
      case TripState.CALCULATING:
        return _buildLoadingRouteContent();
      case TripState.ROUTE_PREVIEW:
        return Column(
          children: [
            // Si está abajo muestra el resumen, si sube muestra la flecha
            isBottom ? _buildMinifiedHeader() : _buildExpandArrow(),
            if (!isBottom) ...[
              const Divider(),
              _buildRoutePreviewContent(setState),
            ],
          ],
        );

      case TripState.SEARCHING_DRIVER:
        return Column(
          children: [
            isBottom
                ? _buildGenericMinifiedHeader(
                    "Buscando conductor...",
                    Icons.search,
                  )
                : _buildExpandArrow(),
            if (!isBottom) ...[const Divider(), _buildSearchingDriverContent()],
          ],
        );

      case TripState.DRIVER_ON_WAY:
        return Column(
          children: [
            isBottom
                ? _buildGenericMinifiedHeader(
                    "Conductor en camino",
                    Icons.directions_car,
                  )
                : _buildExpandArrow(),
            if (!isBottom) ...[const Divider(), _buildDriverOnWayContent()],
          ],
        );

      case TripState.IN_TRIP:
        return Column(
          children: [
            isBottom
                ? _buildGenericMinifiedHeader(
                    "En viaje a destino",
                    Icons.navigation,
                  )
                : _buildExpandArrow(),
            if (!isBottom) ...[const Divider(), _buildInTripContent()],
          ],
        );

      case TripState.PAYMENT:
        return Column(
          children: [
            isBottom
                ? _buildGenericMinifiedHeader(
                    "¡Llegamos! Pago",
                    Icons.check_circle,
                  )
                : _buildExpandArrow(),
            if (!isBottom) ...[const Divider(), _buildPaymentContent()],
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLoadingRouteContent() {
    final isCorp = _currentUser.isCorporateMode;
    final color = isCorp ? const Color(0xFF1565C0) : AppColors.primaryGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Un indicador lineal animado
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              // ignore: deprecated_member_use
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono con una pequeña animación (puedes usar un Spinner si prefieres)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(width: 15),
              Text(
                "Buscando la mejor ruta...",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Estamos cotizando servicios de ${isCorp ? 'Empresa' : 'VAMOS'}",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // Widget de la flecha que pides
  Widget _buildExpandArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Icon(Icons.keyboard_arrow_up, color: Colors.grey[400], size: 30),
    );
  }

  Widget _buildPaymentContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            (_selectedPaymentMethod == 'EFECTIVO')
                ? "Por favor entrega \$${_formatCurrency(_tripPrice)} al conductor."
                : "Procesando pago electrónico...",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 20),
          if (_selectedPaymentMethod == 'EFECTIVO')
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                onPressed: () => _finishTripAndSave(),
                child: const Text(
                  "ENTREGUÉ EL DINERO",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            const CircularProgressIndicator(color: AppColors.primaryGreen),
        ],
      ),
    );
  }

  Widget _buildGenericMinifiedHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: [
          Icon(
            icon,
            color: _currentUser.isCorporateMode
                ? Colors.blue[800]
                : AppColors.primaryGreen,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.unfold_more, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }

  Widget _buildRequestButton(Color color) {
    bool isScheduled = _scheduledAt != null;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _totalPassengers > 0
            ? () {
                // 2. EJECUTAR LA LÓGICA DE SOLICITUD
                _handleTripRequest();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 2,
        ),
        child: Text(
          isScheduled
              ? "Programar para el ${DateFormat('dd/MM HH:mm').format(_scheduledAt!)}"
              : "Solicitar Viaje Ahora",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTripDetailsCard(Color color, StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchDestinationScreen(
                    currentPosition: _currentPosition,
                    initialOriginName: _originName,
                    initialOriginCoords: _originCoordinates,
                  ),
                ),
              );
              if (result != null) _handleSearchResult(result);
            },
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Viajar a:",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _destinationName ?? "Sin destino",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // --- ESTO USA LA VARIABLE Y QUITA EL WARNING ---
                      Text(
                        "$_tripDistance • $_tripDuration aprox.",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.edit_location_alt_outlined,
                  color: Colors.grey,
                  size: 18,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          InkWell(
            onTap: () async {
              await _showBeneficiarySelector();
              setModalState(() {});
            },
            child: Row(
              children: [
                Icon(Icons.people_outline, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pasajeros ($_totalPassengers)",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getPassengerSummary(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE PROGRAMACIÓN (Front) ---
  // Paso 1: Actualizar la firma para recibir setModalState
  Future<void> _showDateTimePicker(StateSetter setModalState) async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(minutes: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date == null) return;
    if (!mounted) return;

    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;
    if (!mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });

    // Paso 2: Forzar actualización instantánea del Modal
    setModalState(() {});
  }

  String _getPassengerSummary() {
    List<String> names = [];
    if (_includeMyself) names.add("Yo");
    names.addAll(
      _selectedBeneficiariesList.map((b) => b.name.split(" ").first),
    );
    return names.isEmpty ? "Selecciona quién viaja" : names.join(", ");
  }

  Widget _buildTimeSelector(Color color, StateSetter setModalState) {
    return Row(
      children: [
        Expanded(
          child: _timeOptionTile(
            title: "Ahora",
            isSelected: _scheduledAt == null,
            icon: Icons.flash_on,
            onTap: () {
              setModalState(
                () => _scheduledAt = null,
              ); // Cambio instantáneo en UI
              setState(() => _scheduledAt = null);
            },
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _timeOptionTile(
            title: _scheduledAt == null
                ? "Programar"
                : DateFormat('dd/MM HH:mm').format(_scheduledAt!),
            isSelected: _scheduledAt != null,
            icon: Icons.calendar_month,
            onTap: () => _showDateTimePicker(setModalState),
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _timeOptionTile({
    required String title,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmPassengersDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified_user, color: AppColors.primaryGreen),
            const SizedBox(width: 10),
            Text(
              "Verificar Pasajeros",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "¿Están todos los pasajeros en la lista?",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              "IMPORTANTE: El conductor solicitará el documento físico de CADA persona antes de iniciar. Sin registro en la App, no podrán subir al vehículo.",
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[800]),
            ),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PASAJEROS CONFIRMADOS:",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_includeMyself)
                    Text(
                      "• Yo (${_currentUser.name})",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ..._selectedBeneficiariesList.map(
                    (b) => Text(
                      "• ${b.name}",
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // 1. Agregamos async aquí
              Navigator.pop(
                ctx,
              ); // 2. Cierra el diálogo de confirmación de pasajeros

              // 3. Abrimos el selector y ESPERAMOS (await) a que el usuario termine
              await _showBeneficiarySelector();

              // 4. Una vez cerrado el selector, volvemos a mostrar el panel de solicitud
              if (mounted) {
                _showRequestTripPanel();
              }
            },
            child: Text(
              "Editar Lista",
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _processTripCreation(); // Única forma de llegar al backend
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Confirmar y Pedir",
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTripRequest() {
    // NUEVA VALIDACIÓN:
    if (_currentUser.documentNumber.isEmpty ||
        _currentUser.documentNumber == "0") {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Perfil Incompleto"),
          content: const Text(
            "Para generar el seguro de viaje (FUEC), necesitamos tu número de cédula en el perfil.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Entendido"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(
                  context,
                  '/profile_edit',
                ); // Ajusta a tu ruta de perfil
              },
              child: const Text("Ir a Perfil"),
            ),
          ],
        ),
      );
      return;
    }

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
                _showConfirmPassengersDialog();
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
      _showConfirmPassengersDialog();
    }
  }

  Future<void> _processTripCreation() async {
    if (_currentPosition == null || _destinationCoordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Ubicación no disponible.")),
      );
      return;
    }

    setState(() => _tripState = TripState.CALCULATING);

    try {
      // 1. OBTENER DIRECCIÓN REAL DE ORIGEN (Para el FUEC)
      // Usamos el osmService que ya tienes para convertir coordenadas en texto real
      String realOriginAddress = await _osmService.getAddressFromCoordinates(
        _currentPosition!,
      );

      // Si falla el servicio de mapas, usamos un fallback pero intentamos que sea descriptivo
      if (realOriginAddress.isEmpty ||
          realOriginAddress == "Dirección no encontrada") {
        realOriginAddress =
            "Origen cerca de: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}";
      }

      final tripService = TripService();

      // 2. MAPEO DE PASAJEROS
      List<Passenger> passengersList = _selectedBeneficiariesList.map((b) {
        return Passenger(name: b.name, nationalId: b.documentNumber);
      }).toList();

      // 3. DEFINICIÓN DE MÉTODO DE PAGO PARA EL BACKEND
      String backendPaymentId = 'EFECTIVO';
      if (_selectedMethod?.id == 'cash') backendPaymentId = 'EFECTIVO';
      if (_selectedMethod?.id == 'corp') backendPaymentId = 'CORPORATIVO';
      if (_selectedMethod?.type == PaymentMethodType.card)
        // ignore: curly_braces_in_flow_control_structures
        backendPaymentId = 'TARJETA';

      // 4. LLAMADA AL SERVICIO CON LA DIRECCIÓN REAL
      String? tripId = await tripService.createTripRequest(
        currentUser: _currentUser,
        origin: _currentPosition!,
        destination: _destinationCoordinates!,
        originAddress: realOriginAddress, // <--- AQUÍ PASAMOS LA DIRECCIÓN REAL
        destinationAddress: _destinationName!,
        serviceCategory: _selectedServiceCategory,
        estimatedPrice: _tripPrice,
        passengers: passengersList,
        includeMyself: _includeMyself,
        scheduledAt: _scheduledAt,
        desglose: _tripDesglose,
        paymentMethod: backendPaymentId,
      );

      if (!mounted) return;

      if (tripId != null) {
        _currentTripId = tripId;
        if (_scheduledAt != null) {
          _showScheduledSuccessDialog();
        } else {
          _startSearchingDriver();
          _startTrackingListener(tripId);
        }
      } else {
        _resetApp();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo crear la solicitud. Intenta de nuevo."),
          ),
        );
      }
    } catch (e) {
      _resetApp();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error de conexión: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // NUEVO: Diálogo de éxito para viajes programados
  void _showScheduledSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.calendar_today, color: Colors.blue, size: 50),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "¡Viaje Programado!",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Tu servicio ha sido registrado. Te notificaremos con los datos del conductor y el vehículo 15 minutos antes de la hora seleccionada.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resetApp(); // Limpiamos el mapa y volvemos al inicio
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
              ),
              child: const Text(
                "Entendido",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBeneficiarySelector() {
    bool isCorp = _currentUser.isCorporateMode;
    Color primaryColor = isCorp ? Colors.blue[800]! : AppColors.primaryGreen;

    return showModalBottomSheet(
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

              if (name.isEmpty || doc.isEmpty || doc.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Datos inválidos")),
                );
                return;
              }

              // 1. Llamada al servicio
              bool success = await AuthService.addBeneficiary(name, doc);

              if (!dialogContext.mounted) return;

              if (success) {
                // 2. Cerramos el diálogo de texto
                Navigator.pop(dialogContext);

                // 3. MAGIA: Obtenemos el último beneficiario agregado (el que acaba de entrar a la lista)
                final nuevoPasajero = _currentUser.beneficiaries.last;

                // 4. Actualizamos el Modal de "Quiénes viajan"
                parentModalState(() {
                  // Lo marcamos como seleccionado automáticamente
                  _selectedPassengerIds.add(nuevoPasajero.id);
                });

                // 5. Actualizamos el estado general (Precio y Categoría)
                setState(() {
                  _updateFinalPrice();
                });
              } else {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Error al conectar con el servidor"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
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
    // Solo cambiamos el estado.
    // QUITAMOS el timer y QUITAMOS la llamada a _assignDriverAndSimulateMovement
    setState(() {
      _tripState = TripState.SEARCHING_DRIVER;
    });

    debugPrint("⏳ Esperando a que un conductor acepte el viaje real...");

    // Nota: Aquí añadiremos el listener para que cuando el backend avise
    // que el viaje cambió a 'ACCEPTED', la pantalla cambie a 'DRIVER_ON_WAY'.
  }

  void _finishTripAndSave() async {
    // 1. Bloqueo de seguridad
    setState(() => _isFinishingLock = true);

    // 2. OPCIONAL: Si tu PaymentPanel no lo hace, podrías enviar aquí el método al backend
    // Pero asumiendo que el PaymentPanel ya procesó el pago, procedemos al Reset.

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
              "¡Viaje Completado!",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text("Gracias por viajar con VAMOS.", style: GoogleFonts.poppins()),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _resetApp(); // Limpia mapa, variables y estados

                // Liberamos el Lock tras un breve delay para que el backend limpie la sesión
                Future.delayed(const Duration(seconds: 4), () {
                  if (mounted) setState(() => _isFinishingLock = false);
                });
              },
              child: Text(
                "Finalizar",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetApp() {
    _simulationTimer?.cancel();
    _waitTimer?.cancel();
    _waitTimer = null;

    if (mounted) {
      setState(() {
        _tripState = TripState.IDLE;
        _routePoints = [];
        _destinationCoordinates = null;
        _destinationName = null;
        _driverPosition = null;
        _scheduledAt = null;
        _currentTripId = null; // IMPORTANTE: Limpiar ID del viaje
        _driverData = null; // IMPORTANTE: Limpiar datos del conductor (Vacío 2)
        _selectedPassengerIds.clear();
        _includeMyself = true;
        _driverEta = "Calculando...";
      });
      _moveToCurrentPosition();
    }
  }

  // --- HELPERS UI ---

  Widget _buildMapControlBtn(IconData icon, VoidCallback tap) {
    // Detectamos el color según el modo actual
    final Color iconColor = _currentUser.isCorporateMode
        ? const Color(0xFF1565C0)
        : AppColors.primaryGreen;

    return Container(
      width: 50, // Lo hacemos un poco más grande para que sea fácil de tocar
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        // Cambiamos black87 por iconColor para que combine con el switch
        icon: Icon(icon, color: iconColor, size: 26),
        onPressed: tap,
      ),
    );
  }

  // --- WIDGET BUSCADOR ESTILO INPUT ---
  Widget _buildSearchWidget() => GestureDetector(
    // --- DENTRO DE _buildSearchWidget EN HOME_SCREEN ---
    onTap: () async {
      if (_originCoordinates == null) {
        _originCoordinates = _currentPosition;
        _originName = "Mi ubicación";
      }
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchDestinationScreen(
            currentPosition: _currentPosition,
            initialOriginName: _originName,
            initialOriginCoords: _originCoordinates,
          ),
        ),
      );
      if (result != null) _handleSearchResult(result);
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
            "¿A dónde vamos?",
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

  Widget _buildDriverOnWayContent() {
    // Extraemos los datos que guardamos en _driverData
    final driver = _driverData?['conductor'] ?? {};
    String? fotoUrl = driver['foto_perfil'] ?? driver['photo_url'];
    final vehicle = _driverData?['vehiculo'] ?? {};
    if (fotoUrl != null && fotoUrl.contains('10.0.2.2')) {
      fotoUrl = fotoUrl.replaceAll('10.0.2.2', '192.168.10.3');
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Tu conductor está en camino",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 15),

        // TARJETA DE INFORMACIÓN (Vacío 2)
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[300],
                backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                child: fotoUrl == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver['nombre'] ?? "Conductor",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "${vehicle['marca']} ${vehicle['modelo']} • ${vehicle['placa']}",
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.orange),
                    Text(
                      " 4.8",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Column(
          children: [
            Text(
              _waitTimer == null
                  ? "Llegada estimada: $_driverEta"
                  : "¡El conductor ha llegado!",
              style: GoogleFonts.poppins(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (_waitTimer != null) ...[
              const SizedBox(height: 5),
              Text(
                "Tiempo de espera legal: ${(_waitSeconds ~/ 60).toString().padLeft(2, '0')}:${(_waitSeconds % 60).toString().padLeft(2, '0')}",
                style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _resetApp,
            icon: const Icon(Icons.close, color: Colors.red),
            label: Text(
              "Cancelar Viaje",
              style: GoogleFonts.poppins(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount) => amount
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
  Widget _buildPriceTicket() {
    if (_tripPrice <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Total estimado",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                "Sujeto a cambios por tráfico",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          Text(
            "\$ ${_formatCurrency(_tripPrice)}",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: _currentUser.isCorporateMode
                  ? Colors.blue[800]
                  : AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

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

    // Convertimos las coordenadas del PIN en dirección de texto
    String address = await _osmService.getAddressFromCoordinates(
      _mapCenterPicker!,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingAddress = false;
      _isPickingLocation = false; // Apagamos el modo mapa

      if (_isPickingOrigin) {
        _originName = address;
        _originCoordinates = _mapCenterPicker;
      } else {
        _destinationName = address;
        _destinationCoordinates = _mapCenterPicker;
      }
    });

    // LOGICA RE-INICIO:
    // Si falta alguno de los dos puntos, abrimos el buscador otra vez
    // con los datos que ya tenemos para que el usuario complete el flujo.
    if (_originCoordinates == null || _destinationCoordinates == null) {
      _openSearchFromCurrentState();
    } else {
      // Si ya tiene ambos, lanzamos la cotización de ruta
      _calculateRouteAndPrice(_destinationCoordinates!);
    }
  }

  // Función auxiliar para no repetir el código del Navigator.push
  void _openSearchFromCurrentState() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchDestinationScreen(
          currentPosition: _currentPosition,
          initialOriginName: _originName,
          initialOriginCoords: _originCoordinates,
        ),
      ),
    );

    // Aquí procesas el resultado igual que en el _buildSearchWidget
    if (result != null) _handleSearchResult(result);
  }

  void _handleSearchResult(dynamic result) {
    if (result == null) return;

    try {
      setState(() {
        // Si el usuario elige fijar en mapa
        if (result is Map && result['isMapPick'] == true) {
          _isPickingLocation = true; // Activamos el PIN central
          _tripState = TripState.IDLE; // Ocultamos el modal Draggable
          _isPickingOrigin = result['isPickingOrigin'] ?? false;
          _mapCenterPicker = _mapController.camera.center;
          return; // Detenemos aquí, el build se encarga del resto
        }

        // Si el usuario seleccionó una dirección de la lista
        if (result is Map && result.containsKey('destinationCoords')) {
          _originName = result['originName'] ?? "Mi ubicación";
          _originCoordinates = result['originCoords'];
          _destinationName = result['destinationName'];
          _destinationCoordinates = result['destinationCoords'];

          _tripState = TripState.CALCULATING;
          _currentSheetExtent = 0.22;
        }
      });

      // Solo si tenemos coordenadas de destino calculamos ruta
      if (_tripState == TripState.CALCULATING &&
          _destinationCoordinates != null) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _calculateRouteAndPrice(_destinationCoordinates!);
        });
      }
    } catch (e) {
      debugPrint("Error procesando búsqueda: $e");
      _resetApp();
    }
  }

  void _startTrackingListener(String tripId) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    if (token != null) {
      _homeService.subscribeToTripTracking(tripId, token, (lat, lng) {
        if (!mounted) return;

        LatLng newPos = LatLng(lat, lng);

        setState(() {
          _driverPosition = newPos; // Actualiza el marcador del carro
        });

        // Si el conductor aún no llega (ACCEPTED), forzamos el recalculo del ETA
        if (_tripState == TripState.DRIVER_ON_WAY && _waitTimer == null) {
          _calculateDriverToPickupRoute(newPos);
        }
      });
    }
  }

  void _initSocketCommunication() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    if (token != null) {
      _homeService.initUserSocket(
        userId: _currentUser.id,
        token: token,
        onEvent: (event, data) {
          if (event == 'ViajeAceptado') {
            _checkActiveTrip(); // Esto disparará la UI de "Conductor en camino"
          }
          // 🔥 NUEVO: Manejo de la cancelación automática
          else if (event == 'ViajeCancelado') {
            if (mounted) {
              _resetApp(); // Limpia el mapa y quita la pantalla de carga

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    data['mensaje'] ?? "No hay conductores disponibles cerca.",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.orange[800],
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.all(20),
                ),
              );
            }
          }
        },
      );
    }
  }

  // --- AÑADIR AL FINAL DE LA CLASE ---
  void _startWaitTimer() {
    _waitTimer?.cancel();
    setState(() => _waitSeconds = 300); // Reset a 5 minutos

    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_waitSeconds > 0) {
        if (mounted) setState(() => _waitSeconds--);
      } else {
        _waitTimer?.cancel();
        // Aquí podrías habilitar un botón de "Cancelar sin penalización"
      }
    });
  }

  Widget _buildInTripContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.navigation,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "En viaje hacia el destino",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _destinationName ?? "Destino seleccionado",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Valor a pagar",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  "\$ ${_formatCurrency(_tripPrice)}",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            // BOTÓN SOS (Seguridad)
            ElevatedButton.icon(
              onPressed: () => _showSOSDialog(),
              icon: const Icon(Icons.security, color: Colors.white, size: 18),
              label: Text(
                "S.O.S",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Centro de Emergencias"),
        content: const Text(
          "¿Deseas comunicarte con la línea de emergencia 123 o compartir tu ubicación con un contacto de confianza?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              /* Lógica para llamar al 123 */
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "LLAMAR 123",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _calculateDriverToPickupRoute(LatLng driverPos) async {
    if (_currentPosition == null) return;

    try {
      final result = await _routeService.getRoute(
        driverPos, // Origen: El carro del conductor
        _currentPosition!, // Destino: Tú (el pasajero)
        tipoVehiculo: _getDbCategory(_selectedServiceCategory),
      );

      if (mounted) {
        setState(() {
          _routePoints = result.points; // Dibujamos la ruta hacia el pasajero
          // Actualizamos el ETA con el tiempo real de la ruta
          _driverEta = "${(result.durationSeconds / 60).round()} min";
        });
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([
              _driverPosition!,
              _currentPosition!,
            ]),
            padding: const EdgeInsets.only(
              top: 100,
              bottom: 300,
              left: 70,
              right: 70,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error calculando ruta al punto de recogida: $e");
    }
  }

  // --- SUSTITUIR EL MÉTODO _buildPaymentSelector COMPLETO ---
  Widget _buildPaymentSelector(StateSetter setModalState) {
    if (_userMethods.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          // 1. Cambiamos de <PaymentMethod> a <String>
          isExpanded: true,
          value: _selectedMethod?.id, // 2. Usamos el ID como valor seleccionado
          items: _userMethods
              .map(
                (m) => DropdownMenuItem<String>(
                  value: m.id, // 3. El valor de cada item ahora es su ID
                  child: Row(
                    children: [
                      Icon(
                        _getPaymentIcon(m.type),
                        size: 20,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          m.name,
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (String? newId) {
            // 4. Recibimos el ID seleccionado
            if (newId == null) return;

            // Buscamos el objeto completo correspondiente a ese ID
            final methodObj = _userMethods.firstWhere((m) => m.id == newId);

            setModalState(() {
              _selectedMethod = methodObj;
            });
            setState(() {
              _selectedMethod = methodObj;
              _selectedPaymentMethod = methodObj.id;
            });
          },
        ),
      ),
    );
  }

  // Helper para iconos basado en tu Enum PaymentMethodType
  IconData _getPaymentIcon(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.cash:
        return Icons.payments_outlined;
      case PaymentMethodType.card:
        return Icons.credit_card;
      case PaymentMethodType.corporateVoucher:
        return Icons.business_center;
      case PaymentMethodType.pse:
        return Icons.account_balance;
    }
  }
}
