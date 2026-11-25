import 'package:flutter/material.dart';
import '../data/repositories/social_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/models/notification_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SocialViewModel extends ChangeNotifier {
  final SocialRepository _repository = SocialRepository();

  List<String> _followingIds = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  List<String> get followingIds => _followingIds;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get isLoading => _isLoading;

  bool isFollowing(String userId) => _followingIds.contains(userId);

  List<String> _pendingRequestIds = []; // sol·licituds que HE ENVIAT jo
  List<Map<String, dynamic>> _followRequests = []; // sol·licituds que HE REBUT

  List<String> get pendingRequestIds => _pendingRequestIds;
  List<Map<String, dynamic>> get followRequests => _followRequests;

  bool hasPendingRequest(String userId) =>
      _pendingRequestIds.contains(userId);

  Future<void> loadFollowing(String currentUserId) async {
    _followingIds = await _repository.getFollowingIds(currentUserId);
    notifyListeners();
  }

  Future<void> toggleFollow(String currentUserId, String currentUserName,
      String targetUserId,
      {bool isPrivate = false}) async {
    if (isFollowing(targetUserId)) {
      await _repository.unfollowUser(currentUserId, targetUserId);
      _followingIds.remove(targetUserId);
    } else if (hasPendingRequest(targetUserId)) {
      // Cancel·lar sol·licitud pendent
      await _repository.cancelFollowRequest(currentUserId, targetUserId);
      _pendingRequestIds.remove(targetUserId);
    } else if (isPrivate) {
      // Enviar sol·licitud
      await _repository.sendFollowRequest(
        currentUserId,
        currentUserName,
        targetUserId,
        NotificationRepository(),
      );
      _pendingRequestIds.add(targetUserId);
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

  String _normalize(String text) {
    var result = text.toLowerCase();
    const from = 'àáâãäåèéêëìíîïòóôõöùúûüýÿçñ';
    const to   = 'aaaaaaeeeeiiiiooooouuuuyyçn';
    for (int i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }

  Future<void> searchUsers(String query, String currentUserId) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();

    // Obtenir tots els usuaris i filtrar localment (per suportar accents i majúscules)
    final allUsers = await _repository.searchUsers('', currentUserId);
    final normalizedQuery = _normalize(query);

    _searchResults = allUsers.where((user) {
      final name = _normalize(user['displayName'] ?? '');
      return name.contains(normalizedQuery);
    }).toList();

  _isLoading = false;
  notifyListeners();
}
  Future<List<String>> loadFollowingIds(String userId) async {
    _followingIds = await _repository.getFollowingIds(userId);
    notifyListeners();
    return _followingIds;
  }

  Future<void> loadPendingRequests(String currentUserId) async {
    // Sol·licituds que jo he enviat
    final snapshot = await FirebaseFirestore.instance
        .collection('follow_requests')
        .get();
    // Buscar en quins targetUsers tinc una sol·licitud meva
    // Ho fem de forma més eficient: guardem els ids directament
    // (es carreguen quan es visita un perfil)
  }

  Future<void> checkPendingRequest(
      String currentUserId, String targetUserId) async {
    final has =
        await _repository.hasPendingRequest(currentUserId, targetUserId);
    if (has && !_pendingRequestIds.contains(targetUserId)) {
      _pendingRequestIds.add(targetUserId);
      notifyListeners();
    }
  }

  Future<void> loadFollowRequests(String userId) async {
    _followRequests = await _repository.getFollowRequests(userId);
    notifyListeners();
  }

  Future<void> acceptRequest(String currentUserId, String requesterId,
      String requesterName) async {
    await _repository.acceptFollowRequest(
        currentUserId, requesterId, requesterName, NotificationRepository());
    _followRequests.removeWhere((r) => r['fromUserId'] == requesterId);
    notifyListeners();
  }

  Future<void> rejectRequest(
      String currentUserId, String requesterId) async {
    await _repository.rejectFollowRequest(currentUserId, requesterId);
    _followRequests.removeWhere((r) => r['fromUserId'] == requesterId);
    notifyListeners();
  }
}