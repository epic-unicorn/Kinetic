import '../../todo/models/enums.dart';

// ---------------------------------------------------------------------------
// LoadSnapshot — computed load for one parent (scores only, no task content).
//
// Scoring: high=4.0  medium=2.0  low=1.0  none=0.5
// Urgency boost: overdue +2.0, due today +1.0.
// ---------------------------------------------------------------------------

class LoadSnapshot {
  final double total;
  final Map<TaskCategory, double> perCategory;

  const LoadSnapshot({required this.total, required this.perCategory});

  factory LoadSnapshot.empty() => LoadSnapshot(
    total: 0,
    perCategory: {for (final c in TaskCategory.values) c: 0.0},
  );
}

// ---------------------------------------------------------------------------
// ParentLoadDoc — synced CouchDB document.
//
// C3 privacy model: only aggregate scores are shared, never task titles.
// ---------------------------------------------------------------------------

class ParentLoadDoc {
  static const docType = 'parent_load';

  final String deviceId;
  final LoadSnapshot snapshot;
  final DateTime updatedAt;

  const ParentLoadDoc({
    required this.deviceId,
    required this.snapshot,
    required this.updatedAt,
  });

  String get docId => 'parent_load_$deviceId';

  Map<String, dynamic> toJson() => {
    '_id': docId,
    'type': docType,
    'deviceId': deviceId,
    'total': snapshot.total,
    'categories': {
      for (final e in snapshot.perCategory.entries) e.key.name: e.value,
    },
    'updatedAt': updatedAt.toIso8601String(),
  };

  static ParentLoadDoc? fromJson(Map<String, dynamic> json) {
    try {
      if (json['type'] != docType) return null;
      final cats = (json['categories'] as Map?)?.cast<String, dynamic>() ?? {};
      final perCat = <TaskCategory, double>{};
      for (final c in TaskCategory.values) {
        perCat[c] = (cats[c.name] as num?)?.toDouble() ?? 0.0;
      }
      return ParentLoadDoc(
        deviceId: json['deviceId'] as String,
        snapshot: LoadSnapshot(
          total: (json['total'] as num).toDouble(),
          perCategory: perCat,
        ),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}
