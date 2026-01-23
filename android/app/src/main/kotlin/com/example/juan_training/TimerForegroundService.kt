package com.example.juan_training

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Foreground service to keep the rest timer running and visible on lock screen.
 *
 * This service:
 * - Shows a persistent notification with countdown
 * - Updates every second
 * - Provides action buttons (pause, resume, skip, +30s)
 * - Keeps running even when app is in background
 */
class TimerForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "timer_foreground_channel"
        const val NOTIFICATION_ID = 1002

        const val ACTION_START = "com.juantraining.ACTION_START_TIMER"
        const val ACTION_UPDATE = "com.juantraining.ACTION_UPDATE_TIMER"
        const val ACTION_STOP = "com.juantraining.ACTION_STOP_TIMER"

        const val EXTRA_TOTAL_SECONDS = "totalSeconds"
        const val EXTRA_END_TIME_MILLIS = "endTimeMillis"
        const val EXTRA_IS_PAUSED = "isPaused"
    }

    private var totalSeconds: Int = 0
    private var endTimeMillis: Long = 0
    private var isPaused: Boolean = false

    private val handler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null

    private val updateRunnable = object : Runnable {
        override fun run() {
            if (!isPaused) {
                updateNotification()
                val remaining = (endTimeMillis - System.currentTimeMillis()) / 1000
                if (remaining > 0) {
                    handler.postDelayed(this, 1000)
                } else {
                    // Timer finished
                    showTimerFinishedNotification()
                    stopSelf()
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                totalSeconds = intent.getIntExtra(EXTRA_TOTAL_SECONDS, 90)
                endTimeMillis = intent.getLongExtra(EXTRA_END_TIME_MILLIS, System.currentTimeMillis() + 90000)
                isPaused = intent.getBooleanExtra(EXTRA_IS_PAUSED, false)

                startForeground(NOTIFICATION_ID, createNotification())

                if (!isPaused) {
                    handler.post(updateRunnable)
                }
            }
            ACTION_UPDATE -> {
                totalSeconds = intent.getIntExtra(EXTRA_TOTAL_SECONDS, totalSeconds)
                endTimeMillis = intent.getLongExtra(EXTRA_END_TIME_MILLIS, endTimeMillis)
                val wasPaused = isPaused
                isPaused = intent.getBooleanExtra(EXTRA_IS_PAUSED, isPaused)

                updateNotification()

                // Handle pause/resume state change
                if (wasPaused && !isPaused) {
                    handler.post(updateRunnable)
                } else if (!wasPaused && isPaused) {
                    handler.removeCallbacks(updateRunnable)
                }
            }
            ACTION_STOP -> {
                stopSelf()
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(updateRunnable)
        releaseWakeLock()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Temporizador de Descanso",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Muestra el temporizador de descanso en la pantalla de bloqueo"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val remaining: Long = if (isPaused) {
            totalSeconds.toLong()
        } else {
            ((endTimeMillis - System.currentTimeMillis()) / 1000).coerceAtLeast(0)
        }

        val minutes = (remaining / 60L).toString().padStart(2, '0')
        val seconds = (remaining % 60L).toString().padStart(2, '0')
        val timeString = "$minutes:$seconds"

        // Progress calculation
        val progress = if (totalSeconds > 0) {
            ((remaining.toFloat() / totalSeconds) * 100).toInt().coerceIn(0, 100)
        } else 100

        // Intent to open the app
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("🏋️ Descanso: $timeString")
            .setContentText(if (isPaused) "Pausado - Toca para continuar" else "Prepárate para la siguiente serie")
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setProgress(100, progress, false)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)

        // Use chronometer for smooth countdown display
        if (!isPaused && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            builder.setUsesChronometer(true)
                .setChronometerCountDown(true)
                .setWhen(endTimeMillis)
        }

        // Add action buttons based on state
        if (isPaused) {
            builder.addAction(
                android.R.drawable.ic_media_play,
                "▶️ Reanudar",
                createActionPendingIntent("com.juantraining.TIMER_RESUME")
            )
        } else {
            builder.addAction(
                android.R.drawable.ic_media_pause,
                "⏸️ Pausar",
                createActionPendingIntent("com.juantraining.TIMER_PAUSE")
            )
            builder.addAction(
                0,
                "+30s",
                createActionPendingIntent("com.juantraining.TIMER_ADD30")
            )
        }

        builder.addAction(
            android.R.drawable.ic_menu_close_clear_cancel,
            "⏭️ Saltar",
            createActionPendingIntent("com.juantraining.TIMER_SKIP")
        )

        return builder.build()
    }

    private fun createActionPendingIntent(action: String): PendingIntent {
        val intent = Intent(this, TimerActionReceiver::class.java).apply {
            this.action = action
        }
        return PendingIntent.getBroadcast(
            this,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, createNotification())
    }

    private fun showTimerFinishedNotification() {
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("🏋️ ¡Descanso terminado!")
            .setContentText("Es hora de continuar con tu entrenamiento")
            .setContentIntent(openAppPendingIntent)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID + 1, notification)
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "JuanTraining::TimerWakeLock"
        ).apply {
            acquire(10 * 60 * 1000L) // 10 minutes max
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }
}
