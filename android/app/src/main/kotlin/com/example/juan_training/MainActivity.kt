package com.example.juan_training

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "juan_training/music_launcher")
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
