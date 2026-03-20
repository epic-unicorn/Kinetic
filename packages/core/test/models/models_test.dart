import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_core/kinetic_core.dart';

void main() {
  group('FamilyPlan', () {
    late FamilyMember parent1;
    late FamilyMember child1;
    late FamilyPlan plan;

    setUp(() {
      parent1 = FamilyMember.create(
        publicKeyBase64: 'YWJj',
        name: 'Sarah',
        role: MemberRole.parent,
      );
      child1 = FamilyMember.create(
        publicKeyBase64: 'ZGVm',
        name: 'Alex',
        role: MemberRole.child,
      );
      plan = FamilyPlan.create(
        meshKeyBase64: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        creator: parent1,
      );
    });

    test('create includes only the creator', () {
      expect(plan.members, hasLength(1));
      expect(plan.members.first, equals(parent1));
    });

    test('parents / children accessors filter correctly', () {
      final updated = plan.addMember(child1);
      expect(updated.parents, contains(parent1));
      expect(updated.children, contains(child1));
    });

    test('addMember returns new plan with incremented crdtVersion', () {
      final updated = plan.addMember(child1);

      expect(updated.members, hasLength(2));
      expect(updated.crdtVersion, equals(plan.crdtVersion + 1));
    });

    test('addMember is idempotent', () {
      final once = plan.addMember(child1);
      final twice = once.addMember(child1);
      expect(twice.members, hasLength(2));
      expect(twice.crdtVersion, equals(once.crdtVersion));
    });

    test('toJson / fromJson round-trip', () {
      final updated = plan.addMember(child1);
      final restored = FamilyPlan.fromJson(updated.toJson());

      expect(restored.id, equals(updated.id));
      expect(restored.meshKeyBase64, equals(updated.meshKeyBase64));
      expect(restored.members, hasLength(2));
      expect(restored.crdtVersion, equals(updated.crdtVersion));
    });

    test('original plan is unchanged after addMember (immutability)', () {
      plan.addMember(child1);
      expect(plan.members, hasLength(1));
    });
  });

  group('Task', () {
    test('create sets pending status and correct timestamps', () {
      final task = Task.create(
        familyPlanId: 'plan-1',
        createdById: 'member-1',
        title: 'Clean Room',
        category: TaskCategory.mission,
        xpReward: 50,
      );

      expect(task.status, equals(TaskStatus.pending));
      expect(task.xpReward, equals(50));
      expect(task.category, equals(TaskCategory.mission));
      expect(task.createdAt, equals(task.updatedAt));
    });

    test('copyWith updates status and bumps updatedAt', () async {
      final original = Task.create(
        familyPlanId: 'plan-1',
        createdById: 'member-1',
        title: 'Homework',
        category: TaskCategory.mission,
        xpReward: 30,
      );

      await Future<void>.delayed(const Duration(milliseconds: 2));
      final updated = original.copyWith(status: TaskStatus.pendingApproval);

      expect(updated.status, equals(TaskStatus.pendingApproval));
      expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);
    });

    test('toJson / fromJson round-trip', () {
      final task = Task.create(
        familyPlanId: 'plan-1',
        createdById: 'member-1',
        title: 'Brush Teeth',
        category: TaskCategory.habit,
        xpReward: 0,
      );
      final restored = Task.fromJson(task.toJson());

      expect(restored.id, equals(task.id));
      expect(restored.title, equals(task.title));
      expect(restored.category, equals(task.category));
      expect(restored.xpReward, equals(0));
    });
  });
}
