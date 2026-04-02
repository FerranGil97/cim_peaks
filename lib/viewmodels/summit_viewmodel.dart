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

  List<SummitModel> get filteredSummits {
    return _allSummits.where((summit) {
      // Filtre per estat
      final statusOk = switch (_statusFilter) {
        SummitFilter.all => true,
        SummitFilter.achieved => summit.status == SummitStatus.achieved,
        SummitFilter.pending => summit.status == SummitStatus.pending,
        SummitFilter.saved => summit.status == SummitStatus.saved,
      };

      // Filtre per altitud
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

  SummitFilter get statusFilter => _statusFilter;
  AltitudeFilter get altitudeFilter => _altitudeFilter;
  bool get isLoading => _isLoading;

  void loadSummits(String userId) {
    _isLoading = true;
    notifyListeners();
    _repository.getUserSummitsWithGlobal(userId).listen((summits) {
      _allSummits = summits;
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
  }
}