// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../services/search_service.dart';
import '../../auth/services/auth_service.dart';
import 'package:uuid/uuid.dart';

class SearchDestinationScreen extends StatefulWidget {
  final String? initialOriginName;
  final LatLng? initialOriginCoords;
  final LatLng? currentPosition;
  final String? configModeType; // <--- AGREGAR ESTO (home o work)

  const SearchDestinationScreen({
    super.key,
    this.currentPosition,
    this.initialOriginName,
    this.initialOriginCoords,
    this.configModeType,
  });

  @override
  State<SearchDestinationScreen> createState() =>
      _SearchDestinationScreenState();
}

class _SearchDestinationScreenState extends State<SearchDestinationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _originController = TextEditingController();

  bool _isEditingOrigin = false;
  String? _settingAddressType; // 'home' o 'work' o null

  final FocusNode _focusNode = FocusNode();
  final FocusNode _originFocusNode = FocusNode();

  final SearchService _searchService = SearchService();
  final _uuid = const Uuid();
  String? _sessionToken;

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recentPlaces = [];
  bool _isLoading = false;
  Timer? _debounce;
  Map<String, dynamic>? _selectedOrigin;
  Map<String, dynamic>? _selectedDestination;

  @override
  void initState() {
    super.initState();
    _settingAddressType = widget.configModeType;

    if (widget.initialOriginCoords != null) {
      _selectedOrigin = {
        'name': widget.initialOriginName,
        'lat': widget.initialOriginCoords!.latitude,
        'lng': widget.initialOriginCoords!.longitude,
      };
      _originController.text = widget.initialOriginName ?? "";
    } else {
      _selectedOrigin = null;
      _originController.text = "";
    }
    _loadRecents();

    _originFocusNode.addListener(() {
      if (_originFocusNode.hasFocus) {
        setState(() {
          _isEditingOrigin = true;
          _searchResults = [];
        });
      }
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _isEditingOrigin = false;
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _loadRecents() async {
    final res = await _searchService.getRecentPlaces();
    if (mounted) {
      setState(() {
        // Tomamos solo los primeros 5 para no saturar y que sean los más nuevos
        _recentPlaces = res.take(7).toList();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _originController.dispose();
    _focusNode.dispose();
    _originFocusNode.dispose();
    super.dispose();
  }

  InputDecoration _getInputStyle({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.montserrat(
        fontSize: 13,
        color: Colors.grey.shade500,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, size: 22, color: AppColors.primaryGreen),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade100, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
    );
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    _sessionToken ??= _uuid.v4();

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // Solo disparamos la carga si el componente sigue montado y hay texto
      if (!mounted || query.length < 3) return;

      setState(() => _isLoading = true);
      // ignore: avoid_print
      print(
        "📡 Buscando: $query cerca de: ${widget.currentPosition?.latitude}, ${widget.currentPosition?.longitude}",
      );

      final results = await _searchService.searchPlaces(
        query,
        lat: widget.currentPosition?.latitude ?? 0.0,
        lng: widget.currentPosition?.longitude ?? 0.0,
        sessionToken: _sessionToken,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _handleResultTap(Map<String, dynamic> place) async {
    // 1. Obtener coordenadas si no las tiene (tu lógica actual)
    if (place['lat'] == null) {
      setState(() => _isLoading = true);
      final details = await _searchService.getPlaceCoords(
        place['place_id'] ?? place['mapbox_id'],
        _sessionToken,
      );
      if (mounted) setState(() => _isLoading = false);
      if (details != null) {
        place['lat'] = details['lat'];
        place['lng'] = details['lng'];
      }
    }

    setState(() {
      if (_isEditingOrigin) {
        // Guardamos el origen
        _selectedOrigin = place;
        _originController.text = place['name'] ?? "";

        // ✅ Esto hará que el IF del build se cumpla y aparezca el segundo campo
        _isEditingOrigin = false;

        // Abrimos el teclado en el destino automáticamente tras un breve delay
        Future.delayed(const Duration(milliseconds: 150), () {
          _focusNode.requestFocus();
        });
      } else {
        // Guardamos el destino
        _selectedDestination = place;
        _searchController.text = place['name'] ?? "";
        // Si el origen está vacío, pasamos el foco al origen
        if (_originController.text.isEmpty) {
          _originFocusNode.requestFocus();
          _isEditingOrigin = true;
        }
      }
      _searchResults = []; // Limpiamos la lista
    });

    // 2. AUTO-GUARDADO DE RECIENTES (tu lógica actual)
    if (_settingAddressType == null) {
      _searchService.saveManualRecent(
        name: place['name'] ?? "Ubicación",
        address: place['address'] ?? "",
        lat: (place['lat'] as num).toDouble(),
        lng: (place['lng'] as num).toDouble(),
      );
    }

    // 3. VERIFICACIÓN FINAL: ¿Tenemos ambos?
    // Dentro de SearchDestinationScreen -> _handleResultTap
    if (_selectedOrigin != null && _selectedDestination != null) {
      if (!mounted) return;

      Navigator.pop(context, {
        'originName': _selectedOrigin!['name'],
        'originCoords': LatLng(
          _selectedOrigin!['lat'],
          _selectedOrigin!['lng'],
        ),
        'destinationName': _selectedDestination!['name'],
        'destinationCoords': LatLng(
          _selectedDestination!['lat'],
          _selectedDestination!['lng'],
        ),
        'isManualOrigin': true, // Caso C: Origen y Destino definidos
        'isMapPick': false, // No es fijar en mapa libre
        'settingAddressType': _settingAddressType,
      });
    }
  }

  Future<void> _deleteRecent(dynamic id) async {
    if (id == null) return;

    // 1. Llamada al service que creamos en el Paso 3
    final success = await _searchService.deleteRecentPlace(id);

    if (success && mounted) {
      // 2. Refrescamos la lista localmente
      _loadRecents();
      _showAppSnackBar("Lugar eliminado del historial");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.45),
            radius: 1.8,
            colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Alineación al inicio
            children: [
              // --- BOTÓN ATRÁS ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
              ),

              // --- TÍTULO E INFORMACIÓN RELEVANTE ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Configura tu viaje",
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Selecciona primero tu punto de partida para continuar.",
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // --- CONTENEDOR DE INPUTS ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // INPUT 1: SIEMPRE VISIBLE
                      TextField(
                        controller: _originController,
                        focusNode: _originFocusNode,
                        onChanged: (val) {
                          if (val.isEmpty) {
                            setState(() => _selectedOrigin = null);
                          }
                          _onSearchChanged(val);
                        },
                        decoration: _getInputStyle(
                          label: "Punto de partida",
                          icon: Icons.my_location_rounded,
                          suffixIcon: _originController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _originController.clear();
                                      _selectedOrigin = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),

                      // INPUT 2: DINÁMICO (Solo si hay origen)
                      if (_selectedOrigin != null) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          onChanged: _onSearchChanged,
                          decoration: _getInputStyle(
                            label: "¿A dónde quieres ir?",
                            icon: Icons.search_rounded,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // --- LISTA DE OPCIONES (Solo si hay un foco activo) ---
              Expanded(
                child: (_originFocusNode.hasFocus || _focusNode.hasFocus)
                    ? _buildDynamicOptionsList()
                    : Center(
                        child: Opacity(
                          opacity: 0.3,
                          child: Icon(
                            Icons.map_outlined,
                            size: 100,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicOptionsList() {
    // Si el usuario está escribiendo más de 3 letras, mostramos resultados de API
    if ((_originFocusNode.hasFocus && _originController.text.length >= 3) ||
        (_focusNode.hasFocus && _searchController.text.length >= 3)) {
      if (_isLoading) {
        return ListView(
          children: List.generate(5, (_) => _buildLoadingShimmer()),
        );
      }
      if (_searchResults.isEmpty) return _buildEmptyState();
      return ListView(
        children: _searchResults
            .map((place) => _buildPlaceItem(place))
            .toList(),
      );
    }

    // Si el campo está vacío pero tiene el foco, mostramos las opciones fijas
    return ListView(
      padding: const EdgeInsets.only(top: 10),
      children: [
        // 1. Ubicación Actual (SOLO en origen)
        if (_originFocusNode.hasFocus && widget.currentPosition != null)
          _buildCurrentLocationOption(),

        // 2. Casa y Oficina
        _buildQuickActionsGrid(),

        // 3. Recientes
        if (_recentPlaces.isNotEmpty) ...[
          _buildSectionHeader("RECIENTES"),
          ..._recentPlaces.map((place) => _buildPlaceItem(place)),
        ],

        const SizedBox(height: 10),
        const Divider(
          height: 1,
          color: Color(0xFFF1F5F9),
          indent: 25,
          endIndent: 25,
        ),

        // 4. Fijar en Mapa (Si es destino, requiere que el origen ya exista)
        if (_originFocusNode.hasFocus ||
            (_focusNode.hasFocus && _selectedOrigin != null))
          _buildMapPickOption(),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 8),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF64748B),
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildCurrentLocationOption() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.gps_fixed_rounded,
          color: Colors.blue,
          size: 20,
        ),
      ),
      title: Text(
        "Mi ubicación actual",
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.darkBlue,
        ),
      ),
      subtitle: Text(
        "Usar coordenadas de tu GPS",
        style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
      ),
      onTap: () {
        if (widget.currentPosition != null) {
          _handleResultTap({
            'name': "Ubicación actual",
            'address': "Cerca de tu posición",
            'lat': widget.currentPosition!.latitude,
            'lng': widget.currentPosition!.longitude,
          });
        }
      },
    );
  }

  Widget _buildMapPickOption() {
    final bool pickingOrigin = _originFocusNode.hasFocus || _isEditingOrigin;
    if (!pickingOrigin && _selectedOrigin == null) {
      return const SizedBox.shrink();
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 25),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.map_rounded,
          color: AppColors.primaryGreen,
          size: 22,
        ),
      ),
      title: Text(
        pickingOrigin
            ? "Fijar punto de partida en mapa"
            : "Fijar destino en el mapa",
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      onTap: () {
        Navigator.pop(context, {
          'isMapPick': true,
          // Aquí enviamos el tipo correcto para que el modal de HomeScreen sepa qué mostrar
          'mapPickType': pickingOrigin ? 'pickup_pin' : 'destination_pin',
          'isPickingOrigin': pickingOrigin,
          'lat': pickingOrigin
              ? (_selectedOrigin?['lat'] ?? widget.currentPosition?.latitude)
              : (_selectedDestination?['lat'] ??
                    widget.currentPosition?.latitude),
          'lng': pickingOrigin
              ? (_selectedOrigin?['lng'] ?? widget.currentPosition?.longitude)
              : (_selectedDestination?['lng'] ??
                    widget.currentPosition?.longitude),
        });
      },
    );
  }

  Widget _buildQuickActionsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _buildQuickBtn(Icons.home_rounded, "Casa", "home"),
          const SizedBox(width: 15),
          _buildQuickBtn(Icons.work_rounded, "Oficina", "work"),
        ],
      ),
    );
  }

  Widget _buildQuickBtn(IconData icon, String label, String type) {
    final user = AuthService.currentUser!;
    final String? addr = type == 'home' ? user.homeAddress : user.workAddress;
    bool isSet = addr != null && addr.isNotEmpty;

    return Expanded(
      child: InkWell(
        onTap: () => _handleQuickAction(label, type, addr),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 12,
          ), // Más compacto
          decoration: BoxDecoration(
            color: isSet
                ? AppColors.darkBlue
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSet ? Colors.transparent : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: isSet
                ? [
                    BoxShadow(
                      color: AppColors.darkBlue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            // Cambiamos a Row para que sea más bajo y compacto
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSet
                      ? AppColors.primaryGreen.withValues(alpha: 0.2)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSet ? AppColors.primaryGreen : Colors.grey.shade400,
                  size: 20, // Icono un poco más pequeño
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSet ? Colors.white : Colors.grey.shade600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      isSet
                          ? addr
                          : "Configurar", // Mostramos la dirección real
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: isSet
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.grey.shade400,
                      ),
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis, // Si es muy larga, pone "..."
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

  void _handleQuickAction(String label, String type, String? addr) {
    if (addr != null && addr.isNotEmpty) {
      final user = AuthService.currentUser!;
      // Si ya existe, le mandamos al Home la orden de viajar a esa coordenada
      _handleResultTap({
        'name': label, // "Casa" u "Oficina"
        'address': addr,
        'lat': type == 'home' ? user.homeLat : user.workLat,
        'lng': type == 'home' ? user.homeLng : user.workLng,
        'source': 'favorite_shortcut',
      });
    } else {
      // Si NO existe, activamos el modo "Configuración"
      setState(() {
        _settingAddressType = type; // 'home' o 'work'
        _searchController.clear();
      });
      _focusNode
          .requestFocus(); // Abrir teclado para que busque la dirección de su casa
      _showAppSnackBar("Escribe la dirección de tu $label");
    }
  }

  void _showAppSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        // Si es error se pone rojo, si no, se queda en azul oscuro
        backgroundColor: isError ? Colors.redAccent : AppColors.darkBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildPlaceItem(Map<String, dynamic> place) {
    bool isRecent = place['type'] == 'recent' || place['source'] == 'user_db';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isRecent
              ? AppColors.primaryGreen.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isRecent ? Icons.history_rounded : Icons.location_on_rounded,
          color: isRecent ? AppColors.primaryGreen : Colors.grey.shade500,
          size: 20,
        ),
      ),
      title: Text(
        place['name'] ?? "Ubicación",
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.darkBlue,
        ),
      ),
      subtitle: Text(
        "${place['distance'] != null ? '${place['distance']} km • ' : ''}${place['address'] ?? ''}",
        style: GoogleFonts.montserrat(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // --- NUEVO: BOTÓN DE BORRADO INDIVIDUAL ---
      trailing: isRecent
          ? IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.grey,
              ),
              onPressed: () => _deleteRecent(
                place['id'],
              ), // Usamos el ID que enviamos desde el backend
            )
          : null,
      onTap: () => _handleResultTap(place),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListTile(
      leading: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
      ),
      title: Container(
        width: 150,
        height: 12,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      subtitle: Container(
        width: 250,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.location_off_rounded,
            size: 60,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 15),
          Text(
            "No encontramos resultados.",
            style: GoogleFonts.montserrat(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
