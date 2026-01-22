package com.example.juan_training

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * BroadcastReceiver to handle notification action button presses.
 *
 * Actions:
 * - TIMER_PAUSE: Pause the rest timer
 * - TIMER_RESUME: Resume the rest timer
 * - TIMER_SKIP: Skip/stop the rest timer
 * - TIMER_ADD30: Add 30 seconds to the timer
 */
class TimerActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_PAUSE = "com.juantraining.TIMER_PAUSE"
        const val ACTION_RESUME = "com.juantraining.TIMER_RESUME"
        const val ACTION_SKIP = "com.juantraining.TIMER_SKIP"
        const val ACTION_ADD30 = "com.juantraining.TIMER_ADD30"

        // Flutter engine reference for sending events back to Dart
        var flutterEngine: FlutterEngine? = null

        private const val TIMER_EVENTS_CHANNEL = "com.juantraining/timer_events"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return

        // Send the action to Flutter via MethodChannel
        flutterEngine?.let { engine ->
            val channel = MethodChannel(
                engine.dartExecutor.binaryMessenger,
                TIMER_EVENTS_CHANNEL
            )

            val methodName = when (action) {
                ACTION_PAUSE -> "onPause"
                ACTION_RESUME -> "onResume"
                ACTION_SKIP -> "onSkip"
                ACTION_ADD30 -> "onAdd30"
                else -> return
            }

            // Invoke the method on the Dart side
            channel.invokeMethod(methodName, null)
        }
    }
}
