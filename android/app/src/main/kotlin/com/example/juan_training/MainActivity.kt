package com.example.juan_training

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val MUSIC_CHANNEL = "juan_training/music_launcher"
    private val TIMER_CHANNEL = "com.juantraining/timer_service"

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
