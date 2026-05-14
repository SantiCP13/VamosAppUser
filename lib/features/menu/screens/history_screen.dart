// ignore_for_file: deprecated_member_use
// ignore: unnecessary_import
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../menu/services/menu_service.dart';
import '../../../core/models/trip_model.dart';
import 'package:intl/intl.dart'; // <--- Vital para el formato de hora local

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final MenuService _menuService = MenuService();
  Future<List<TripModel>> _historyFuture = Future.value([]);
  String _selectedFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      List<TripModel> data = await _menuService.getTripHistory();
      // ignore: avoid_print
      print("DEBUG: Viajes recibidos del servidor: ${data.length}");
      for (var v in data) {
        // ignore: avoid_print
        print(
          "DEBUG: Viaje ID ${v.id} - Estado: ${v.status} - Programado: ${v.scheduledAt}",
        );
      }
      setState(() {
        _historyFuture = Future.value(data);
      });
    } catch (e) {
      // ignore: avoid_print
      print("DEBUG ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // FONDO GRADIENTE (Consistencia con Perfil/Login)
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.5,
                colors: [Colors.white, Color(0xFFF1F5F9)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(context),
                _buildFilterBar(),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primaryGreen,
                    onRefresh: () async => _loadHistory(),
                    child: FutureBuilder<List<TripModel>>(
                      future: _historyFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryGreen,
                            ),
                          );
                        }

                        // 🔥 CAMBIO AQUÍ: Verifica si hay error o si no hay datos
                        if (snapshot.hasError || !snapshot.hasData) {
                          return _buildErrorState();
                        }

                        List<TripModel> allTrips = snapshot.data!;
                        // Ordenar por fecha más reciente
                        allTrips.sort((a, b) {
                          try {
                            DateTime dateA =
                                a.scheduledAt ??
                                DateTime.parse(a.dateRaw).toLocal();
                            DateTime dateB =
                                b.scheduledAt ??
                                DateTime.parse(b.dateRaw).toLocal();
                            return dateB.compareTo(dateA);
                          } catch (e) {
                            return 0; // Si falla el parseo, no los ordena y evita el crash
                          }
                        });

                        List<TripModel> filteredTrips = _applyFilter(allTrips);
                        if (filteredTrips.isEmpty) return _buildEmptyState();

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
                          itemCount: filteredTrips.length,
                          physics: const AlwaysScrollableScrollPhysics(),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 20),
                          itemBuilder: (context, index) =>
                              _buildTripCardPremium(filteredTrips[index]),
                        );
                      },
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

  Widget _buildCustomAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black54,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
          Text(
            "MIS VIAJES",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 2,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(width: 48), // Balanceador
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['Todos', 'Programados', 'Finalizados', 'Cancelados'];
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryGreen.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 5,
                        ),
                      ],
              ),
              child: Center(
                child: Text(
                  filter,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: isSelected ? Colors.white : Colors.blueGrey.shade400,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTripCardPremium(TripModel trip) {
    // 1. Lógica dinámica: Azul si es corporativo (id_contrato > 1), Verde si es personal
    final bool isCorporate =
        (int.tryParse(trip.id) != null &&
            trip.price > 0 &&
            trip.statusLabel.contains("CORP")) ||
        (trip.status.contains('CORP'));

    final Color brandColor = isCorporate
        ? AppColors.darkBlue
        : AppColors.primaryGreen;
    final Color statusColor = trip.isCancelled ? Colors.redAccent : brandColor;
    final IconData statusIcon = trip.isUpcoming
        ? Icons.event_available_rounded
        : Icons.check_circle_rounded;

    DateTime dateObj =
        trip.scheduledAt ?? DateTime.tryParse(trip.dateRaw) ?? DateTime.now();
    dateObj = dateObj.toLocal();
    final String localTimeStr = DateFormat(
      'EEE, d MMM • hh:mm a',
      'es',
    ).format(dateObj).toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // HEADER: Fecha y Estado
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      localTimeStr,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 10, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        trip.isUpcoming
                            ? "PROGRAMADO"
                            : trip.statusLabel.toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // CUERPO: Ruta
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildRouteRow(
                  Icons.radio_button_on,
                  AppColors.primaryGreen,
                  "Origen",
                  trip.origin,
                  isMain: true,
                ),
                const SizedBox(height: 5),
                _buildRouteConnector(),
                const SizedBox(height: 5),
                _buildRouteRow(
                  Icons.location_on_rounded,
                  AppColors.darkBlue,
                  "Destino",
                  trip.destination,
                ),
              ],
            ),
          ),

          // FOOTER: Precio y Acciones
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Envolvemos en Flexible para que el precio no desborde ni pida ancho infinito
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TOTAL",
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey.shade400,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trip.formattedPrice,
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: brandColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Envolvemos el botón para que se mantenga dentro del espacio permitido
                if (trip.isUpcoming)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: _buildCancelButton(trip),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRow(
    IconData icon,
    Color color,
    String label,
    String address, {
    bool isMain = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 15),
        // CAMBIO AQUÍ: Usar Flexible en lugar de Expanded
        Flexible(
          fit: FlexFit.loose,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.montserrat(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: isMain ? AppColors.primaryGreen : Colors.grey.shade400,
                ),
              ),
              Text(
                address,
                style: GoogleFonts.poppins(
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
      ],
    );
  }

  Widget _buildRouteConnector() {
    return Row(
      children: [
        const SizedBox(width: 8),
        Container(width: 2, height: 15, color: Colors.grey.shade100),
      ],
    );
  }

  List<TripModel> _applyFilter(List<TripModel> trips) {
    if (_selectedFilter == 'Programados') {
      return trips.where((t) => t.isUpcoming).toList();
    }
    if (_selectedFilter == 'Finalizados') {
      return trips.where((t) => t.isCompleted).toList();
    }
    if (_selectedFilter == 'Cancelados') {
      return trips.where((t) => t.isCancelled).toList();
    }
    return trips;
  }

  Widget _buildCancelButton(TripModel trip) {
    if (!trip.canCancelProgrammed) {
      return Text(
        "BLOQUEADO (<24H)",
        style: GoogleFonts.montserrat(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.amber.shade700,
        ),
      );
    }

    // Usamos InkWell en lugar de ElevatedButton para evitar problemas de Layout en el ListView
    return InkWell(
      onTap: () => _showCancelDialog(trip),
      child: Container(
        height: 35,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          "CANCELAR",
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(TripModel trip) {
    final bool isPenalty = trip.isWithinPenaltyPeriod;

    showDialog(
      context: context,
      barrierDismissible: false, // Forzamos al usuario a decidir
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono con sombra suave
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isPenalty
                        ? Colors.amber.shade50
                        : Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPenalty
                        ? Icons.error_outline_rounded
                        : Icons.cancel_rounded,
                    color: isPenalty ? Colors.amber.shade700 : Colors.redAccent,
                    size: 45,
                  ),
                ),
                const SizedBox(height: 24),

                // Título con impacto
                Text(
                  isPenalty ? "¡Aviso de Penalización!" : "¿Cancelar viaje?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 16),

                // Descripción con mejor legibilidad
                Text(
                  trip.cancelationWarning,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),

                if (isPenalty) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      "La multa se cargará a tu próximo método de pago.",
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // Botones Premium
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          "VOLVER",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // 1. Recibimos el mapa con el resultado
                          final Map<String, dynamic> resultado =
                              await _menuService.cancelTrip(trip.id);
                          // ignore: avoid_print
                          print(
                            "DEBUG: Respuesta del servidor: $resultado",
                          ); // <--- MIRA ESTO EN LA CONSOLA DE FLUTTER

                          // 2. Verificamos si sigue montado
                          if (!mounted) return;

                          // 3. Cerramos el diálogo usando el contexto que el constructor del builder nos dio (ctx)
                          // ignore: use_build_context_synchronously
                          Navigator.pop(ctx);

                          // 4. Usamos el contexto de la clase (_HistoryScreenState) para el SnackBar
                          bool fueExitoso = resultado['success'] ?? false;
                          bool huboMulta = resultado['aplica_multa'] ?? false;

                          if (fueExitoso) {
                            _showAppSnackBar(
                              huboMulta
                                  ? "Viaje cancelado. Se aplicó multa."
                                  : "Viaje cancelado con éxito.",
                              isError: huboMulta,
                            );
                            _loadHistory();
                          } else {
                            _showAppSnackBar(
                              "Error al cancelar el viaje",
                              isError: true,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPenalty
                              ? Colors.amber.shade700
                              : Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isPenalty ? "ACEPTAR MULTA" : "CONFIRMAR",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAppSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? Colors.redAccent : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.auto_graph_rounded, size: 80, color: Colors.grey.shade200),
        const SizedBox(height: 20),
        Text(
          "Sin aventuras registradas",
          style: GoogleFonts.montserrat(
            color: Colors.blueGrey.shade200,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        Text(
          "Tus viajes aparecerán aquí",
          style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _buildErrorState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off_rounded, size: 50, color: Colors.redAccent),
        const SizedBox(height: 10),
        Text(
          "Error de conexión",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        TextButton(onPressed: _loadHistory, child: const Text("REINTENTAR")),
      ],
    ),
  );
}
