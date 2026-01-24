package com.example.juan_training

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MediaSessionService - Servicio que crea una MediaSession propia de la app
 *
 * Este servicio es CRÍTICO para que aparezca el Media Player del sistema.
 * Sin una MediaSession activa con notificación MediaStyle, Android NO muestra
 * controles de media en:
 * - Notificaciones
 * - Lock screen
 * - Quick settings
 * - Controles de volumen
 *
 * Arquitectura:
 * 1. Singleton Service que vive mientras hay entrenamiento activo
 * 2. MediaSession con isActive = true
 * 3. Notificación con MediaStyle y sessionToken
 * 4. Callbacks de media buttons para controlar Spotify
 * 5. Platform Channel para comunicar con Flutter
 *
 * El servicio NO reproduce música - solo expone controles que redirigen
 * comandos a la app de música activa (Spotify).
 */
class MediaSessionService : Service() {

    companion object {
        const val CHANNEL_ID = "juan_training_media"
        const val NOTIFICATION_ID = 2001

        // Actions
        const val ACTION_START = "com.juantraining.MEDIA_START"
        const val ACTION_STOP = "com.juantraining.MEDIA_STOP"
        const val ACTION_UPDATE_STATE = "com.juantraining.MEDIA_UPDATE_STATE"
        const val ACTION_UPDATE_METADATA = "com.juantraining.MEDIA_UPDATE_METADATA"

        // Extras
        const val EXTRA_IS_PLAYING = "isPlaying"
        const val EXTRA_TITLE = "title"
        const val EXTRA_ARTIST = "artist"
        const val EXTRA_TRAINING_NAME = "trainingName"

        // Media button actions
        const val ACTION_PLAY = "com.juantraining.MEDIA_PLAY"
        const val ACTION_PAUSE = "com.juantraining.MEDIA_PAUSE"
        const val ACTION_NEXT = "com.juantraining.MEDIA_NEXT"
        const val ACTION_PREVIOUS = "com.juantraining.MEDIA_PREVIOUS"

        // Static reference to Flutter engine for callbacks
        var flutterEngine: FlutterEngine? = null
    }

    private var mediaSession: MediaSession? = null
    private var audioManager: AudioManager? = null
    private var notificationManager: NotificationManager? = null

    // Estado actual
    private var isPlaying = false
    private var currentTitle: String? = "Entrenando"
    private var currentArtist: String? = "Juan Training"
    private var trainingName: String? = null

    // BroadcastReceiver para botones de media
    private val mediaButtonReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_PLAY -> handlePlayPause()
                ACTION_PAUSE -> handlePlayPause()
                ACTION_NEXT -> handleNext()
                ACTION_PREVIOUS -> handlePrevious()
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ════════════════════════════════════════════════════════════════════════════

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        createNotificationChannel()
        initializeMediaSession()
        registerMediaButtonReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                trainingName = intent.getStringExtra(EXTRA_TRAINING_NAME)
                startForegroundWithNotification()
                activateMediaSession()
            }
            ACTION_STOP -> {
                stopMediaSession()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_UPDATE_STATE -> {
                isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, false)
                updatePlaybackState()
                updateNotification()
            }
            ACTION_UPDATE_METADATA -> {
                currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                currentArtist = intent.getStringExtra(EXTRA_ARTIST) ?: currentArtist
                updateMetadata()
                updateNotification()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        unregisterReceiver(mediaButtonReceiver)
        mediaSession?.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ════════════════════════════════════════════════════════════════════════════
    // MEDIA SESSION
    // ════════════════════════════════════════════════════════════════════════════

    private fun initializeMediaSession() {
        mediaSession = MediaSession(this, "JuanTrainingMediaSession").apply {
            // Callbacks para media buttons
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() {
                    handlePlayPause()
                }

                override fun onPause() {
                    handlePlayPause()
                }

                override fun onSkipToNext() {
                    handleNext()
                }

                override fun onSkipToPrevious() {
                    handlePrevious()
                }

                override fun onMediaButtonEvent(mediaButtonIntent: Intent?): Boolean {
                    val keyEvent = mediaButtonIntent?.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)
                    if (keyEvent?.action == KeyEvent.ACTION_DOWN) {
                        when (keyEvent.keyCode) {
                            KeyEvent.KEYCODE_MEDIA_PLAY,
                            KeyEvent.KEYCODE_MEDIA_PAUSE,
                            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> handlePlayPause()
                            KeyEvent.KEYCODE_MEDIA_NEXT -> handleNext()
                            KeyEvent.KEYCODE_MEDIA_PREVIOUS -> handlePrevious()
                        }
                    }
                    return true
                }
            })

            // Permitir media buttons
            setFlags(
                MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
                MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
        }
    }

    private fun activateMediaSession() {
        mediaSession?.isActive = true
        updatePlaybackState()
        updateMetadata()
    }

    private fun stopMediaSession() {
        mediaSession?.isActive = false
    }

    private fun updatePlaybackState() {
        val state = if (isPlaying) {
            PlaybackState.STATE_PLAYING
        } else {
            PlaybackState.STATE_PAUSED
        }

        val playbackState = PlaybackState.Builder()
            .setActions(
                PlaybackState.ACTION_PLAY or
                PlaybackState.ACTION_PAUSE or
                PlaybackState.ACTION_PLAY_PAUSE or
                PlaybackState.ACTION_SKIP_TO_NEXT or
                PlaybackState.ACTION_SKIP_TO_PREVIOUS
            )
            .setState(state, PlaybackState.PLAYBACK_POSITION_UNKNOWN, 1.0f)
            .build()

        mediaSession?.setPlaybackState(playbackState)
    }

    private fun updateMetadata() {
        val metadata = android.media.MediaMetadata.Builder()
            .putString(android.media.MediaMetadata.METADATA_KEY_TITLE, currentTitle ?: "Entrenando")
            .putString(android.media.MediaMetadata.METADATA_KEY_ARTIST, currentArtist ?: "Juan Training")
            .putString(android.media.MediaMetadata.METADATA_KEY_ALBUM, trainingName ?: "Entrenamiento")
            .build()

        mediaSession?.setMetadata(metadata)
    }

    // ════════════════════════════════════════════════════════════════════════════
    // NOTIFICATION
    // ════════════════════════════════════════════════════════════════════════════

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Control de Música",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Controles de música durante el entrenamiento"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        notificationManager?.createNotificationChannel(channel)
    }

    private fun startForegroundWithNotification() {
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    private fun updateNotification() {
        notificationManager?.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        // Intent para abrir la app
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Acciones de media
        val playPauseAction = NotificationCompat.Action(
            if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
            if (isPlaying) "Pausar" else "Reproducir",
            createMediaPendingIntent(if (isPlaying) ACTION_PAUSE else ACTION_PLAY)
        )

        val previousAction = NotificationCompat.Action(
            android.R.drawable.ic_media_previous,
            "Anterior",
            createMediaPendingIntent(ACTION_PREVIOUS)
        )

        val nextAction = NotificationCompat.Action(
            android.R.drawable.ic_media_next,
            "Siguiente",
            createMediaPendingIntent(ACTION_NEXT)
        )

        // MediaStyle con session token - CRÍTICO para que aparezca el media player
        val mediaStyle = androidx.media.app.NotificationCompat.MediaStyle()
            .setMediaSession(androidx.media.session.MediaSessionCompat.Token.fromToken(mediaSession?.sessionToken))
            .setShowActionsInCompactView(0, 1, 2) // prev, play/pause, next

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentTitle ?: "Entrenando")
            .setContentText(currentArtist ?: "Juan Training")
            .setSubText(trainingName)
            .setSmallIcon(android.R.drawable.ic_media_play) // TODO: usar icono propio
            .setContentIntent(contentIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .addAction(previousAction)
            .addAction(playPauseAction)
            .addAction(nextAction)
            .setStyle(mediaStyle)
            .build()
    }

    private fun createMediaPendingIntent(action: String): PendingIntent {
        val intent = Intent(action).apply {
            setPackage(packageName)
        }
        return PendingIntent.getBroadcast(
            this,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    // ════════════════════════════════════════════════════════════════════════════
    // MEDIA BUTTON HANDLERS
    // ════════════════════════════════════════════════════════════════════════════

    private fun registerMediaButtonReceiver() {
        val filter = IntentFilter().apply {
            addAction(ACTION_PLAY)
            addAction(ACTION_PAUSE)
            addAction(ACTION_NEXT)
            addAction(ACTION_PREVIOUS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(mediaButtonReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(mediaButtonReceiver, filter)
        }
    }

    private fun handlePlayPause() {
        // 1. Enviar KeyEvent al sistema para controlar app de música activa
        sendMediaKeyEvent(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)

        // 2. Toggle estado local
        isPlaying = !isPlaying
        updatePlaybackState()
        updateNotification()

        // 3. Notificar a Flutter
        notifyFlutter("onMediaPlayPause", mapOf("isPlaying" to isPlaying))
    }

    private fun handleNext() {
        sendMediaKeyEvent(KeyEvent.KEYCODE_MEDIA_NEXT)
        notifyFlutter("onMediaNext", null)
    }

    private fun handlePrevious() {
        sendMediaKeyEvent(KeyEvent.KEYCODE_MEDIA_PREVIOUS)
        notifyFlutter("onMediaPrevious", null)
    }

    private fun sendMediaKeyEvent(keyCode: Int) {
        val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
        }
        sendBroadcast(downIntent)
        sendBroadcast(upIntent)
    }

    private fun notifyFlutter(method: String, arguments: Map<String, Any>?) {
        try {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, "com.juantraining/media_session_events")
                    .invokeMethod(method, arguments)
            }
        } catch (e: Exception) {
            // Ignorar errores de comunicación
        }
    }
}
