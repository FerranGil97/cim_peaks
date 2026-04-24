import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/activity_model.dart';
import '../../data/models/summit_model.dart';
import '../../data/repositories/social_repository.dart';
import '../../data/repositories/summit_repository.dart';
import '../../data/services/storage_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/feed_viewmodel.dart';
import '../../viewmodels/summit_viewmodel.dart';
import '../../data/models/review_model.dart';
import 'summit_detail_view.dart';


class AscentDetailsView extends StatefulWidget {
  final SummitModel summit;

  const AscentDetailsView({super.key, required this.summit});

  @override
  State<AscentDetailsView> createState() => _AscentDetailsViewState();
}

class _AscentDetailsViewState extends State<AscentDetailsView> {
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final StorageService _storageService = StorageService();
  final SocialRepository _socialRepository = SocialRepository();
  final SummitRepository _summitRepository = SummitRepository();

  SportType? _selectedSport;
  File? _selectedImage;
  bool _isSaving = false;
  List<Map<String, String>> _taggedUsers = [];
  List<Map<String, dynamic>> _userSuggestions = [];
  bool _showSuggestions = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({bool fromCamera = false}) async {
    final file = await _storageService.pickImage(fromCamera: fromCamera);
    if (file != null) setState(() => _selectedImage = file);
  }

  void _showImageOptions() {
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
                _pickImage(fromCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escollir de la galeria'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(fromCamera: false);
              },
            ),
            if (_selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar foto',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedImage = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTagSearchChanged(String value) async {
    final authViewModel = context.read<AuthViewModel>();
    if (value.isEmpty) {
      setState(() {
        _userSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    final results = await _socialRepository.searchUsersByPrefix(
        value, authViewModel.currentUser!.uid);
    final filtered = results
        .where((u) => !_taggedUsers.any((t) => t['id'] == u['id']))
        .toList();
    setState(() {
      _userSuggestions = filtered;
      _showSuggestions = filtered.isNotEmpty;
    });
  }

  void _addTag(Map<String, dynamic> user) {
    setState(() {
      _taggedUsers.add({
        'id': user['id'] as String,
        'name': user['displayName'] as String,
      });
      _tagController.clear();
      _userSuggestions = [];
      _showSuggestions = false;
    });
  }

  void _removeTag(String userId) {
    setState(() {
      _taggedUsers.removeWhere((t) => t['id'] == userId);
    });
  }

  Future<void> _save({bool publishAfter = false}) async {
    final authViewModel = context.read<AuthViewModel>();
    final summitViewModel = context.read<SummitViewModel>();
    if (authViewModel.currentUser == null) return;

    setState(() => _isSaving = true);

    final userId = authViewModel.currentUser!.uid;

    // Pujar foto si n'hi ha
    String? photoUrl;
    if (_selectedImage != null) {
      photoUrl = await _storageService.uploadSummitPhoto(
        userId: userId,
        summitId: widget.summit.id,
        image: _selectedImage!,
      );
      // Afegir la foto a la col·lecció de fotos del cim
      if (photoUrl != null) {
        await _summitRepository.addPhotoToSummit(
            userId, widget.summit.id, photoUrl);
      }
    }

    // Guardar detalls privats a user_summits
    await _summitRepository.saveAscentDetails(
      userId: userId,
      summitId: widget.summit.id,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      sport: _selectedSport,
      taggedUsers: _taggedUsers,
      photoUrl: photoUrl,
    );

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (publishAfter && _selectedSport != null) {
      // Navegar a PublishActivityView
      final feedViewModel = context.read<FeedViewModel>();
      final activity = ActivityModel(
        id: '',
        userId: userId,
        userName: authViewModel.currentUser!.displayName,
        summitId: widget.summit.id,
        summitName: widget.summit.name,
        altitude: widget.summit.altitude,
        title: null,
        photoUrl: photoUrl,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        sport: _selectedSport,
        taggedUsers: _taggedUsers,
        createdAt: DateTime.now(),
      );
      await feedViewModel.publishActivity(activity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ascensió guardada i publicada al feed!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Detalls de l\'ascensió guardats!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.read<AuthViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalls de l\'ascensió'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => _save(),
            child: const Text(
              'Guardar',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showSuggestions = false),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info del cim
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.terrain,
                        color: Colors.green, size: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.summit.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          '${widget.summit.altitude}m assolit! ✅',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Com has fet el cim (sport)
              const Text(
                'Com has fet el cim?',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.3,
                children: SportType.values.map((sport) {
                  final isSelected = _selectedSport == sport;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedSport = sport),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.green[100]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.green
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(sport.emoji,
                              style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(
                            sport.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.green[800]
                                  : Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Foto
              const Text(
                'Foto (privada)',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _showImageOptions,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _selectedImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _selectedImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo,
                                size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Afegir foto (opcional)',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Descripció privada
              const Text(
                'Notes privades',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Com ha anat l\'ascensió? Notes personals...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),

              // Companys
              const Text(
                'Amb qui has anat?',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (_taggedUsers.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _taggedUsers.map((user) {
                    return Chip(
                      avatar: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.person,
                            size: 14, color: Colors.white),
                      ),
                      label: Text('@${user['name']}'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeTag(user['id']!),
                      backgroundColor: Colors.green[50],
                      side: BorderSide(color: Colors.green[200]!),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
              Column(
                children: [
                  TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar usuari...',
                      prefixIcon: Icon(Icons.alternate_email,
                          color: Colors.green),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onChanged: _onTagSearchChanged,
                  ),
                  if (_showSuggestions)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8)),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12, blurRadius: 4)
                        ],
                      ),
                      child: Column(
                        children: _userSuggestions.map((user) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green,
                              radius: 16,
                              child: Text(
                                (user['displayName'] as String)[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                            title: Text('@${user['displayName']}'),
                            onTap: () => _addTag(user),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // Valoració pública
              const Text(
                'Valoració pública',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Les estrelles i el comentari seran visibles per tots els usuaris.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              _InlineReviewWidget(
                summitId: widget.summit.id,
                userId: authViewModel.currentUser!.uid,
                userName: authViewModel.currentUser!.displayName,
              ),
              const SizedBox(height: 20),

              // Botó publicar al feed
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Vols compartir-ho?',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Pots publicar l\'ascensió al feed perquè la comunitat la pugui veure.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () {
                        if (_selectedSport == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Selecciona com has fet el cim primer'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        _save(publishAfter: true);
                      },
                icon: const Icon(Icons.public, color: Colors.green),
                label: const Text('Guardar i publicar al feed',
                    style: TextStyle(color: Colors.green)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  
}
class _InlineReviewWidget extends StatefulWidget {
    final String summitId;
    final String userId;
    final String userName;

    const _InlineReviewWidget({
      required this.summitId,
      required this.userId,
      required this.userName,
    });

    @override
    State<_InlineReviewWidget> createState() => _InlineReviewWidgetState();
  }

  class _InlineReviewWidgetState extends State<_InlineReviewWidget> {
    final SummitRepository _repository = SummitRepository();
    final _commentController = TextEditingController();
    double _rating = 0;
    bool _isSaving = false;
    bool _saved = false;

    @override
    void initState() {
      super.initState();
      _loadExistingReview();
    }

    @override
    void dispose() {
      _commentController.dispose();
      super.dispose();
    }

    Future<void> _loadExistingReview() async {
      final review =
          await _repository.getUserReview(widget.summitId, widget.userId);
      if (review != null && mounted) {
        setState(() {
          _rating = review.rating;
          _commentController.text = review.comment ?? '';
          _saved = true;
        });
      }
    }

    Future<void> _saveReview() async {
      if (_rating == 0) {
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
        rating: _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _repository.saveReview(widget.summitId, review);

      setState(() {
        _isSaving = false;
        _saved = true;
      });

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
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estrelles
            Row(
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () =>
                      setState(() => _rating = (index + 1).toDouble()),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            // Comentari
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Explica la teva experiència... (opcional)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Botó
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_saved
                        ? 'Actualitzar valoració'
                        : 'Publicar valoració'),
              ),
            ),
          ],
        ),
      );
    }
  }