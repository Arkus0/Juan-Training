package com.example.juan_training

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.service.notification.NotificationListenerService
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val MUSIC_CHANNEL = "juan_training/music_launcher"
    private val TIMER_CHANNEL = "com.juantraining/timer_service"
    private val MEDIA_SESSION_CHANNEL = "com.juantraining/media_session"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Music launcher channel (existing)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MUSIC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "mediaNext" -> {
                        sendMediaButton(KeyEvent.KEYCODE_MEDIA_NEXT)
                        result.success(null)
                    }
                    "mediaPrevious" -> {
                        sendMediaButton(KeyEvent.KEYCODE_MEDIA_PREVIOUS)
                        result.success(null)
                    }
                    "mediaPlayPause" -> {
                        sendMediaButton(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
                        result.success(null)
                    }
                    "isMusicActive" -> {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        val isMusicActive = audioManager?.isMusicActive ?: false
                        result.success(isMusicActive)
                    }
                    "getMediaSession" -> {
                        val sessionInfo = getActiveMediaSessionInfo()
                        result.success(sessionInfo)
                    }
                    else -> result.notImplemented()
                }
            }

        // Timer foreground service channel (new)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TIMER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startTimerService" -> {
                        val totalSeconds = call.argument<Int>("totalSeconds") ?: 90
                        val endTimeMillis = call.argument<Long>("endTimeMillis") ?: System.currentTimeMillis() + 90000
                        val isPaused = call.argument<Boolean>("isPaused") ?: false

                        val intent = Intent(this, TimerForegroundService::class.java).apply {
                            action = TimerForegroundService.ACTION_START
                            putExtra(TimerForegroundService.EXTRA_TOTAL_SECONDS, totalSeconds)
                            putExtra(TimerForegroundService.EXTRA_END_TIME_MILLIS, endTimeMillis)
                            putExtra(TimerForegroundService.EXTRA_IS_PAUSED, isPaused)
                        }
                        startForegroundService(intent)
                        result.success(null)
                    }
                    "updateTimerService" -> {
                        val totalSeconds = call.argument<Int>("totalSeconds") ?: 90
                        val endTimeMillis = call.argument<Long>("endTimeMillis") ?: 0L
                        val isPaused = call.argument<Boolean>("isPaused") ?: false

                        val intent = Intent(this, TimerForegroundService::class.java).apply {
                            action = TimerForegroundService.ACTION_UPDATE
                            putExtra(TimerForegroundService.EXTRA_TOTAL_SECONDS, totalSeconds)
                            putExtra(TimerForegroundService.EXTRA_END_TIME_MILLIS, endTimeMillis)
                            putExtra(TimerForegroundService.EXTRA_IS_PAUSED, isPaused)
                        }
                        startService(intent)
                        result.success(null)
                    }
                    "stopTimerService" -> {
                        val intent = Intent(this, TimerForegroundService::class.java).apply {
                            action = TimerForegroundService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Store the Flutter engine for use by TimerActionReceiver
        TimerActionReceiver.flutterEngine = flutterEngine

        // Store for MediaSessionService
        MediaSessionService.flutterEngine = flutterEngine

        // MediaSession service channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_SESSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMediaSession" -> {
                        val trainingName = call.argument<String>("trainingName")
                        val intent = Intent(this, MediaSessionService::class.java).apply {
                            action = MediaSessionService.ACTION_START
                            putExtra(MediaSessionService.EXTRA_TRAINING_NAME, trainingName)
                        }
                        startForegroundService(intent)
                        result.success(true)
                    }
                    "stopMediaSession" -> {
                        val intent = Intent(this, MediaSessionService::class.java).apply {
                            action = MediaSessionService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "updatePlaybackState" -> {
                        val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                        val intent = Intent(this, MediaSessionService::class.java).apply {
                            action = MediaSessionService.ACTION_UPDATE_STATE
                            putExtra(MediaSessionService.EXTRA_IS_PLAYING, isPlaying)
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "updateMetadata" -> {
                        val title = call.argument<String>("title")
                        val artist = call.argument<String>("artist")
                        val intent = Intent(this, MediaSessionService::class.java).apply {
                            action = MediaSessionService.ACTION_UPDATE_METADATA
                            putExtra(MediaSessionService.EXTRA_TITLE, title)
                            putExtra(MediaSessionService.EXTRA_ARTIST, artist)
                        }
                        startService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Gets information about the active media session.
     * Requires MEDIA_CONTENT_CONTROL permission or notification listener permission.
     *
     * Returns a map with:
     * - packageName: String? - Package name of the app playing media
     * - title: String? - Current track title
     * - artist: String? - Current track artist
     * - album: String? - Current track album
     * - playbackState: Int? - Current playback state (from PlaybackState constants)
     *
     * If no active session is found or permission is not granted, returns null.
     */
    private fun getActiveMediaSessionInfo(): Map<String, Any?>? {
        return try {
            val mediaSessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as? MediaSessionManager
                ?: return null

            // Try to get active sessions
            // This requires either MEDIA_CONTENT_CONTROL (system apps only)
            // or an enabled NotificationListenerService
            val componentName = ComponentName(this, NotificationListenerServiceImpl::class.java)

            val controllers: List<MediaController>
            try {
                controllers = mediaSessionManager.getActiveSessions(componentName)
            } catch (e: SecurityException) {
                // Permission not granted - fall back to basic audio check
                return null
            }

            if (controllers.isEmpty()) return null

            // Get the first (most recently active) controller
            val controller = controllers.first()
            val metadata = controller.metadata
            val playbackState = controller.playbackState

            mapOf(
                "packageName" to controller.packageName,
                "title" to metadata?.getString(MediaMetadata.METADATA_KEY_TITLE),
                "artist" to metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST),
                "album" to metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM),
                "playbackState" to playbackState?.state
            )
        } catch (e: Exception) {
            // Any error - return null and let Dart handle fallback
            null
        }
    }

    private fun sendMediaButton(keyCode: Int) {
        val down = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        val up = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
        }
        sendBroadcast(down)
        sendBroadcast(up)
    }
}

/**
 * Notification listener service required to access active media sessions.
 *
 * The user must enable this service in Settings > Apps > Special access > Notification access
 * for the getMediaSession functionality to work.
 */
class NotificationListenerServiceImpl : NotificationListenerService() {
    // This service doesn't need to do anything - it just needs to exist
    // and be enabled by the user to grant us permission to access media sessions
}
