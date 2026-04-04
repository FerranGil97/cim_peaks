import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../data/models/summit_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/summit_viewmodel.dart';
import '../summit/summit_detail_view.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? _mapController;
  static const LatLng _initialPosition = LatLng(42.0, 1.5);
  bool _filtersVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = context.read<AuthViewModel>();
      final summitViewModel = context.read<SummitViewModel>();

      authViewModel.addListener(() {
        if (authViewModel.currentUser != null) {
          summitViewModel.loadSummits(authViewModel.currentUser!.uid);
        }
      });

      if (authViewModel.currentUser != null) {
        summitViewModel.loadSummits(authViewModel.currentUser!.uid);
      }
    });
  }

  void _checkNotifications() {
    final summitViewModel = context.read<SummitViewModel>();

    if (summitViewModel.newBadgeMessage != null) {
      final message = summitViewModel.newBadgeMessage!;
      summitViewModel.clearNotifications();
      Future.delayed(Duration.zero, () {
        _showAchievementOverlay(message);
      });
    }
  }

  void _showAchievementOverlay(String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AchievementOverlay(
        message: message,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  Set<Marker> _buildMarkers(List<SummitModel> summits) {
    return summits.map((summit) {
      final hue = switch (summit.status) {
        SummitStatus.achieved => BitmapDescriptor.hueGreen,
        SummitStatus.saved => BitmapDescriptor.hueYellow,
        SummitStatus.pending => BitmapDescriptor.hueRed,
      };
      return Marker(
        markerId: MarkerId(summit.id),
        position: LatLng(summit.latitude, summit.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: summit.name,
          snippet: '${summit.altitude}m — ${_statusLabel(summit.status)}',
          onTap: () => _showSummitDetail(summit),
        ),
      );
    }).toSet();
  }

  String _statusLabel(SummitStatus status) {
    return switch (status) {
      SummitStatus.achieved => 'Assolit ✅',
      SummitStatus.pending => 'Pendent 🔴',
      SummitStatus.saved => 'Guardat ⭐',
    };
  }

  void _showSummitDetail(SummitModel summit) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SummitDetailView(summit: summit),
    ),
  );
}

  Widget _statusButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel(SummitViewModel summitViewModel) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Filtre per estat',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _filterChip('Tots',
                  summitViewModel.statusFilter == SummitFilter.all,
                  () => summitViewModel.setStatusFilter(SummitFilter.all)),
              _filterChip('Assolits ✅',
                  summitViewModel.statusFilter == SummitFilter.achieved,
                  () => summitViewModel.setStatusFilter(SummitFilter.achieved)),
              _filterChip('Pendents 🔴',
                  summitViewModel.statusFilter == SummitFilter.pending,
                  () => summitViewModel.setStatusFilter(SummitFilter.pending)),
              _filterChip('Guardats ⭐',
                  summitViewModel.statusFilter == SummitFilter.saved,
                  () => summitViewModel.setStatusFilter(SummitFilter.saved)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Filtre per altitud',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _filterChip('Tots',
                  summitViewModel.altitudeFilter == AltitudeFilter.all,
                  () => summitViewModel.setAltitudeFilter(AltitudeFilter.all)),
              _filterChip('+3000m',
                  summitViewModel.altitudeFilter == AltitudeFilter.above3000,
                  () => summitViewModel
                      .setAltitudeFilter(AltitudeFilter.above3000)),
              _filterChip('2000-3000m',
                  summitViewModel.altitudeFilter ==
                      AltitudeFilter.between2000and3000,
                  () => summitViewModel
                      .setAltitudeFilter(AltitudeFilter.between2000and3000)),
              _filterChip('-2000m',
                  summitViewModel.altitudeFilter == AltitudeFilter.below2000,
                  () => summitViewModel
                      .setAltitudeFilter(AltitudeFilter.below2000)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(label),
        backgroundColor: selected ? Colors.green : Colors.grey[200],
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final summitViewModel = context.watch<SummitViewModel>();
    final summits = summitViewModel.filteredSummits;

    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkNotifications());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cim Peaks'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_filtersVisible
                ? Icons.filter_list_off
                : Icons.filter_list),
            onPressed: () =>
                setState(() => _filtersVisible = !_filtersVisible),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authViewModel.signOut(),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: 8,
            ),
            markers: _buildMarkers(summits),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.terrain,
          ),
          if (_filtersVisible)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: _buildFilterPanel(summitViewModel),
            ),
          if (summitViewModel.isLoading)
            const Center(
                child: CircularProgressIndicator(color: Colors.green)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Afegir cim',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class _AchievementOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _AchievementOverlay({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_AchievementOverlay> createState() => _AchievementOverlayState();
}

class _AchievementOverlayState extends State<_AchievementOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0, end: 1).animate(_controller);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      left: 24,
      right: 24,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('🏅',
                      style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Medalla Guanyada!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}