import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/repositories/summit_repository.dart';
import '../../data/models/summit_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'package:flutter/foundation.dart';

class AddSummitView extends StatefulWidget {
  const AddSummitView({super.key});

  @override
  State<AddSummitView> createState() => _AddSummitViewState();
}

class _AddSummitViewState extends State<AddSummitView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _altitudeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final SummitRepository _repository = SummitRepository();

  LatLng? _selectedLocation;
  bool _isSubmitting = false;
  bool _locationPickerVisible = false;
  GoogleMapController? _mapController;

  static const LatLng _initialPosition = LatLng(42.0, 1.5);

  @override
  void dispose() {
    _nameController.dispose();
    _altitudeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 12),
      );
    } catch (e) {
      // Ignorar errors de localització
    }
  }

  Future<void> _submitProposal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona la ubicació del cim al mapa'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final authViewModel = context.read<AuthViewModel>();
    final summit = SummitModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      altitude: int.parse(_altitudeController.text.trim()),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    await _repository.addSummitRequest(
      authViewModel.currentUser!.uid,
      summit,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('✅ Proposta enviada!'),
          content: const Text(
            'La teva proposta de cim ha estat enviada i serà revisada per l\'administrador. '
            'Un cop aprovada apareixerà al mapa per a tots els usuaris.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child:
                  const Text('Entès', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proposar nou cim'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La teva proposta serà revisada per l\'administrador abans d\'aparèixer al mapa.',
                        style: TextStyle(color: Colors.blue, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Nom
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom del cim *',
                  prefixIcon: Icon(Icons.terrain),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Introdueix el nom del cim';
                  }
                  if (value.length < 3) return 'Mínim 3 caràcters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Altitud
              TextFormField(
                controller: _altitudeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Altitud (metres) *',
                  prefixIcon: Icon(Icons.height),
                  border: OutlineInputBorder(),
                  suffixText: 'm',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Introdueix l\'altitud';
                  }
                  final altitude = int.tryParse(value);
                  if (altitude == null) return 'Introdueix un número vàlid';
                  if (altitude < 100 || altitude > 9000) {
                    return 'Altitud entre 100 i 9000m';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Descripció
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripció (opcional)',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Ubicació
              const Text(
                'Ubicació al mapa *',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (_selectedLocation != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Text(
                    '📍 Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, '
                    'Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          setState(() => _locationPickerVisible = true),
                      icon: const Icon(Icons.map),
                      label: Text(_selectedLocation == null
                          ? 'Seleccionar al mapa'
                          : 'Canviar ubicació'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.green),
                    onPressed: _getCurrentLocation,
                    tooltip: 'Usar la meva ubicació actual',
                  ),
                ],
              ),

              // Mapa per seleccionar ubicació
              if (_locationPickerVisible) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
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
                            setState(() => _selectedLocation = latLng);
                          },
                          markers: _selectedLocation != null
                              ? {
                                  Marker(
                                    markerId: const MarkerId('selected'),
                                    position: _selectedLocation!,
                                    icon:
                                        BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueGreen),
                                  ),
                                }
                              : {},
                          mapType: MapType.terrain,
                          zoomControlsEnabled: true,
                          zoomGesturesEnabled: true,
                          scrollGesturesEnabled: true,
                          rotateGesturesEnabled: true,
                          tiltGesturesEnabled: true,
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
                              'Mou el mapa i toca per marcar la ubicació del cim',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_selectedLocation != null)
                  ElevatedButton(
                    onPressed: () =>
                        setState(() => _locationPickerVisible = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('✅ Confirmar ubicació'),
                  ),
              ],

              const SizedBox(height: 32),

              // Botó enviar
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitProposal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Enviar proposta',
                        style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}