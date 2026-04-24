import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../data/models/summit_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/summit_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../summit/summit_detail_view.dart';
import '../summit/summit_list_view.dart';
import '../notifications/notifications_view.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? _mapController;
  static const LatLng _initialPosition = LatLng(42.0, 1.5);

  bool _useCircleMarkers = false;
  Map<double, BitmapDescriptor> _circleDescriptors = {};

  Future<BitmapDescriptor> _createCircleMarker(double hue, {double size = 30}) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double radius = size / 2;

    // Color del cercle segons el hue
    final Color color = HSVColor.fromAHSV(1.0, hue, 0.8, 0.8).toColor();

    // Ombra
    canvas.drawCircle(
      Offset(radius, radius + 2),
      radius * 0.9,
      Paint()..color = Colors.black.withOpacity(0.25),
    );

    // Cercle principal
    canvas.drawCircle(
      Offset(radius, radius),
      radius,
      Paint()..color = color,
    );

    // Vora blanca
    canvas.drawCircle(
      Offset(radius, radius),
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final ui.Image image = await recorder
        .endRecording()
        .toImage(size.toInt(), (size + 4).toInt());
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> _preloadCircleMarkers() async {
    _circleDescriptors = {
      BitmapDescriptor.hueGreen:
          await _createCircleMarker(BitmapDescriptor.hueGreen),
      BitmapDescriptor.hueYellow:
          await _createCircleMarker(BitmapDescriptor.hueYellow),
      BitmapDescriptor.hueBlue:
          await _createCircleMarker(BitmapDescriptor.hueBlue),
    };
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationPermission();
      final authViewModel = context.read<AuthViewModel>();
      final summitViewModel = context.read<SummitViewModel>();

      authViewModel.addListener(() {
        if (authViewModel.currentUser != null) {
          summitViewModel.loadSummits(authViewModel.currentUser!.uid);
          summitViewModel.loadChallengeSummits(authViewModel.currentUser!.uid);
        }
      });

      if (authViewModel.currentUser != null) {
        summitViewModel.loadSummits(authViewModel.currentUser!.uid);
        summitViewModel.loadChallengeSummits(authViewModel.currentUser!.uid);
      }
      _preloadCircleMarkers();
    });
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
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

  Set<Marker> _buildMarkers(
      List<SummitModel> userSummits,
      List<SummitModel> challengeSummits,
      bool challengeActive) {
    final markers = <Marker>{};

    // Sempre: cims assolits (verd) i guardats (groc) de l'usuari
    for (final summit in userSummits) {
      if (summit.status == SummitStatus.achieved ||
          summit.status == SummitStatus.saved) {
        final hue = summit.status == SummitStatus.achieved
            ? BitmapDescriptor.hueGreen
            : BitmapDescriptor.hueYellow;
        markers.add(_buildMarker(summit, hue));
      }
    }

    // Si el filtre del repte està actiu: afegeix els cims del repte en blau
    // (els que ja eren verd/groc ja estan, els nous en blau)
    if (challengeActive) {
      final userSummitIds = userSummits
          .where((s) =>
              s.status == SummitStatus.achieved ||
              s.status == SummitStatus.saved)
          .map((s) => s.id)
          .toSet();

      for (final summit in challengeSummits) {
        if (!userSummitIds.contains(summit.id)) {
          markers.add(_buildMarker(summit, BitmapDescriptor.hueBlue));
        }
      }
    }

    return markers;
  }

  Marker _buildMarker(SummitModel summit, double hue) {
    final icon = _useCircleMarkers && _circleDescriptors.containsKey(hue)
        ? _circleDescriptors[hue]!
        : BitmapDescriptor.defaultMarkerWithHue(hue);

    return Marker(
      markerId: MarkerId(summit.id),
      position: LatLng(summit.latitude, summit.longitude),
      icon: icon,
      infoWindow: InfoWindow(
        title: summit.name,
        snippet: '${summit.altitude}m — ${_statusLabel(summit.status)}',
        onTap: () => _showSummitDetail(summit),
      ),
    );
}

  String _statusLabel(SummitStatus status) {
    return switch (status) {
      SummitStatus.achieved => 'Assolit ✅',
      SummitStatus.pending => 'Pendent 🔵',
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

  void _showFiltersSheet(BuildContext context, SummitViewModel summitViewModel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtres de reptes',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Activa un repte per veure els seus cims al mapa',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // Repte 1: Els 100 Cims
                  _ChallengeFilterTile(
                    emoji: '🏔️',
                    title: 'Els 100 Cims FEEC',
                    subtitle: '528 cims per Catalunya',
                    color: Colors.blue,
                    active: summitViewModel.challengeFilterActive,
                    onChanged: (val) {
                      summitViewModel.toggleChallengeFilter();
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  // Aquí podràs afegir més reptes en el futur
                  const SizedBox(height: 16),
                  // Llegenda de colors
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Llegenda',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _LegendRow(color: Colors.green, label: 'Cim assolit ✅'),
                  _LegendRow(color: Colors.yellow[700]!, label: 'Cim guardat ⭐'),
                  _LegendRow(color: Colors.blue, label: 'Cim del repte 🔵'),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Estil dels marcadors',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            summitViewModel; // per tancar el sheet
                            Navigator.pop(context);
                            setState(() => _useCircleMarkers = false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: !_useCircleMarkers ? Colors.green : Colors.grey[300]!,
                                width: !_useCircleMarkers ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: !_useCircleMarkers ? Colors.green[50] : null,
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.location_on, color: Colors.red, size: 28),
                                const SizedBox(height: 4),
                                Text('Pin',
                                    style: TextStyle(
                                      fontWeight: !_useCircleMarkers
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: !_useCircleMarkers ? Colors.green : Colors.grey,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            setState(() => _useCircleMarkers = true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _useCircleMarkers ? Colors.green : Colors.grey[300]!,
                                width: _useCircleMarkers ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: _useCircleMarkers ? Colors.green[50] : null,
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Boleta',
                                    style: TextStyle(
                                      fontWeight: _useCircleMarkers
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _useCircleMarkers ? Colors.green : Colors.grey,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final summitViewModel = context.watch<SummitViewModel>();

    final userSummits = summitViewModel.allSummits;
    final challengeSummits = summitViewModel.challengeSummits;
    final challengeActive = summitViewModel.challengeFilterActive;

    final markers = _buildMarkers(userSummits, challengeSummits, challengeActive);

    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkNotifications());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cim Peaks'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // Botó filtres amb indicador actiu
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showFiltersSheet(context, summitViewModel),
              ),
              if (challengeActive)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          Consumer<NotificationViewModel>(
            builder: (context, notifViewModel, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsView()),
                      );
                      if (context.mounted) {
                        context.read<NotificationViewModel>().markAllAsRead(
                            authViewModel.currentUser!.uid);
                      }
                    },
                  ),
                  if (notifViewModel.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${notifViewModel.unreadCount}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
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
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.terrain,
          ),
          if (summitViewModel.isLoading || summitViewModel.challengeLoading)
            const Center(
                child: CircularProgressIndicator(color: Colors.green)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SummitListView()),
        ),
        backgroundColor: Colors.green,
        icon: const Icon(Icons.list, color: Colors.white),
        label: const Text('Llistat de cims',
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

// Widget per a cada filtre de repte
class _ChallengeFilterTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final bool active;
  final ValueChanged<bool> onChanged;

  const _ChallengeFilterTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: active ? color : Colors.grey[300]!, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: active ? color.withOpacity(0.07) : null,
      ),
      child: SwitchListTile(
        secondary: Text(emoji, style: const TextStyle(fontSize: 28)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        value: active,
        activeColor: color,
        onChanged: onChanged,
      ),
    );
  }
}

// Widget per a la llegenda de colors
class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// Overlay de medalla (sense canvis)
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
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _controller.reverse().then((_) => widget.onDismiss());
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('🏅', style: TextStyle(fontSize: 32)),
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
                              fontSize: 16),
                        ),
                        Text(
                          widget.message,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
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