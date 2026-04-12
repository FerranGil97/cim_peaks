import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../data/models/summit_model.dart';
import '../../viewmodels/summit_viewmodel.dart';
import 'summit_detail_view.dart';
import 'package:flutter/gestures.dart';

class NearbySummitsView extends StatefulWidget {
  const NearbySummitsView({super.key});

  @override
  State<NearbySummitsView> createState() => _NearbySummitsViewState();
}

class _NearbySummitsViewState extends State<NearbySummitsView> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  double _radiusKm = 10;
  bool _isLoadingLocation = false;
  bool _locationPickerVisible = false;
  List<Map<String, dynamic>> _nearbySummits = [];
  bool _searched = false;

  static const LatLng _initialPosition = LatLng(42.0, 1.5);

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Cal activar els permisos de localització'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation =
            LatLng(position.latitude, position.longitude);
        _locationPickerVisible = false;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 10),
      );
      _searchNearbySummits();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No s\'ha pogut obtenir la ubicació'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  void _searchNearbySummits() {
    if (_selectedLocation == null) return;
    final summitViewModel = context.read<SummitViewModel>();
    final results = summitViewModel.getSummitsNearLocation(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
      _radiusKm,
    );
    setState(() {
      _nearbySummits = results;
      _searched = true;
    });
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Marcador de la ubicació seleccionada
    if (_selectedLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('selected_location'),
        position: _selectedLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'La meva ubicació'),
      ));
    }

    // Marcadors dels cims propers
    for (final item in _nearbySummits) {
      final summit = item['summit'] as SummitModel;
      final hue = switch (summit.status) {
        SummitStatus.achieved => BitmapDescriptor.hueGreen,
        SummitStatus.saved => BitmapDescriptor.hueYellow,
        SummitStatus.pending => BitmapDescriptor.hueRed,
      };
      markers.add(Marker(
        markerId: MarkerId(summit.id),
        position: LatLng(summit.latitude, summit.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: summit.name,
          snippet:
              '${summit.altitude}m · ${(item['distance'] as double).toStringAsFixed(1)}km',
        ),
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cims a prop'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Controls
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Botons d'ubicació
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingLocation
                            ? null
                            : _useCurrentLocation,
                        icon: _isLoadingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.my_location),
                        label: const Text('La meva ubicació'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(
                            () => _locationPickerVisible =
                                !_locationPickerVisible),
                        icon: const Icon(Icons.map),
                        label: Text(_locationPickerVisible
                            ? 'Tancar mapa'
                            : 'Escollir al mapa'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),

                // Ubicació seleccionada
                if (_selectedLocation != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Selector de radi
                Row(
                  children: [
                    const Text('Radi:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: [5, 10, 20, 50, 100].map((km) {
                          final selected = _radiusKm == km.toDouble();
                          return GestureDetector(
                            onTap: () {
                              setState(() => _radiusKm = km.toDouble());
                              if (_selectedLocation != null) {
                                _searchNearbySummits();
                              }
                            },
                            child: Chip(
                              label: Text('${km}km'),
                              backgroundColor: selected
                                  ? Colors.green
                                  : Colors.grey[200],
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.black,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Mapa per escollir ubicació
          if (_locationPickerVisible)
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  GoogleMap(
                    onMapCreated: (c) => _mapController = c,
                    initialCameraPosition: const CameraPosition(
                      target: _initialPosition,
                      zoom: 8,
                    ),
                    onTap: (latLng) {
                      setState(() {
                        _selectedLocation = latLng;
                        _locationPickerVisible = false;
                      });
                      _searchNearbySummits();
                    },
                    markers: _selectedLocation != null
                        ? {
                            Marker(
                              markerId:
                                  const MarkerId('selected'),
                              position: _selectedLocation!,
                              icon:
                                  BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueBlue),
                            ),
                          }
                        : {},
                    mapType: MapType.terrain,
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Toca al mapa per seleccionar la ubicació',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Mapa amb resultats
          if (_searched && _selectedLocation != null)
            SizedBox(
              height: 300,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation!,
                  zoom: _radiusKm <= 10
                      ? 11
                      : _radiusKm <= 20
                          ? 10
                          : 8,
                ),
                markers: _buildMarkers(),
                mapType: MapType.terrain,
                circles: {
                  Circle(
                    circleId: const CircleId('radius'),
                    center: _selectedLocation!,
                    radius: _radiusKm * 1000,
                    fillColor: Colors.blue.withOpacity(0.1),
                    strokeColor: Colors.blue,
                    strokeWidth: 1,
                  ),
                },
              ),
            ),

          // Resultats
          Expanded(
            child: !_searched
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_searching,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Selecciona una ubicació\nper veure els cims propers',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : _nearbySummits.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.terrain,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No hi ha cims en un radi de ${_radiusKm.toInt()}km',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Text(
                                  '${_nearbySummits.length} cims en ${_radiusKm.toInt()}km',
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _nearbySummits.length,
                              itemBuilder: (context, index) {
                                final item = _nearbySummits[index];
                                final summit =
                                    item['summit'] as SummitModel;
                                final distance =
                                    item['distance'] as double;

                                final statusEmoji =
                                    switch (summit.status) {
                                  SummitStatus.achieved => '✅',
                                  SummitStatus.saved => '⭐',
                                  SummitStatus.pending => '🔘',
                                };

                                final statusColor =
                                    switch (summit.status) {
                                  SummitStatus.achieved =>
                                    Colors.green,
                                  SummitStatus.saved => Colors.orange,
                                  SummitStatus.pending =>
                                    Colors.grey[350]!,
                                };

                                return ListTile(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SummitDetailView(
                                          summit: summit),
                                    ),
                                  ),
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: statusColor
                                          .withOpacity(0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: statusColor),
                                    ),
                                    child: Center(
                                      child: Text(statusEmoji,
                                          style: const TextStyle(
                                              fontSize: 20)),
                                    ),
                                  ),
                                  title: Text(
                                    summit.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    '${summit.altitude}m${summit.massif != null ? ' · ${summit.massif}' : ''}',
                                    style: const TextStyle(
                                        fontSize: 12),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.blue[200]!),
                                    ),
                                    child: Text(
                                      '${distance.toStringAsFixed(1)}km',
                                      style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}