package com.example.juan_training

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/**
 * Servicio de sonidos de beep que NO solicita Audio Focus.
 *
 * Usa ToneGenerator con STREAM_NOTIFICATION para reproducir tonos cortos
 * sin pausar la música del usuario (Spotify, YouTube Music, etc.).
 *
 * AudioAttributes configurados:
 * - USAGE_NOTIFICATION: Indica que es un sonido de notificación corto
 * - CONTENT_TYPE_SONIFICATION: Sonido de sistema, no media
 * - NO AudioFocus request: No interrumpe otros reproductores
 */
class BeepSoundService private constructor() {

    companion object {
        private const val CHANNEL_NAME = "com.juantraining/beep_sound"

        @Volatile
        private var instance: BeepSoundService? = null

        fun getInstance(): BeepSoundService {
            return instance ?: synchronized(this) {
                instance ?: BeepSoundService().also { instance = it }
            }
        }

        /**
         * Registra el MethodChannel con Flutter.
         * Llamar desde MainActivity.configureFlutterEngine()
         */
        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val service = getInstance()
            service.context = context

            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "playBeep" -> {
                            val frequency = call.argument<Int>("frequency") ?: 880
                            val durationMs = call.argument<Int>("durationMs") ?: 150
                            val volume = call.argument<Double>("volume") ?: 0.5
                            val useMusicStream = call.argument<Boolean>("useMusicStream") ?: false

                            service.playBeep(frequency, durationMs, volume.toFloat(), useMusicStream)
                            result.success(true)
                        }
                        "playDoubleBeep" -> {
                            val frequency = call.argument<Int>("frequency") ?: 1047
                            val durationMs = call.argument<Int>("durationMs") ?: 250
                            val gapMs = call.argument<Int>("gapMs") ?: 150
                            val volume = call.argument<Double>("volume") ?: 0.5
                            val useMusicStream = call.argument<Boolean>("useMusicStream") ?: false

                            service.playDoubleBeep(frequency, durationMs, gapMs, volume.toFloat(), useMusicStream)
                            result.success(true)
                        }
                        "playSequence" -> {
                            val frequencies = call.argument<List<Int>>("frequencies") ?: listOf(880)
                            val durations = call.argument<List<Int>>("durations") ?: listOf(100)
                            val gaps = call.argument<List<Int>>("gaps") ?: listOf(50)
                            val volume = call.argument<Double>("volume") ?: 0.5
                            val useMusicStream = call.argument<Boolean>("useMusicStream") ?: false

                            service.playSequence(frequencies, durations, gaps, volume.toFloat(), useMusicStream)
                            result.success(true)
                        }
                        "dispose" -> {
                            service.dispose()
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                }
        }
    }

    private var context: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // ToneGenerator pool para diferentes frecuencias
    // Usamos STREAM_NOTIFICATION que no solicita audio focus
    private var toneGenerator: ToneGenerator? = null

    /**
     * Reproduce un beep simple sin interrumpir la música del usuario.
     *
     * @param frequency Frecuencia en Hz (aproximada - ToneGenerator tiene tonos predefinidos)
     * @param durationMs Duración en milisegundos
     * @param volume Volumen de 0.0 a 1.0
     */
    fun playBeep(frequency: Int, durationMs: Int, volume: Float, useMusicStream: Boolean) {
        mainHandler.post {
            try {
                // Mapear frecuencia a tono de ToneGenerator
                val toneType = frequencyToToneType(frequency)

                // Calcular volumen (ToneGenerator usa 0-100)
                val volumeInt = (volume * 100).roundToInt().coerceIn(0, 100)

                val streamType = if (useMusicStream) {
                    AudioManager.STREAM_MUSIC
                } else {
                    AudioManager.STREAM_NOTIFICATION
                }

                // Crear ToneGenerator con stream configurable (sin solicitar audio focus)
                val generator = ToneGenerator(streamType, volumeInt)

                // Reproducir tono
                generator.startTone(toneType, durationMs)

                // Liberar después de que termine
                mainHandler.postDelayed({
                    try {
                        generator.release()
                    } catch (e: Exception) {
                        // Ignorar errores de liberación
                    }
                }, durationMs.toLong() + 50)

            } catch (e: Exception) {
                // Silenciar errores de audio
            }
        }
    }

    /**
     * Reproduce un beep doble (para señal de "timer terminado").
     */
    fun playDoubleBeep(
        frequency: Int,
        durationMs: Int,
        gapMs: Int,
        volume: Float,
        useMusicStream: Boolean,
    ) {
        playBeep(frequency, durationMs, volume, useMusicStream)
        mainHandler.postDelayed({
            playBeep(frequency, durationMs, volume, useMusicStream)
        }, (durationMs + gapMs).toLong())
    }

    /**
     * Reproduce una secuencia de tonos (para feedback complejo de voz).
     */
    fun playSequence(
        frequencies: List<Int>,
        durations: List<Int>,
        gaps: List<Int>,
        volume: Float,
        useMusicStream: Boolean,
    ) {
        if (frequencies.isEmpty()) return

        var delay = 0L
        for (i in frequencies.indices) {
            val freq = frequencies[i]
            val dur = durations.getOrElse(i) { durations.lastOrNull() ?: 100 }
            val gap = gaps.getOrElse(i) { gaps.lastOrNull() ?: 50 }

            mainHandler.postDelayed({
                playBeep(freq, dur, volume, useMusicStream)
            }, delay)

            delay += dur + gap
        }
    }

    /**
     * Mapea una frecuencia (Hz) al tono más cercano de ToneGenerator.
     * ToneGenerator tiene tonos DTMF estándar y algunos tonos supervisores.
     *
     * Para el timer usamos principalmente:
     * - 440 Hz (A4) → TONE_DTMF_A (697 Hz + 1633 Hz)
     * - 660 Hz (E5) → TONE_SUP_CONFIRM (alta frecuencia)
     * - 880 Hz (A5) → TONE_PROP_BEEP (beep estándar)
     * - 1046 Hz (C6) → TONE_PROP_BEEP2 (beep alto)
     */
    private fun frequencyToToneType(frequency: Int): Int {
        return when {
            frequency < 500 -> ToneGenerator.TONE_DTMF_A        // Tono bajo (697+1633 Hz)
            frequency < 700 -> ToneGenerator.TONE_PROP_BEEP     // Tono medio
            frequency < 900 -> ToneGenerator.TONE_PROP_BEEP2    // Tono medio-alto
            frequency < 1100 -> ToneGenerator.TONE_SUP_CONFIRM  // Tono alto (confirmación)
            else -> ToneGenerator.TONE_SUP_RADIO_ACK            // Tono muy alto
        }
    }

    /**
     * Libera recursos.
     */
    fun dispose() {
        try {
            toneGenerator?.release()
            toneGenerator = null
        } catch (e: Exception) {
            // Ignorar
        }
    }
}
