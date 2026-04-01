import '../models/family_load_metrics.dart';
import 'load_analyzer.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

/// LoadSyncService — manages family load metrics sync via WebDAV.
///
/// Load metrics are JSON snapshots of each parent's task workload,
/// stored at `/kinetic/shared/load/{parentId}.json` (encrypted with family key).
class LoadSyncService {
  final WebDavSyncService service;
  final LoadAnalyzer analyzer;

  LoadSyncService({required this.service, required this.analyzer});

  /// Calculate and push the current user's load metrics to the server.
  Future<void> pushMyLoad(String userId, String userName) async {
    final metrics = await analyzer.getMyLoad(userId, userName);
    final json = _metricsToJson(metrics);
    await service.pushLoadMetrics(json);
  }

  /// Pull all family members' load metrics from the server.
  Future<Map<String, FamilyLoadMetrics>> pullFamilyLoad() async {
    final jsons = await service.pullLoadMetrics();
    final result = <String, FamilyLoadMetrics>{};

    for (final json in jsons) {
      final metrics = _jsonToMetrics(json);
      result[metrics.parentId] = metrics;
    }
    return result;
  }

  /// Sync load metrics: push self, then pull family.
  Future<Map<String, FamilyLoadMetrics>> syncLoad(
    String userId,
    String userName,
  ) async {
    // Push self load
    await pushMyLoad(userId, userName);

    // Pull family load
    return pullFamilyLoad();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _metricsToJson(FamilyLoadMetrics metrics) {
    return {
      'parentId': metrics.parentId,
      'parentName': metrics.parentName,
      'taskCount': metrics.taskCount,
      'urgentCount': metrics.urgentCount,
      'tasksByCategory': metrics.tasksByCategory,
      'calculatedAt': metrics.calculatedAt.toIso8601String(),
    };
  }

  FamilyLoadMetrics _jsonToMetrics(Map<String, dynamic> json) {
    return FamilyLoadMetrics(
      parentId: json['parentId'] as String,
      parentName: json['parentName'] as String,
      taskCount: json['taskCount'] as int,
      urgentCount: json['urgentCount'] as int,
      tasksByCategory: Map<String, int>.from(json['tasksByCategory'] as Map),
      calculatedAt: DateTime.parse(json['calculatedAt'] as String),
    );
  }
}
