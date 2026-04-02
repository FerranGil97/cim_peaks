import 'package:flutter/material.dart';
import '../data/models/summit_model.dart';
import '../data/repositories/summit_repository.dart';

enum SummitFilter { all, achieved, pending, saved }
enum AltitudeFilter { all, above3000, between2000and3000, below2000 }

class SummitViewModel extends ChangeNotifier {
  final SummitRepository _repository = SummitRepository();

  List<SummitModel> _allSummits = [];
  SummitFilter _statusFilter = SummitFilter.all;
  AltitudeFilter _altitudeFilter = AltitudeFilter.all;
  bool _isLoading = false;
  bool _initialized = false;

  List<String> _previousBadges = [];
  String? _newBadgeMessage;

  String? get newBadgeMessage => _newBadgeMessage;
  bool get isLoading => _isLoading;
  SummitFilter get statusFilter => _statusFilter;
  AltitudeFilter get altitudeFilter => _altitudeFilter;

  List<SummitModel> get filteredSummits {
    return _allSummits.where((summit) {
      final statusOk = switch (_statusFilter) {
        SummitFilter.all => true,
        SummitFilter.achieved => summit.status == SummitStatus.achieved,
        SummitFilter.pending => summit.status == SummitStatus.pending,
        SummitFilter.saved => summit.status == SummitStatus.saved,
      };
      final altitudeOk = switch (_altitudeFilter) {
        AltitudeFilter.all => true,
        AltitudeFilter.above3000 => summit.altitude >= 3000,
        AltitudeFilter.between2000and3000 =>
          summit.altitude >= 2000 && summit.altitude < 3000,
        AltitudeFilter.below2000 => summit.altitude < 2000,
      };
      return statusOk && altitudeOk;
    }).toList();
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
}