import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_kiosk/kinetic_kiosk.dart';

import 'helpers/fake_kiosk_service.dart';

void main() {
  late FakeKioskService sut;

  setUp(() => sut = FakeKioskService());
  tearDown(() => sut.dispose());

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  group('KioskState initial', () {
    test('starts unlocked', () {
      expect(sut.state.lockState, equals(KioskLockState.unlocked));
      expect(sut.state.isLocked, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // lock()
  // -------------------------------------------------------------------------

  group('KioskService.lock', () {
    test('transitions to locked state', () async {
      await sut.lock();
      expect(sut.state.lockState, equals(KioskLockState.locked));
      expect(sut.state.isLocked, isTrue);
    });

    test('emits locked event on stateStream', () async {
      final future = sut.stateStream.first;
      await sut.lock();
      final emitted = await future;
      expect(emitted.lockState, equals(KioskLockState.locked));
    });

    test('is idempotent — second lock call does not emit', () async {
      await sut.lock();

      var extraEmissions = 0;
      sut.stateStream.listen((_) => extraEmissions++);

      await sut.lock(); // second call — should be a no-op
      await Future<void>.delayed(Duration.zero);

      expect(extraEmissions, equals(0));
    });

    test('emits error state on platform failure', () async {
      sut.failNextCall = true;
      await sut.lock();
      expect(sut.state.lockState, equals(KioskLockState.error));
      expect(sut.state.errorMessage, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // unlock()
  // -------------------------------------------------------------------------

  group('KioskService.unlock', () {
    test('transitions from locked to unlocked', () async {
      await sut.lock();
      await sut.unlock();
      expect(sut.state.lockState, equals(KioskLockState.unlocked));
      expect(sut.state.isLocked, isFalse);
    });

    test('emits unlocked event on stateStream', () async {
      await sut.lock();
      final future = sut.stateStream.first;
      await sut.unlock();
      final emitted = await future;
      expect(emitted.lockState, equals(KioskLockState.unlocked));
    });

    test('is idempotent — unlock when already unlocked does not emit',
        () async {
      var emissions = 0;
      sut.stateStream.listen((_) => emissions++);

      await sut.unlock(); // already unlocked — no-op
      await Future<void>.delayed(Duration.zero);

      expect(emissions, equals(0));
    });

    test('emits error state on platform failure', () async {
      await sut.lock();
      sut.failNextCall = true;
      await sut.unlock();
      expect(sut.state.lockState, equals(KioskLockState.error));
    });
  });

  // -------------------------------------------------------------------------
  // KioskState model
  // -------------------------------------------------------------------------

  group('KioskState', () {
    test('unlocked factory sets correct fields', () {
      const s = KioskState.unlocked();
      expect(s.lockState, KioskLockState.unlocked);
      expect(s.isLocked, isFalse);
      expect(s.errorMessage, isNull);
    });

    test('locked factory sets correct fields', () {
      const s = KioskState.locked();
      expect(s.lockState, KioskLockState.locked);
      expect(s.isLocked, isTrue);
    });

    test('error factory stores message', () {
      const s = KioskState.error('oops');
      expect(s.lockState, KioskLockState.error);
      expect(s.errorMessage, equals('oops'));
      expect(s.isLocked, isFalse);
    });

    test('equality holds for same fields (Equatable)', () {
      expect(
        const KioskState.locked(),
        equals(const KioskState.locked()),
      );
      expect(
        const KioskState.error('msg'),
        equals(const KioskState.error('msg')),
      );
      expect(
        const KioskState.locked(),
        isNot(equals(const KioskState.unlocked())),
      );
    });
  });
}
