import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Escollir foto de la galeria o càmera
  Future<File?> pickImage({bool fromCamera = false}) async {
    final XFile? picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  // Pujar foto a Firebase Storage
  Future<String?> uploadSummitPhoto({
    required String userId,
    required String summitId,
    required File image,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('users/$userId/summits/$summitId/${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await ref.putFile(
        image,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // Eliminar foto de Firebase Storage
  Future<void> deletePhoto(String photoUrl) async {
    try {
      final ref = _storage.refFromURL(photoUrl);
      await ref.delete();
    } catch (e) {
      // Ignorar errors si la foto no existeix
    }
  }
}