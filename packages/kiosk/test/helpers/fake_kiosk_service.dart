import 'dart:async';

import 'package:kinetic_kiosk/kinetic_kiosk.dart';

/// In-process [KioskService] for unit tests — no method channel required.
class FakeKioskService implements KioskService {
  final StreamController<KioskState> _controller =
      StreamController<KioskState>.broadcast();

  KioskState _state = const KioskState.unlocked();

  /// If set to true, the next [lock] / [unlock] call will emit an error state
  /// and throw, simulating a platform failure.
  bool failNextCall = false;

  @override
  KioskState get state => _state;

  @override
  Stream<KioskState> get stateStream => _controller.stream;

  @override
  Future<void> lock() async {
    if (failNextCall) {
      failNextCall = false;
      _emit(const KioskState.error('simulated lock failure'));
      return;
    }
    if (_state.isLocked) return;
    _emit(const KioskState.locked());
  }

  @override
  Future<void> unlock() async {
    if (failNextCall) {
      failNextCall = false;
      _emit(const KioskState.error('simulated unlock failure'));
      return;
    }
    if (!_state.isLocked) return;
    _emit(const KioskState.unlocked());
  }

  void _emit(KioskState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  void dispose() => _controller.close();
}
