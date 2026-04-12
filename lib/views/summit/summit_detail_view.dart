import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/summit_model.dart';
import '../../data/repositories/summit_repository.dart';
import '../../data/services/storage_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/summit_viewmodel.dart';
import '../feed/publish_activity_view.dart';
import '../../data/models/activity_model.dart';

class SummitDetailView extends StatefulWidget {
  final SummitModel summit;

  const SummitDetailView({super.key, required this.summit});

  @override
  State<SummitDetailView> createState() => _SummitDetailViewState();
}

class _SummitDetailViewState extends State<SummitDetailView> {
  final StorageService _storageService = StorageService();
  final SummitRepository _repository = SummitRepository();
  List<String> _photos = [];
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _loadPhotos() async {
    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.currentUser == null) return;
    final photos = await _repository.getSummitPhotos(
      authViewModel.currentUser!.uid,
      widget.summit.id,
    );
    setState(() => _photos = photos);
  }

  Future<void> _addPhoto({bool fromCamera = false}) async {
    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.currentUser == null) return;

    final file = await _storageService.pickImage(fromCamera: fromCamera);
    if (file == null) return;

    setState(() => _isUploadingPhoto = true);

    final url = await _storageService.uploadSummitPhoto(
      userId: authViewModel.currentUser!.uid,
      summitId: widget.summit.id,
      image: file,
    );

    if (url != null) {
      await _repository.addPhotoToSummit(
        authViewModel.currentUser!.uid,
        widget.summit.id,
        url,
      );
      setState(() => _photos.add(url));
    }

    setState(() => _isUploadingPhoto = false);
  }

  Future<void> _deletePhoto(String photoUrl) async {
    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('Estàs segur que vols eliminar aquesta foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel·lar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _storageService.deletePhoto(photoUrl);
    await _repository.removePhotoFromSummit(
      authViewModel.currentUser!.uid,
      widget.summit.id,
      photoUrl,
    );
    setState(() => _photos.remove(photoUrl));
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Fer una foto'),
              onTap: () {
                Navigator.pop(context);
                _addPhoto(fromCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escollir de la galeria'),
              onTap: () {
                Navigator.pop(context);
                _addPhoto(fromCamera: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(SummitStatus status) {
    return switch (status) {
      SummitStatus.achieved => Colors.green,
      SummitStatus.saved => Colors.orange,
      SummitStatus.pending => Colors.red,
    };
  }

  String _statusLabel(SummitStatus status) {
    return switch (status) {
      SummitStatus.achieved => 'Assolit ✅',
      SummitStatus.saved => 'Guardat ⭐',
      SummitStatus.pending => 'Pendent 🔴',
    };
  }

  @override
  Widget build(BuildContext context) {
    final summitViewModel = context.read<SummitViewModel>();
    final authViewModel = context.read<AuthViewModel>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.green,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.summit.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              background: _photos.isNotEmpty
                  ? Image.network(_photos.first, fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                        ),
                      ),
                      child: const Icon(Icons.terrain,
                          size: 80, color: Colors.white54),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info bàsica
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${widget.summit.altitude}m',
                                  style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _statusColor(widget.summit.status)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _statusColor(
                                          widget.summit.status)),
                                ),
                                child: Text(
                                  _statusLabel(widget.summit.status),
                                  style: TextStyle(
                                      color: _statusColor(
                                          widget.summit.status),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (widget.summit.province != null)
                            Text('📍 ${widget.summit.province}',
                                style:
                                    const TextStyle(color: Colors.grey)),
                          if (widget.summit.massif != null)
                            Text('⛰️ ${widget.summit.massif}',
                                style:
                                    const TextStyle(color: Colors.grey)),
                          // Data d'assoliment
                          if (widget.summit.status ==
                                  SummitStatus.achieved &&
                              widget.summit.achievedAt != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 14, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  'Assolit el ${_formatDate(widget.summit.achievedAt!)}',
                                  style: const TextStyle(
                                      color: Colors.green, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                          if (widget.summit.description != null) ...[
                            const SizedBox(height: 8),
                            Text(widget.summit.description!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Canviar estat
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Canvia l\'estat',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _statusButton(
                                  label: 'Assolit',
                                  color: Colors.green,
                                  icon: Icons.check_circle,
                                  onTap: () async {
                                    summitViewModel.updateSummitStatus(
                                      authViewModel.currentUser!.uid,
                                      widget.summit.id,
                                      SummitStatus.achieved,
                                    );

                                    final publish =
                                        await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text(
                                            '🎉 Cim assolit!'),
                                        content: const Text(
                                            'Vols publicar aquesta ascensió al feed perquè els altres usuaris la puguin veure?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(
                                                    context, false),
                                            child: const Text(
                                                'No, gràcies'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(
                                                    context, true),
                                            style: ElevatedButton
                                                .styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    foregroundColor:
                                                        Colors.white),
                                            child: const Text(
                                                'Publicar!'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (!context.mounted) return;

                                    if (publish == true) {
                                      final sport =
                                          await showModalBottomSheet
                                              <SportType>(
                                        context: context,
                                        shape:
                                            const RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.vertical(
                                                  top:
                                                      Radius.circular(
                                                          20)),
                                        ),
                                        builder: (_) =>
                                            const _SportPickerSheet(),
                                      );

                                      if (sport != null &&
                                          context.mounted) {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                PublishActivityView(
                                              summit: widget.summit,
                                              sport: sport,
                                            ),
                                          ),
                                        );
                                      }
                                    }

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
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
                                      widget.summit.id,
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
                                      widget.summit.id,
                                      SummitStatus.pending,
                                    );
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Fotos
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  'Les meves fotos (${_photos.length})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              IconButton(
                                icon: _isUploadingPhoto
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.green))
                                    : const Icon(Icons.add_a_photo,
                                        color: Colors.green),
                                onPressed: _isUploadingPhoto
                                    ? null
                                    : _showPhotoOptions,
                              ),
                            ],
                          ),
                          if (_photos.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Afegeix fotos del teu ascens 📸',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                              itemCount: _photos.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () =>
                                      _showFullPhoto(_photos[index]),
                                  onLongPress: () =>
                                      _deletePhoto(_photos[index]),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    child: Image.network(
                                      _photos[index],
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, progress) {
                                        if (progress == null)
                                          return child;
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child:
                                                CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.green),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullPhoto(String photoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(photoUrl),
            ),
          ),
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
}

class _SportPickerSheet extends StatelessWidget {
  const _SportPickerSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Com has fet el cim?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: SportType.values.map((sport) {
              return GestureDetector(
                onTap: () => Navigator.pop(context, sport),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(sport.emoji,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        sport.label,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}