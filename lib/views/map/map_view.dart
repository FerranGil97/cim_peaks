import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../data/models/summit_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/summit_viewmodel.dart';

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
    
      // Escoltar canvis d'usuari
      authViewModel.addListener(() {
        if (authViewModel.currentUser != null) {
          summitViewModel.loadSummits(authViewModel.currentUser!.uid);
        }
      });

      // Carregar immediatament si ja tenim usuari
      if (authViewModel.currentUser != null) {
        summitViewModel.loadSummits(authViewModel.currentUser!.uid);
      }
      print('USER: ${authViewModel.currentUser?.uid}');
    });
    
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
    final authViewModel = context.read<AuthViewModel>();
    final summitViewModel = context.read<SummitViewModel>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(summit.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${summit.altitude}m · ${summit.province ?? ''}',
                style: const TextStyle(color: Colors.grey)),
            if (summit.description != null) ...[
              const SizedBox(height: 8),
              Text(summit.description!),
            ],
            const SizedBox(height: 16),
            const Text('Canvia l\'estat:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _statusButton(
                    label: 'Assolit',
                    color: Colors.green,
                    icon: Icons.check_circle,
                    onTap: () {
                      summitViewModel.updateSummitStatus(
                        authViewModel.currentUser!.uid,
                        summit.id,
                        SummitStatus.achieved,
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statusButton(
                    label: 'Guardat',
                    color: Colors.orange,
                    icon: Icons.star,
                    onTap: () {
                      summitViewModel.updateSummitStatus(
                        authViewModel.currentUser!.uid,
                        summit.id,
                        SummitStatus.saved,
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statusButton(
                    label: 'Pendent',
                    color: Colors.red,
                    icon: Icons.radio_button_unchecked,
                    onTap: () {
                      summitViewModel.updateSummitStatus(
                        authViewModel.currentUser!.uid,
                        summit.id,
                        SummitStatus.pending,
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
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
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
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
              _filterChip('Tots', summitViewModel.statusFilter == SummitFilter.all,
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
                  () => summitViewModel.setAltitudeFilter(AltitudeFilter.above3000)),
              _filterChip('2000-3000m',
                  summitViewModel.altitudeFilter == AltitudeFilter.between2000and3000,
                  () => summitViewModel.setAltitudeFilter(AltitudeFilter.between2000and3000)),
              _filterChip('-2000m',
                  summitViewModel.altitudeFilter == AltitudeFilter.below2000,
                  () => summitViewModel.setAltitudeFilter(AltitudeFilter.below2000)),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cim Peaks'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_filtersVisible ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () => setState(() => _filtersVisible = !_filtersVisible),
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
            const Center(child: CircularProgressIndicator(color: Colors.green)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Afegir cim', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}