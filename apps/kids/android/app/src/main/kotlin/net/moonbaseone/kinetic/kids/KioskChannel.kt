package net.moonbaseone.kinetic.kids

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges [io.flutter.plugin.common.MethodChannel] calls from Flutter to
 * Android Lock Task Mode (kiosk lockdown).
 *
 * Lock Task Mode has two tiers:
 *  1. **Screen-pinning** (user-initiated) — any app, no Device Owner required.
 *     Works but the user can exit via the Overview + Back long-press combo.
 *  2. **Full kiosk lock** — requires this app to be Device Owner (provisioned
 *     in Phase 5); prevents ALL escape gestures including status bar.
 *
 * This implementation attempts full lock first; if the app is not Device Owner
 * it falls back to [Activity.startLockTask] (screen-pinning prompt).
 */
class KioskChannel(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "net.moonbase-one.kinetic/kiosk"
    }

    private val dpm: DevicePolicyManager by lazy {
        activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    }

    private val adminComponent: ComponentName by lazy {
        ComponentName(activity, KineticDeviceAdminReceiver::class.java)
    }

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "lock" -> {
                try {
                    if (dpm.isDeviceOwnerApp(activity.packageName)) {
                        // Full kiosk: whitelist this package so startLockTask works
                        // without a user-visible prompt.
                        dpm.setLockTaskPackages(adminComponent, arrayOf(activity.packageName))
                    }
                    activity.startLockTask()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("LOCK_FAILED", e.message, null)
                }
            }
            "unlock" -> {
                try {
                    activity.stopLockTask()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("UNLOCK_FAILED", e.message, null)
                }
            }
            "isLocked" -> {
                val locked = dpm.getLockTaskModeState(activity) !=
                        DevicePolicyManager.LOCK_TASK_MODE_NONE
                result.success(locked)
            }
            else -> result.notImplemented()
        }
    }
}
