import 'package:drift/native.dart';
import 'package:parent/db/app_database.dart';

/// Creates an in-memory Drift database for testing.
/// Each call creates a fresh isolated database.
AppDatabase createTestDatabase() {
  return AppDatabase.withExecutor(NativeDatabase.memory());
}
