import 'package:flutter/foundation.dart';

import '../../db/app_database.dart';
import '../models/family_load_metrics.dart';
import '../services/load_analyzer.dart';
import '../services/load_sync_service.dart';

/// PartnerLoadRepository — family workload metrics tracking.
///
/// Manages synchronization and display of family workload to help with
/// fair task distribution and load balancing.
class PartnerLoadRepository extends ChangeNotifier {
  LoadSyncService? _loadService;
  late final LoadAnalyzer _analyzer;

  List<FamilyLoadMetrics> _familyLoad = [];

  PartnerLoadRepository({
    required AppDatabase db,
    LoadSyncService? loadService,
  })  : _loadService = loadService {
    _analyzer = LoadAnalyzer(db: db);
  }

  /// Family load metrics (all parents' current workload).
  List<FamilyLoadMetrics> get familyLoad => _familyLoad;

  /// Set the load service (call after WebDAV setup).
  void setLoadService(LoadSyncService service) {
    _loadService = service;
  }

  /// Fetch latest family load metrics from WebDAV.
  Future<void> refreshFamilyLoad() async {
    if (_loadService == null) {
      debugPrint('LoadSyncService not initialized');
      return;
    }
    try {
      final loadMap = await _loadService!.pullFamilyLoad();
      _familyLoad = loadMap.values.toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing family load: $e');
    }
  }

  /// Push this device's user's current load metrics.
  Future<void> pushMyLoad(String userId, String userName) async {
    if (_loadService == null) {
      debugPrint('LoadSyncService not initialized');
      return;
    }
    try {
      await _loadService!.pushMyLoad(userId, userName);
      await refreshFamilyLoad();
      notifyListeners();
    } catch (e) {
      debugPrint('Error pushing my load: $e');
    }
  }

  /// Check if current user has capacity for more proposals.
  Future<bool> hasCapacity(int maxFamilyTaskCount) async {
    return _analyzer.hasCapacityForMoreProposals(maxFamilyTaskCount);
  }
}
