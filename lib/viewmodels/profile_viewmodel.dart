import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/summit_model.dart';
import '../data/models/user_model.dart';
import '../data/repositories/social_repository.dart';
import 'dart:io';
import '../data/services/storage_service.dart';


class ProfileViewModel extends ChangeNotifier {
  UserModel? _user;
  List<SummitModel> _userSummits = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _following = [];
  List<Map<String, dynamic>> _followers = [];


  final SocialRepository _socialRepository = SocialRepository();

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get following => _following;
  List<Map<String, dynamic>> get followers => _followers;

  List<SummitModel> _challengeSummits = [];
  List<SummitModel> _achievedChallengeSummits = [];
  bool _challengeLoading = false;

  List<SummitModel> get challengeSummits => _challengeSummits;
  List<SummitModel> get achievedChallengeSummits => _achievedChallengeSummits;
  bool get challengeLoading => _challengeLoading;
  int get totalChallengeAchieved => _achievedChallengeSummits.length;
  int get totalChallengeCount => _challengeSummits.length;
  double get challengeProgress => _challengeSummits.isEmpty
      ? 0
      : totalChallengeAchieved / totalChallengeCount;

  List<SummitModel> _comarcaChallengeSummits = [];
  List<SummitModel> _achievedComarcaChallengeSummits = [];
  bool _comarcaChallengeLoading = false;

  List<SummitModel> get comarcaChallengeSummits => _comarcaChallengeSummits;
  List<SummitModel> get achievedComarcaChallengeSummits => _achievedComarcaChallengeSummits;
  bool get comarcaChallengeLoading => _comarcaChallengeLoading;
  int get totalComarcaAchieved => _achievedComarcaChallengeSummits.length;
  int get totalComarcaCount => _comarcaChallengeSummits.length;
  double get comarcaChallengeProgress => _comarcaChallengeSummits.isEmpty
      ? 0
      : totalComarcaAchieved / totalComarcaCount;

  int get totalAchieved =>
      _userSummits.where((s) => s.status == SummitStatus.achieved).length;
  int get totalSaved =>
      _userSummits.where((s) => s.status == SummitStatus.saved).length;
  int get totalPending =>
      _userSummits.where((s) => s.status == SummitStatus.pending).length;
  int get highestSummit => _userSummits
      .where((s) => s.status == SummitStatus.achieved)
      .fold(0, (max, s) => s.altitude > max ? s.altitude : max);


  String? _photoUrl;
    String? get photoUrl => _user?.photoUrl;

    Future<void> updateProfilePhoto(String userId, File image) async {
      final storageService = StorageService();
      final url = await storageService.uploadSummitPhoto(
        userId: userId,
        summitId: 'profile',
        image: image,
      );
      if (url != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'photoUrl': url});
        notifyListeners();
      }
    }

    bool get isPrivate => _user?.isPrivate ?? false;

    Future<void> setPrivate(String userId, bool value) async {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'isPrivate': value});
      await loadProfile(userId);
    }



  Future<void> loadProfile(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Pas 1: Carregar usuari i mostrar de seguida
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        _user = UserModel.fromFirestore(userDoc.data()!, userId);
      }
      _isLoading = false; // Mostrem el perfil amb les dades bàsiques ja
      notifyListeners();

      // Pas 2: Carregar la resta en paral·lel
      await Future.wait([
        _loadUserSummits(userId),
        _loadFollowData(userId),
        _loadChallengeProgress(userId),
        _loadComarcaChallengeProgress(userId),
      ]);

      // Migració puntual — només afecta cims sense userRating
      await migrateUserRatings(userId);
      await _loadUserSummits(userId); // recarregar amb els ratings migrats

      notifyListeners();
    } catch (e) {
      debugPrint('Error carregant perfil: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserSummits(String userId) async {
    try {
      final summitsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('user_summits')
          .get();

      final summitIds = summitsSnapshot.docs.map((d) => d.id).toList();
      if (summitIds.isEmpty) return;

      final userSummitsMap = {
        for (var doc in summitsSnapshot.docs) doc.id: doc.data()
      };

      // whereIn en comptes de N crides individuals (màx 30 per lot)
      final List<SummitModel> summits = [];
      for (int i = 0; i < summitIds.length; i += 30) {
        final chunk = summitIds.sublist(
            i, i + 30 > summitIds.length ? summitIds.length : i + 30);
        final globalSnapshot = await FirebaseFirestore.instance
            .collection('summits')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in globalSnapshot.docs) {
          final data = doc.data();
          final userData = userSummitsMap[doc.id];
          if (userData != null) {
            data['status'] = userData['status'];
            data['achievedAt'] = userData['achievedAt'];
            data['userRating'] = userData['userRating'];
          }
          summits.add(SummitModel.fromFirestore(data, doc.id));
        }
      }

      _userSummits = summits;
      notifyListeners();
    } catch (e) {
      debugPrint('Error carregant cims de l´usuari: $e');
    }
  }

  Future<void> _loadChallengeProgress(String userId) async {
    try {
      _challengeLoading = true;

      // Obtenir els 528 cims del repte
      final challengeSnapshot = await FirebaseFirestore.instance
          .collection('summits')
          .where('showOnMap', isEqualTo: true)
          .get();

      _challengeSummits = challengeSnapshot.docs
          .map((doc) => SummitModel.fromFirestore(doc.data(), doc.id))
          .toList();

      // Obtenir els que l'usuari ja ha assolit
      final userSummitsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('user_summits')
          .where('status', isEqualTo: 'achieved')
          .get();

      final achievedIds = userSummitsSnapshot.docs.map((d) => d.id).toSet();

      _achievedChallengeSummits = _challengeSummits
          .where((s) => achievedIds.contains(s.id))
          .toList();

      _challengeLoading = false;
    } catch (e) {
      _challengeLoading = false;
      debugPrint('Error carregant repte: $e');
    }
  }

  Future<void> _loadComarcaChallengeProgress(String userId) async {
    try {
      _comarcaChallengeLoading = true;

      final challengeSnapshot = await FirebaseFirestore.instance
          .collection('summits')
          .where('showOnMapComarca', isEqualTo: true)
          .get();

      _comarcaChallengeSummits = challengeSnapshot.docs
          .map((doc) => SummitModel.fromFirestore(doc.data(), doc.id))
          .toList();

      final userSummitsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('user_summits')
          .where('status', isEqualTo: 'achieved')
          .get();

      final achievedIds = userSummitsSnapshot.docs.map((d) => d.id).toSet();

      _achievedComarcaChallengeSummits = _comarcaChallengeSummits
          .where((s) => achievedIds.contains(s.id))
          .toList();

      _comarcaChallengeLoading = false;
    } catch (e) {
      _comarcaChallengeLoading = false;
      debugPrint('Error carregant repte comarca: $e');
    }
  }

  Future<void> _loadFollowData(String userId) async {
    try {
      final results = await Future.wait([
        _socialRepository.getFollowingIds(userId),
        _socialRepository.getFollowerIds(userId),
      ]);
      final followingIds = results[0];
      final followerIds = results[1];

      // Carregar en chunks de 30 (límit de whereIn)
      Future<List<Map<String, dynamic>>> fetchUsers(List<String> ids) async {
        if (ids.isEmpty) return [];
        final List<Map<String, dynamic>> result = [];
        for (int i = 0; i < ids.length; i += 30) {
          final chunk = ids.sublist(
              i, i + 30 > ids.length ? ids.length : i + 30);
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          // Mantenir l'ordre original dels IDs
          final docsMap = {for (var doc in snap.docs) doc.id: doc.data()};
          for (final id in chunk) {
            if (docsMap.containsKey(id)) {
              result.add({'id': id, ...docsMap[id]!});
            }
          }
        }
        return result;
      }

      final followingFollowerResults = await Future.wait([
        fetchUsers(followingIds),
        fetchUsers(followerIds),
      ]);

      _following = followingFollowerResults[0];
      _followers = followingFollowerResults[1];
      notifyListeners();
    } catch (e) {
      debugPrint('Error carregant follow data: $e');
    }
  }
  

  Future<void> migrateUserRatings(String userId) async {
    final userSummitsSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('user_summits')
        .where('status', isEqualTo: 'achieved')
        .get();

    for (final doc in userSummitsSnap.docs) {
      // Només migrar els que encara no tenen userRating
      if (doc.data()['userRating'] != null) continue;

      final reviewDoc = await FirebaseFirestore.instance
          .collection('summits')
          .doc(doc.id)
          .collection('reviews')
          .doc(userId)
          .get();

      if (reviewDoc.exists) {
        final rating = reviewDoc.data()?['rating'];
        if (rating != null) {
          await doc.reference.update({'userRating': rating});
        }
      }
    }
  }
  
  List<SummitModel> get achievedSummits =>
      _userSummits.where((s) => s.status == SummitStatus.achieved).toList()
        ..sort((a, b) => b.altitude.compareTo(a.altitude));

  List<SummitModel> get savedSummits =>
      _userSummits.where((s) => s.status == SummitStatus.saved).toList()
        ..sort((a, b) => b.altitude.compareTo(a.altitude));
}