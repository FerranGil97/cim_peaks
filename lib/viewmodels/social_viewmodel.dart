import 'package:flutter/material.dart';
import '../data/repositories/social_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/models/notification_model.dart';

class SocialViewModel extends ChangeNotifier {
  final SocialRepository _repository = SocialRepository();

  List<String> _followingIds = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  List<String> get followingIds => _followingIds;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get isLoading => _isLoading;

  bool isFollowing(String userId) => _followingIds.contains(userId);

  Future<void> loadFollowing(String currentUserId) async {
    _followingIds = await _repository.getFollowingIds(currentUserId);
    notifyListeners();
  }

  Future<void> toggleFollow(
      String currentUserId, String currentUserName, String targetUserId) async {
    if (isFollowing(targetUserId)) {
      await _repository.unfollowUser(currentUserId, targetUserId);
      _followingIds.remove(targetUserId);
    } else {
      await _repository.followUser(
        currentUserId,
        currentUserName,
        targetUserId,
        NotificationRepository(),
      );
      _followingIds.add(targetUserId);
    }
    notifyListeners();
  }

  Future<void> searchUsers(String query, String currentUserId) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    _searchResults = await _repository.searchUsers(query, currentUserId);
    _isLoading = false;
    notifyListeners();
  }
  Future<List<String>> loadFollowingIds(String userId) async {
    _followingIds = await _repository.getFollowingIds(userId);
    notifyListeners();
    return _followingIds;
  }
}