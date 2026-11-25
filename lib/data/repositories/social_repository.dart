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
        .limit(200)
        .get();

    return snapshot.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchUsersByPrefix(
      String prefix, String currentUserId) async {
    if (prefix.isEmpty) return [];

    final snapshot = await _firestore
        .collection('users')
        .limit(200)
        .get();

    final q = _normalize(prefix);

    return snapshot.docs
        .where((doc) => doc.id != currentUserId)
        .where((doc) {
          final name = (doc.data()['displayName'] as String? ?? '');
          return _normalize(name).contains(q);
        })
        .map((doc) => {'id': doc.id, ...doc.data()})
        .take(5)
        .toList();
  }

  String _normalize(String text) {
    const accents    = 'àáâãäåèéêëìíîïòóôõöùúûüçñÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÇÑ';
    const normalized = 'aaaaaaeeeeiiiioooooуuuucnAAAAAAEEEEIIIIOOOOOUUUUCN';
    var result = text.toLowerCase();
    for (var i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], normalized[i]);
    }
    return result;
  }
  // Enviar sol·licitud de seguiment
  Future<void> sendFollowRequest(String currentUserId, String currentUserName,
      String targetUserId, NotificationRepository notifRepo) async {
    await _firestore
        .collection('follow_requests')
        .doc(targetUserId)
        .collection('requests')
        .doc(currentUserId)
        .set({
      'fromUserId': currentUserId,
      'fromUserName': currentUserName,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'pending',
    });

    await notifRepo.createNotification(NotificationModel(
      id: '',
      userId: targetUserId,
      type: NotificationType.followRequest,
      title: 'Sol·licitud de seguiment',
      body: '$currentUserName vol seguir-te',
      createdAt: DateTime.now(),
      fromUserId: currentUserId,
      fromUserName: currentUserName,
    ));
  }

  // Comprovar si hi ha sol·licitud pendent
  Future<bool> hasPendingRequest(
      String currentUserId, String targetUserId) async {
    final doc = await _firestore
        .collection('follow_requests')
        .doc(targetUserId)
        .collection('requests')
        .doc(currentUserId)
        .get();
    return doc.exists;
  }

  // Acceptar sol·licitud
  Future<void> acceptFollowRequest(String targetUserId, String requesterId,
      String requesterName, NotificationRepository notifRepo) async {
    // Eliminar la sol·licitud
    await _firestore
        .collection('follow_requests')
        .doc(targetUserId)
        .collection('requests')
        .doc(requesterId)
        .delete();

    // Crear la relació de seguiment normal
    final now = DateTime.now().toIso8601String();
    final batch = _firestore.batch();

    batch.set(
      _firestore
          .collection('follows')
          .doc(requesterId)
          .collection('following')
          .doc(targetUserId),
      {'createdAt': now},
    );
    batch.set(
      _firestore
          .collection('follows')
          .doc(targetUserId)
          .collection('followers')
          .doc(requesterId),
      {'createdAt': now},
    );
    await batch.commit();
  }

  // Rebutjar sol·licitud
  Future<void> rejectFollowRequest(
      String targetUserId, String requesterId) async {
    await _firestore
        .collection('follow_requests')
        .doc(targetUserId)
        .collection('requests')
        .doc(requesterId)
        .delete();
  }

  // Cancel·lar sol·licitud enviada
  Future<void> cancelFollowRequest(
      String currentUserId, String targetUserId) async {
    await _firestore
        .collection('follow_requests')
        .doc(targetUserId)
        .collection('requests')
        .doc(currentUserId)
        .delete();
  }

  // Obtenir sol·licituds rebudes
  Future<List<Map<String, dynamic>>> getFollowRequests(
      String userId) async {
    final snapshot = await _firestore
        .collection('follow_requests')
        .doc(userId)
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }
}