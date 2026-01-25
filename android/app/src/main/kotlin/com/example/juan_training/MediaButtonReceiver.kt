package com.example.juan_training

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * BroadcastReceiver para acciones de media buttons desde la notificación.
 *
 * Este receiver escucha los intents de los botones de media en la notificación
 * y los reenvía al MediaSessionService para procesarlos.
 */
class MediaButtonReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        // Reenviar el intent al servicio
        val serviceIntent = Intent(context, MediaSessionService::class.java).apply {
            action = when (intent.action) {
                MediaSessionService.ACTION_PLAY -> MediaSessionService.ACTION_UPDATE_STATE
                MediaSessionService.ACTION_PAUSE -> MediaSessionService.ACTION_UPDATE_STATE
                MediaSessionService.ACTION_NEXT -> intent.action
                MediaSessionService.ACTION_PREVIOUS -> intent.action
                else -> return
            }

            // Para play/pause, togglear el estado
            if (intent.action == MediaSessionService.ACTION_PLAY) {
                putExtra(MediaSessionService.EXTRA_IS_PLAYING, true)
            } else if (intent.action == MediaSessionService.ACTION_PAUSE) {
                putExtra(MediaSessionService.EXTRA_IS_PLAYING, false)
            }
        }

        context.startService(serviceIntent)
    }
}
