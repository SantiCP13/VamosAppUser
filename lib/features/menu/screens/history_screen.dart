// ignore_for_file: deprecated_member_use
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
  late Future<List<TripModel>> _historyFuture;
  String _selectedFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = _menuService.getTripHistory();
    });
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
                        if (snapshot.hasError) return _buildErrorState();

                        List<TripModel> allTrips = snapshot.data ?? [];
                        // Ordenar por fecha más reciente
                        allTrips.sort((a, b) {
                          DateTime dateA =
                              a.scheduledAt ??
                              DateTime.parse(a.dateRaw).toLocal();
                          DateTime dateB =
                              b.scheduledAt ??
                              DateTime.parse(b.dateRaw).toLocal();
                          return dateB.compareTo(dateA);
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
    final DateTime dateObj = (trip.scheduledAt ?? DateTime.parse(trip.dateRaw))
        .toLocal();

    // Le damos un formato premium: "LUN, 4 MAY • 10:30 AM"
    final String localTimeStr = DateFormat(
      'EEE, d MMM • hh:mm a',
      'es',
    ).format(dateObj).toUpperCase();
    // ----------------------------------

    Color statusColor = AppColors.primaryGreen;
    if (trip.isCancelled) statusColor = Colors.redAccent;
    if (trip.isUpcoming) statusColor = AppColors.darkBlue;

    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // HEADER DE LA TARJETA
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: Colors.blueGrey.shade300,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          localTimeStr,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey.shade300,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        trip.statusLabel.toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // CUERPO: RUTA VISUAL
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildRouteRow(
                      Icons.radio_button_on,
                      AppColors.primaryGreen,
                      "Origen",
                      trip.origin,
                      isMain: true, // <--- Nueva bandera para resaltar el verde
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

              // INFO CONDUCTOR (Si aplica)
              if (trip.hasDriverAssigned) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 18, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "${trip.driverName} • ${trip.vehiclePlate}",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // FOOTER: PRECIO Y ACCIONES
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TOTAL",
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          trip.formattedPrice,
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    if (trip.isUpcoming) _buildCancelButton(trip),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteRow(
    IconData icon,
    Color color,
    String label,
    String address, {
    bool isMain = false, // <--- Nuevo parámetro
  }) {
    return Row(
      children: [
        // Círculo de color alrededor del icono para estilo premium
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.montserrat(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  // Si es el origen (isMain), usamos verde para el label
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
    return ElevatedButton(
      onPressed: () => _showCancelDialog(trip),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.1),
        foregroundColor: Colors.redAccent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      child: Text(
        "CANCELAR",
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
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

  void _showCancelDialog(TripModel trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(
          "¿Cancelar viaje?",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("VOLVER"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _menuService.cancelTrip(trip.id);
              if (success) _loadHistory();
            },
            child: const Text(
              "CONFIRMAR",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
