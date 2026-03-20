import 'package:equatable/equatable.dart';

/// Whether the device is currently locked into kiosk mode.
enum KioskLockState {
  /// Kiosk lock is not active; user can freely leave the app.
  unlocked,

  /// Kiosk lock is active via Android Lock Task Mode.
  locked,

  /// An attempt to start or stop kiosk mode encountered an error.
  error,
}

/// Snapshot of the kiosk subsystem at a point in time.
class KioskState extends Equatable {
  final KioskLockState lockState;

  /// Present when [lockState] is [KioskLockState.error].
  final String? errorMessage;

  const KioskState({
    required this.lockState,
    this.errorMessage,
  });

  /// Convenience factory — device is not locked.
  const KioskState.unlocked()
      : lockState = KioskLockState.unlocked,
        errorMessage = null;

  /// Convenience factory — device is in kiosk lock.
  const KioskState.locked()
      : lockState = KioskLockState.locked,
        errorMessage = null;

  /// Convenience factory — a lock/unlock operation failed.
  const KioskState.error(String message)
      : lockState = KioskLockState.error,
        errorMessage = message;

  bool get isLocked => lockState == KioskLockState.locked;

  @override
  List<Object?> get props => [lockState, errorMessage];
}
