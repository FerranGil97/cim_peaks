import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_model.dart';
import '../models/notification_model.dart';
import 'notification_repository.dart';

class ActivityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtenir el feed global
  Stream<List<ActivityModel>> getFeed() {
    return _firestore
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Publicar una activitat
  Future<String> publishActivity(ActivityModel activity) async {
    final doc = await _firestore.collection('activities').add(activity.toFirestore());
    return doc.id;
  }

  Stream<List<ActivityModel>> getUserActivities(String userId) {
    return _firestore
        .collection('activities')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Donar/treure like
  Future<void> toggleLike(String activityId, String userId,
      String userName, String activityOwnerId,
      String summitName, NotificationRepository notifRepo) async {
    final ref = _firestore.collection('activities').doc(activityId);
    final doc = await ref.get();
    final likes = List<String>.from(doc.data()?['likes'] ?? []);

    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
      // Crear notificació de like si no és el propi usuari
      if (userId != activityOwnerId) {
        await notifRepo.createNotification(NotificationModel(
          id: '',
          userId: activityOwnerId,
          type: NotificationType.like,
          title: 'Nou like!',
          body: '$userName ha donat like a la teva ascensió a $summitName',
          createdAt: DateTime.now(),
          activityId: activityId,
          fromUserId: userId,
          fromUserName: userName,
        ));
      }
    }
    await ref.update({'likes': likes});
  }

  // Obtenir comentaris
  Stream<List<CommentModel>> getComments(String activityId) {
    return _firestore
        .collection('activities')
        .doc(activityId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Afegir comentari
  Future<void> addComment(String activityId, CommentModel comment) async {
    await _firestore
        .collection('activities')
        .doc(activityId)
        .collection('comments')
        .add(comment.toFirestore());

    await _firestore
        .collection('activities')
        .doc(activityId)
        .update({'commentsCount': FieldValue.increment(1)});
  }

  // Eliminar activitat
  Future<void> deleteActivity(String activityId) async {
    await _firestore.collection('activities').doc(activityId).delete();
  }
}