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

  const SearchDestinationScreen({
    super.key,
    this.currentPosition,
    this.initialOriginName,
    this.initialOriginCoords,
  });

  @override
  State<SearchDestinationScreen> createState() =>
      _SearchDestinationScreenState();
}

class _SearchDestinationScreenState extends State<SearchDestinationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _originController = TextEditingController();

  bool _isEditingOrigin = false;
  LatLng? _selectedOriginCoords;
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

  @override
  void initState() {
    super.initState();
    _originController.text = widget.initialOriginName ?? "Ubicación actual";
    _selectedOriginCoords = widget.initialOriginCoords;
    _loadRecents();

    _originFocusNode.addListener(() {
      if (_originFocusNode.hasFocus) {
        setState(() {
          _isEditingOrigin = true;
          _searchResults = [];
        });
        if (_originController.text == "Ubicación actual") {
          _originController.clear();
        }
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

  Future<void> _saveQuickAddress(
    String type,
    String name,
    double lat,
    double lng,
  ) async {
    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus(); // Cerramos el teclado

    bool success = await AuthService.updateUserAddress(
      type: type,
      address: name,
      lat: lat,
      lng: lng,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        // Feedback visual
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "¡${type == 'home' ? 'Casa' : 'Oficina'} guardada exitosamente!",
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        // Forzamos el redibujado para que el botón pase de "Configurar" a "Casa/Oficina"
        setState(() {});
      }
    }
  }

  Future<void> _loadRecents() async {
    final res = await _searchService.getRecentPlaces();
    if (mounted) setState(() => _recentPlaces = res);
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
    // 1. Obtener detalles si vienen de Google o no tienen coordenadas aún
    if (place['source'] == 'google' ||
        place['place_id'] != null ||
        (place['lat'] == null)) {
      setState(() => _isLoading = true);

      final details = await _searchService.getPlaceCoords(
        place['place_id'] ?? place['mapbox_id'],
        _sessionToken,
      );

      if (mounted) setState(() => _isLoading = false);

      if (details != null) {
        // Actualizamos el objeto 'place' con la data del servidor
        place['lat'] = details['lat'];
        place['lng'] = details['lng'];
        place['snapped_lat'] = details['snapped_lat'];
        place['snapped_lng'] = details['snapped_lng'];
      }
    }

    // 2. Extraer coordenadas finales (Prioridad absoluta al Snapping/Imán de la calle)
    // Usamos .toDouble() para evitar errores de tipo entre int/double en Dart
    final double latCalle = (place['snapped_lat'] ?? place['lat'] ?? 0.0)
        .toDouble();
    final double lngCalle = (place['snapped_lng'] ?? place['lng'] ?? 0.0)
        .toDouble();

    // Coordenada visual (donde está el edificio/sitio originalmente)
    final double latReal = (place['lat'] ?? 0.0).toDouble();
    final double lngReal = (place['lng'] ?? 0.0).toDouble();

    // --- LÓGICA A: GUARDAR DIRECCIÓN RÁPIDA (Favoritos) ---
    if (_settingAddressType != null) {
      // Guardamos la dirección en el backend usando el punto de la calle para que el ruteo sea perfecto
      await _saveQuickAddress(
        _settingAddressType!,
        place['name'],
        latCalle,
        lngCalle,
      );

      setState(() {
        _searchController.clear();
        _settingAddressType = null;
      });
      return;
    }

    // --- LÓGICA B: EDITANDO PUNTO DE PARTIDA (ORIGEN) ---
    if (_isEditingOrigin) {
      setState(() {
        _originController.text = place['name'];
        _selectedOriginCoords = LatLng(latCalle, lngCalle);
        _searchResults = [];
        _isEditingOrigin = false;
      });
      _focusNode.requestFocus(); // Salto automático al destino
    }
    // --- LÓGICA C: SELECCIONANDO DESTINO ---
    else {
      final LatLng? finalOriginCoords =
          _selectedOriginCoords ?? widget.currentPosition;
      String finalOriginName = _originController.text.trim();

      if (finalOriginName.isEmpty || finalOriginName == "Ubicación actual") {
        finalOriginName = "Mi ubicación";
      }

      Navigator.pop(context, {
        'originName': finalOriginName,
        'originCoords': finalOriginCoords,
        'destinationName': place['name'],
        'destinationCoords': LatLng(
          latCalle,
          lngCalle,
        ), // La app usará el punto de la calle
        'visualDestinationCoords': LatLng(
          latReal,
          lngReal,
        ), // Para poner el pin visualmente
        'isManualOrigin': _selectedOriginCoords != null,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearching =
        _searchController.text.isNotEmpty ||
        (_originFocusNode.hasFocus && _originController.text.isNotEmpty);

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
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.black54,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _originController,
                        focusNode: _originFocusNode,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (val) {
                          if (val.isEmpty) {
                            setState(() => _selectedOriginCoords = null);
                          }
                          _onSearchChanged(val);
                        },
                        decoration: _getInputStyle(
                          label: "Punto de partida",
                          icon: Icons.my_location_rounded,
                          suffixIcon: _originController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _originController.clear();
                                      _selectedOriginCoords = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: _onSearchChanged,
                        decoration: _getInputStyle(
                          label: _settingAddressType != null
                              ? "Escribe la dirección de tu ${_settingAddressType == 'home' ? 'Casa' : 'Oficina'}"
                              : "A dónde quieres ir",
                          icon: Icons.search_rounded,
                          suffixIcon: _isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(15),
                                  child: SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged("");
                                  },
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 10),
                  children: [
                    if (!isSearching) ...[
                      _buildMapPickOption(),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 10,
                        ),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _buildQuickActionsGrid(),
                      if (_recentPlaces.isNotEmpty) ...[
                        _buildSectionHeader("RECIENTES"),
                        ..._recentPlaces.map((place) => _buildPlaceItem(place)),
                      ],
                    ],
                    if (isSearching) ...[
                      if (_isLoading)
                        ...List.generate(5, (index) => _buildLoadingShimmer())
                      else if (_searchResults.isEmpty)
                        _buildEmptyState()
                      else
                        ..._searchResults.map(
                          (place) => _buildPlaceItem(place),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
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

  Widget _buildMapPickOption() {
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
        "Fijar en el mapa",
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: AppColors.darkBlue,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: () {
        bool pickingOrigin = _originFocusNode.hasFocus || _isEditingOrigin;
        FocusScope.of(context).unfocus();
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            Navigator.pop(context, {
              'isMapPick': true,
              'isPickingOrigin': pickingOrigin,
              'settingAddressType':
                  _settingAddressType, // <--- Enviamos el tipo al HomeScreen
            });
          }
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
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: isSet ? AppColors.darkBlue : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSet ? Colors.transparent : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: isSet
                ? [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: AppColors.darkBlue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSet
                      // ignore: deprecated_member_use
                      ? AppColors.primaryGreen.withOpacity(0.15)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSet ? AppColors.primaryGreen : Colors.grey.shade400,
                  size: 28,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isSet ? label : "Configurar",
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isSet ? Colors.white : Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                isSet ? "Guardado" : label, // Ej: "Configurar Casa"
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSet ? AppColors.primaryGreen : Colors.grey.shade400,
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
      _showAddressOptions(
        label,
        addr,
        type == 'home'
            ? AuthService.currentUser!.homeLat!
            : AuthService.currentUser!.workLat!,
        type == 'home'
            ? AuthService.currentUser!.homeLng!
            : AuthService.currentUser!.workLng!,
        type,
      );
    } else {
      // SI NO EXISTE: Activamos el modo de configuración
      setState(() {
        _settingAddressType = type;
        _isEditingOrigin =
            false; // Aseguramos que estamos buscando destino/favorito
      });
      _focusNode.requestFocus(); // Ponemos el foco en el buscador de arriba

      _showAppSnackBar("Busca la dirección de tu $label");
    }
  }

  void _showAppSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.darkBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showAddressOptions(
    String label,
    String address,
    double lat,
    double lng,
    String type,
  ) {
    final bool isHome = type == 'home';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Importante para ver el redondeo
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(25, 12, 25, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tirador superior (Handle)
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 30),

            // Icono Central Premium con degradado
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHome ? Icons.home_rounded : Icons.business_center_rounded,
                size: 45,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 20),

            // Títulos
            Text(
              isHome ? "Tu Casa" : "Tu Oficina",
              style: GoogleFonts.montserrat(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.darkBlue,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                address,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 35),

            // BOTÓN PRINCIPAL: VAMOS PARA ALLÁ (Estilo Neumórfico/Premium)
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _handleResultTap({
                  'name': label,
                  'address': address,
                  'lat': lat,
                  'lng': lng,
                });
              },
              child: Container(
                width: double.infinity,
                height: 65,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen,
                      const Color.fromARGB(255, 89, 158, 33),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 12),
                    Text(
                      "VAMOS PARA ALLÁ",
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // BOTÓN SECUNDARIO: CAMBIAR DIRECCIÓN
            SizedBox(
              width: double.infinity,
              height: 60,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Lógica para enviar al Home a configurar
                  Navigator.pop(context, {
                    'isMapPick': true,
                    'isPickingOrigin': false,
                    'settingAddressType': type,
                  });
                },
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: AppColors.darkBlue.withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_location_alt_outlined,
                      color: AppColors.darkBlue.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Cambiar dirección",
                      style: GoogleFonts.montserrat(
                        color: AppColors.darkBlue.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceItem(Map<String, dynamic> place) {
    bool isRecent = place['type'] == 'recent' || place['source'] == 'cache';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isRecent
              ? AppColors.primaryGreen.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isRecent ? Icons.history_rounded : Icons.location_on_rounded,
          color: isRecent ? AppColors.primaryGreen : Colors.grey.shade400,
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
        "${place['distance'] ?? ''} km • ${place['address'] ?? ''}",
        style: GoogleFonts.montserrat(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
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
