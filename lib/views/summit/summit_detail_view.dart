import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/summit_model.dart';
import '../../data/models/review_model.dart';
import '../../data/repositories/summit_repository.dart';
import '../../data/services/storage_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/summit_viewmodel.dart';
import 'ascent_details_view.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math';

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


  /// Mostra un diàleg per triar la data d'ascensió.
  /// Retorna la data seleccionada, o null si l'usuari cancel·la.
  Future<DateTime?> _pickAscentDate() async {
    DateTime selectedDate = DateTime.now();

    return await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.green, size: 22),
                  SizedBox(width: 8),
                  Text("'Data de l'ascensió'"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quin dia vas fer el cim?',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(1970),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Colors.green,
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.green.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDate(selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          const Icon(Icons.edit_calendar,
                              color: Colors.green, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _quickDateChip(
                        label: 'Avui',
                        date: DateTime.now(),
                        selectedDate: selectedDate,
                        onTap: (d) => setDialogState(() => selectedDate = d),
                      ),
                      _quickDateChip(
                        label: 'Ahir',
                        date: DateTime.now().subtract(const Duration(days: 1)),
                        selectedDate: selectedDate,
                        onTap: (d) => setDialogState(() => selectedDate = d),
                      ),
                      _quickDateChip(
                        label: 'Fa una setmana',
                        date: DateTime.now().subtract(const Duration(days: 7)),
                        selectedDate: selectedDate,
                        onTap: (d) => setDialogState(() => selectedDate = d),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel·lar',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _quickDateChip({
    required String label,
    required DateTime date,
    required DateTime selectedDate,
    required void Function(DateTime) onTap,
  }) {
    final isSelected = _formatDate(date) == _formatDate(selectedDate);
    return GestureDetector(
      onTap: () => onTap(date),
      child: Chip(
        label: Text(label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : Colors.green,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
        backgroundColor:
            isSelected ? Colors.green : Colors.green.withOpacity(0.08),
        side: BorderSide(color: Colors.green.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
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

                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _SummitLocatorView(summit: widget.summit),
                      ),
                    ),
                    icon: const Icon(Icons.location_searching, color: Colors.blue),
                    label: const Text('Localitzar al mapa',
                        style: TextStyle(color: Colors.blue)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botó editar detalls (si ja és assolit)
                  if (widget.summit.status == SummitStatus.achieved)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AscentDetailsView(
                              summit: widget.summit,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.edit_note,
                            color: Colors.green),
                        label: const Text('Editar detalls de l\'ascensió',
                            style: TextStyle(color: Colors.green)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

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
                                    // 1. Demanar la data d'ascensió
                                    final pickedDate = await _pickAscentDate();
                                    // Si l'usuari cancel·la, no fem res
                                    if (pickedDate == null) return;
                                    if (!context.mounted) return;

                                    // 2. Guardar l'estat amb la data triada
                                    await summitViewModel.updateSummitStatus(
                                      authViewModel.currentUser!.uid,
                                      widget.summit.id,
                                      SummitStatus.achieved,
                                      achievedAt: pickedDate,
                                    );

                                    if (!context.mounted) return;

                                    // 3. Navegar als detalls d'ascensió
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AscentDetailsView(
                                          summit: widget.summit.copyWith(
                                            status: SummitStatus.achieved,
                                            achievedAt: pickedDate,
                                          ),
                                        ),
                                      ),
                                    );
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

                  // Valoracions públiques del cim
                  ReviewsSection(
                    summit: widget.summit,
                    userId: authViewModel.currentUser!.uid,
                    userName: authViewModel.currentUser!.displayName,
                    readOnly: widget.summit.status != SummitStatus.achieved,
                  ),
                  const SizedBox(height: 16),

                  // Fotos privades
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
                                        if (progress == null) return child;
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

// ── REVIEWS ──────────────────────────────────────────────────────────────

class ReviewsSection extends StatefulWidget {
  final SummitModel summit;
  final String userId;
  final String userName;
  final bool readOnly;

  const ReviewsSection({
    required this.summit,
    required this.userId,
    required this.userName,
    this.readOnly = false,
  });

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  final SummitRepository _repository = SummitRepository();
  List<ReviewModel> _reviews = [];
  ReviewModel? _myReview;
  bool _isLoading = true;
  double _myRating = 0;
  final _commentController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    final reviews = await _repository.getSummitReviews(widget.summit.id);
    final myReview =
        await _repository.getUserReview(widget.summit.id, widget.userId);
    setState(() {
      _reviews = reviews;
      _myReview = myReview;
      if (myReview != null) {
        _myRating = myReview.rating;
        _commentController.text = myReview.comment ?? '';
      }
      _isLoading = false;
    });
  }

  Future<void> _saveReview() async {
    if (_myRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una puntuació primer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final review = ReviewModel(
      userId: widget.userId,
      userName: widget.userName,
      rating: _myRating,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      createdAt: DateTime.now(),
    );

    await _repository.saveReview(widget.summit.id, review);
    await _loadReviews();
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Valoració guardada!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Capçalera amb mitjana global
            Row(
              children: [
                const Text('Valoracions',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (widget.summit.avgRating != null) ...[
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.summit.avgRating!.toStringAsFixed(1)} (${widget.summit.reviewsCount})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ] else
                  const Text('Sense valoracions',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 16),

            // La meva valoració (només si el cim és assolit)
            if (!widget.readOnly) ...[
const Text('La meva valoració',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),

            // Estrelles interactives
            Row(
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () =>
                      setState(() => _myRating = (index + 1).toDouble()),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      index < _myRating
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            // Comentari públic
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Explica la teva experiència... (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Botó guardar valoració
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_myReview != null
                        ? 'Actualitzar valoració'
                        : 'Publicar valoració'),
              ),
            ),

            ],

            if (widget.readOnly)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Marca el cim com a assolit per deixar la teva valoració',
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Valoracions d'altres usuaris
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child:
                      CircularProgressIndicator(color: Colors.green),
                ),
              )
            else if (_reviews
                .where((r) => r.userId != widget.userId)
                .isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Altres valoracions',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              ..._reviews
                  .where((r) => r.userId != widget.userId)
                  .map((review) => _ReviewTile(review: review)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ReviewModel review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.green,
            backgroundImage: review.userPhotoUrl != null
                ? NetworkImage(review.userPhotoUrl!)
                : null,
            child: review.userPhotoUrl == null
                ? Text(
                    review.userName[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < review.rating
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 14,
                      ),
                    ),
                  ],
                ),
                if (review.comment != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    review.comment!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _SummitLocatorView extends StatefulWidget {
  final SummitModel summit;
  const _SummitLocatorView({required this.summit});

  @override
  State<_SummitLocatorView> createState() => _SummitLocatorViewState();
}

class _SummitLocatorViewState extends State<_SummitLocatorView>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  BitmapDescriptor? _markerIcon;

  @override
  void initState() {
    super.initState();
    // Animació de puls
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _animController.addListener(() async {
      final icon = await _buildAnimatedMarker(_pulseAnimation.value);
      if (mounted) setState(() => _markerIcon = icon);
    });

    _buildAnimatedMarker(1.0).then((icon) {
      if (mounted) setState(() => _markerIcon = icon);
    });
  }

  Future<BitmapDescriptor> _buildAnimatedMarker(double scale) async {
    final baseSize = 36.0;
    final size = baseSize * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final color = Colors.green;

    // Ombra
    final shadowPath = Path()
      ..moveTo(size / 2, 2)
      ..lineTo(size - 2, size + 2)
      ..lineTo(2, size + 2)
      ..close();
    canvas.drawPath(
        shadowPath, Paint()..color = Colors.black.withOpacity(0.2));

    // Triangle principal
    final trianglePath = Path()
      ..moveTo(size / 2, 0)
      ..lineTo(size, size)
      ..lineTo(0, size)
      ..close();
    canvas.drawPath(trianglePath, Paint()..color = color);

    // Vora blanca
    canvas.drawPath(
      trianglePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    final image = await recorder
        .endRecording()
        .toImage(size.toInt() + 4, size.toInt() + 4);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  @override
  void dispose() {
    _animController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summit = widget.summit;
    final target = LatLng(summit.latitude, summit.longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(summit.name),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(target, 13),
              );
            },
            initialCameraPosition: CameraPosition(
              target: target,
              zoom: 13,
            ),
            markers: _markerIcon != null
                ? {
                    Marker(
                      markerId: MarkerId(summit.id),
                      position: target,
                      icon: _markerIcon!,
                      infoWindow: InfoWindow(
                        title: summit.name,
                        snippet: '${summit.altitude}m',
                      ),
                    ),
                  }
                : {},
            mapType: MapType.terrain,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
          // Card informativa a baix
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('🏔️', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            summit.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${summit.altitude}m'
                            '${summit.province != null ? ' · ${summit.province}' : ''}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(target, 14),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Centrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}