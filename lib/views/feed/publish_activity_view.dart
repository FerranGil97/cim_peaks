import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/activity_model.dart';
import '../../data/models/summit_model.dart';
import '../../data/repositories/social_repository.dart';
import '../../data/services/storage_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/feed_viewmodel.dart';

class PublishActivityView extends StatefulWidget {
  final SummitModel summit;
  final SportType sport;

  const PublishActivityView({
    super.key,
    required this.summit,
    required this.sport,
  });

  @override
  State<PublishActivityView> createState() => _PublishActivityViewState();
}

class _PublishActivityViewState extends State<PublishActivityView> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final StorageService _storageService = StorageService();
  final SocialRepository _socialRepository = SocialRepository();

  File? _selectedImage;
  bool _isPublishing = false;
  List<Map<String, String>> _taggedUsers = [];
  List<Map<String, dynamic>> _userSuggestions = [];
  bool _showSuggestions = false;

  @override
  void dispose() {
    _titleController.dispose();
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

    // Filtrar els que ja estan etiquetats
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

  Future<void> _publish() async {
    final authViewModel = context.read<AuthViewModel>();
    final feedViewModel = context.read<FeedViewModel>();
    if (authViewModel.currentUser == null) return;

    setState(() => _isPublishing = true);

    String? photoUrl;
    if (_selectedImage != null) {
      photoUrl = await _storageService.uploadSummitPhoto(
        userId: authViewModel.currentUser!.uid,
        summitId: widget.summit.id,
        image: _selectedImage!,
      );
    }

    final activity = ActivityModel(
      id: '',
      userId: authViewModel.currentUser!.uid,
      userName: authViewModel.currentUser!.displayName,
      summitId: widget.summit.id,
      summitName: widget.summit.name,
      altitude: widget.summit.altitude,
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      photoUrl: photoUrl,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      sport: widget.sport,
      taggedUsers: _taggedUsers,
      createdAt: DateTime.now(),
    );

    await feedViewModel.publishActivity(activity);
    setState(() => _isPublishing = false);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicar activitat'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isPublishing ? null : _publish,
            child: _isPublishing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Publicar',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
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
                        Text(widget.summit.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                        Text('${widget.summit.altitude}m assolit! ✅',
                            style:
                                const TextStyle(color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Esport
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Text(widget.sport.emoji,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(widget.sport.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Títol
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Títol (opcional)',
                  hintText: 'Ex: Primera ascensió al Pedraforca!',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Foto
              GestureDetector(
                onTap: _showImageOptions,
                child: Container(
                  height: 200,
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
                                size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Afegir foto (opcional)',
                                style: TextStyle(color: Colors.grey)),
                            SizedBox(height: 4),
                            Text('Toca per seleccionar',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Descripció
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descripció (opcional)',
                  hintText: 'Explica la teva experiència...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Etiquetar companys
              const Text(
                'Etiquetar companys',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),

              // Usuaris etiquetats
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

              // Camp de cerca d'usuaris
              Column(
                children: [
                  TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar usuari per etiquetar...',
                      prefixIcon: Icon(Icons.alternate_email,
                          color: Colors.green),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onChanged: _onTagSearchChanged,
                    onTap: () {
                      if (_tagController.text.isNotEmpty) {
                        _onTagSearchChanged(_tagController.text);
                      }
                    },
                  ),

                  // Suggeriments
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
                                    color: Colors.white,
                                    fontSize: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}