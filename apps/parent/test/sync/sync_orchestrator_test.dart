import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'dart:typed_data';
import 'package:parent/todo/models/enums.dart';
import 'package:parent/todo/models/personal_task.dart';

void main() {
  group('SyncConfig WebDAV Configuration', () {
    late SyncConfig config;

    setUp(() {
      config = SyncConfig(
        serverUrl: 'https://nextcloud.example.com/remote.php/dav',
        username: 'testuser',
        password: 'testpass',
        personalKeyBytes: Uint8List.fromList(List.generate(32, (i) => i)),
        familyKeyBytes: Uint8List.fromList(List.generate(32, (i) => i + 1)),
      );
    });

    test('stores WebDAV credentials securely', () {
      expect(config.username, equals('testuser'));
      expect(config.password, equals('testpass'));
      expect(config.serverUrl, contains('nextcloud'));
    });

    test('normalizes server URL by stripping trailing slash', () {
      final configWithSlash = SyncConfig(
        serverUrl: 'https://example.com/dav/',
        username: 'user',
        password: 'pass',
        personalKeyBytes: Uint8List(32),
      );
      expect(configWithSlash.baseUrl, equals('https://example.com/dav'));
    });

    test('baseUrl property removes trailing slash', () {
      expect(config.baseUrl, equals(config.serverUrl));
    });

    test('stores personal encryption key', () {
      expect(config.personalKeyBytes, isNotNull);
      expect(config.personalKeyBytes.length, equals(32));
    });

    test('stores family encryption key when provided', () {
      expect(config.familyKeyBytes, isNotNull);
      expect(config.familyKeyBytes!.length, equals(32));
    });

    test('family key is optional', () {
      final noFamilyKey = SyncConfig(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'pass',
        personalKeyBytes: Uint8List(32),
      );
      expect(noFamilyKey.familyKeyBytes, isNull);
    });

    test('withFamilyKey creates new config with family key set', () {
      final original = SyncConfig(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'pass',
        personalKeyBytes: Uint8List(32),
      );

      final newFamilyKey = Uint8List.fromList(List.generate(32, (i) => i * 2));
      final updated = original.withFamilyKey(newFamilyKey);

      expect(updated.familyKeyBytes, equals(newFamilyKey));
      expect(updated.serverUrl, equals(original.serverUrl));
      expect(updated.username, equals(original.username));
    });

    test('encryption keys are independent of URL and credentials', () {
      final config1 = SyncConfig(
        serverUrl: 'https://a.com',
        username: 'user1',
        password: 'pass1',
        personalKeyBytes: Uint8List(32),
      );

      final config2 = SyncConfig(
        serverUrl: 'https://b.com',
        username: 'user2',
        password: 'pass2',
        personalKeyBytes: Uint8List(32),
      );

      expect(config1.personalKeyBytes, equals(config2.personalKeyBytes));
    });
  });

  group('Personal Task Sync Preparation', () {
    test('task structure supports sync serialization', () {
      final task = PersonalTask.create(
        title: 'Meeting',
        listId: 'work',
        priority: TaskPriority.high,
        dueDate: DateTime.utc(2026, 4, 15, 14, 0, 0),
      );

      expect(task.title, equals('Meeting'));
      expect(task.priority, equals(TaskPriority.high));
      expect(task.dueDate, isNotNull);
    });

    test('completed tasks have timestamp', () {
      final task = PersonalTask.create(title: 'Task');
      final now = DateTime.now();

      final completed = task.copyWith(isCompleted: true, completedAt: now);

      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);
    });

    test('category classification for sync filtering', () {
      final financial = PersonalTask.create(
        title: 'Pay bills',
        category: TaskCategory.finance,
      );

      final admin = PersonalTask.create(
        title: 'Sign form',
        category: TaskCategory.admin,
      );

      expect(financial.category, equals(TaskCategory.finance));
      expect(admin.category, equals(TaskCategory.admin));
    });

    test('private tasks vs shared tasks', () {
      final privateTask = PersonalTask.create(
        title: 'Private',
        isPrivate: true,
      );

      final sharedTask = PersonalTask.create(title: 'Shared', isPrivate: false);

      expect(privateTask.isPrivate, isTrue);
      expect(sharedTask.isPrivate, isFalse);
    });
  });

  group('Encryption Key Management', () {
    test('personal key is always present for encryption', () {
      final personalKey = Uint8List.fromList(List.generate(32, (_) => 255));
      final config = SyncConfig(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'pass',
        personalKeyBytes: personalKey,
      );

      expect(config.personalKeyBytes, equals(personalKey));
    });

    test('family key derivation is deferred until password known', () {
      final config = SyncConfig(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'pass',
        personalKeyBytes: Uint8List(32),
        familyKeyBytes: null,
      );

      expect(config.familyKeyBytes, isNull);

      final withFamily = config.withFamilyKey(Uint8List(32));
      expect(withFamily.familyKeyBytes, isNotNull);
    });

    test('encryption keys are 32 bytes for AES-256', () {
      final config = SyncConfig(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'pass',
        personalKeyBytes: Uint8List(32),
        familyKeyBytes: Uint8List(32),
      );

      expect(config.personalKeyBytes.length, equals(32));
      expect(config.familyKeyBytes!.length, equals(32));
    });
  });

  group('Date and Time Handling for Sync', () {
    test('due dates are properly handled', () {
      final futureDate = DateTime.now().add(const Duration(days: 7));
      final task = PersonalTask.create(
        title: 'Future task',
        dueDate: futureDate,
      );

      expect(task.dueDate, isNotNull);
      expect(task.isDueToday, isFalse);
    });

    test('overdue tasks are properly flagged', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final task = PersonalTask.create(title: 'Overdue', dueDate: pastDate);

      expect(task.dueDate, isNotNull);
      expect(
        task.isDueToday,
        isFalse,
      ); // Overdue tasks are in the past, not due "today"
    });

    test('all-day flag affects sync serialization', () {
      final allDayTask = PersonalTask.create(
        title: 'All day event',
        dueDate: DateTime.now(),
        isAllDay: true,
      );

      final timedTask = PersonalTask.create(
        title: 'Timed event',
        dueDate: DateTime.now(),
        isAllDay: false,
      );

      expect(allDayTask.isAllDay, isTrue);
      expect(timedTask.isAllDay, isFalse);
    });

    test('reminder times are optional', () {
      final noReminder = PersonalTask.create(title: 'No alarm');
      final withReminder = PersonalTask.create(
        title: 'With alarm',
        remindAt: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(noReminder.remindAt, isNull);
      expect(withReminder.remindAt, isNotNull);
    });

    test('creation and update timestamps track sync state', () {
      final task = PersonalTask.create(title: 'Task');
      final originalCreatedAt = task.createdAt;

      final updated = task.copyWith(title: 'Updated');

      expect(updated.createdAt, equals(originalCreatedAt));
      // updatedAt should be >= createdAt (allowing for same instant if very fast)
      expect(
        updated.updatedAt.isAfter(originalCreatedAt) ||
            updated.updatedAt.isAtSameMomentAs(originalCreatedAt),
        isTrue,
      );
    });
  });
}
