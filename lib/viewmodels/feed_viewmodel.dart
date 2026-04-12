import 'package:flutter/material.dart';
import '../data/models/activity_model.dart';
import '../data/repositories/activity_repository.dart';
import '../data/repositories/social_repository.dart';
import '../data/repositories/notification_repository.dart';

class FeedViewModel extends ChangeNotifier {
  final ActivityRepository _activityRepository = ActivityRepository();
  final SocialRepository _socialRepository = SocialRepository();

  List<ActivityModel> _activities = [];
  bool _isLoading = false;

  List<ActivityModel> get activities => _activities;
  bool get isLoading => _isLoading;

  void loadFeed(String currentUserId) {
    _isLoading = true;
    notifyListeners();

    _activityRepository.getFeed().listen((allActivities) async {
      // Obtenir IDs de les persones que segueixo
      final followingIds =
          await _socialRepository.getFollowingIds(currentUserId);

      // Filtrar: mostrar les meves i les dels que segueixo
      _activities = allActivities
          .where((a) =>
              a.userId == currentUserId ||
              followingIds.contains(a.userId))
          .toList();

      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> toggleLike(String activityId, String userId,
      String userName) async {
    // Buscar l'activitat a la llista local
    final activity = _activities.firstWhere((a) => a.id == activityId);
    
    await _activityRepository.toggleLike(
      activityId,
      userId,
      userName,
      activity.userId,
      activity.summitName,
      NotificationRepository(),
    );
  }

  Future<String> publishActivity(ActivityModel activity) async {
    return await _activityRepository.publishActivity(activity);
  }

  Future<void> deleteActivity(String activityId) async {
    await _activityRepository.deleteActivity(activityId);
  }
}