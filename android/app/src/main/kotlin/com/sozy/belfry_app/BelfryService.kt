package com.sozy.belfry_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * A do-nothing foreground service whose only job is to keep the Belfry process
 * at "foreground service" priority so the `flutter_local_notifications` alarm
 * receiver actually has CPU budget to post notifications when an alarm fires.
 *
 * Why this exists: on Android 14+ (and especially API 37 preview), broadcast
 * receivers living inside a *cached* app process are given a tiny CPU window
 * — empirically ~7ms — which is not enough for the Flutter notification
 * plugin to load, deserialize the saved notification details, and call
 * NotificationManager.notify(). Even with doze-whitelisting and the cached-
 * apps freezer disabled, the receiver runs too briefly to post. Promoting
 * the process to foreground-service priority solves this at the OS level.
 *
 * The persistent shade notification is the visible cost; it's the standard
 * pattern for alarm/reminder apps (Google Clock, Alarmy, …).
 */
class BelfryService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannel(this)
        val notification = buildNotification(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        // START_STICKY: if the OS kills us under memory pressure, restart
        // when resources free up so alarm delivery resumes.
        return START_STICKY
    }

    companion object {
        const val CHANNEL_ID = "belfry_service"
        const val NOTIFICATION_ID = 1

        fun start(context: Context) {
            val intent = Intent(context, BelfryService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, BelfryService::class.java))
        }

        private fun ensureChannel(context: Context) {
            val nm = context.getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL_ID) != null) return
            // LOW importance: shows in the shade, no heads-up, no sound — just
            // enough to satisfy the "foreground services must be user-visible"
            // contract without nagging the user.
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Belfry watcher",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps Belfry running so alarms ring on time."
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }

        private fun buildNotification(context: Context): Notification {
            val openApp = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            return Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("Belfry")
                .setContentText("Watching for reminders.")
                .setContentIntent(openApp)
                .setOngoing(true)
                .setShowWhen(false)
                .setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
                .build()
        }
    }
}
