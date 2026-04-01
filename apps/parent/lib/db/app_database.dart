import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.drift.dart';

@DriftDatabase(
  tables: [
    PersonalLists,
    PersonalTasks,
    PersonalNotes,
    PersonalSubtasks,
    PartnerProposals,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(personalTasks, personalTasks.remindAt);
      }
      if (from < 3) {
        await m.addColumn(personalTasks, personalTasks.webdavEtag);
        await m.addColumn(personalTasks, personalTasks.syncState);
        await m.createTable(personalNotes);
      }
    },
  );

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
