import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/summit_model.dart';
import '../../data/repositories/summit_repository.dart';
import '../../data/services/storage_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/summit_viewmodel.dart';

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
          // Header
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                      color:
                                          _statusColor(widget.summit.status)),
                                ),
                                child: Text(
                                  _statusLabel(widget.summit.status),
                                  style: TextStyle(
                                      color:
                                          _statusColor(widget.summit.status),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (widget.summit.province != null)
                            Text('📍 ${widget.summit.province}',
                                style: const TextStyle(color: Colors.grey)),
                          if (widget.summit.massif != null)
                            Text('⛰️ ${widget.summit.massif}',
                                style: const TextStyle(color: Colors.grey)),
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
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
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
                                      widget.summit.id,
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Les meves fotos (${_photos.length})',
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
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                              itemCount: _photos.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () => _showFullPhoto(_photos[index]),
                                  onLongPress: () =>
                                      _deletePhoto(_photos[index]),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _photos[index],
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: CircularProgressIndicator(
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