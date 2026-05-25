package com.example.glamora
import android.app.*
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.example.glamora/notifications"
    }

    // Chat messages store — chatId → list of (sender, message)
    private val messageStore = mutableMapOf<String, MutableList<Pair<String, String>>>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannels()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "showMessageNotification" -> {
                    showMessageNotification(
                        chatId     = call.argument("chatId") ?: "",
                        senderName = call.argument("senderName") ?: "",
                        message    = call.argument("message") ?: ""
                    )
                    result.success(null)
                }

                "showOrderUpdateNotification" -> {
                    showOrderUpdateNotification(
                        orderId = call.argument("orderId") ?: "",
                        title   = call.argument("title") ?: "",
                        body    = call.argument("body") ?: ""
                    )
                    result.success(null)
                }

                "cancelChatNotification" -> {
                    val chatId = call.argument<String>("chatId") ?: ""
                    NotificationManagerCompat.from(this).cancel(chatId.hashCode())
                    messageStore.remove(chatId)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ── Channels ─────────────────────────────────────────────────
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)

        // Message channel — existing "chat_channel" maintain karo
        val msgSound = Uri.parse("android.resource://$packageName/raw/message")
        val msgAttr = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        NotificationChannel(
            "chat_channel", "Chat Notifications", NotificationManager.IMPORTANCE_HIGH
        ).apply {
            setSound(msgSound, msgAttr)
            enableVibration(true)
            description = "Chat message notifications"
        }.also { manager.createNotificationChannel(it) }

        // Order update channel
        val orderSound = Uri.parse("android.resource://$packageName/raw/money")
        val orderAttr = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        NotificationChannel(
            "order_channel", "Order Updates", NotificationManager.IMPORTANCE_HIGH
        ).apply {
            setSound(orderSound, orderAttr)
            enableVibration(true)
            description = "Order status notifications"
        }.also { manager.createNotificationChannel(it) }
    }

    // ── WhatsApp Style Message Notification ───────────────────────
    private fun showMessageNotification(chatId: String, senderName: String, message: String) {
        messageStore.getOrPut(chatId) { mutableListOf() }
            .add(Pair(senderName, message))

        val openIntent = PendingIntent.getActivity(
            this, chatId.hashCode(),
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("type", "chat")
                putExtra("chat_id", chatId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val style = NotificationCompat.MessagingStyle("You")
        messageStore[chatId]!!.forEach { (sender, msg) ->
            style.addMessage(msg, System.currentTimeMillis(), Person.Builder().setName(sender).build())
        }

        val notif = NotificationCompat.Builder(this, "chat_channel")
            .setSmallIcon(R.drawable.ic_stat_icon)   // tumhara existing icon
            .setStyle(style)
            .setGroup("GROUP_CHATS")
            .setAutoCancel(true)
            .setContentIntent(openIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        NotificationManagerCompat.from(this).notify(chatId.hashCode(), notif)

        // Group summary
        val summary = NotificationCompat.Builder(this, "chat_channel")
            .setSmallIcon(R.drawable.ic_stat_icon)
            .setGroup("GROUP_CHATS")
            .setGroupSummary(true)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(this).notify(0, summary)
    }

    // ── Order Update Notification ─────────────────────────────────
    private fun showOrderUpdateNotification(orderId: String, title: String, body: String) {
        val openIntent = PendingIntent.getActivity(
            this, orderId.hashCode(),
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("type", "order_update")
                putExtra("order_id", orderId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notif = NotificationCompat.Builder(this, "order_channel")
            .setSmallIcon(R.drawable.ic_stat_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setGroup("GROUP_ORDERS_$orderId")
            // Same orderId → same notif ID → update hoga, nayi nahi banegi
            .setAutoCancel(true)
            .setContentIntent(openIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        NotificationManagerCompat.from(this).notify(orderId.hashCode(), notif)
    }
}