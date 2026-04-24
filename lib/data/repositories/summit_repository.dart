import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/summit_model.dart';
import '../models/activity_model.dart';
import '../models/review_model.dart';

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
  // Afegir foto a un cim de l'usuari
  Future<void> addPhotoToSummit(
      String userId, String summitId, String photoUrl) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('user_summits')
        .doc(summitId)
        .set({
      'photos': FieldValue.arrayUnion([photoUrl]),
    }, SetOptions(merge: true));
  }

  // Eliminar foto d'un cim de l'usuari
  Future<void> removePhotoFromSummit(
      String userId, String summitId, String photoUrl) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('user_summits')
        .doc(summitId)
        .update({
      'photos': FieldValue.arrayRemove([photoUrl]),
    });
  }

  // Obtenir fotos d'un cim
  Future<List<String>> getSummitPhotos(
      String userId, String summitId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('user_summits')
        .doc(summitId)
        .get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    return List<String>.from(data['photos'] ?? []);
  }
  Future<List<SummitModel>> getChallengeSummits(String userId) async {
    final globalSnapshot = await _firestore
        .collection('summits')
        .where('showOnMap', isEqualTo: true)
        .get();

    final userSummitsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('user_summits')
        .get();

    final userSummitsMap = {
      for (var doc in userSummitsSnapshot.docs) doc.id: doc.data()
    };

    return globalSnapshot.docs.map((doc) {
      final data = doc.data();
      final userData = userSummitsMap[doc.id];
      if (userData != null) {
        data['status'] = userData['status'];
        data['achievedAt'] = userData['achievedAt'];
      }
      return SummitModel.fromFirestore(data, doc.id);
    }).toList();
  }
  Future<void> saveAscentDetails({
    required String userId,
    required String summitId,
    String? description,
    SportType? sport,
    List<Map<String, String>>? taggedUsers,
    String? photoUrl,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('user_summits')
        .doc(summitId)
        .set({
      if (description != null) 'description': description,
      if (sport != null) 'sport': sport.name,
      if (taggedUsers != null) 'taggedUsers': taggedUsers,
      if (photoUrl != null) 'ascentPhotoUrl': photoUrl,
    }, SetOptions(merge: true));
  }

  // Obtenir totes les reviews d'un cim
  Future<List<ReviewModel>> getSummitReviews(String summitId) async {
    final snapshot = await _firestore
        .collection('summits')
        .doc(summitId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ReviewModel.fromFirestore(doc.data()))
        .toList();
  }

  // Obtenir la review de l'usuari actual
  Future<ReviewModel?> getUserReview(String summitId, String userId) async {
    final doc = await _firestore
        .collection('summits')
        .doc(summitId)
        .collection('reviews')
        .doc(userId)
        .get();
    if (!doc.exists) return null;
    return ReviewModel.fromFirestore(doc.data()!);
  }

  // Guardar o actualitzar la review de l'usuari
  Future<void> saveReview(String summitId, ReviewModel review) async {
    // Guardar la review
    await _firestore
        .collection('summits')
        .doc(summitId)
        .collection('reviews')
        .doc(review.userId)
        .set(review.toFirestore());

    // Actualitzar la mitjana al document del cim
    final snapshot = await _firestore
        .collection('summits')
        .doc(summitId)
        .collection('reviews')
        .get();

    final ratings = snapshot.docs
        .map((d) => (d.data()['rating'] ?? 0).toDouble())
        .toList();

    final avg = ratings.reduce((a, b) => a + b) / ratings.length;

    await _firestore.collection('summits').doc(summitId).update({
      'avgRating': double.parse(avg.toStringAsFixed(1)),
      'reviewsCount': ratings.length,
    });
  }

}