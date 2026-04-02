import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/summit_model.dart';

class SummitRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtenir tots els cims globals combinats amb l'estat de l'usuari
  Stream<List<SummitModel>> getUserSummitsWithGlobal(String userId) {
    return _firestore.collection('summits').snapshots().asyncMap((snapshot) async {
      final userSummitsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('user_summits')
          .get();

      final userSummitsMap = {
        for (var doc in userSummitsSnapshot.docs) doc.id: doc.data()
      };

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final userData = userSummitsMap[doc.id];
        if (userData != null) {
          data['status'] = userData['status'];
          data['achievedAt'] = userData['achievedAt'];
        }
        return SummitModel.fromFirestore(data, doc.id);
      }).toList();
    });
  }

  // Obtenir tots els cims d'un usuari (col·lecció pròpia)
  Stream<List<SummitModel>> getUserSummits(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('summits')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SummitModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Actualitzar l'estat d'un cim per a un usuari
  Future<void> updateSummitStatus(
      String userId, String summitId, SummitStatus status) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('user_summits')
        .doc(summitId)
        .set({
      'status': status.name,
      'achievedAt': status == SummitStatus.achieved
          ? DateTime.now().toIso8601String()
          : null,
    });
  }

  // Afegir un cim nou (proposta de l'usuari)
  Future<void> addSummitRequest(String userId, SummitModel summit) async {
    await _firestore.collection('summit_requests').add({
      'userId': userId,
      'name': summit.name,
      'latitude': summit.latitude,
      'longitude': summit.longitude,
      'altitude': summit.altitude,
      'description': summit.description,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // Eliminar un cim de l'usuari
  Future<void> deleteSummit(String userId, String summitId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('user_summits')
        .doc(summitId)
        .delete();
  }
}