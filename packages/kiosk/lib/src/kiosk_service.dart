import 'dart:async';

import 'kiosk_state.dart';

/// Abstraction over Android Lock Task Mode (kiosk lockdown).
///
/// The production implementation [AndroidKioskService] bridges to Kotlin via a
/// Flutter MethodChannel. Tests inject a [FakeKioskService] that manipulates
/// state in-process.
abstract class KioskService {
  /// The current kiosk state.
  KioskState get state;

  /// Stream that emits a new [KioskState] on every transition.
  Stream<KioskState> get stateStream;

  /// Enters Android Lock Task Mode, preventing the user from leaving the app.
  ///
  /// No-op if already locked.
  Future<void> lock();

  /// Exits Android Lock Task Mode.
  ///
  /// No-op if already unlocked.
  Future<void> unlock();

  /// Releases resources (closes the state [StreamController]).
  void dispose();
}
