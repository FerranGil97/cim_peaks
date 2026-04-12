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
        'name': 'Madrugador',
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
      // Carregar dades de l'usuari
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        _user = UserModel.fromFirestore(userDoc.data()!, userId);
      }

      // Carregar cims de l'usuari
      final summitsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('user_summits')
          .get();

      final List<SummitModel> summits = [];
      for (final doc in summitsSnapshot.docs) {
        final globalDoc = await FirebaseFirestore.instance
            .collection('summits')
            .doc(doc.id)
            .get();
        if (globalDoc.exists) {
          final data = globalDoc.data()!;
          data['status'] = doc.data()['status'];
          data['achievedAt'] = doc.data()['achievedAt'];
          summits.add(SummitModel.fromFirestore(data, doc.id));
        }
      }
      _userSummits = summits;

      // Carregar seguits i seguidors
      await _loadFollowData(userId);
    } catch (e) {
      debugPrint('Error carregant perfil: $e');
    }

    _isLoading = false;
    notifyListeners();
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