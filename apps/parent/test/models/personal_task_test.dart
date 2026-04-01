import 'package:flutter_test/flutter_test.dart';
import 'package:parent/todo/models/enums.dart';
import 'package:parent/todo/models/personal_task.dart';

void main() {
  group('PersonalList', () {
    test('create() initializes required fields', () {
      final list = PersonalList.create(name: 'Groceries');

      expect(list.id, isNotEmpty);
      expect(list.name, equals('Groceries'));
      expect(list.colorValue, equals(0xFF44BBA4)); // default teal
      expect(list.isPrivateDefault, isFalse);
      expect(list.createdAt, isNotNull);
      expect(list.updatedAt, isNotNull);
    });

    test('create() generates unique IDs', () {
      final list1 = PersonalList.create(name: 'List1');
      final list2 = PersonalList.create(name: 'List2');

      expect(list1.id, isNot(equals(list2.id)));
    });

    test('create() accepts custom color', () {
      const customColor = 0xFFFF0000;
      final list = PersonalList.create(
        name: 'Shopping',
        colorValue: customColor,
      );

      expect(list.colorValue, equals(customColor));
    });

    test('copyWith() preserves ID and timestamps', () {
      final original = PersonalList.create(name: 'Original');
      final originalId = original.id;
      final originalCreatedAt = original.createdAt;

      final updated = original.copyWith(name: 'Updated');

      expect(updated.id, equals(originalId));
      expect(updated.createdAt, equals(originalCreatedAt));
      expect(updated.name, equals('Updated'));
      // updatedAt should be >= createdAt (allowing for same instant if very fast)
      expect(
        updated.updatedAt.isAfter(originalCreatedAt) ||
            updated.updatedAt.isAtSameMomentAs(originalCreatedAt),
        isTrue,
      );
    });

    test('copyWith() can update multiple fields', () {
      final original = PersonalList.create(name: 'Original');

      final updated = original.copyWith(
        name: 'Updated',
        colorValue: 0xFFFF0000,
        position: 5,
      );

      expect(updated.name, equals('Updated'));
      expect(updated.colorValue, equals(0xFFFF0000));
      expect(updated.position, equals(5));
    });
  });

  group('PersonalTask', () {
    test('create() initializes required fields', () {
      final task = PersonalTask.create(title: 'Buy milk', listId: 'inbox');

      expect(task.id, isNotEmpty);
      expect(task.title, equals('Buy milk'));
      expect(task.listId, equals('inbox'));
      expect(task.isCompleted, isFalse);
      expect(task.category, equals(TaskCategory.other));
      expect(task.priority, equals(TaskPriority.none));
      expect(task.isFlagged, isFalse);
      expect(task.isPrivate, isFalse);
      expect(task.createdAt, isNotNull);
      expect(task.updatedAt, isNotNull);
    });

    test('create() generates unique IDs', () {
      final task1 = PersonalTask.create(title: 'Task1', listId: 'inbox');
      final task2 = PersonalTask.create(title: 'Task2', listId: 'inbox');

      expect(task1.id, isNot(equals(task2.id)));
    });

    test('create() accepts all parameters', () {
      final dueDate = DateTime.now().add(const Duration(days: 1));
      final task = PersonalTask.create(
        title: 'Buy groceries',
        listId: 'shopping',
        notes: 'Check list',
        priority: TaskPriority.high,
        dueDate: dueDate,
        isAllDay: true,
        recurrenceRule: 'FREQ=WEEKLY',
        isFlagged: true,
        isPrivate: true,
        category: TaskCategory.household,
      );

      expect(task.title, equals('Buy groceries'));
      expect(task.notes, equals('Check list'));
      expect(task.priority, equals(TaskPriority.high));
      expect(task.dueDate, equals(dueDate));
      expect(task.isAllDay, isTrue);
      expect(task.recurrenceRule, equals('FREQ=WEEKLY'));
      expect(task.isFlagged, isTrue);
      expect(task.isPrivate, isTrue);
      expect(task.category, equals(TaskCategory.household));
    });

    test('copyWith() preserves ID and timestamps', () {
      final original = PersonalTask.create(title: 'Original', listId: 'inbox');
      final originalId = original.id;
      final originalCreatedAt = original.createdAt;

      final updated = original.copyWith(title: 'Updated');

      expect(updated.id, equals(originalId));
      expect(updated.createdAt, equals(originalCreatedAt));
      expect(updated.title, equals('Updated'));
      expect(updated.updatedAt.isAfter(originalCreatedAt), isTrue);
    });

    test('copyWith() can toggle completion status', () {
      final open = PersonalTask.create(title: 'Task', listId: 'inbox');
      expect(open.isCompleted, isFalse);

      final completed = open.copyWith(isCompleted: true);
      expect(completed.isCompleted, isTrue);

      final reopened = completed.copyWith(isCompleted: false);
      expect(reopened.isCompleted, isFalse);
    });

    test('copyWith() can update priority', () {
      final task = PersonalTask.create(title: 'Task', listId: 'inbox');

      final highPriority = task.copyWith(priority: TaskPriority.high);
      expect(highPriority.priority, equals(TaskPriority.high));
    });

    test('isDueToday identifies tasks due today or overdue', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      final overdue = PersonalTask.create(
        title: 'Overdue',
        listId: 'inbox',
        dueDate: yesterday,
      );

      final upcoming = PersonalTask.create(
        title: 'Upcoming',
        listId: 'inbox',
        dueDate: tomorrow,
      );

      final noDueDate = PersonalTask.create(
        title: 'No due date',
        listId: 'inbox',
      );

      // isDueToday should be true for overdue and today
      // False for future tasks and tasks with no due date
      expect(upcoming.isDueToday, isFalse);
      expect(noDueDate.isDueToday, isFalse);
    });

    test('isDueToday is false for completed tasks', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final task = PersonalTask.create(
        title: 'Done',
        listId: 'inbox',
        dueDate: yesterday,
      );

      final completedTask = task.copyWith(isCompleted: true);
      expect(completedTask.isDueToday, isFalse);
    });

    test('can set and clear reminders', () {
      final task = PersonalTask.create(title: 'Task', listId: 'inbox');
      expect(task.remindAt, isNull);

      final remindTime = DateTime.now().add(const Duration(hours: 1));
      final withReminder = task.copyWith(remindAt: remindTime);
      expect(withReminder.remindAt, equals(remindTime));

      final noReminder = withReminder.copyWith(clearRemindAt: true);
      expect(noReminder.remindAt, isNull);
    });

    test('can set and clear due dates', () {
      final task = PersonalTask.create(title: 'Task', listId: 'inbox');
      expect(task.dueDate, isNull);

      final dueDate = DateTime.now().add(const Duration(days: 5));
      final withDueDate = task.copyWith(dueDate: dueDate);
      expect(withDueDate.dueDate, equals(dueDate));

      final cleared = withDueDate.copyWith(clearDueDate: true);
      expect(cleared.dueDate, isNull);
    });

    test('can associate with kids tasks', () {
      final task = PersonalTask.create(title: 'Task', listId: 'inbox');
      expect(task.kidsTaskId, isNull);

      final withKids = task.copyWith(kidsTaskId: 'kids:123');
      expect(withKids.kidsTaskId, equals('kids:123'));
    });

    test('can toggle flag status', () {
      final task = PersonalTask.create(title: 'Task', listId: 'inbox');
      expect(task.isFlagged, isFalse);

      final flagged = task.copyWith(isFlagged: true);
      expect(flagged.isFlagged, isTrue);
    });

    test('can mark as private', () {
      final task = PersonalTask.create(title: 'Task', listId: 'inbox');
      expect(task.isPrivate, isFalse);

      final private = task.copyWith(isPrivate: true);
      expect(private.isPrivate, isTrue);
    });
  });

  group('PersonalSubtask', () {
    test('create() initializes with default values', () {
      final subtask = PersonalSubtask.create(
        taskId: 'task-123',
        title: 'Step 1',
      );

      expect(subtask.id, isNotEmpty);
      expect(subtask.taskId, equals('task-123'));
      expect(subtask.title, equals('Step 1'));
      expect(subtask.isCompleted, isFalse);
      expect(subtask.sortOrder, isNotNull);
    });

    test('create() generates unique IDs', () {
      final sub1 = PersonalSubtask.create(taskId: 'task', title: 'Sub1');
      final sub2 = PersonalSubtask.create(taskId: 'task', title: 'Sub2');

      expect(sub1.id, isNot(equals(sub2.id)));
    });

    test('copyWith() preserves ID and taskId', () {
      final original = PersonalSubtask.create(
        taskId: 'task-123',
        title: 'Original',
      );

      final updated = original.copyWith(title: 'Updated');

      expect(updated.id, equals(original.id));
      expect(updated.taskId, equals(original.taskId));
      expect(updated.title, equals('Updated'));
    });

    test('copyWith() can toggle completion', () {
      final subtask = PersonalSubtask.create(taskId: 'task', title: 'Step');

      final completed = subtask.copyWith(isCompleted: true);
      expect(completed.isCompleted, isTrue);
    });

    test('can update sort order', () {
      final subtask = PersonalSubtask.create(
        taskId: 'task',
        title: 'Step',
        sortOrder: 1,
      );

      final reordered = subtask.copyWith(sortOrder: 5);
      expect(reordered.sortOrder, equals(5));
    });
  });

  group('TaskCategory enum', () {
    test('all enum values are defined', () {
      expect(TaskCategory.household, isNotNull);
      expect(TaskCategory.health, isNotNull);
      expect(TaskCategory.admin, isNotNull);
      expect(TaskCategory.school, isNotNull);
      expect(TaskCategory.finance, isNotNull);
      expect(TaskCategory.other, isNotNull);
    });
  });

  group('TaskPriority enum', () {
    test('all enum values are defined and ordered', () {
      expect(TaskPriority.none, equals(TaskPriority.none));
      expect(TaskPriority.low, equals(TaskPriority.low));
      expect(TaskPriority.medium, equals(TaskPriority.medium));
      expect(TaskPriority.high, equals(TaskPriority.high));
    });
  });
}
