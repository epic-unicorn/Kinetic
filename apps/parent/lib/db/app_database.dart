import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [PersonalLists, PersonalTasks, PersonalSubtasks, PartnerProposals],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Open a persistent SQLite file in the app's documents directory.
  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'kinetic_parent',
      native: DriftNativeOptions(
        databaseDirectory: getApplicationDocumentsDirectory,
      ),
    );
  }
}
