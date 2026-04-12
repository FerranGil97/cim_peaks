import 'package:flutter/material.dart';
import '../data/models/summit_model.dart';
import '../data/repositories/summit_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/models/notification_model.dart';
import 'dart:math';

enum SummitFilter { all, achieved, pending, saved }

enum AltitudeFilter {
  none,
  below1000,
  from1000to1500,
  from1500to2000,
  from2000to2500,
  from2500to3000,
  above3000,
}

class SummitViewModel extends ChangeNotifier {
  final SummitRepository _repository = SummitRepository();

  List<SummitModel> get allSummits => _allSummits;
  List<SummitModel> _allSummits = [];
  SummitFilter _statusFilter = SummitFilter.all;
  AltitudeFilter _altitudeFilter = AltitudeFilter.none;
  bool _isLoading = false;
  bool _initialized = false;

  List<String> _previousBadges = [];
  String? _newBadgeMessage;

  String? get newBadgeMessage => _newBadgeMessage;
  bool get isLoading => _isLoading;
  SummitFilter get statusFilter => _statusFilter;
  AltitudeFilter get altitudeFilter => _altitudeFilter;

  // Retorna true si hi ha algun filtre actiu
  bool get hasActiveFilter => _altitudeFilter != AltitudeFilter.none;

  // Màxim de marcadors visibles
  static const int _maxMarkers = 500;

  List<SummitModel> get filteredSummits {
    // Si no hi ha filtre d'altitud actiu, no mostrar res
    if (_altitudeFilter == AltitudeFilter.none) return [];

    var results = _allSummits.where((summit) {
      // Filtre per estat
      final statusOk = switch (_statusFilter) {
        SummitFilter.all => true,
        SummitFilter.achieved => summit.status == SummitStatus.achieved,
        SummitFilter.pending => summit.status == SummitStatus.pending,
        SummitFilter.saved => summit.status == SummitStatus.saved,
      };

      // Filtre per altitud
      final altitudeOk = switch (_altitudeFilter) {
        AltitudeFilter.none => false,
        AltitudeFilter.below1000 => summit.altitude < 1000,
        AltitudeFilter.from1000to1500 =>
          summit.altitude >= 1000 && summit.altitude < 1500,
        AltitudeFilter.from1500to2000 =>
          summit.altitude >= 1500 && summit.altitude < 2000,
        AltitudeFilter.from2000to2500 =>
          summit.altitude >= 2000 && summit.altitude < 2500,
        AltitudeFilter.from2500to3000 =>
          summit.altitude >= 2500 && summit.altitude < 3000,
        AltitudeFilter.above3000 => summit.altitude >= 3000,
      };

      return statusOk && altitudeOk;
    }).toList();

    // Limitar a _maxMarkers per evitar que peti
    if (results.length > _maxMarkers) {
      results = results.sublist(0, _maxMarkers);
    }

    return results;
  }

  int get totalFilteredCount {
    if (_altitudeFilter == AltitudeFilter.none) return 0;
    return _allSummits.where((summit) {
      final statusOk = switch (_statusFilter) {
        SummitFilter.all => true,
        SummitFilter.achieved => summit.status == SummitStatus.achieved,
        SummitFilter.pending => summit.status == SummitStatus.pending,
        SummitFilter.saved => summit.status == SummitStatus.saved,
      };
      final altitudeOk = switch (_altitudeFilter) {
        AltitudeFilter.none => false,
        AltitudeFilter.below1000 => summit.altitude < 1000,
        AltitudeFilter.from1000to1500 =>
          summit.altitude >= 1000 && summit.altitude < 1500,
        AltitudeFilter.from1500to2000 =>
          summit.altitude >= 1500 && summit.altitude < 2000,
        AltitudeFilter.from2000to2500 =>
          summit.altitude >= 2000 && summit.altitude < 2500,
        AltitudeFilter.from2500to3000 =>
          summit.altitude >= 2500 && summit.altitude < 3000,
        AltitudeFilter.above3000 => summit.altitude >= 3000,
      };
      return statusOk && altitudeOk;
    }).length;
  }

  void loadSummits(String userId) {
    _isLoading = true;
    notifyListeners();
    _repository.getUserSummitsWithGlobal(userId).listen((summits) {
      _allSummits = summits;
      if (!_initialized) {
        _previousBadges = _calculateBadges(summits);
        _initialized = true;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  void setStatusFilter(SummitFilter filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  void setAltitudeFilter(AltitudeFilter filter) {
    _altitudeFilter = filter;
    notifyListeners();
  }

  Future<void> updateSummitStatus(
      String userId, String summitId, SummitStatus status) async {
    await _repository.updateSummitStatus(userId, summitId, status);

    final index = _allSummits.indexWhere((s) => s.id == summitId);
    if (index != -1) {
      _allSummits[index] = _allSummits[index].copyWith(
        status: status,
        achievedAt: status == SummitStatus.achieved ? DateTime.now() : null,
      );

      if (status == SummitStatus.achieved) {
        final newBadges = _calculateBadges(_allSummits);
        final earnedBadge = newBadges.firstWhere(
          (b) => !_previousBadges.contains(b),
          orElse: () => '',
        );

        if (earnedBadge.isNotEmpty) {
          _newBadgeMessage = '🏅 Nova medalla: $earnedBadge';
          _previousBadges = newBadges;

          final notifRepo = NotificationRepository();
          await notifRepo.createNotification(NotificationModel(
            id: '',
            userId: userId,
            type: NotificationType.medal,
            title: '🏅 Nova medalla!',
            body: 'Has aconseguit la medalla: $earnedBadge',
            createdAt: DateTime.now(),
          ));
        }
      }

      notifyListeners();
    }
  }

  void clearNotifications() {
    _newBadgeMessage = null;
    notifyListeners();
  }

  List<String> _calculateBadges(List<SummitModel> summits) {
    final achieved =
        summits.where((s) => s.status == SummitStatus.achieved).length;
    final maxAltitude = summits
        .where((s) => s.status == SummitStatus.achieved)
        .fold(0, (max, s) => s.altitude > max ? s.altitude : max);
    final savedCount =
        summits.where((s) => s.status == SummitStatus.saved).length;
    final pirineusAchieved = summits
        .where((s) =>
            s.status == SummitStatus.achieved &&
            (s.massif ?? '').contains('Pirineu'))
        .length;
    final above2500Achieved = summits
        .where((s) => s.status == SummitStatus.achieved && s.altitude >= 2500)
        .length;

    final List<String> badges = [];
    if (achieved >= 1) badges.add('Primer Cim');
    if (achieved >= 5) badges.add('Explorador');
    if (achieved >= 10) badges.add('Àguila');
    if (achieved >= 25) badges.add('Campió');
    if (maxAltitude >= 3000) badges.add('Tres Mil');
    if (achieved >= 50) badges.add('Llegenda');
    if (savedCount >= 10) badges.add('Cartògraf');
    if (pirineusAchieved >= 3) badges.add('Madrugador');
    if (above2500Achieved >= 5) badges.add('Escalador');
    return badges;
  }
  List<Map<String, dynamic>> getSummitsNearLocation(
      double lat, double lon, double radiusKm) {
    final results = <Map<String, dynamic>>[];

    for (final summit in _allSummits) {
      final distance = _calculateDistance(
          lat, lon, summit.latitude, summit.longitude);
      if (distance <= radiusKm) {
        results.add({'summit': summit, 'distance': distance});
      }
    }

    results.sort((a, b) =>
        (a['distance'] as double).compareTo(b['distance'] as double));
    return results;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}