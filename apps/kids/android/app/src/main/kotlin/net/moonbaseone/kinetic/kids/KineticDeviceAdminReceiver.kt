package net.moonbaseone.kinetic.kids

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Android Device Admin Receiver for Kinetic Link Kids.
 *
 * Declared in AndroidManifest.xml and device_admin.xml.
 * Required so the Device Policy Manager can manage lock-task whitelisting
 * once the app is provisioned as Device Owner in Phase 5.
 *
 * In Phase 4 (current) the receiver is registered but the app is NOT yet
 * Device Owner — lock-task falls back to user-visible screen-pinning.
 */
class KineticDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
    }
}
