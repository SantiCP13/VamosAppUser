// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
/*import '../services/mapbox_search_service.dart';*/
import '../services/search_service.dart';
import '../../auth/services/auth_service.dart';
import 'package:uuid/uuid.dart';

class SearchDestinationScreen extends StatefulWidget {
  final String? initialOriginName; // NUEVO
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
  // _searchController se usará para el DESTINO
  bool _isEditingOrigin =
      false; // Para saber qué campo llenar al tocar un resultado
  LatLng? _selectedOriginCoords;
  LatLng? _selectedDestinationCoords;
  final FocusNode _focusNode = FocusNode();
  // Debajo de las otras declaraciones de controladores (aprox. línea 30)
  final FocusNode _originFocusNode = FocusNode();
  final SearchService _searchService = SearchService();
  final _uuid = const Uuid();
  String? _sessionToken;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recentPlaces = [];
  bool _isLoading = false;
  Timer? _debounce;
  String? _settingMode;
  @override
  void initState() {
    super.initState();
    _originController.text = widget.initialOriginName ?? "Ubicación actual";
    _selectedOriginCoords = widget.initialOriginCoords;
    _loadRecents();

    // Listener para el campo de ORIGEN
    _originFocusNode.addListener(() {
      if (_originFocusNode.hasFocus) {
        setState(() {
          _isEditingOrigin = true;
          _searchResults = []; // Limpiar resultados para nueva búsqueda
        });
        if (_originController.text == "Ubicación actual") {
          _originController.clear();
        }
      }
    });

    // Listener para el campo de DESTINO
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _isEditingOrigin = false;
          _searchResults = []; // Limpiar resultados para nueva búsqueda
        });
      }
    });
  }

  Future<void> _loadRecents() async {
    final res = await _searchService.getRecentPlaces();
    if (mounted) setState(() => _recentPlaces = res);
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Ya lo tienes, está bien.
    _searchController.dispose();
    _originController.dispose(); // <--- AGREGA ESTO
    _focusNode.dispose();
    _originFocusNode.dispose(); // <--- AGREGA ESTA LÍNEA TAMBIÉN
    super.dispose();
  }

  // --- ESTO ES LO QUE FALTABA (Estilo del Input) ---
  InputDecoration _getInputStyle({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: "Ej. Centro Comercial Fontanar",
      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
      labelStyle: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.grey.shade600,
      ),
      prefixIcon: Icon(icon, size: 20, color: AppColors.primaryGreen),
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
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
    );
  }

  // lib/features/home/screens/search_destination_screen.dart

  void _onSearchChanged(String query) {
    // Generamos un token de sesión si no hay uno activo
    _sessionToken ??= _uuid.v4();

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          _searchResults = [];
          _isLoading = false;
          _sessionToken = null; // Limpiamos el token si borra todo
        });
        return;
      }

      setState(() => _isLoading = true);

      try {
        final results = await _searchService.searchPlaces(
          query,
          lat: widget.currentPosition?.latitude,
          lng: widget.currentPosition?.longitude,
          sessionToken: _sessionToken, // <--- PASAMOS EL TOKEN
        );

        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      } catch (e) {
        debugPrint("Error en pantalla de búsqueda: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _handleResultTap(Map<String, dynamic> place) async {
    // 1. Obtención de coordenadas (Google Place ID)
    if (place.containsKey('place_id') && place['lat'] == null) {
      if (mounted) setState(() => _isLoading = true);

      final coords = await _searchService.getPlaceCoords(
        place['place_id'],
        _sessionToken,
      );

      // 🔥 ESTA ES LA LÍNEA QUE FALTA PARA EVITAR EL CRASH
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _sessionToken = null;
      });

      if (coords != null) {
        place['lat'] = coords['lat'];
        place['lng'] = coords['lng'];
      } else {
        return;
      }
    }

    // 2. Lógica de guardado rápido (Casa/Oficina)
    if (_settingMode != null) {
      final updatedUser = await _searchService.saveQuickAddress(
        type: _settingMode!,
        address: place['name'],
        lat: place['lat'],
        lng: place['lng'],
      );

      // 🔥 TAMBIÉN DEBES PONERLO AQUÍ
      if (!mounted) return;

      if (updatedUser != null) {
        AuthService.updateLocalUser(updatedUser);
        setState(() => _settingMode = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("¡Dirección guardada!")));
      }
      return;
    }

    // 3. SELECCIÓN DE DIRECCIÓN
    if (_isEditingOrigin) {
      setState(() {
        _originController.text = place['name'];
        _selectedOriginCoords = LatLng(place['lat'], place['lng']);
        _searchResults = [];
        _isEditingOrigin = false;
      });
      _focusNode.requestFocus(); // Salta al campo de destino
      // No hacemos pop aquí porque falta el destino
    } else {
      // Estamos seleccionando el DESTINO
      setState(() {
        _searchController.text = place['name'];
        _selectedDestinationCoords = LatLng(place['lat'], place['lng']);
      });

      // 4. CIERRE Y RETORNO: Si seleccionamos destino, cerramos enviando todo
      final finalOriginCoords = _selectedOriginCoords ?? widget.currentPosition;
      final finalOriginName = _originController.text.isEmpty
          ? "Mi ubicación"
          : _originController.text;

      Navigator.pop(context, {
        'originName': finalOriginName,
        'originCoords': finalOriginCoords,
        'destinationName': _searchController.text,
        'destinationCoords': _selectedDestinationCoords, // LLAVE CORREGIDA
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearching =
        _searchController.text.isNotEmpty ||
        (_originFocusNode.hasFocus && _originController.text.isNotEmpty);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // <--- ESTO QUITA EL FOCO
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. CABECERA Y BUSCADOR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "¿A dónde vamos?",
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // CAMPO ORIGEN
                    // CAMPO ORIGEN
                    TextField(
                      controller: _originController,
                      focusNode: _originFocusNode,
                      onChanged: (val) {
                        // No hace falta setear _isEditingOrigin aquí, el FocusNode ya lo hizo
                        _onSearchChanged(val);
                      },
                      decoration: _getInputStyle(
                        label: "Punto de origen",
                        icon: Icons.my_location,
                        suffixIcon: _originController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _originController.clear();
                                  _selectedOriginCoords = null;
                                  _onSearchChanged("");
                                  FocusScope.of(context).unfocus();
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // CAMPO DESTINO
                    TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: (val) {
                        _onSearchChanged(val);
                      },
                      decoration: _getInputStyle(
                        label: "Dirección de destino",
                        icon: Icons.search,
                        suffixIcon: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _selectedDestinationCoords = null;
                                  _onSearchChanged("");
                                  FocusScope.of(
                                    context,
                                  ).unfocus(); // <--- CIERRA TECLADO AL BORRAR
                                },
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 2. CUERPO DINÁMICO
              Expanded(
                child: ListView(
                  children: [
                    // SI NO ESTÁ BUSCANDO: Mostrar accesos rápidos y favoritos
                    if (!isSearching) ...[
                      // --- BUSCA EL ListTile "Fijar en el mapa" Y REEMPLÁZALO ---
                      ListTile(
                        leading: const Icon(
                          Icons.location_on,
                          color: AppColors.primaryGreen,
                        ),
                        title: Text(
                          "Fijar en el mapa",
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        onTap: () {
                          // CAPTURAMOS el estado del foco antes de que desaparezca
                          // Si el cursor estaba arriba (origen), pickingOrigin es true.
                          bool pickingOrigin =
                              _originFocusNode.hasFocus || _isEditingOrigin;

                          FocusScope.of(context).unfocus(); // Quitamos teclado

                          // Un pequeño delay para estabilidad visual
                          Future.delayed(const Duration(milliseconds: 150), () {
                            if (mounted) {
                              Navigator.pop(context, {
                                'isMapPick': true,
                                'isPickingOrigin': pickingOrigin,
                                'settingMode': _settingMode,
                              });
                            }
                          });
                        },
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            _buildQuickAction(
                              Icons.home_outlined,
                              "Casa",
                              "home",
                            ),
                            _buildQuickAction(
                              Icons.work_outline,
                              "Oficina",
                              "work",
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // TÍTULO DE SECCIÓN RECIENTES
                      if (_recentPlaces.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 24,
                            top: 20,
                            bottom: 10,
                          ),
                          child: Text(
                            "DESTINOS RECIENTES",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400],
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),

                      // LISTA DE RECIENTES
                      ..._recentPlaces
                          .map((place) => _buildPlaceItem(place))
                          // ignore: unnecessary_to_list_in_spreads
                          .toList(),
                    ],

                    if (isSearching) ...[
                      if (_isLoading)
                        // NUEVO: Efecto de carga simple (Skeleton)
                        ...List.generate(5, (index) => _buildLoadingShimmer())
                      else if (_searchResults.isEmpty)
                        // NUEVO: Estado vacío
                        Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.location_off_outlined,
                                size: 50,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "No encontramos resultados para tu búsqueda.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // TUS RESULTADOS
                        ..._searchResults
                            .map((place) => _buildPlaceItem(place))
                            // ignore: unnecessary_to_list_in_spreads
                            .toList(),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.grey[100], radius: 20),
      title: Container(height: 12, width: 100, color: Colors.grey[100]),
      subtitle: Container(height: 10, width: 200, color: Colors.grey[50]!),
    );
  }

  // NUEVO MÉTODO PARA RENDERIZAR CADA ITEM DE LA LISTA (Para no repetir código)
  Widget _buildPlaceItem(Map<String, dynamic> place) {
    IconData leadingIcon = Icons.location_on_outlined;
    if (place['type'] == 'recent' || place['source'] == 'cache')
      // ignore: curly_braces_in_flow_control_structures
      leadingIcon = Icons.history;
    if (place['type'] == 'fav') leadingIcon = Icons.star_border;

    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 4.0,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(leadingIcon, color: Colors.grey[600], size: 20),
          ),
          title: Text(
            place['name'] ?? "Ubicación",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            place['address'] ?? "",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // MODIFICADO: Lógica de la estrella
          trailing: IconButton(
            icon: Icon(
              place['type'] == 'fav' ? Icons.star : Icons.star_border,
              color: place['type'] == 'fav' ? Colors.amber : Colors.grey[300],
              size: 22,
            ),
            onPressed: () {
              // Lógica simple para feedback visual inmediato
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Se ha guardado ${place['name']} en favoritos"),
                ),
              );
            },
          ),
          onTap: () => _handleResultTap(place),
        ),
        const Divider(indent: 75, endIndent: 24, height: 1),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, String type) {
    final user = AuthService.currentUser!;
    final String? savedAddr = type == 'home'
        ? user.homeAddress
        : user.workAddress;
    final bool isSettingThis = _settingMode == type;

    // LÓGICA DE COLORES
    Color mainColor = Colors.grey;
    if (isSettingThis)
      // ignore: curly_braces_in_flow_control_structures
      mainColor = Colors.orange;
    else if (savedAddr != null) {
      mainColor = user.isCorporateMode
          ? Colors.blue[800]!
          : AppColors.primaryGreen;
    }

    return Expanded(
      child: InkWell(
        onTap: () {
          if (savedAddr != null && !isSettingThis) {
            // Si ya existe, mostramos opciones (Viajar o Cambiar)
            _showAddressOptions(
              label,
              type,
              savedAddr,
              type == 'home' ? user.homeLat! : user.workLat!,
              type == 'home' ? user.homeLng! : user.workLng!,
            );
          } else {
            // Si está vacío o estamos en modo cambio
            setState(() {
              _settingMode = type;
              _searchController.text = "";
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Busca la dirección de tu $label")),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: mainColor),
              const SizedBox(height: 4),
              Text(
                savedAddr == null ? "Configurar $label" : label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: mainColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddressOptions(
    String label,
    String type,
    String address,
    double lat,
    double lng,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              "Opciones de $label",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.directions_car,
              color: AppColors.primaryGreen,
            ),
            title: Text("Viajar a $label"),
            subtitle: Text(
              address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.pop(ctx); // Cierra el modal de opciones
              _handleResultTap({
                'name': label,
                'address': address,
                'lat': lat,
                'lng': lng,
              });
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.edit_location_alt_outlined,
              color: Colors.orange,
            ),
            title: Text("Cambiar dirección de $label"),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _settingMode = type;
                _searchController.text = "";
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Busca la nueva dirección para $label")),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
