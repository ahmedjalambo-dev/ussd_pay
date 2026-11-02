package com.ussdpay.app

import android.app.Notification
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

/**
 * Watches posted notifications for a wallet's "money sent" SMS, so a payment
 * can be confirmed from the carrier's own message.
 *
 * Privacy is enforced HERE, before anything crosses into Dart: a notification
 * is forwarded only while a payment is waiting ([watchedSenders] non-empty),
 * only while the Flutter UI is attached ([sink] non-null), and only when its
 * title is one of the wallet's SMS senders. Everything else -- chats, email,
 * other SMS -- is dropped on the spot and never leaves this method.
 *
 * Nothing is queued: if the app process has no Flutter engine (the user swiped
 * the app away), there is no sink and the notification is ignored. The user
 * then answers the ordinary Done/Cancel prompt instead.
 */
class PaymentSmsListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val events = sink ?: return
        val senders = watchedSenders
        if (senders.isEmpty() || sbn == null) return
        // Our own prompts can never be a carrier SMS.
        if (sbn.packageName == packageName) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: return
        if (normalizeSender(title) !in senders) return

        val text = latestText(sbn.notification) ?: return
        val payload = mapOf(
            "sender" to title,
            "text" to text,
            "postedAtMs" to sbn.postTime,
        )
        mainHandler.post { events.success(payload) }
    }

    /**
     * Messaging apps put the body in different places: BIG_TEXT for an
     * expanded single message, TEXT for the collapsed form, and MessagingStyle
     * notifications keep a list in EXTRA_MESSAGES where the newest is last.
     */
    private fun latestText(notification: Notification): String? {
        val extras = notification.extras
        @Suppress("DEPRECATION")
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        val lastMessage = messages?.lastOrNull()?.let { parcel ->
            (parcel as? android.os.Bundle)?.getCharSequence("text")?.toString()
        }
        return lastMessage
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
    }

    companion object {
        private val mainHandler = Handler(Looper.getMainLooper())

        /** Normalized sender titles of the wallet whose payment is pending. */
        @Volatile
        var watchedSenders: Set<String> = emptySet()

        /** Set while the Dart side is listening; cleared when it stops. */
        @Volatile
        var sink: EventChannel.EventSink? = null

        /** Must match SmsConfirmationConfig.normalizeSender in Dart. */
        fun normalizeSender(raw: String): String =
            raw.lowercase().replace(Regex("\\s+"), "")
    }
}
