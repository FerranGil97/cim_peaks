import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'notification_repository.dart';

class SocialRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Seguir un usuari
  Future<void> followUser(String currentUserId, String currentUserName,
      String targetUserId, NotificationRepository notifRepo) async {
    final now = DateTime.now().toIso8601String();
    final batch = _firestore.batch();

    batch.set(
      _firestore
          .collection('follows')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId),
      {'createdAt': now},
    );

    batch.set(
      _firestore
          .collection('follows')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId),
      {'createdAt': now},
    );

    await batch.commit();

    // Crear notificació
    await notifRepo.createNotification(NotificationModel(
      id: '',
      userId: targetUserId,
      type: NotificationType.follow,
      title: 'Nou seguidor!',
      body: '$currentUserName ha començat a seguir-te',
      createdAt: DateTime.now(),
      fromUserId: currentUserId,
      fromUserName: currentUserName,
    ));
  }

  // Deixar de seguir
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    final batch = _firestore.batch();

    batch.delete(_firestore
        .collection('follows')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId));

    batch.delete(_firestore
        .collection('follows')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId));

    await batch.commit();
  }

  // Comprovar si segueixo un usuari
  Future<bool> isFollowing(
      String currentUserId, String targetUserId) async {
    final doc = await _firestore
        .collection('follows')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .get();
    return doc.exists;
  }

  // Obtenir llista d'IDs que segueixo
  Future<List<String>> getFollowingIds(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .doc(userId)
        .collection('following')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // Obtenir seguidors
  Future<List<String>> getFollowerIds(String userId) async {
    final snapshot = await _firestore
        .collection('follows')
        .doc(userId)
        .collection('followers')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // Buscar usuaris per nom
  Future<List<Map<String, dynamic>>> searchUsers(
      String query, String currentUserId) async {
    final snapshot = await _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }
  // Afegeix aquest mètode al SocialRepository
  Future<List<Map<String, dynamic>>> searchUsersByPrefix(
      String prefix, String currentUserId) async {
    if (prefix.isEmpty) return [];
    final snapshot = await _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: prefix)
        .where('displayName', isLessThanOrEqualTo: '$prefix\uf8ff')
        .limit(5)
        .get();

    return snapshot.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }
}