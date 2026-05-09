// lib/features/home/screens/home_screen.dart
// ignore_for_file: constant_identifier_names, avoid_print
import 'dart:ui' as ui; // O simplemente el import de material
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
// --- IMPORTS ---
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../widgets/side_menu.dart';
import '../services/route_service.dart';
import '../services/search_service.dart';
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
// Verifica que esta sea la ruta real en tu proyecto

enum TripState {
  DASHBOARD, // Antes IDLE
  CALCULATING, // Estado de carga
  ROUTE_PREVIEW, // Ver ruta y precio
  CONFIRMING_PICKUP, // Mover el pin de salida
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
  final TextEditingController _favSearchController = TextEditingController();
  List<Map<String, dynamic>> _favSearchResults = [];
  Timer? _favDebounce;
  bool _isSearchingFav = false;
  String? _mapPickingTarget;
  bool _isStrictPickupMode = false; // Nueva bandera para activar la restricción
  // En la zona de controladores (donde está el MapController)
  AnimationController? _mapMoveController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final RouteService _routeService = RouteService();
  final HomeService _homeService = HomeService();
  final SearchService _searchService = SearchService(); // <--- AÑADE ESTA LÍNEA
  Timer? _debounceGeocoding;
  LatLng?
  // ignore: unused_field
  _lastGeocodedPosition; // Rastrear dónde pedimos dirección por última vez
  // --- ANIMACIÓN DE RUTA ---
  AnimationController? _routeDrawingController;
  LatLng? _referenceOriginCoords; // Guardará el punto original buscado
  List<LatLng> _animatedRoutePoints = []; // Esta lista es la que verá el mapa
  // --- ESTADO GENERAL ---
  String _loadingTitle = "PREPARANDO TU VIAJE";
  String _loadingSubtitle = "Estamos calculando la mejor ruta para ti...";
  // Cerca de donde tienes _isPickingOrigin
  bool _isOutsideRadius = false;
  TripState _tripState = TripState.DASHBOARD;
  String? _addressTypeToSave; // Guardará 'home' o 'work'

  LatLng? _currentPosition;
  final LatLng _defaultLocation = const LatLng(4.9183, -74.0258); // Cajicá
  bool _isMapReady = false;
  bool _isOriginSnapped = false; // Nueva bandera

  bool _isPickingLocation =
      false; // Controla si el panel de pedido está abierto o minimizado
  bool _isOriginConfirmed = false; // Nueva bandera
  bool _isCalculatingRoute = false;
  bool _showTollsDetail = false; // Controla el acordeón de peajes
  // Usamos un ValueNotifier para actualizaciones de alto rendimiento sin redibujar todo el build
  final ValueNotifier<double> _sheetExtentNotifier = ValueNotifier(0.45);
  bool _isLoadingAddress = false;
  final OsmService _osmService = OsmService();
  bool _isFinishingLock = false; // El Lock anti-polling
  Map<String, dynamic>? _driverData; // Datos del conductor (Vacío 2)
  String? _currentTripId;
  // Cerca de las otras variables booleanas (aprox línea 65)
  // ignore: unused_field
  bool _isPickingOrigin = false;
  // --- PAGO ---
  // ignore: prefer_final_fields
  List<PaymentMethod> _userMethods = []; // Lista real del service
  PaymentMethod? _selectedMethod;

  // --- DATOS DEL VIAJE ---
  String? _destinationName;
  LatLng? _destinationCoordinates;
  List<LatLng> _routePoints = [];
  String? _originName; // Valor por defecto

  String?
  _originReferenceName; // Guarda el nombre de lo que el usuario buscó originalmente
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
  String _pickingAddress = "Buscando dirección...";
  // ignore: unused_field, prefer_final_fields
  String _pickingSubAddress = ""; // <--- AÑADE ESTA LÍNEA
  LatLng _mapCenter = const LatLng(0, 0);
  List<Map<String, dynamic>> _recentPlaces =
      []; // Asegúrate de que no falte esta línea
  // --- CATEGORÍAS ---
  // ignore: prefer_final_fields
  double _baseRoutePrice = 0;
  String _selectedServiceCategory = 'STANDARD';
  final Map<String, double> _categoryMultipliers = {
    'STANDARD': 1.0,
    'PREMIUM': 1.35,
    'VAN': 1.8,
  };
  Map<String, dynamic> _categoryPricesFromServer = {};
  String get myMapboxToken => dotenv.env['MAPBOX_TOKEN'] ?? '';

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
    _loadRecentPlaces();

    // 1. Inicializamos el controlador
    _routeDrawingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 2. Agregamos el Listener AQUÍ (Solo una vez)
    // Esto asegura que cada vez que el controlador se mueva, intente dibujar
    _routeDrawingController!.addListener(() {
      if (_routePoints.isEmpty) return;

      double progress = Curves.fastOutSlowIn.transform(
        _routeDrawingController!.value,
      );

      // Calculamos el conteo, pero aseguramos un mínimo de 2 puntos siempre que progrese
      int count = (progress * _routePoints.length).floor();
      if (count < 2 && progress > 0) count = 2;

      if (count >= 2 && count <= _routePoints.length && mounted) {
        setState(() {
          _animatedRoutePoints = _routePoints.take(count).toList();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService.currentUser == null) {
        Navigator.pushReplacementNamed(context, '/');
        return;
      }
      _checkStatusTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _verifyUserStatus();
        _checkActiveTrip();
      });
    });
    _initSocketCommunication();
    _determinePosition();
    _checkActiveTrip();
    print("HORA DISPOSITIVO: ${DateTime.now().toLocal()}");
  }

  @override
  void dispose() {
    _favSearchController.dispose(); // <--- Agrega esta línea
    _favDebounce?.cancel();
    _routeDrawingController?.dispose(); // <--- VITAL para no gastar memoria

    _checkStatusTimer?.cancel();
    _simulationTimer?.cancel();
    _sheetExtentNotifier.dispose(); // <--- Agrega esto
    _mapMoveController?.dispose();

    super.dispose();
  }

  Future<void> _loadRecentPlaces() async {
    final res = await _searchService.getRecentPlaces();
    if (mounted) setState(() => _recentPlaces = res);
  }

  void _animateRouteDrawing() {
    if (_routePoints.isEmpty || _routeDrawingController == null) return;

    // Detenemos cualquier dibujo previo, limpiamos la lista visual e iniciamos
    _routeDrawingController!.stop();
    _routeDrawingController!.reset();

    setState(() {
      _animatedRoutePoints = [];
    });

    _routeDrawingController!.forward();
  }

  // Llama a _loadRecentPlaces() dentro de tu initState() al final
  List<Beneficiary> get _selectedBeneficiariesList {
    return _currentUser.beneficiaries
        .where((b) => _selectedPassengerIds.contains(b.id))
        .toList();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      // CAMBIO: Pasamos el objeto User completo (!), no solo el ID
      final methods = await PaymentService().getPaymentMethods(
        AuthService.currentUser!,
      );
      if (mounted) {
        setState(() {
          _userMethods = methods;
          if (methods.isNotEmpty) _selectedMethod = methods.first;
        });
      }
    } catch (e) {
      debugPrint("Error cargando métodos de pago: $e");
    }
  }

  int get _totalPassengers =>
      (_includeMyself ? 1 : 0) + _selectedPassengerIds.length;

  // ===============================================================
  // 1. GEOLOCALIZACIÓN Y VALIDACIÓN
  // ===============================================================
  Future<void> _verifyUserStatus() async {
    try {
      // Solo verificar si estamos "quietos" en el dashboard
      if (_tripState == TripState.DASHBOARD) {
        await AuthService.checkAuthStatus();
      }
    } catch (e) {
      // Silenciamos el error para que el polling no rompa la navegación
      debugPrint("Error silencioso en polling de estado: $e");
    }
  }

  void _showAppSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 4),
      ),
    );
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
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _originCoordinates = _currentPosition;
        // IMPORTANTE: No llamamos a reverseGeocode aquí si estamos en el Dashboard.
        // Solo ponemos un texto genérico.
        _originName = "Mi ubicación";
      });

      _moveMapToCurrent();
    } catch (e) {
      _useDefaultLocation();
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
          style: GoogleFonts.montserrat(),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
    _moveMapToCurrent();
  }

  void _moveMapToCurrent() {
    if (_currentPosition != null && _isMapReady) {
      _animatedMapMove(_currentPosition!, 15.0);
    }
  }

  void _toggleAppMode(bool isTargetCorporate) async {
    if (_tripState != TripState.DASHBOARD) {
      _showAppSnackBar(
        "No puedes cambiar de modo durante un viaje activo",
        isError: true,
      );
      return;
    }

    // Si el usuario cambia de modo, limpiamos la ruta previa para evitar cobros erróneos
    setState(() {
      _resetTripData(); // Limpia coordenadas, nombres y puntos de polilínea
      _tripState = TripState.DASHBOARD;
      _tripPrice = 0;
    });

    if (isTargetCorporate) {
      if (_currentUser.canUseCorporateMode) {
        bool success = await AuthService.toggleAppMode(true);
        if (success && mounted) {
          _showModeSnackBar("Modo Corporativo activado", AppColors.darkBlue);
        }
      } else {
        _showCorporateLinkingModal();
      }
    } else {
      bool success = await AuthService.toggleAppMode(false);
      if (success && mounted) {
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
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
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
    // 1. Siempre permitir si es corporativo
    if (_currentUser.isCorporateMode) {
      print("✅ MODO CORPORATIVO DETECTADO: Saltando restricción DANE.");
      return true;
    }
    try {
      // 2. Pedir datos al servidor
      final results = await Future.wait([
        _searchService.getReverseGeocode(start.latitude, start.longitude),
        _searchService.getReverseGeocode(end.latitude, end.longitude),
      ]);

      // 3. Extraer IDs y nombres de forma segura
      final String? idOrigen = results[0]?['municipality_id']?.toString();
      final String? idDestino = results[1]?['municipality_id']?.toString();
      final String cityOrigen = results[0]?['city'] ?? "Desconocido";
      final String cityDestino = results[1]?['city'] ?? "Desconocido";

      // --- 📊 BLOQUE DE DEBUG PARA CONSOLA ---
      print("--------------------------------------------------");
      print("🔍 VERIFICACIÓN DE RESTRICCIÓN DANE");
      print("📍 ORIGEN: $cityOrigen (DANE: $idOrigen)");
      print("📍 DESTINO: $cityDestino (DANE: $idDestino)");

      if (idOrigen == null || idDestino == null) {
        print("⚠️ ADVERTENCIA: Código DANE nulo. Delegando al servidor.");
        print("--------------------------------------------------");
        return true;
      }

      if (idOrigen == idDestino) {
        print("⛔ RESULTADO: BLOQUEADO (Mismo municipio)");
        print("--------------------------------------------------");
        _showRestrictionError(cityOrigen);
        return false;
      }

      print("✅ RESULTADO: PERMITIDO (Diferentes municipios)");
      print("--------------------------------------------------");
      return true;
    } catch (e) {
      print("❌ Error en validación local DANE: $e");
      return true; // En error de red, dejamos que el servidor decida
    }
  }

  // 1. Error de Restricción (Viaje Urbano en Modo Personal)
  void _showRestrictionError(String city) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            CircleAvatar(
              backgroundColor: const Color.fromARGB(28, 111, 182, 52),
              radius: 30,
              child: Icon(
                Icons.shield_outlined,
                color: AppColors.primaryGreen,
                size: 35,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              "Viaje No Permitido",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                color: AppColors.darkBlue,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          "En MODO PERSONAL, los viajes dentro de la misma ciudad no están permitidos.\n\nPara traslados urbanos, por favor activa el MODO CORPORATIVO.",
          style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text(
                "ENTENDIDO",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Diálogo de Cédula Faltante (Dentro de _handleTripRequest)
  void _showIncompleteProfileDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shield_moon_rounded,
                color: AppColors.primaryGreen,
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                "Perfil Incompleto",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Para generar el seguro de viaje (FUEC), es obligatorio registrar tu documento.",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: Colors.grey),
              ),
              const SizedBox(height: 25),
              _buildPremiumButton(
                text: "IR A MI PERFIL",
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/profile_edit');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoDriversDialog(String? message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Icon(
              Icons.person_search_rounded,
              color: AppColors.primaryGreen,
              size: 60,
            ),
            const SizedBox(height: 15),
            Text(
              "Lo sentimos",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppColors.darkBlue,
              ),
            ),
          ],
        ),
        content: Text(
          message ??
              "No hay conductores disponibles cerca de ti en este momento. Por favor, intenta de nuevo en unos minutos.",
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[700]),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "ENTENDIDO",
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
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
  // --- REEMPLAZA ESTOS MÉTODOS EN home_screen.dart ---

  Future<void> _confirmMapSelection() async {
    // 1. BLOQUEO PREVENTIVO (Solo si es estricto)
    if (_isStrictPickupMode && _isOutsideRadius) {
      _showAppSnackBar(
        "Estás fuera del rango permitido (200m).",
        isError: true,
      );
      return;
    }

    if (_isLoadingAddress || _pickingAddress == "Buscando dirección...") return;

    setState(() {
      _loadingTitle = "VALIDANDO UBICACIÓN";
      _loadingSubtitle = "Confirmando dirección seleccionada...";
      _tripState = TripState.CALCULATING;
      _isLoadingAddress = true;
    });

    final LatLng pointOnMap = _mapController.camera.center;

    try {
      // 3. GUARDAR FAVORITO
      if (_addressTypeToSave != null) {
        await _saveFavoriteToDB(
          _addressTypeToSave!,
          _pickingAddress,
          pointOnMap.latitude,
          pointOnMap.longitude,
        );
        setState(() {
          _tripState = TripState.DASHBOARD;
          _isPickingLocation = false;
          _addressTypeToSave = null;
          _isLoadingAddress = false;
        });
        return;
      }

      // 4. GEODECODIFICACIÓN
      final data = await _searchService.getReverseGeocode(
        pointOnMap.latitude,
        pointOnMap.longitude,
        persist: true,
      );

      if (data != null && mounted) {
        final LatLng snappedPoint = LatLng(
          (data['snapped_lat'] as num).toDouble(),
          (data['snapped_lng'] as num).toDouble(),
        );

        // --- VALIDACIÓN DE RESTRICCIÓN 200 METROS (Solo si aplica) ---
        if (_isStrictPickupMode && _mapPickingTarget == 'pickup') {
          double distance = Geolocator.distanceBetween(
            _referenceOriginCoords!.latitude,
            _referenceOriginCoords!.longitude,
            pointOnMap.latitude,
            pointOnMap.longitude,
          );

          if (distance > 200) {
            setState(() {
              _isLoadingAddress = false;
              _tripState = TripState.CONFIRMING_PICKUP;
              _isOutsideRadius = true;
            });
            _showAppSnackBar("No puedes alejarte más de 200m.", isError: true);
            return;
          }
        }

        // --- FINALIZAR PROCESO (Fuera del IF de restricción) ---
        setState(() {
          _isLoadingAddress = false;
          _isOutsideRadius = false;
          _isOriginSnapped = true;

          if (_mapPickingTarget == 'pickup') {
            _originName = data['name'];
            _originCoordinates = snappedPoint;
            _isOriginConfirmed = true;
          } else if (_mapPickingTarget == 'reference') {
            _originReferenceName = data['name'];
            _referenceOriginCoords = snappedPoint;
            _originName = data['name'];
            _originCoordinates = snappedPoint;
            _isOriginConfirmed = true;
          } else if (_mapPickingTarget == 'destination') {
            _destinationName = data['name'];
            _destinationCoordinates = snappedPoint;
          }

          _isPickingLocation = false;
          _mapPickingTarget = null;
        });
        // LÓGICA DE REGRESO O CÁLCULO
        if (_destinationCoordinates == null) {
          // Si estamos confirmando origen pero NO hay destino, abrimos buscador
          _openSearchFromCurrentState();
        } else if (_originCoordinates != null &&
            _destinationCoordinates != null) {
          // Si ya tenemos ambos, calculamos ruta de inmediato
          _calculateRouteAndPrice(_destinationCoordinates!);
        }
      }
    } catch (e) {
      debugPrint("Error en confirmación: $e");
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
          _tripState =
              TripState.CONFIRMING_PICKUP; // Volvemos al mapa si algo falla
        });
        _showAppSnackBar(
          "Error al procesar ubicación, intenta de nuevo.",
          isError: true,
        );
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF64748B), // Un gris azulado elegante
          letterSpacing: 2,
        ),
      ),
    );
  }

  Future<void> _checkActiveTrip() async {
    if (_isFinishingLock || _isCalculatingRoute) return;

    try {
      final tripData = await _homeService.getActiveTrip().timeout(
        const Duration(seconds: 8),
      );
      if (!mounted) return;

      if (tripData != null) {
        String newTripId = tripData['id'].toString();

        // 1. Calculamos cuál sería el "Estado Lógico" según el servidor
        TripState serverState;
        if (tripData['finalizado_en'] != null ||
            tripData['estado'] == 'DROPPED_OFF') {
          serverState = TripState.PAYMENT;
        } else if (tripData['iniciado_en'] != null) {
          serverState = TripState.IN_TRIP;
        } else if (tripData['id_conductor'] != null ||
            tripData['estado'] == 'ACCEPTED') {
          serverState = TripState.DRIVER_ON_WAY;
        } else {
          serverState = TripState.SEARCHING_DRIVER;
        }

        // 2. REGLA DE ORO: El estado solo puede avanzar, nunca retroceder
        // (A menos que el viaje se haya cancelado o estemos en IDLE)
        bool esAvance = serverState.index >= _tripState.index;
        bool esReinicio =
            _tripState == TripState.DASHBOARD ||
            _tripState == TripState.CALCULATING;

        if (esAvance || esReinicio) {
          setState(() {
            _currentTripId = newTripId;
            _driverData = tripData;
            _tripState = serverState;

            // 🔥 VITAL: Avisar al detector de inactividad
            // Si el estado NO es DASHBOARD, significa que hay un proceso de viaje activo.
            AuthService.isTripActive = (serverState != TripState.DASHBOARD);

            if (tripData['llegado_en'] != null && _waitTimer == null) {
              _startWaitTimer();
            }

            // Si ya inició el viaje, cancelamos el timer de espera
            if (serverState == TripState.IN_TRIP) {
              _waitTimer?.cancel();
              _waitTimer = null;
            }
          });

          // Solo recalculamos la ruta si cambió el estado o no hay puntos
          if (_routePoints.isEmpty && _destinationCoordinates != null) {
            _calculateRouteAndPrice(_destinationCoordinates!);
          }
        }

        if (_currentTripId != null) {
          _startTrackingListener(_currentTripId!);
        }
      } else {
        // Si el servidor dice que no hay viaje activo pero nosotros creemos que sí
        // (Significa que se canceló o terminó en otro lado)
        if (_tripState == TripState.SEARCHING_DRIVER ||
            _tripState == TripState.DRIVER_ON_WAY ||
            _tripState == TripState.IN_TRIP) {
          _resetApp();
        }
      }
    } catch (e) {
      debugPrint("Error en polling: $e");
    }
  }

  void _updateFinalPrice() {
    // Lógica de salto automático de categoría según pasajeros
    if (_totalPassengers > 4 && _selectedServiceCategory != 'VAN') {
      _selectedServiceCategory = 'VAN';
    } else if (_totalPassengers <= 4 && _selectedServiceCategory == 'VAN') {
      _selectedServiceCategory = 'STANDARD';
    }

    String dbKey = _getDbCategory(_selectedServiceCategory);
    double? serverPrice = _categoryPricesFromServer[dbKey]?.toDouble();

    setState(() {
      if (serverPrice != null && serverPrice > 0) {
        _tripPrice = serverPrice;
      } else {
        double multiplier =
            _categoryMultipliers[_selectedServiceCategory] ?? 1.0;
        double finalRaw = _baseRoutePrice * multiplier;
        _tripPrice = (finalRaw / 100).ceil() * 100;
      }
    });
  }

  /*
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
    ).then((result) {
      // Cambiamos 'wasConfirmed' por 'result'
      // ✅ Si el resultado es 'PICKING', NO hacemos nada (dejamos que el mapa fluya)
      if (result == 'PICKING') return;

      // Si el resultado es true (proceso de solicitud iniciado), tampoco reseteamos
      if (result == true) return;

      // Solo si se cierra deslizando hacia abajo o dando atrás sin elegir nada:
      if (_tripState == TripState.ROUTE_PREVIEW) {
        _resetApp();
      }
    });
  }
*/
  void _moveToCurrentPosition() {
    if (_currentPosition != null) {
      _animatedMapMove(_currentPosition!, 16.0);
    } else {
      _determinePosition();
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    // CRUCIAL: Si el mapa no está renderizado, el MapController lanzará una excepción.
    // Usamos la bandera _isMapReady que ya tienes definida.
    if (!_isMapReady || !mounted) return;

    // 1. Si ya hay una animación corriendo, la detenemos y cerramos
    _mapMoveController?.dispose();

    // Encapsulamos en un try-catch por seguridad adicional con MapController
    try {
      final latTween = Tween<double>(
        begin: _mapController.camera.center.latitude,
        end: destLocation.latitude,
      );
      final lngTween = Tween<double>(
        begin: _mapController.camera.center.longitude,
        end: destLocation.longitude,
      );
      final zoomTween = Tween<double>(
        begin: _mapController.camera.zoom,
        end: destZoom,
      );

      _mapMoveController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );

      final animation = CurvedAnimation(
        parent: _mapMoveController!,
        curve: Curves.fastOutSlowIn,
      );

      _mapMoveController!.addListener(() {
        _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation),
        );
      });

      _mapMoveController!.forward();
    } catch (e) {
      debugPrint("Error en animación de mapa: $e");
      // Si falla la animación, intentamos un movimiento directo sin Tween
      _mapController.move(destLocation, destZoom);
    }
  }

  // ===============================================================
  // 3. UI PRINCIPAL
  // ===============================================================
  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];

    // 1. Ubicación GPS actual (MANTIENE TU LÓGICA)
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 22,
          height: 22,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- LÓGICA DE PERSISTENCIA PARA EL ANCLA (PUNTO A) ---
    if (_referenceOriginCoords != null) {
      bool mostrarAncla = false;

      // ✅ Solo mostramos el ancla si el objetivo es ajustar la recogida ('pickup')
      // Si estamos cambiando la 'reference' o el 'destination', el ancla vieja desaparece.
      if (_isPickingLocation && _mapPickingTarget == 'pickup') {
        mostrarAncla = true;
      }
      // Mostrar en el resumen final si hay diferencia
      else if (!_isPickingLocation &&
          _routePoints.isNotEmpty &&
          _tripState != TripState.ROUTE_PREVIEW) {
        mostrarAncla = true;
      }

      if (mostrarAncla) {
        markers.add(
          Marker(
            point: _referenceOriginCoords!,
            width: 100,
            height: 40,
            alignment: Alignment.topCenter,
            child: _buildReferencePin(),
          ),
        );
      }
    }
    print("🔍 DEBUG PEAJES: $_tripDesglose");
    if (_tripState == TripState.ROUTE_PREVIEW && _tripDesglose != null) {
      final List peajes = _tripDesglose?['peajes_detalles'] ?? [];
      for (var peaje in peajes) {
        // Extraemos los valores del mapa 'peaje' a variables locales
        final lat = peaje['lat']?.toDouble();
        final lng = peaje['lng']?.toDouble();

        // Ahora sí, usamos esas variables locales
        if (lat != null && lng != null) {
          markers.add(
            Marker(
              point: LatLng(lat, lng), // Usando las variables recién definidas
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.circle, color: Colors.white, size: 24),
                  Icon(Icons.toll, color: Colors.amber[900], size: 20),
                ],
              ),
            ),
          );
        }
      }
    }
    // 2. LOGICA DE RUTA Y PINES (MANTIENE TU DISEÑO ORIGINAL)
    // Solo dibujamos los pines de Recogida (Verde) y Destino (Azul) si NO estamos ajustando el mapa,
    // para que no se dupliquen con el pin flotante del centro.
    if (_routePoints.isNotEmpty &&
        _tripState != TripState.DASHBOARD &&
        !_isPickingLocation) {
      final LatLng startPt = _originCoordinates ?? _routePoints.first;
      final LatLng endPt = _routePoints.last;

      // PUNTO BLANCO BASE
      markers.add(_buildBaseDot(startPt, AppColors.primaryGreen));
      markers.add(_buildBaseDot(endPt, AppColors.darkBlue));

      // PIN DE RECOGIDA PRINCIPAL (Verde)
      markers.add(
        Marker(
          point: startPt,
          width: 200,
          height: 100,
          rotate: true,
          alignment: Alignment.topCenter,
          child: _buildSimplePin(
            label: _originName?.split(',').first ?? "Recogida",
            color: AppColors.primaryGreen,
            icon: Icons.person_pin_circle,
          ),
        ),
      );

      // PIN DE DESTINO (Azul)
      markers.add(
        Marker(
          point: endPt,
          width: 220,
          height: 110,
          rotate: true,
          alignment: Alignment.topCenter,
          child: _buildSimplePin(
            label: _destinationName?.split(',').first ?? "Destino",
            color: AppColors.darkBlue,
            icon: Icons.location_on,
          ),
        ),
      );

      // BURBUJA DE TIEMPO
      if (_animatedRoutePoints.length > 5) {
        final midIndex = (_animatedRoutePoints.length / 2).floor();
        markers.add(
          Marker(
            point: _animatedRoutePoints[midIndex],
            width: 85,
            height: 35,
            rotate: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.access_time_filled,
                    size: 12,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _tripDuration,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    return markers;
  }

  // Widget auxiliar para el punto blanco exacto (Agrégalo debajo de _buildMarkers)
  Marker _buildBaseDot(LatLng point, Color color) {
    return Marker(
      point: point,
      width: 12,
      height: 12,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
        ),
      ),
    );
  }

  Widget _buildSimplePin({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment
          .end, // Asegura que el icono quede al final de la columna
      children: [
        // 1. ETIQUETA NEGRA (Arriba)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        // 2. TRIÁNGULO (Apunta hacia abajo)
        CustomPaint(size: const Size(12, 6), painter: _TrianglePainter()),
        const SizedBox(height: 2),
        // 3. ICONO CIRCULAR (Este toca el punto blanco del mapa)
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        // NO AGREGAR SIZEDBOX AQUÍ. La base del icono debe ser el final del widget.
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Determinamos qué vista mostrar basándonos en el estado
    return Scaffold(
      key: _scaffoldKey,
      // El drawer solo en Dashboard
      drawer: (_tripState == TripState.DASHBOARD && !_isPickingLocation)
          ? SideMenu(onToggleMode: _toggleAppMode)
          : null,
      body: AnimatedSwitcher(
        duration: const Duration(
          milliseconds: 500,
        ), // Transición suave de medio segundo
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: _buildCurrentStateBody(),
      ),
    );
  }

  // Nueva función para organizar las jerarquías de las pantallas
  Widget _buildCurrentStateBody() {
    // 1. PRIORIDAD: Pantalla completa de carga
    if (_tripState == TripState.CALCULATING) {
      return _buildFullScreenLoading(key: const ValueKey("loading_screen"));
    }

    // 2. DASHBOARD
    // POR ESTO:
    if (_tripState == TripState.DASHBOARD && !_isPickingLocation) {
      return _buildUberDashboardFull(key: const ValueKey("dashboard_screen"));
    }

    return _buildMapInterface(key: const ValueKey("map_screen"));
  }

  Widget _buildFullScreenLoading({required Key key}) {
    final isCorp = _currentUser.isCorporateMode;
    final color = isCorp ? AppColors.darkBlue : AppColors.primaryGreen;

    return Container(
      key: key,
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // EL ICONO DE PULSO SE QUEDA AFUERA: Siempre animando
          _PulseLoadingIcon(color: color),

          const SizedBox(height: 50),

          // --- ANIMACIÓN DE TEXTO SUAVE ---
          // --- DENTRO DE _buildFullScreenLoading ---
          // --- DENTRO DE _buildFullScreenLoading ---
          SizedBox(
            height: 120, // Altura fija para evitar que la UI se mueva
            child: AnimatedSwitcher(
              duration: const Duration(
                milliseconds: 600,
              ), // Duración más larga para suavidad
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                // SOLO EFECTO DE FADE Y ESCALA, NADA DE OFFSET (NADA DE ARRIBA/ABAJO)
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.98,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey(
                  _loadingTitle + _loadingSubtitle,
                ), // Clave para disparar animación
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _loadingTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkBlue,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _loadingSubtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PEGA ESTO AL FINAL DE LA CLASE _HomeScreenState ---
  Widget _buildMapInterface({required Key key}) {
    return Stack(
      key: key, // <--- AÑADE ESTO

      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? _defaultLocation,
              initialZoom: 15.0,
              minZoom: 6.0, // No permite alejarse más allá del nivel país
              maxZoom:
                  18.0, // No permite acercarse más allá del nivel puerta de edificio
              onMapReady: () => setState(() => _isMapReady = true),
              onPositionChanged: (camera, hasGesture) {
                if (_isPickingLocation && hasGesture) {
                  // BLOQUEO INSTANTÁNEO:
                  if (_pickingAddress != "Buscando dirección...") {
                    setState(() {
                      _pickingAddress = "Buscando dirección...";
                    });
                  }
                  _handleMapCameraMovement(camera);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}{r}?access_token=$myMapboxToken',
                tileProvider: CachedTileProvider(),
                retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
              ),
              if (_isPickingLocation &&
                  _isStrictPickupMode &&
                  _referenceOriginCoords != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _referenceOriginCoords!,
                      radius: 200,
                      useRadiusInMeter: true,
                      color: AppColors.primaryGreen.withValues(alpha: 0.08),
                      borderColor: AppColors.primaryGreen.withValues(
                        alpha: 0.3,
                      ),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),

              // 2. LÍNEA DE PUNTOS: Solo si es Ajuste de Recogida
              if (_isPickingLocation &&
                  _mapPickingTarget == 'pickup' &&
                  _referenceOriginCoords != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_referenceOriginCoords!, _mapCenter],
                      strokeWidth: 5,
                      color: Colors.grey.withValues(alpha: 0.5),
                      pattern: const StrokePattern.dotted(),
                    ),
                  ],
                ),

              // 3. RUTA DIBUJADA: Solo si NO estamos editando (Vista Previa)
              if (_animatedRoutePoints.isNotEmpty &&
                  (!_isPickingLocation || _mapPickingTarget == 'pickup'))
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _animatedRoutePoints,
                      strokeWidth: 5,
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),

              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
        ),
        _buildMapPickingSearchOverlay(), // <--- AÑADIR ESTO AQUÍ

        if (!_isPickingLocation) _buildDraggablePanel(),

        if (_isPickingLocation) _buildMapPickerUI(),

        if (_tripState == TripState.DASHBOARD && !_isPickingLocation)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: _buildRoundMenuButton(),
          ),
      ],
    );
  }

  Widget _buildUberDashboardFull({required Key key}) {
    return Container(
      key: key, // <--- AÑADE ESTO

      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.45),
          radius: 1.8,
          colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER: Menú y Logo ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRoundMenuButton(),
                  Hero(
                    tag: 'logo',
                    child: Image.asset('assets/images/logo.png', height: 60),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- BIENVENIDA ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.montserrat(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.darkBlue,
                            letterSpacing: -0.5,
                          ),
                          children: [
                            const TextSpan(text: "¿A dónde "),
                            TextSpan(
                              text: "VAMOS",
                              style: TextStyle(color: AppColors.primaryGreen),
                            ),
                            const TextSpan(text: " hoy?"),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // --- BUSCADOR ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildSearchWidgetPremium(),
                    ),
                    const SizedBox(height: 20),
                    // --- SECCIÓN: ACCESOS RÁPIDOS ---
                    _buildSectionTitle("Mis lugares favoritos"),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _buildQuickAccessBtn(
                            icon: Icons.home_rounded,
                            label: "Casa",
                            type: "home",
                            address: _currentUser.homeAddress,
                            lat: _currentUser.homeLat,
                            lng: _currentUser.homeLng,
                          ),
                          const SizedBox(width: 12),
                          _buildQuickAccessBtn(
                            icon: Icons.work_rounded,
                            label: "Oficina",
                            type: "work",
                            address: _currentUser.workAddress,
                            lat: _currentUser.workLat,
                            lng: _currentUser.workLng,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // --- SECCIÓN: RECIENTES ---
                    if (_recentPlaces.isNotEmpty) ...[
                      _buildSectionTitle("Destinos recientes"),
                      ..._recentPlaces
                          .take(3)
                          .map((place) => _buildRecentItemPremium(place)),
                    ],

                    const SizedBox(height: 20),

                    // --- SECCIÓN: SERVICIOS ---
                    _buildSectionTitle("Nuestros servicios"),
                    _buildServiceGrid(),

                    const SizedBox(height: 20),

                    // --- SECCIÓN: COMUNIDAD / TUTORIAL ---
                    _buildSectionTitle("Para ti"),
                    _buildTutorialBanner(AppColors.primaryGreen),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessBtn({
    required IconData icon,
    required String label,
    required String type, // <--- ESTO ES LO QUE FALTABA
    String? address,
    double? lat,
    double? lng,
  }) {
    bool isSet = address != null && address.isNotEmpty;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (isSet) {
            // Si ya existe, abrimos el modal de opciones (Viajar o Cambiar)
            _showQuickAddressOptions(label, type, address, lat!, lng!);
          } else {
            // Si no existe, abrimos buscador para configurar
            _openSearchForConfig(type);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSet
                    ? const ui.Color.fromARGB(255, 255, 255, 255)
                    : Colors.grey.shade300,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const ui.Color.fromARGB(255, 255, 255, 255),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Botón de Menú con Alta Visibilidad ---
  Widget _buildRoundMenuButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: IconButton(
        icon: const Icon(
          Icons.menu_rounded,
          color: AppColors.darkBlue,
          size: 28,
        ),
        // Ya no necesitas el if aquí, ya controlaste la visibilidad afuera
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
    );
  }

  // --- Buscador Premium ---
  Widget _buildSearchWidgetPremium() {
    return GestureDetector(
      onTap: () => _openSearchFromCurrentState(),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: AppColors.primaryGreen,
              size: 28,
            ),
            const SizedBox(width: 15),
            Text(
              "Ingresa tu destino...",
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: const ui.Color.fromARGB(255, 129, 129, 129),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Tarjetas de Servicios en AZUL OSCURO con iconos VERDES ---
  Widget _buildServiceGrid() {
    return SizedBox(
      height: 125, // Un poco más alto para nombres de dos líneas
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        children: [
          _serviceItem("Transporte\nCorporativo", Icons.business_rounded),
          _serviceItem("Transporte\nEspecial", Icons.airport_shuttle_rounded),
          _serviceItem("Turismo\ny Viajes", Icons.explore_rounded),
          _serviceItem(
            "Pacientes no\nMedicalizados",
            Icons.health_and_safety_rounded,
          ),
        ],
      ),
    );
  }

  Widget _serviceItem(String label, IconData icon) {
    return Container(
      width: 110, // Ancho ajustado para equilibrio visual
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        color: AppColors.darkBlue, // FONDO AZUL OSCURO
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBlue.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primaryGreen,
              size: 28,
            ), // ICONO VERDE
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Recientes ajustados para fondo claro ---
  Widget _buildRecentItemPremium(Map<String, dynamic> place) {
    return ListTile(
      visualDensity: VisualDensity.compact, // Más apretadito estilo Uber
      contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 0),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.history_rounded,
          color: AppColors.primaryGreen,
          size: 18,
        ),
      ),
      title: Text(
        place['name'] ?? "Ubicación",
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.darkBlue,
        ),
      ),
      subtitle: Text(
        place['address'] ?? "",
        style: GoogleFonts.montserrat(
          fontSize: 11,
          color: Colors.grey.shade500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _handleSearchResult({
        'destinationName': place['name'],
        'destinationCoords': LatLng(place['lat'], place['lng']),
        'originName': "Mi ubicación",
        'originCoords': _currentPosition,
        'isManualOrigin': false,
      }),
    );
  }

  // --- Banner de Tutorial ---
  Widget _buildTutorialBanner(Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      // Eliminamos height: 160 para evitar el desbordamiento si el texto es grande
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: LinearGradient(
          colors: [accentColor, accentColor.withValues(alpha: 0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.stars_rounded,
              size: 140, // Un poco más pequeño para no empujar el layout
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Ocupa solo el espacio necesario
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "¿Nuevo en VAMOS?",
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Mira nuestro tutorial de uso y\nsaca el máximo provecho.",
                  style: GoogleFonts.montserrat(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 15),
                // Usamos un ConstrainedBox para que el botón no sea excesivamente alto
                SizedBox(
                  height: 40, // Altura fija para el botón para ahorrar espacio
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "VER AHORA",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMapCameraMovement(MapCamera camera) {
    // --- BLOQUE 1: RESTRICCIÓN DE 200M (SOLO MODO ESTRICTO) ---
    if (_isStrictPickupMode && _referenceOriginCoords != null) {
      double distFromOrigin = Geolocator.distanceBetween(
        _referenceOriginCoords!.latitude,
        _referenceOriginCoords!.longitude,
        camera.center.latitude,
        camera.center.longitude,
      );

      if (distFromOrigin > 200) {
        final double bearing = Geolocator.bearingBetween(
          _referenceOriginCoords!.latitude,
          _referenceOriginCoords!.longitude,
          camera.center.latitude,
          camera.center.longitude,
        );

        final LatLng puntoLimite = const Distance().offset(
          _referenceOriginCoords!,
          195.0,
          bearing,
        );

        _mapController.move(puntoLimite, camera.zoom);
        if (!_isOutsideRadius) setState(() => _isOutsideRadius = true);
        return; // No continuamos con la geocodificación si está fuera de rango
      } else {
        if (_isOutsideRadius) setState(() => _isOutsideRadius = false);
      }
    }

    // --- BLOQUE 2: GEOCODIFICACIÓN (LIBRE O ESTRICTA) ---
    // Mantenemos el debounce pero sin bloquear el movimiento en modo libre
    _debounceGeocoding?.cancel();
    _debounceGeocoding = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;

      final data = await _searchService.getReverseGeocode(
        camera.center.latitude,
        camera.center.longitude,
        persist: false,
      );

      if (data != null && mounted) {
        setState(() {
          _pickingAddress = data['name'] ?? "Ubicación seleccionada";
          _lastGeocodedPosition = camera.center;
        });
      }
    });
  }

  Widget _buildMapPickerUI() {
    final bool isSavingFavorite = _addressTypeToSave != null;

    String mainLabel = "";
    String buttonText = "";
    Color activeColor = Colors.grey;
    IconData iconData = Icons.location_on;

    if (isSavingFavorite) {
      mainLabel = "CONFIGURAR FAVORITO";
      buttonText = "GUARDAR FAVORITO";
      activeColor = AppColors.darkBlue;
      iconData = Icons.bookmark_add_rounded;
    } else if (_mapPickingTarget == 'pickup') {
      mainLabel = "PUNTO DE ENCUENTRO";
      buttonText = "CONFIRMAR RECOGIDA";
      activeColor = AppColors.primaryGreen;
      iconData = Icons.person_pin_circle;
    } else if (_mapPickingTarget == 'reference') {
      mainLabel = "NUEVA DIRECCIÓN DE PARTIDA";
      buttonText = "ESTABLECER INICIO";
      activeColor = Colors.black;
      iconData = Icons.adjust;
    } else if (_mapPickingTarget == 'destination') {
      mainLabel = "NUEVO DESTINO";
      buttonText = "ESTABLECER DESTINO";
      activeColor = AppColors.darkBlue;
      iconData = Icons.location_on;
    } else {
      // Caso de seguridad por si acaso
      mainLabel = "SELECCIONAR UBICACIÓN";
      buttonText = "CONFIRMAR";
      activeColor = AppColors.primaryGreen;
      iconData = Icons.location_on;
    }

    if (_pickingAddress == "Buscando dirección...") {
      buttonText = "BUSCANDO VÍA...";
    }
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 45),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkBlue,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_pickingAddress == "Buscando dirección...")
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(
                          Icons.gps_fixed,
                          color: Colors.white,
                          size: 14,
                        ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            _pickingAddress,
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // El triángulo de la burbuja
                SizedBox(
                  width: 12,
                  height: 8,
                  child: CustomPaint(painter: _TrianglePainter()),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                      ),
                    ],
                    border: Border.all(color: activeColor, width: 3),
                  ),
                  child: Icon(iconData, color: activeColor, size: 28),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildMapControlBtn(Icons.my_location, _moveToCurrentPosition),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: activeColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(iconData, color: activeColor, size: 24),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mainLabel,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey.shade400,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _pickingAddress,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.darkBlue,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      // Busca el GestureDetector del botón de confirmación y modifícalo así:
                      // Busca esto dentro de _buildMapPickerUI
                      GestureDetector(
                        onTap: () {
                          // Si el usuario quiere confirmar, dejamos que el método _confirmMapSelection
                          // gestione si es seguro o no, pero permitimos el clic.
                          _confirmMapSelection();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            // Eliminamos la condición que bloqueaba el color por "Buscando dirección..."
                            // Solo lo bloqueamos si está cargando activamente (isLoadingAddress)
                            color: _isLoadingAddress
                                ? Colors.grey.shade400
                                : activeColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoadingAddress
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  )
                                : Text(
                                    buttonText,
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isPickingLocation = false;
                              _addressTypeToSave = null;
                              _isPickingOrigin = false;
                              _mapPickingTarget =
                                  null; // IMPORTANTE: Limpiar el target para no quedar en bucle
                            });

                            // LÓGICA DE REGRESO INTELIGENTE:
                            // 1. Si no hay origen ni destino, es que el viaje nunca inició, volvemos al dashboard
                            if (_originCoordinates == null &&
                                _destinationCoordinates == null) {
                              _resetApp();
                            }
                            // 2. Si estábamos editando/fijando pero ya había una ruta, volvemos al preview
                            else if (_routePoints.isNotEmpty &&
                                _destinationCoordinates != null) {
                              setState(
                                () => _tripState = TripState.ROUTE_PREVIEW,
                              );
                              _fitCameraToRoute();
                            }
                            // 3. CASO CLAVE: Si estábamos en el mapa y NO hay viaje completo,
                            // regresamos al buscador para que el usuario pueda corregir su elección.
                            else {
                              _openSearchFromCurrentState();
                            }
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: AppColors.darkBlue.withValues(
                                  alpha: 0.15,
                                ),
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            "CANCELAR",
                            style: GoogleFonts.montserrat(
                              color: AppColors.darkBlue.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMinifiedHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      child: Row(
        children: [
          Icon(
            Icons.directions_car,
            color: _currentUser.isCorporateMode
                ? AppColors.darkBlue
                : AppColors.primaryGreen,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Viaje a ${_destinationName?.split(',').first ?? 'Destino'}",
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Total: \$ ${_formatCurrency(_tripPrice)}",
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
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
        'icon': Icons.directions_car_filled,
        'capacity': '1-4',
        'dbKey': 'CITY CAR',
        'max': 4,
      },
      {
        'id': 'PREMIUM',
        'label': 'Confort',
        'icon': Icons.local_taxi,
        'capacity': '1-4',
        'dbKey': 'SUV',
        'max': 4,
      },
      {
        'id': 'VAN',
        'label': 'Van',
        'icon': Icons.airport_shuttle,
        'capacity': '5-10',
        'dbKey': 'VAN',
        'max': 10,
      },
    ];

    final isCorp = _currentUser.isCorporateMode;
    final activeColor = isCorp ? AppColors.darkBlue : AppColors.primaryGreen;

    return Container(
      height: 125, // Altura optimizada para que no se vea apretado
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        itemCount: options.length,
        // ignore: unnecessary_underscores
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final opt = options[index];
          final bool isSelected = _selectedServiceCategory == opt['id'];

          // --- LÓGICA DE BLOQUEO ESTRICTO ---
          bool isDisabled = false;
          if (_totalPassengers > 4 && opt['max'] == 4) isDisabled = true;
          if (_totalPassengers <= 4 && opt['id'] == 'VAN') isDisabled = true;

          // --- PRECIO ---
          double displayPrice = (_categoryPricesFromServer[opt['dbKey']] ?? 0)
              .toDouble();
          if (displayPrice <= 0) {
            double mult = _categoryMultipliers[opt['id']] ?? 1.0;
            displayPrice = ((_baseRoutePrice * mult) / 100).ceil() * 100;
          }

          return GestureDetector(
            onTap: isDisabled
                ? null
                : () {
                    setModalState(() {
                      _selectedServiceCategory = opt['id'];
                      _tripPrice = displayPrice;
                    });
                    setState(() {
                      _selectedServiceCategory = opt['id'];
                      _tripPrice = displayPrice;
                    });
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 105,
              decoration: BoxDecoration(
                // CORRECCIÓN LINTER: Uso de withValues en lugar de withOpacity
                color: isSelected
                    ? activeColor.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? activeColor : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Opacity(
                opacity: isDisabled ? 0.35 : 1.0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      opt['icon'],
                      color: isSelected ? activeColor : Colors.grey[500],
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      opt['label'],
                      style: GoogleFonts.montserrat(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 12,
                        color: isSelected ? activeColor : Colors.black87,
                      ),
                    ),
                    Text(
                      "\$ ${_formatCurrency(displayPrice)}",
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected ? activeColor : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withValues(alpha: 0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${opt['capacity']} pax",
                        style: GoogleFonts.montserrat(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? activeColor : Colors.grey[500],
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
    final primaryColor = isCorp ? AppColors.darkBlue : AppColors.primaryGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        // 1. Agregamos esto para que la columna no ocupe espacio infinito
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeSelector(primaryColor, setModalState),
          const SizedBox(
            height: 15,
          ), // Reducimos un poco los espacios de 20 a 15

          _sectionLabel("VAMOS PARA"),
          _buildTripDetailsCard(primaryColor, setModalState, _isOriginSnapped),

          const SizedBox(height: 15),
          _sectionLabel("¿EN CUÁL CARRO NOS VAMOS?"),
          _buildVehicleSelector(setModalState),

          // 2. IMPORTANTE: Si el ticket de precio es muy grande, podría causar el error
          Flexible(child: _buildPriceTicket(setModalState)),

          const SizedBox(height: 10),
          _sectionLabel("¿CÓMO VAS A PAGAR?"),
          _buildPaymentSelector(setModalState),

          const SizedBox(height: 20),
          _buildRequestButton(primaryColor),
          const SizedBox(height: 10),

          Center(
            child: TextButton(
              onPressed: () => _resetApp(),
              child: Text(
                "Cancelar solicitud",
                style: GoogleFonts.montserrat(
                  color: Colors.red[400],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para las etiquetas de sección
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.grey[400],
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // Determina qué tan abierto empieza el panel según el estado
  // 1. Determina el tamaño de apertura (Lo que ve el usuario apenas carga el estado)
  double _getInitialSheetSize() {
    switch (_tripState) {
      case TripState.CALCULATING:
        return 0.42; // Aumentamos para que se vea toda la animación Premium y el checklist
      case TripState.ROUTE_PREVIEW:
        return 0.48;
      case TripState.SEARCHING_DRIVER:
        return 0.38;
      case TripState.DRIVER_ON_WAY:
        return 0.45;
      case TripState.IN_TRIP:
        return 0.35;
      case TripState.PAYMENT:
        return 0.50;
      default:
        return 0.40;
    }
  }

  // 2. Determina el límite superior (El "techo" del modal)
  double _getMaxSheetSize() {
    switch (_tripState) {
      case TripState.CALCULATING:
        // Ahora el máximo (0.45) es mayor al inicial (0.42). Ya no habrá bloqueo.
        return 0.45;
      case TripState.ROUTE_PREVIEW:
        return 0.50; // Permitimos que suba casi todo para elegir el carro cómodamente
      case TripState.SEARCHING_DRIVER:
        return 0.50;
      case TripState.DRIVER_ON_WAY:
        return 0.85; // Permitimos subir para ver bien la foto del conductor y placa
      case TripState.IN_TRIP:
        return 0.45;
      case TripState.PAYMENT:
        return 0.60;
      default:
        return 0.90;
    }
  }

  // Retorna el contenido correcto para el panel
  Widget _buildDynamicSheetContent(double extent) {
    // <--- Agrega 'double extent'
    // Aumentamos ligeramente el umbral de 0.13 a 0.16 para que
    // el cambio de cabecera ocurra un poco antes de llegar al fondo total.
    bool isBottom = extent <= 0.16;

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
    final color = isCorp ? AppColors.darkBlue : AppColors.primaryGreen;

    return _AnimatedChecklist(color: color, isCorp: isCorp);
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
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[700],
            ),
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

  void _onFavSearchChanged(String query) {
    if (query.trim().length < 3) {
      setState(() {
        _favSearchResults = [];
        _isSearchingFav = false;
      });
      return;
    }

    _favDebounce?.cancel();
    _favDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _isSearchingFav = true);

      final results = await _searchService.searchPlaces(
        query,
        lat: _currentPosition?.latitude,
        lng: _currentPosition?.longitude,
      );

      if (mounted) {
        setState(() {
          _favSearchResults = results;
          _isSearchingFav = false;
        });
      }
    });
  }

  Future<void> _onFavResultSelected(Map<String, dynamic> place) async {
    FocusManager.instance.primaryFocus?.unfocus();

    // 1. Si no tiene coordenadas, las pedimos al servidor
    if (place['lat'] == null) {
      setState(() => _isLoadingAddress = true);
      final coords = await _searchService.getPlaceCoords(
        place['place_id'] ?? place['mapbox_id'],
        null,
      );
      if (coords != null) {
        place['lat'] = coords['lat'];
        place['lng'] = coords['lng'];
      }
    }

    if (place['lat'] != null && mounted) {
      final LatLng target = LatLng(place['lat'], place['lng']);

      setState(() {
        _pickingAddress = place['name'] ?? "Ubicación seleccionada";
        _favSearchResults = []; // Limpiamos la lista de sugerencias
        _favSearchController.text = ""; // Limpiamos el buscador
        _isLoadingAddress = false;
      });

      // Movemos el mapa suavemente al lugar elegido
      _animatedMapMove(target, 17.5);
    }
  }

  Widget _buildGenericMinifiedHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: [
          Icon(
            icon,
            color: _currentUser.isCorporateMode
                ? AppColors.darkBlue
                : AppColors.primaryGreen,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.montserrat(
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
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isOriginConfirmed ? color : AppColors.darkBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: () {
          if (_isOriginConfirmed) {
            _handleTripRequest();
          } else {
            // ❌ ELIMINA ESTA LÍNEA: Navigator.pop(context, 'PICKING');

            // ✅ Solo llama al método. Al hacer setState dentro de él,
            // la UI detectará que _isPickingLocation es true y cambiará los widgets.
            _startPickupConfirmation();
          }
        },
        child: Text(
          _isOriginConfirmed
              ? "Confirmar este servicio"
              : "Fijar punto de recogida",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTripDetailsCard(
    Color color,
    StateSetter setModalState,
    bool isSnapped, // Mantén este parámetro
  ) {
    // 1. Definimos la condición directamente aquí, combinando el parámetro recibido
    // y nuestra variable de estado global _isOriginConfirmed.
    final bool showFixPickup = !_isOriginConfirmed;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          // 2. Usamos la variable aquí
          if (showFixPickup) ...[
            _buildLocationRow(
              icon: Icons.adjust_rounded,
              iconColor: _isOriginConfirmed
                  ? AppColors.primaryGreen
                  : Colors.orangeAccent,
              label: "PUNTO DE RECOGIDA EXACTO",
              address: _originName ?? "Toca para fijar recogida",
              isHighlight: !_isOriginConfirmed,
              onEdit: () {
                // 1. Activamos el estado de carga ANTES de abrir el modo de picking
                setState(() {
                  _tripState = TripState.CALCULATING;
                });

                // 2. Pequeño delay para que el usuario VEA la pantalla de carga (opcional pero recomendado)
                Future.delayed(const Duration(milliseconds: 300), () {
                  setState(() {
                    _mapPickingTarget =
                        'pickup'; // O 'reference'/'destination' según corresponda
                    _isPickingOrigin = true;
                    _isPickingLocation = true;
                    _isOriginSnapped = false;
                    _tripState = TripState
                        .CONFIRMING_PICKUP; // Regresamos al estado de mapa
                  });
                });

                _startPickupConfirmation();
              },
            ),
            _buildCustomDivider(),
          ],

          // --- FILA 2: ORIGEN / REFERENCIA (Siempre se muestra) ---
          _buildLocationRow(
            icon: Icons.search_rounded,
            iconColor: Colors.grey,
            label: "DIRECCIÓN DE PARTIDA",
            address: _originReferenceName ?? "Mi ubicación",
            onEdit: () {
              setState(() {
                _mapPickingTarget = 'reference';
                _isPickingOrigin = true;
                _isPickingLocation = true;
                _isOriginSnapped =
                    false; // Si edita la referencia, debe volver a fijar
              });
              _startPickupConfirmation(
                initialAddress: _originReferenceName,
                initialPosition: _originCoordinates,
              );
            },
          ),

          _buildCustomDivider(),

          // --- FILA 3: DESTINO ---
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: AppColors.darkBlue,
            label: "DESTINO DEL VIAJE",
            address: _destinationName ?? "Seleccionar destino",
            info: "$_tripDistance • $_tripDuration aprox.",
            onEdit: () {
              setState(() {
                _mapPickingTarget = 'destination';
                _isPickingOrigin = false;
                _isPickingLocation = true;
              });
              _startPickupConfirmation(
                initialAddress: _destinationName,
                initialPosition: _destinationCoordinates,
              );
            },
          ),

          const Divider(height: 1),

          // --- SECCIÓN PASAJEROS (Mantenemos tu lógica pero con estilo limpio) ---
          InkWell(
            onTap: () async {
              await _showBeneficiarySelector();
              setModalState(() {});
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Pasajeros",
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getPassengerSummary(),
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Marcador sutil para el punto que se buscó originalmente (Referencia)
  Widget _buildReferencePin() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Etiqueta pequeña
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            "DIRECCIÓN BUSCADA",
            style: GoogleFonts.montserrat(
              fontSize: 7,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        // Un punto negro pequeño como ancla
        Container(
          margin: const EdgeInsets.only(
            top: 2,
          ), // <--- Cambia .top(2) por .only(top: 2)
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        children: [
          Container(width: 2, height: 10, color: Colors.grey.shade200),
          const Expanded(child: Divider(height: 1, indent: 20)),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required VoidCallback onEdit,
    String? info,
    bool isHighlight =
        false, // <--- 1. Agregamos el parámetro con valor por defecto
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isHighlight
                        ? Colors.orange[800]
                        : Colors
                              .grey[400], // <--- 2. Color dinámico en etiqueta
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  address,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    // 3. Color dinámico en la dirección: naranja si resalta, si no, azul oscuro
                    color: isHighlight
                        ? Colors.orange[900]
                        : AppColors.darkBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (info != null)
                  Text(
                    info,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              backgroundColor: isHighlight
                  ? Colors.orange[50]
                  : Colors.grey[50], // 4. Fondo sutil naranja
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isHighlight ? "FIJAR" : "Cambiar", // 5. Texto dinámico
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isHighlight
                    ? Colors.orange[900]
                    : AppColors.primaryGreen,
              ),
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
      ).toLocal();
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
              style: GoogleFonts.montserrat(
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
              style: GoogleFonts.montserrat(
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
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              "IMPORTANTE: El conductor solicitará el documento físico de CADA persona antes de iniciar. Sin registro en la App, no podrán subir al vehículo.",
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.grey[800],
              ),
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
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_includeMyself)
                    Text(
                      "• Yo (${_currentUser.name})",
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ..._selectedBeneficiariesList.map(
                    (b) => Text(
                      "• ${b.name}",
                      style: GoogleFonts.montserrat(fontSize: 13),
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
              // 1. Cierra el diálogo de confirmación de pasajeros
              Navigator.pop(ctx);

              // 2. Abre el selector y ESPERAMOS a que el usuario termine
              await _showBeneficiarySelector();

              // 3. Al terminar, simplemente refrescamos la pantalla.
              // El panel Draggable (que ya está en el fondo) mostrará los cambios.
              if (mounted) {
                setState(() {});
              }
            },
            child: Text(
              "Editar Lista",
              style: GoogleFonts.montserrat(
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
              style: GoogleFonts.montserrat(color: Colors.white),
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
      _showIncompleteProfileDialog();
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
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                "El FUEC se generará a nombre de:",
                style: GoogleFonts.montserrat(fontSize: 13),
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
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _currentUser.name,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Empresa:",
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _currentUser.empresa.isEmpty
                          ? "N/A"
                          : _currentUser.empresa,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Volver", style: GoogleFonts.montserrat()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showConfirmPassengersDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Aceptar",
                style: GoogleFonts.montserrat(color: Colors.white),
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
    if (!_isOriginConfirmed && _tripState == TripState.CONFIRMING_PICKUP) {
      _showAppSnackBar(
        "Por favor confirma tu punto de partida en el mapa",
        isError: true,
      );
      return;
    }
    if (_currentPosition == null || _destinationCoordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Ubicación no disponible.")),
      );
      return;
    }

    setState(() {
      _loadingTitle = "SOLICITANDO SERVICIO";
      _loadingSubtitle = "Conectando con un conductor cercano...";
      _tripState = TripState.CALCULATING;
    });
    try {
      // 1. Obtener dirección con Timeout
      String realOriginAddress = "Ubicación actual";
      try {
        realOriginAddress = await _osmService
            .getAddressFromCoordinates(_currentPosition!)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        /* Ignorar error de dirección, usar fallback */
      }

      // Si falla el servicio de mapas, usamos un fallback pero intentamos que sea descriptivo
      if (realOriginAddress.isEmpty ||
          realOriginAddress == "Dirección no encontrada") {
        realOriginAddress =
            "Origen cerca de: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}";
      }

      final tripService = TripService();

      // 2. MAPEO DE PASAJEROS
      // Dentro de _processTripCreation en home_screen.dart
      List<Passenger> passengersList = _selectedBeneficiariesList.map((b) {
        return Passenger(
          id: b.id,
          name: b.name,
          nationalId: b.documentNumber,
          documentType:
              b.documentType, // <--- IMPORTANTE: Usar el campo del modelo
        );
      }).toList();

      // 3. DEFINICIÓN DE MÉTODO DE PAGO PARA EL BACKEND

      String backendPaymentId = 'EFECTIVO';

      // Si el usuario tiene el switch de Modo Corporativo encendido,
      // forzamos que el método de pago sea CORPORATIVO para el FUEC.
      if (_currentUser.isCorporateMode) {
        backendPaymentId = 'CORPORATIVO';
      } else {
        // Si es modo personal, mapeamos según lo seleccionado
        if (_selectedMethod?.id == 'cash') backendPaymentId = 'EFECTIVO';
        if (_selectedMethod?.type == PaymentMethodType.card)
          // ignore: curly_braces_in_flow_control_structures
          backendPaymentId = 'TARJETA';
      }

      print("💳 MÉTODO DE PAGO ENVIADO: $backendPaymentId");
      // 4. LLAMADA AL SERVICIO CON LA DIRECCIÓN REAL
      String? tripId = await tripService
          .createTripRequest(
            currentUser: _currentUser,
            origin: _originCoordinates!,
            destination: _destinationCoordinates!,
            // Usamos los mismos puntos ya que _confirmMapSelection se encarga de que
            // _originCoordinates y _destinationCoordinates ya sean los "snapped"
            snappedLatOrigin: _originCoordinates!.latitude,
            snappedLngOrigin: _originCoordinates!.longitude,
            snappedLatDestino: _destinationCoordinates!.latitude,
            snappedLngDestino: _destinationCoordinates!.longitude,

            originAddress: _originName!,
            destinationAddress: _destinationName!,
            serviceCategory: _selectedServiceCategory,
            estimatedPrice: _tripPrice,
            passengers: passengersList,
            includeMyself: _includeMyself,
            scheduledAt: _scheduledAt,
            desglose: _tripDesglose,
            paymentMethod: backendPaymentId,
          )
          .timeout(const Duration(seconds: 15));

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
      debugPrint("🚨 Error creando viaje: $e");

      if (mounted) {
        // 1. PRIMERO: Limpiamos la app (esto quita el modal de "Buscando")
        _resetApp();

        // 2. SEGUNDO: Procesamos el mensaje de error
        String errorMsg = e.toString();
        if (e is DioException) {
          errorMsg = e.response?.data['message'] ?? e.message;
        }

        // 3. TERCERO: Mostramos la alerta sobre la pantalla ya limpia (DASHBOARD)
        if (errorMsg.contains("conductor") || errorMsg.contains("disponible")) {
          _showNoDriversDialog(errorMsg);
        } else {
          _showAppSnackBar(errorMsg, isError: true);
        }
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
        title: const Icon(
          Icons.calendar_today,
          color: AppColors.darkBlue,
          size: 50,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "¡Viaje Programado!",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Tu servicio ha sido registrado. Te notificaremos con los datos del conductor y el vehículo 15 minutos antes de la hora seleccionada.",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 14),
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
                backgroundColor: AppColors.darkBlue,
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
    Color primaryColor = isCorp ? AppColors.darkBlue : AppColors.primaryGreen;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  // Indicador de arrastre
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Cabecera
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "¿Quiénes viajan?",
                          style: GoogleFonts.montserrat(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.darkBlue,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Lista de Pasajeros
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      children: [
                        // Opción "Yo"
                        _buildSelectionCard(
                          title: "Viajo yo",
                          subtitle: _currentUser.name,
                          isSelected: _includeMyself,
                          icon: Icons.person_rounded,
                          primaryColor: primaryColor,
                          onChanged: (val) {
                            setModalState(() => _includeMyself = val);
                            setState(() => _updateFinalPrice());
                          },
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 15,
                            horizontal: 10,
                          ),
                          child: Text(
                            "MIS PASAJEROS",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),

                        if (_currentUser.beneficiaries.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                "No tienes pasajeros guardados",
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          )
                        else
                          ..._currentUser.beneficiaries.map((b) {
                            final isSelected = _selectedPassengerIds.contains(
                              b.id,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildSelectionCard(
                                title: b.name,
                                subtitle:
                                    "${b.documentType}: ${b.documentNumber}",
                                isSelected: isSelected,
                                icon: Icons.group_rounded,
                                primaryColor: primaryColor,
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val) {
                                      _selectedPassengerIds.add(b.id);
                                    } else {
                                      _selectedPassengerIds.remove(b.id);
                                    }
                                  });
                                  setState(() => _updateFinalPrice());
                                },
                              ),
                            );
                          }),
                      ],
                    ),
                  ),

                  // Botón Agregar
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () =>
                            _showAddBeneficiaryDialog(setModalState),
                        child: Text(
                          "AGREGAR PASAJERO",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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

  // Widget de Tarjeta Premium
  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required Color primaryColor,
    required Function(bool) onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.montserrat(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: isSelected,
              activeColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              onChanged: (val) => onChanged(val!),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBeneficiaryDialog(StateSetter parentModalState) {
    final nameCtrl = TextEditingController();
    final docCtrl = TextEditingController();
    String selectedDocType = 'CC'; // Valor inicial

    final List<String> docTypes = ['CC', 'CE', 'TI', 'PP'];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        // Necesario para actualizar el dropdown dentro del dialog
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Nuevo Pasajero",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Selector de Tipo de Documento ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedDocType,
                    isExpanded: true,
                    items: docTypes.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(
                          "$type - ${_getDocName(type)}",
                          style: GoogleFonts.montserrat(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedDocType = val!),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // --- Campo Nombre ---
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDeco("Nombre Completo"),
              ),
              const SizedBox(height: 15),

              // --- Campo Documento ---
              TextField(
                controller: docCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDeco("Número de Identificación"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Cancelar",
                style: GoogleFonts.montserrat(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentUser.isCorporateMode
                    ? AppColors.darkBlue
                    : AppColors.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final doc = docCtrl.text.trim();

                if (name.isEmpty || doc.isEmpty) return;

                // 1. Llamada al servicio
                bool success = await AuthService.addBeneficiary(
                  name,
                  doc,
                  selectedDocType,
                );

                if (success && mounted) {
                  // 2. Obtenemos el último beneficiario agregado (el que acabamos de crear)
                  final nuevoPasajero =
                      AuthService.currentUser!.beneficiaries.last;

                  // 3. Cerramos el diálogo de texto
                  // ignore: use_build_context_synchronously
                  Navigator.pop(dialogContext);

                  // 4. Actualizamos el Modal de "Quiénes viajan" (parentModalState)
                  parentModalState(() {
                    _selectedPassengerIds.add(
                      nuevoPasajero.id,
                    ); // Lo seleccionamos de una vez
                  });

                  // 5. Actualizamos la HomeScreen (Precios y Categoría)
                  setState(() {
                    if (_totalPassengers > 4) {
                      _selectedServiceCategory = 'VAN';
                    }
                    _updateFinalPrice();
                  });
                }
              },
              child: Text(
                "Guardar",
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helpers para el diseño
  String _getDocName(String type) {
    switch (type) {
      case 'CC':
        return 'Cédula';
      case 'CE':
        return 'Cédula Extranjería';
      case 'TI':
        return 'Tarjeta Identidad';
      case 'PP':
        return 'Pasaporte';
      default:
        return '';
    }
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
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
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Gracias por viajar con VAMOS.",
              style: GoogleFonts.montserrat(),
            ),
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
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetApp() {
    print("DEBUG: _resetApp ejecutado!");

    FocusScope.of(context).unfocus();
    _routeDrawingController?.stop();
    _routeDrawingController?.reset();
    _simulationTimer?.cancel();
    _waitTimer?.cancel();
    _waitTimer = null;

    if (mounted) {
      setState(() {
        _isOriginSnapped = false;
        _isOriginConfirmed =
            false; // AGREGA ESTO: Invalida el estado de confirmación
        _originName = null; // AGREGA ESTO: Limpia el nombre
        _originCoordinates = null; // AGREGA ESTO: Limpia las coordenadas

        _tripState = TripState.DASHBOARD;
        _fitCameraToRoute();

        AuthService.isTripActive = false;
        _isCalculatingRoute = false;
        _isPickingLocation = false;
        _isPickingOrigin = false;
        _isOriginConfirmed = false;
        _animatedRoutePoints = [];

        _routePoints = [];
        _destinationCoordinates = null;
        _destinationName = null;
        _originCoordinates = null;

        // --- 🛡️ CRUCIAL: LIMPIAR REFERENCIA ---
        _referenceOriginCoords = null;
        _originReferenceName = null;
        // --------------------------------------

        _sheetExtentNotifier.value = 0.45;
        _driverPosition = null;
        _scheduledAt = null;
        _currentTripId = null;
        _driverData = null;
        _selectedPassengerIds.clear();
        _includeMyself = true;
        _driverEta = "Calculando...";
        _tripDesglose = null;
      });
      _moveToCurrentPosition();
    }
  }
  // --- HELPERS UI ---

  Widget _buildMapControlBtn(IconData icon, VoidCallback tap) {
    // Detectamos el color según el modo actual
    final Color iconColor = _currentUser.isCorporateMode
        ? AppColors.darkBlue
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

  Widget _buildSearchingDriverContent() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      LinearProgressIndicator(
        color: _currentUser.isCorporateMode
            ? AppColors.darkBlue
            : AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      const SizedBox(height: 25),
      Text(
        "Buscando conductor...",
        style: GoogleFonts.montserrat(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        "Estamos conectando con los conductores cercanos",
        style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey),
      ),
      const SizedBox(height: 25),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: // Busca el OutlinedButton dentro de _buildSearchingDriverContent y déjalo así:
            // Busca el OutlinedButton dentro de _buildSearchingDriverContent
            OutlinedButton(
              onPressed: () async {
                if (_currentTripId != null) {
                  // 1. Mostramos un pequeño loading o deshabilitamos el botón
                  // 2. Esperamos la confirmación del servidor
                  bool canceladoEnServer = await MenuService().cancelTrip(
                    _currentTripId!,
                  );

                  if (canceladoEnServer) {
                    _resetApp(); // Solo limpiamos la pantalla si el server confirmó
                  } else {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("No se pudo cancelar. Intenta de nuevo."),
                      ),
                    );
                  }
                }
              },
              child: Text("Cancelar Solicitud"),
            ),
      ),
    ],
  );

  Widget _buildDriverOnWayContent() {
    final data = _driverData ?? {};
    final driver =
        data['conductor'] as Map<String, dynamic>? ?? {}; // <--- CAST SEGURO
    final vehicle =
        data['vehiculo'] as Map<String, dynamic>? ?? {}; // <--- CAST SEGURO

    String? fotoUrl =
        driver['foto_perfil']?.toString() ?? driver['photo_url']?.toString();

    // Si la URL contiene la IP local de Android (emulador) o de tu PC, corregirla
    if (fotoUrl != null) {
      if (fotoUrl.contains('10.0.2.2') || fotoUrl.contains('192.168.')) {
        // 1. Reemplazamos la IP por tu dominio
        // 2. Nos aseguramos de que use HTTPS en lugar de HTTP
        fotoUrl = fotoUrl
            .replaceAll('10.0.2.2:8000', 'api.vamosapp.com.co')
            .replaceAll('192.168.10.3:8000', 'api.vamosapp.com.co')
            .replaceAll('http://', 'https://');
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          driver['nombre']?.toString() ?? "Conductor asignado",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          "${vehicle['marca'] ?? ''} ${vehicle['placa'] ?? 'Sin placa'}",
          style: GoogleFonts.montserrat(color: Colors.grey[600], fontSize: 13),
        ),
        Text(
          "Tu conductor está en camino",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
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
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "${vehicle['marca']} ${vehicle['modelo']} • ${vehicle['placa']}",
                      style: GoogleFonts.montserrat(
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
                    const Icon(
                      Icons.star,
                      size: 14,
                      color: AppColors.primaryGreen,
                    ),
                    Text(
                      " 4.8",
                      style: GoogleFonts.montserrat(
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
              style: GoogleFonts.montserrat(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (_waitTimer != null) ...[
              const SizedBox(height: 5),
              Text(
                "Tiempo de espera legal: ${(_waitSeconds ~/ 60).toString().padLeft(2, '0')}:${(_waitSeconds % 60).toString().padLeft(2, '0')}",
                style: GoogleFonts.montserrat(
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
              style: GoogleFonts.montserrat(color: Colors.red),
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
  Widget _buildPriceTicket(StateSetter setModalState) {
    if (_tripPrice <= 0) return const SizedBox.shrink();

    final isCorp = _currentUser.isCorporateMode;
    final primaryColor = isCorp
        ? const Color(0xFF1565C0)
        : AppColors.primaryGreen;

    // Extraemos info de peajes
    final List peajes = _tripDesglose?['peajes_detalles'] ?? [];
    final double totalPeajes = (_tripDesglose?['total_peajes'] ?? 0).toDouble();
    final bool tienePeajes = peajes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // --- PARTE SUPERIOR: PRECIO PRINCIPAL ---
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total estimado",
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Sujeto a cambios por tráfico",
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  "\$ ${_formatCurrency(_tripPrice)}",
                  style: GoogleFonts.montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // --- PARTE INFERIOR: BARRA DE PEAJES (Solo si existen) ---
          if (tienePeajes) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () {
                // Usamos setModalState para que el cambio sea instantáneo en el modal
                setModalState(() {
                  _showTollsDetail = !_showTollsDetail;
                });
              },
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _showTollsDetail
                      ? Colors.grey[50]
                      : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.amber[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.toll,
                            size: 16,
                            color: Colors.amber[900],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "${peajes.length} peajes incluidos en el precio",
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        Text(
                          "\$ ${_formatCurrency(totalPeajes)}",
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _showTollsDetail
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ],
                    ),

                    // --- DESGLOSE EXPANDIBLE ---
                    if (_showTollsDetail)
                      Padding(
                        padding: const EdgeInsets.only(top: 15, bottom: 5),
                        child: Column(
                          children: peajes.map((p) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.amber[600],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      p['nombre'],
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "\$ ${_formatCurrency(p['precio'].toDouble())}",
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
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
                          color: AppColors.darkBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.domain, color: AppColors.darkBlue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Modo Corporativo",
                          style: GoogleFonts.montserrat(
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
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Verificando con ${selectedCompany?['name']}",
                            style: GoogleFonts.montserrat(color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      "Selecciona tu empresa para validar tu documento.",
                      style: GoogleFonts.montserrat(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Empresa",
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                      ),
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
                                style: GoogleFonts.montserrat(
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
                                    style: GoogleFonts.montserrat(),
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
                          backgroundColor: AppColors.darkBlue,
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
                          style: GoogleFonts.montserrat(
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
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Tu identidad ha sido verificada correctamente por $companyName.",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(),
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
              style: GoogleFonts.montserrat(color: Colors.white),
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
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "No encontramos la cédula ${_currentUser.documentNumber} activa en $companyName.",
          style: GoogleFonts.montserrat(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Intentar de nuevo",
              style: GoogleFonts.montserrat(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

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

    // 🔥 CLAVE: Al volver de la pantalla de búsqueda, SIEMPRE recargamos
    // Hacemos un pequeño delay para dar tiempo al backend de procesar el guardado
    await Future.delayed(const Duration(milliseconds: 300));
    await _loadRecentPlaces();

    if (result != null) {
      // 🔥 AQUÍ ESTÁ EL AJUSTE:
      // Antes de procesar el resultado, forzamos que si el usuario usó el buscador,
      // la precisión del "Punto de recogida" se reinicie a FALSE
      // porque el buscador no garantiza la precisión del pin en el mapa.
      setState(() {
        _isOriginSnapped = false;
      });

      _handleSearchResult(result);
    }
  }

  Future<void> _calculateRouteAndPrice(LatLng destination) async {
    _isPickingLocation = false;
    _isCalculatingRoute = false;

    // 1. Usamos los puntos que YA fueron "snapped" en _confirmMapSelection
    LatLng startPoint =
        _originCoordinates ?? _currentPosition ?? _defaultLocation;
    LatLng endPoint = destination;

    // --- VALIDACIÓN DE DISTANCIA MÍNIMA ---
    double metrosDeDistancia = Geolocator.distanceBetween(
      startPoint.latitude,
      startPoint.longitude,
      endPoint.latitude,
      endPoint.longitude,
    );

    if (metrosDeDistancia < 20) {
      if (mounted) {
        setState(() {
          _tripState = TripState.DASHBOARD;
          _isCalculatingRoute = false;
        });
        _showAppSnackBar("El destino está demasiado cerca.", isError: true);
      }
      return;
    }

    if (_routePoints.isEmpty) {
      setState(() {
        _loadingTitle = "CALCULANDO RUTA";
        _loadingSubtitle = "Estamos trazando el camino más eficiente...";
        _isCalculatingRoute = true;
        _tripState = TripState.CALCULATING;
      });
    }

    try {
      await Future.delayed(const Duration(milliseconds: 1500));

      // --- BLOQUE LEGAL ---
      bool allowed = await _isTripAllowed(startPoint, endPoint);
      if (!allowed) {
        setState(() {
          _tripState = TripState.DASHBOARD;
          _isCalculatingRoute = false;
        });
        return;
      }

      // 2. NORMALIZACIÓN A 4 DECIMALES (Vital para el Caché del Backend)
      // Esto asegura que el "Hash" en el servidor coincida exactamente.
      LatLng finalStart = LatLng(
        double.parse(startPoint.latitude.toStringAsFixed(4)),
        double.parse(startPoint.longitude.toStringAsFixed(4)),
      );
      LatLng finalEnd = LatLng(
        double.parse(endPoint.latitude.toStringAsFixed(4)),
        double.parse(endPoint.longitude.toStringAsFixed(4)),
      );

      // 3. Cotizar con el servidor (Ya con el imán aplicado y decimales unificados)
      final result = await _routeService.getRoute(
        finalStart,
        finalEnd,
        idContrato: _currentUser.isCorporateMode
            ? (_currentUser.companyUuid != null
                  ? int.tryParse(_currentUser.companyUuid!)
                  : null)
            : null,
        tipoVehiculo: _getDbCategory(_selectedServiceCategory),
      );

      if (!mounted) return;

      setState(() {
        _routePoints = result.points;
        // Actualizamos pines a la ruta real del mapa
        _originCoordinates = result.points.first;
        _destinationCoordinates = result.points.last;

        _animatedRoutePoints = [];
        _tripPrice = result.price;
        _baseRoutePrice = result.price;
        _tripDesglose = result.desglose;
        _categoryPricesFromServer = result.preciosCategorias ?? {};
        _tripDistance =
            "${(result.distanceMeters / 1000).toStringAsFixed(1)} km";
        _tripDuration = "${(result.durationSeconds / 60).round()} min";
        _isCalculatingRoute = false;
      });

      // 4. Animación y cámara
      _fitCameraToRoute();

      // ESTA ES LA TRANSICIÓN QUE DEBES AJUSTAR
      if (mounted) {
        setState(() {
          _isCalculatingRoute = false; // Apagamos el flag de cálculo
          _tripState = TripState.ROUTE_PREVIEW; // Cambiamos al estado correcto
          AuthService.isTripActive = true;
        });

        // 2. Esperamos a que el mapa aparezca y luego dibujamos la ruta
        await Future.delayed(const Duration(milliseconds: 400));
        _animateRouteDrawing();
      }
    } catch (e) {
      debugPrint("🚨 Error en ruta: $e");
      if (mounted) {
        setState(() {
          _tripState = TripState.DASHBOARD;
          _isCalculatingRoute = false;
        });
        _showAppSnackBar(
          e.toString().replaceAll("Exception: ", ""),
          isError: true,
        );
        _moveToCurrentPosition();
      }
    }
  }

  void _handleSearchResult(dynamic result) {
    if (result == null) return;

    final bool isMapPick = result['isMapPick'] ?? false;
    final bool isManualOrigin = result['isManualOrigin'] ?? false;

    setState(() {
      _isOriginSnapped = false;
      _isOriginConfirmed = false;

      // --- CASO A: Selección Directa (Lista) ---
      if (!isMapPick &&
          !isManualOrigin &&
          result['destinationCoords'] != null) {
        _destinationName = result['destinationName'];
        _destinationCoordinates = result['destinationCoords'];
        _originName = "Mi ubicación";
        _originCoordinates = _currentPosition;
        _referenceOriginCoords = _currentPosition;

        setState(() {
          _mapPickingTarget = 'pickup';
          _isPickingLocation = true;
          _isPickingOrigin = true;
          _tripState = TripState.CONFIRMING_PICKUP;
        });
        _startPickupConfirmation(strict: true);
        return;
      }

      // --- CASO B: Fijar en Mapa (Sin restricción) ---
      if (isMapPick) {
        // Obtenemos el tipo desde el resultado del buscador
        final String? pickType = result['mapPickType'];

        _destinationName = result['destinationName'];
        _destinationCoordinates = result['destinationCoords'];
        final String? addressFromSearch = result['destinationName'];

        _isPickingLocation = true;

        // AQUÍ ESTÁ EL CAMBIO:
        // Si el usuario eligió "Fijar punto de partida" (pickup_pin),
        // el target debe ser 'reference' para que el modal diga "Establecer Inicio"
        if (pickType == 'pickup_pin') {
          _mapPickingTarget = 'reference';
          _referenceOriginCoords = LatLng(result['lat'], result['lng']);
        } else {
          _mapPickingTarget = 'destination';
        }

        // Lanzamos sin restricción (strict: false) para que no pida 200m
        _startPickupConfirmation(
          strict: false,
          initialAddress: addressFromSearch,
        );
        return;
      }

      // --- CASO C: Buscador completo (Con restricción obligatoria) ---
      if (isManualOrigin) {
        _originName = result['originName'];
        _originCoordinates = result['originCoords'];
        _referenceOriginCoords = _originCoordinates; // Punto para los 200m
        _destinationName = result['destinationName'];
        _destinationCoordinates = result['destinationCoords'];

        _isPickingLocation = true;
        _mapPickingTarget = 'pickup';

        // strict: true OBLIGA a confirmar en el mapa con los 200m
        _startPickupConfirmation(strict: true);
        return;
      }
    });
  }

  // Método auxiliar de guardado real
  // Busca y reemplaza el método _saveFavoriteToDB
  Future<void> _saveFavoriteToDB(
    String type,
    String addr,
    double lat,
    double lng,
  ) async {
    setState(() => _isLoadingAddress = true);

    bool success = await AuthService.updateUserAddress(
      type: type,
      address: addr,
      lat: lat,
      lng: lng,
    );

    if (success && mounted) {
      setState(() {
        _isLoadingAddress = false;
        // ACTUALIZACIÓN LOCAL CLAVE:
        // Actualizamos el objeto en memoria para que la UI reaccione inmediatamente
        if (type == 'home') {
          AuthService.currentUser!.homeAddress = addr;
          AuthService.currentUser!.homeLat = lat;
          AuthService.currentUser!.homeLng = lng;
        } else {
          AuthService.currentUser!.workAddress = addr;
          AuthService.currentUser!.workLat = lat;
          AuthService.currentUser!.workLng = lng;
        }

        _isPickingLocation = false;
        _addressTypeToSave = null;
      });

      _showAppSnackBar("¡${type == 'home' ? 'Casa' : 'Oficina'} guardada!");
      _loadRecentPlaces(); // Refresca la lista de recientes en el Dashboard
    } else {
      if (mounted) setState(() => _isLoadingAddress = false);
      _showAppSnackBar("Error al guardar la ubicación", isError: true);
    }
  }

  void _fitCameraToRoute({double? extent}) {
    if (!_isMapReady || !mounted) return;

    // CASO A: DASHBOARD (Sin ruta activa)
    // Siempre hace zoom a tu ubicación actual
    if (_tripState == TripState.DASHBOARD) {
      if (_currentPosition != null) {
        _animatedMapMove(_currentPosition!, 15.5);
      }
      return;
    }

    // CASO B: VIAJE ACTIVO (Calculando o Preview)
    if (_routePoints.isNotEmpty) {
      try {
        double currentExtent = extent ?? _sheetExtentNotifier.value;
        final bounds = LatLngBounds.fromPoints(_routePoints);

        // Calculamos cuánto espacio ocupa el modal en píxeles
        double screenHeight = MediaQuery.of(context).size.height;
        double modalPixels = screenHeight * currentExtent;

        // Ajustamos la cámara con un padding inferior dinámico
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: EdgeInsets.only(
              top: 100,
              bottom:
                  modalPixels + 60, // Deja la ruta siempre por encima del modal
              left: 70,
              right: 70,
            ),
          ),
        );
      } catch (e) {
        debugPrint("Error en auto-zoom: $e");
      }
    }
  }

  void _showQuickAddressOptions(
    String label,
    String type,
    String address,
    double lat,
    double lng,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent, // Transparente para manejar el diseño interno
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(25, 12, 25, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BARRA SUPERIOR DE ARRASTRE
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 25),

            // ICONO SEGÚN TIPO
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                type == 'home' ? Icons.home_rounded : Icons.work_rounded,
                color: AppColors.primaryGreen,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),

            // TÍTULO PREMIUM
            Text(
              "Tu $label",
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.darkBlue,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),

            // DIRECCIÓN CON ESTILO LIMPIO
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                address,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: AppColors.darkBlue,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 35),

            // BOTÓN PRINCIPAL: VAMOS PARA ALLÁ
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 5,
                  shadowColor: AppColors.darkBlue.withValues(alpha: 0.3),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleSearchResult({
                    'destinationName': label,
                    'destinationCoords': LatLng(lat, lng),
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.navigation_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      "VAMOS PARA ALLÁ",
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // BOTÓN SECUNDARIO: CAMBIAR DIRECCIÓN
            SizedBox(
              width: double.infinity,
              height: 60,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.darkBlue, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openSearchForConfig(type);
                },
                child: Text(
                  "CAMBIAR DIRECCIÓN",
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkBlue,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSearchForConfig(String type) {
    setState(() {
      _addressTypeToSave = type; // 'home' o 'work'
      _isPickingLocation = true; // Activa la interfaz de selección
      _isPickingOrigin = false; // Aseguramos que no es un viaje
      _favSearchResults = []; // Limpiamos búsquedas previas
      _favSearchController.clear();

      // Iniciamos el mapa en tu posición actual para que sea más fácil elegir
      if (_currentPosition != null) {
        _animatedMapMove(_currentPosition!, 17.0);
      }
    });
  }

  Widget _buildMapPickingSearchOverlay() {
    // ✅ MODIFICACIÓN: No mostrar si no estamos en picking,
    // O si estamos específicamente ajustando el punto de recogida ('pickup')
    if (!_isPickingLocation || _mapPickingTarget == 'pickup') {
      return const SizedBox.shrink();
    }

    if (_addressTypeToSave == null && _mapPickingTarget == null) {
      return const SizedBox.shrink();
    }

    String hintText = "";
    // Lógica para Favoritos
    if (_addressTypeToSave != null) {
      hintText =
          "¿Cuál es la dirección de tu ${_addressTypeToSave == 'home' ? 'Casa' : 'Oficina'}?";
    }
    // Lógica para puntos de viaje
    else {
      if (_mapPickingTarget == 'pickup') {
        hintText = "Ajustar punto de encuentro...";
      }
      if (_mapPickingTarget == 'reference') {
        hintText = "Buscar nueva dirección de partida...";
      }
      if (_mapPickingTarget == 'destination') {
        hintText = "Buscar nuevo destino...";
      }
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 40,
      left: 20,
      right: 20,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              controller: _favSearchController,
              onChanged: _onFavSearchChanged,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: Icon(
                  Icons.search,
                  color: (_mapPickingTarget == 'pickup')
                      ? AppColors
                            .primaryGreen // Verde para ajuste fino
                      : AppColors.darkBlue, // Azul para búsqueda libre
                ),
                suffixIcon: _isSearchingFav
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : (_favSearchController
                              .text
                              .isNotEmpty // Solo si hay texto mostramos la X
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _favSearchController.clear();
                                setState(() {
                                  _favSearchResults = [];
                                  _isSearchingFav = false;
                                });
                              },
                            )
                          : null),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          if (_favSearchResults.isNotEmpty) _buildMapSearchResultsList(),
        ],
      ),
    );
  }

  // Lista de resultados flotante (reutilizando tu lógica de favoritos)
  Widget _buildMapSearchResultsList() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _favSearchResults.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 50),
        itemBuilder: (ctx, i) {
          final place = _favSearchResults[i];
          return ListTile(
            leading: const Icon(
              Icons.location_on_outlined,
              color: Colors.grey,
              size: 20,
            ),
            title: Text(
              place['name'] ?? "",
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () =>
                _onFavResultSelected(place), // Esto ya mueve la cámara al lugar
          );
        },
      ),
    );
  }

  // CAMBIA LA FIRMA Y LA LÓGICA DE INICIO
  void _startPickupConfirmation({
    bool strict = false,
    String? initialAddress,
    LatLng? initialPosition,
  }) {
    _mapPickingTarget ??= 'pickup';
    _isStrictPickupMode = strict;

    // Usa la posición inicial si se provee, sino usa la lógica anterior
    LatLng targetPoint =
        initialPosition ??
        _referenceOriginCoords ??
        _currentPosition ??
        _defaultLocation;

    setState(() {
      _tripState = TripState.CONFIRMING_PICKUP;
      _isPickingLocation = true;
      // IMPORTANTE: No reseteamos _isOriginConfirmed a false aquí,
      // solo si realmente estamos iniciando un proceso nuevo.
      _mapCenter = targetPoint;
      _pickingAddress = initialAddress ?? "Selecciona ubicación en el mapa";
      _lastGeocodedPosition = targetPoint;
    });

    _animatedMapMove(targetPoint, 18.5);

    if (initialAddress == null) {
      _searchService
          .getReverseGeocode(targetPoint.latitude, targetPoint.longitude)
          .then((data) {
            if (data != null && mounted) {
              setState(
                () => _pickingAddress = data['name'] ?? "Ubicación en mapa",
              );
            }
          });
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
          // Busca esta parte y reemplázala:
          // 🔥 EVENTO: El motor de búsqueda no encontró a nadie
          else if (event == 'ViajeCancelado') {
            if (mounted) {
              // Igual que arriba: Primero resetear, luego avisar.
              _resetApp();
              _showNoDriversDialog(
                data['mensaje'] ?? "No se encontraron conductores cerca.",
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
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _destinationName ?? "Destino seleccionado",
                    style: GoogleFonts.montserrat(
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
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  "\$ ${_formatCurrency(_tripPrice)}",
                  style: GoogleFonts.montserrat(
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
                style: GoogleFonts.montserrat(
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
      final result = await _routeService
          .getRoute(
            driverPos, // <--- CAMBIADO (Origen: El carro)
            _currentPosition!, // <--- CAMBIADO (Destino: Tú)
            idContrato: _currentUser.isCorporateMode
                ? int.tryParse(_currentUser.companyUuid ?? '1')
                : null,
            tipoVehiculo: _getDbCategory(_selectedServiceCategory),
          )
          .timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _routePoints = result.points;
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

  Widget _buildPremiumButton({
    required String text,
    required VoidCallback onPressed,
    bool isPrimary = true,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppColors.darkBlue : Colors.white,
          foregroundColor: isPrimary ? Colors.white : AppColors.darkBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: isPrimary
                ? BorderSide.none
                : const BorderSide(color: AppColors.darkBlue, width: 2),
          ),
          elevation: isPrimary ? 2 : 0,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              )
            : Text(
                text,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  // --- SUSTITUIR EL MÉTODO _buildPaymentSelector COMPLETO ---
  Widget _buildPaymentSelector(StateSetter setModalState) {
    // Filtramos los métodos: Si no es modo corporativo, quitamos el corporativo
    final List<PaymentMethod> metodosDisponibles = _userMethods.where((m) {
      if (_currentUser.isCorporateMode) return true; // Si es Corp, ve todos
      return m.type !=
          PaymentMethodType
              .corporateVoucher; // Si es Personal, oculta corporativo
    }).toList();

    if (metodosDisponibles.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: metodosDisponibles.any((m) => m.id == _selectedMethod?.id)
              ? _selectedMethod?.id
              : metodosDisponibles.first.id,
          items: metodosDisponibles
              .map(
                (m) => DropdownMenuItem<String>(
                  value: m.id,
                  child: Row(
                    children: [
                      Icon(
                        _getPaymentIcon(m.type),
                        size: 20,
                        color: AppColors.darkBlue,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        m.name,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (newId) {
            final methodObj = metodosDisponibles.firstWhere(
              (m) => m.id == newId,
            );
            setModalState(() => _selectedMethod = methodObj);
            setState(() {
              _selectedMethod = methodObj;
              _selectedPaymentMethod = methodObj.id;
            });
          },
        ),
      ),
    );
  }

  // GESTOR DEL DRAGGABLE SHEET
  Widget _buildDraggablePanel() {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        // 1. Actualizamos el valor del extent (altura del modal)
        _sheetExtentNotifier.value = notification.extent;

        // 2. 🔥 AUTO-ZOOM DINÁMICO:
        // Cada vez que el dedo mueve el modal, le pedimos al mapa que se re-ajuste
        _fitCameraToRoute(extent: notification.extent);

        return true;
      },
      child: DraggableScrollableSheet(
        key: ValueKey(_tripState),
        initialChildSize: _getInitialSheetSize(),
        minChildSize: 0.15,
        maxChildSize: _getMaxSheetSize(),
        snap: true,
        snapSizes: [
          if (_getInitialSheetSize() != _getMaxSheetSize())
            _getInitialSheetSize(),
          _getMaxSheetSize(),
        ]..sort(),
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
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
                  ValueListenableBuilder<double>(
                    valueListenable: _sheetExtentNotifier,
                    builder: (context, extent, child) {
                      return _buildDynamicSheetContent(extent);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
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

class _PulseLoadingIcon extends StatefulWidget {
  final Color color;
  const _PulseLoadingIcon({required this.color});

  @override
  State<_PulseLoadingIcon> createState() => _PulseLoadingIconState();
}

class _PulseLoadingIconState extends State<_PulseLoadingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Círculos de pulso con desvanecimiento
            ...List.generate(3, (index) {
              final progress = (_controller.value + (index * 0.33)) % 1.0;
              return Container(
                width: 80 + (progress * 100),
                height: 80 + (progress * 100),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(
                      alpha: 0.3 * (1.0 - progress),
                    ),
                    width: 2,
                  ),
                ),
              );
            }),
            // Ícono central
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 35,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedChecklist extends StatefulWidget {
  final Color color;
  final bool isCorp;
  const _AnimatedChecklist({required this.color, required this.isCorp});

  @override
  State<_AnimatedChecklist> createState() => _AnimatedChecklistState();
}

class _AnimatedChecklistState extends State<_AnimatedChecklist> {
  int _currentStep = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Simulamos el progreso de los checks cada 800ms
    _timer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted && _currentStep < 2) {
        setState(() => _currentStep++);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- REEMPLAZAMOS EL PULSE POR UN ICONO ESTÁTICO PREMIUM ---
          const SizedBox(height: 30),
          Text(
            "PREPARANDO TU VIAJE",
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.darkBlue,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 35),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              children: [
                _buildStep("Optimizando trayecto vial", _currentStep >= 0),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, indent: 30),
                ),
                _buildStep("Verificando peajes y tarifas", _currentStep >= 1),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, indent: 30),
                ),
                _buildStep(
                  widget.isCorp
                      ? "Validando contrato empresarial"
                      : "Buscando conductores VAMOS",
                  _currentStep >= 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              backgroundColor: widget.color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(widget.color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String title, bool isDone) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: isDone ? 1.0 : 0.4,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            child: Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isDone ? widget.color : Colors.grey.shade300,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
              color: isDone ? AppColors.darkBlue : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

// Esta clase va al final de todo el archivo lib/features/home/screens/home_screen.dart
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.darkBlue
      ..style = PaintingStyle.fill;

    // Usamos el dibujo manual para evitar conflictos con clases "Path" de mapas
    final path = ui.Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
