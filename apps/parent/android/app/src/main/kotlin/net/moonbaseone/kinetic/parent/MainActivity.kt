package net.moonbaseone.kinetic.parent

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.RingtoneManager
import android.content.Context

class MainActivity : FlutterActivity() {
    private val CHANNEL = "net.moonbaseone.kinetic.parent/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playNotificationSound" -> {
                    try {
                        playNotificationSound()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SOUND_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun playNotificationSound() {
        try {
            val ringtone = RingtoneManager.getRingtone(
                this,
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            )
            ringtone.play()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
