import 'dart:async';

import 'package:flutter/services.dart';

import 'kiosk_service.dart';
import 'kiosk_state.dart';

/// Method-channel names must stay in sync with
/// `KioskChannel.kt` in `apps/kids/android/`.
const _kChannel = 'net.moonbase-one.kinetic/kiosk';
const _kMethodLock = 'lock';
const _kMethodUnlock = 'unlock';
const _kMethodIsLocked = 'isLocked';

/// Production [KioskService] that calls into Kotlin via a Flutter
/// [MethodChannel].
///
/// Requires the companion `KioskChannel.kt` (registered in `MainActivity.kt`)
/// and the `BIND_DEVICE_ADMIN` permission granted via Device Policy Controller.
///
/// **Android Lock Task Mode notes**
/// - `startLockTask()` works without Device Owner on Android ≥ 9 when the
///   activity was started by a Device Owner or when the app is itself pinned by
///   the user (screen-pinning fallback).
/// - Full lockdown (no status-bar, no back button) requires the app to be the
///   Device Owner.  Phase 5 documents the provisioning flow.
class AndroidKioskService implements KioskService {
  static const _ch = MethodChannel(_kChannel);

  final StreamController<KioskState> _controller =
      StreamController<KioskState>.broadcast();

  KioskState _state = const KioskState.unlocked();

  @override
  KioskState get state => _state;

  @override
  Stream<KioskState> get stateStream => _controller.stream;

  @override
  Future<void> lock() async {
    if (_state.isLocked) return;
    try {
      await _ch.invokeMethod<void>(_kMethodLock);
      _emit(const KioskState.locked());
    } on PlatformException catch (e) {
      _emit(KioskState.error(e.message ?? 'lock failed'));
    }
  }

  @override
  Future<void> unlock() async {
    if (!_state.isLocked) return;
    try {
      await _ch.invokeMethod<void>(_kMethodUnlock);
      _emit(const KioskState.unlocked());
    } on PlatformException catch (e) {
      _emit(KioskState.error(e.message ?? 'unlock failed'));
    }
  }

  /// Queries the current lock state from the Kotlin side on startup.
  Future<void> initialize() async {
    try {
      final locked = await _ch.invokeMethod<bool>(_kMethodIsLocked) ?? false;
      _emit(locked ? const KioskState.locked() : const KioskState.unlocked());
    } on PlatformException catch (_) {
      // Not fatal — default to unlocked.
    }
  }

  void _emit(KioskState next) {
    _state = next;
    _controller.add(next);
  }

  @override
  void dispose() => _controller.close();
}
