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

  int get totalAchieved =>
      _userSummits.where((s) => s.status == SummitStatus.achieved).length;
  int get totalSaved =>
      _userSummits.where((s) => s.status == SummitStatus.saved).length;
  int get totalPending =>
      _userSummits.where((s) => s.status == SummitStatus.pending).length;
  int get highestSummit => _userSummits
      .where((s) => s.status == SummitStatus.achieved)
      .fold(0, (max, s) => s.altitude > max ? s.altitude : max);

  int get level {
    if (totalAchieved >= 50) return 5;
    if (totalAchieved >= 25) return 4;
    if (totalAchieved >= 10) return 3;
    if (totalAchieved >= 5) return 2;
    return 1;
  }
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

  String get levelName {
    return switch (level) {
      1 => 'Principiant',
      2 => 'Excursionista',
      3 => 'Muntanyenc',
      4 => 'Alpinista',
      5 => 'Llegenda',
      _ => 'Principiant',
    };
  }

  double get levelProgress {
    final thresholds = [0, 5, 10, 25, 50];
    final current = thresholds[level - 1];
    final next = level < 5 ? thresholds[level] : 50;
    return ((totalAchieved - current) / (next - current)).clamp(0.0, 1.0);
  }

  List<Map<String, dynamic>> get allBadges {
    final List<Map<String, dynamic>> badges = [
      {
        'icon': '🏔️',
        'name': 'Primer Cim',
        'desc': 'Assoleix el teu primer cim',
        'earned': totalAchieved >= 1,
      },
      {
        'icon': '⭐',
        'name': 'Explorador',
        'desc': 'Assoleix 5 cims',
        'earned': totalAchieved >= 5,
      },
      {
        'icon': '🦅',
        'name': 'Àguila',
        'desc': 'Assoleix 10 cims',
        'earned': totalAchieved >= 10,
      },
      {
        'icon': '🏆',
        'name': 'Campió',
        'desc': 'Assoleix 25 cims',
        'earned': totalAchieved >= 25,
      },
      {
        'icon': '❄️',
        'name': 'Tres Mil',
        'desc': 'Assoleix un cim de +3000m',
        'earned': highestSummit >= 3000,
      },
      {
        'icon': '👑',
        'name': 'Llegenda',
        'desc': 'Assoleix 50 cims',
        'earned': totalAchieved >= 50,
      },
      {
        'icon': '🗺️',
        'name': 'Cartògraf',
        'desc': 'Guarda 10 cims per fer',
        'earned': totalSaved >= 10,
      },
      {
        'icon': '🌄',
        'name': 'Pirenaic',
        'desc': 'Assoleix 3 cims del Pirineu',
        'earned': _userSummits
                .where((s) =>
                    s.status == SummitStatus.achieved &&
                    (s.massif ?? '').contains('Pirineu'))
                .length >=
            3,
      },
      {
        'icon': '🧗',
        'name': 'Escalador',
        'desc': 'Assoleix 5 cims de +2500m',
        'earned': _userSummits
                .where((s) =>
                    s.status == SummitStatus.achieved && s.altitude >= 2500)
                .length >=
            5,
      },
    ];
    return badges;
  }

  List<Map<String, dynamic>> get badges =>
      allBadges.where((b) => b['earned'] == true).toList();

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
      ]);

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

  Future<void> _loadFollowData(String userId) async {
    try {
      final followingIds =
          await _socialRepository.getFollowingIds(userId);
      final followerIds =
          await _socialRepository.getFollowerIds(userId);

      // Obtenir dades dels usuaris seguits
      _following = [];
      for (final id in followingIds) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();
        if (doc.exists) {
          _following.add({'id': id, ...doc.data()!});
        }
      }

      // Obtenir dades dels seguidors
      _followers = [];
      for (final id in followerIds) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();
        if (doc.exists) {
          _followers.add({'id': id, ...doc.data()!});
        }
      }
    } catch (e) {
      debugPrint('Error carregant follow data: $e');
    }
  }
  List<SummitModel> get achievedSummits =>
      _userSummits.where((s) => s.status == SummitStatus.achieved).toList()
        ..sort((a, b) => b.altitude.compareTo(a.altitude));

  List<SummitModel> get savedSummits =>
      _userSummits.where((s) => s.status == SummitStatus.saved).toList()
        ..sort((a, b) => b.altitude.compareTo(a.altitude));
}