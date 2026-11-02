package com.ussdpay.app

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessGranted" -> result.success(isAccessGranted())
                "openAccessSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val power = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(power.isIgnoringBatteryOptimizations(packageName))
                }
                "openBatterySettings" -> {
                    // The app's own details page, not the system-wide
                    // optimization prompt: that one needs
                    // REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, which Play
                    // restricts. On MIUI this page holds "Battery saver ->
                    // No restrictions", the setting that actually matters.
                    startActivity(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(null)
                }
                "watch" -> {
                    val senders = call.argument<List<String>>("senders").orEmpty()
                    PaymentSmsListenerService.watchedSenders =
                        senders.map(PaymentSmsListenerService::normalizeSender).toSet()
                    result.success(null)
                }
                "unwatch" -> {
                    PaymentSmsListenerService.watchedSenders = emptySet()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    PaymentSmsListenerService.sink = events
                }

                override fun onCancel(arguments: Any?) {
                    PaymentSmsListenerService.sink = null
                    PaymentSmsListenerService.watchedSenders = emptySet()
                }
            }
        )
    }

    override fun onDestroy() {
        // The engine is going away with the activity; a sink left behind would
        // forward into a dead channel.
        PaymentSmsListenerService.sink = null
        PaymentSmsListenerService.watchedSenders = emptySet()
        super.onDestroy()
    }

    /**
     * Notification access is a special permission granted in system settings,
     * not a runtime prompt, so the only reliable check is whether our
     * component is in the enabled-listeners list.
     */
    private fun isAccessGranted(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        val ours = ComponentName(this, PaymentSmsListenerService::class.java)
        return enabled.split(':').any {
            ComponentName.unflattenFromString(it) == ours
        }
    }

    companion object {
        private const val METHOD_CHANNEL = "ussd_pay/sms_confirm"
        private const val EVENT_CHANNEL = "ussd_pay/sms_confirm/events"
    }
}
