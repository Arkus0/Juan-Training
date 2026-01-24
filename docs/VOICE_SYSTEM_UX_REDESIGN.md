# Voice System UX Redesign - Juan Training

## Documento de Arquitectura UX para Interfaces de Voz
**Versión**: 2.0
**Fecha**: Enero 2026
**Autor**: Senior Mobile UX Engineer

---

# 1. DIAGNÓSTICO DEL SISTEMA ACTUAL

## 1.1 Estado Actual de la Arquitectura

El sistema actual implementa reconocimiento de voz offline-first usando `speech_to_text` con las siguientes características:

### Componentes Existentes
| Componente | Archivo | Función |
|------------|---------|---------|
| VoiceInputService | `services/voice_input_service.dart` | Motor de reconocimiento singleton |
| VoiceInputProvider | `providers/voice_input_provider.dart` | Estado reactivo (Riverpod) |
| VoiceInputSheet | `widgets/voice/voice_input_sheet.dart` | UI para creación de rutinas |
| VoiceTrainingFab | `widgets/voice/voice_training_fab.dart` | FAB durante entrenamiento |
| VoiceTrainingButton | `widgets/voice/voice_training_button.dart` | Botón AppBar entrenamiento |
| RoutineOcrService | `services/routine_ocr_service.dart` | OCR con ML Kit |
| ExerciseParsingService | `services/exercise_parsing_service.dart` | Parser unificado voz/OCR |
| ExerciseMatchingService | `services/exercise_matching_service.dart` | Matching fuzzy multi-nivel |

### Flujo Actual
```
Usuario pulsa mic → Toggle escucha → Transcripción tiempo real
    → Pausa/tap de nuevo → Procesa → Muestra resultados → Confirma
```

## 1.2 Problemas Identificados

### P1: Ambigüedad en el Estado de Escucha
- **Síntoma**: El usuario no sabe cuándo la app está escuchando
- **Causa**: Toggle mode sin feedback visual suficiente
- **Impacto**: Desconfianza, capturas accidentales, frustración
- **Evidencia**: `voiceState.isListening` controla todo pero sin feedback claro

### P2: Modo Continuo Confuso
- **Síntoma**: `isContinuousMode` añade complejidad sin beneficio claro
- **Causa**: Dos modos de operación (single vs continuous) dificultan UX
- **Impacto**: Usuario no sabe qué esperar
- **Evidencia**: Líneas 218-226 de `voice_input_sheet.dart`

### P3: Sin Detección de Ruido de Fondo
- **Síntoma**: Fallos silenciosos en gimnasio ruidoso
- **Causa**: No hay análisis de calidad de audio pre-captura
- **Impacto**: Transcripciones incorrectas sin advertencia
- **Evidencia**: `speech_to_text` no expone métricas de SNR

### P4: OCR sin Feedback de Confianza Visible
- **Síntoma**: Usuario no sabe qué tan seguro es el resultado
- **Causa**: `confidence` existe pero no se muestra claramente
- **Impacto**: Datos erróneos entran al historial
- **Evidencia**: `ParsedExerciseCandidate.confidence` no visualizado

### P5: No hay Sesiones Externas en Historial
- **Síntoma**: Solo sesiones hechas en-app aparecen
- **Causa**: No existe flujo para agregar sesiones manuales/externas
- **Impacto**: Historial incompleto, pérdida de continuidad
- **Evidencia**: `HistoryScreen` solo lee de `sesionesHistoryStreamProvider`

### P6: Sin Mecanismo de Undo Post-Acción
- **Síntoma**: Una vez confirmado, no hay vuelta atrás rápida
- **Causa**: No implementado
- **Impacto**: Errores persistentes requieren edición manual

### P7: Fallbacks Reactivos, No Proactivos
- **Síntoma**: Usuario descubre que falló después del hecho
- **Causa**: No hay sugerencia automática de alternativa
- **Impacto**: Fricción aumenta, usuario abandona feature

---

# 2. DECISIONES DE DISEÑO

## 2.1 Lo que SÍ hace el Sistema de Voz

| Capacidad | Descripción | Contexto |
|-----------|-------------|----------|
| **Push To Talk explícito** | Solo escucha mientras botón está pulsado/activo | Todos |
| **Captura de ejercicios básicos** | Nombre, series, reps, peso, notas | Rutinas, Historial |
| **Feedback visual por estado** | Icono + texto + color según estado | Todos |
| **Preview editable obligatorio** | Siempre muestra antes de guardar | Todos |
| **Indicador de confianza** | Verde/amarillo/rojo según % | Todos |
| **Fallback a texto/manual** | Ofrece alternativa tras 2 fallos | Todos |
| **Undo inmediato** | Deshacer última acción 10 segundos | Historial |
| **Comandos de entrenamiento** | "Hecho", "Peso X", "X reps", "Descanso" | Sesión activa |
| **OCR de logs impresos/manuscritos** | Escaneo con edición | Historial |
| **Detección de ruido** | Sugiere acercarse si ambiente ruidoso | Todos |

## 2.2 Lo que NO hace el Sistema de Voz

| Limitación | Razón | Alternativa |
|------------|-------|-------------|
| **No escucha en background** | Privacidad + batería + precisión | Push To Talk |
| **No auto-guarda sin confirmar** | Integridad de datos | Preview obligatorio |
| **No interpreta detalles avanzados** | Complejidad vs errores | Edición manual post |
| **No funciona con música muy alta** | Límite técnico STT | Texto/manual |
| **No reemplaza datos sin avisar** | Seguridad de datos | Confirmación explícita |
| **No cambia progresión automática** | Requiere opt-in | Toggle explícito |
| **No procesa idiomas mezclados** | Precisión | Un idioma por sesión |

## 2.3 Principios de Diseño

```
╔════════════════════════════════════════════════════════════════╗
║  PRINCIPIO 1: PUSH TO TALK = ÚNICO MODO DE ESCUCHA            ║
║  Si no pulsas, no escucha. Punto.                              ║
╠════════════════════════════════════════════════════════════════╣
║  PRINCIPIO 2: FEEDBACK ANTES DE ACCIÓN                         ║
║  Siempre mostrar qué se va a hacer antes de hacerlo.           ║
╠════════════════════════════════════════════════════════════════╣
║  PRINCIPIO 3: FALLAR RUIDOSAMENTE                              ║
║  Nunca errores silenciosos. Si falla, se nota y se ofrece alt. ║
╠════════════════════════════════════════════════════════════════╣
║  PRINCIPIO 4: UNDO SIEMPRE DISPONIBLE                          ║
║  Toda acción destructiva tiene 10s de gracia para deshacer.    ║
╠════════════════════════════════════════════════════════════════╣
║  PRINCIPIO 5: UN TAP PARA RETRY O FALLBACK                     ║
║  En gimnasio, minimizar fricción. Un toque = siguiente opción. ║
╚════════════════════════════════════════════════════════════════╝
```

---

# 3. FLUJOS UX POR CONTEXTO

## 3.1 FLUJO: Push To Talk Base

### Estados del Sistema
```
┌─────────────────────────────────────────────────────────────────┐
│                    MÁQUINA DE ESTADOS PTT                        │
└─────────────────────────────────────────────────────────────────┘

    ┌──────────┐
    │   IDLE   │◄────────────────────────────────────┐
    │ (Espera) │                                     │
    └────┬─────┘                                     │
         │ Usuario pulsa botón                       │
         ▼                                           │
    ┌──────────────┐                                 │
    │  LISTENING   │ ← Botón pulsado activamente     │
    │ (Escuchando) │                                 │
    └────┬─────────┘                                 │
         │ Usuario suelta botón                      │
         ▼                                           │
    ┌──────────────┐                                 │
    │  PROCESSING  │                                 │
    │ (Procesando) │                                 │
    └────┬─────────┘                                 │
         │                                           │
         ├──────────────┐                            │
         ▼              ▼                            │
    ┌─────────┐    ┌─────────┐                       │
    │ SUCCESS │    │  ERROR  │                       │
    │(Éxito)  │    │ (Fallo) │                       │
    └────┬────┘    └────┬────┘                       │
         │              │                            │
         │   Preview    │   Retry/Fallback           │
         │   editable   │   ofrecido                 │
         │              │                            │
         └──────────────┴────────────────────────────┘
```

### Feedback Visual por Estado

| Estado | Icono | Color | Texto | Animación |
|--------|-------|-------|-------|-----------|
| **IDLE** | `mic_none` | Gris neutro | "Pulsa para hablar" | Ninguna |
| **LISTENING** | `mic` | Rojo vivo | "Escuchando..." | Glow pulsante |
| **PROCESSING** | `hourglass_empty` | Amarillo | "Procesando..." | Spinner |
| **SUCCESS** | `check_circle` | Verde | "Detectado: [preview]" | Fade in |
| **ERROR** | `error_outline` | Naranja | "No entendido" | Shake suave |

### Comportamiento del Botón PTT

```dart
// Modelo de interacción
GestureDetector(
  // INICIO: Al pulsar, empieza a escuchar
  onTapDown: (_) => startListening(),

  // FIN: Al soltar, procesa
  onTapUp: (_) => stopAndProcess(),

  // CANCELAR: Si arrastra fuera, cancela
  onTapCancel: () => cancelListening(),
)
```

### Código de Feedback Audio

| Evento | Frecuencia | Duración | Descripción |
|--------|------------|----------|-------------|
| Start listening | 523 Hz (C5) | 100ms | Tono ascendente corto |
| Stop listening | 392 Hz (G4) | 100ms | Tono descendente corto |
| High confidence | 783 Hz (G5) | 150ms x2 | Doble tono agudo |
| Medium confidence | 659 Hz (E5) | 100ms | Tono medio |
| Error/no match | 349 Hz (F4) | 200ms | Tono grave largo |

---

## 3.2 FLUJO: Historial - Subir Sesiones Externas

### Punto de Entrada
```
HistoryScreen
    └── FAB "+" o botón "Agregar Sesión Externa"
            └── ExternalSessionSheet (nuevo)
```

### Wireframe del Sheet

```
╔══════════════════════════════════════════════════════════════════╗
║  ═══ ▔▔▔▔▔▔▔▔ ═══                                               ║
║                                                                  ║
║         AGREGAR SESIÓN EXTERNA                                   ║
║     ─────────────────────────────                                ║
║                                                                  ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │  📅 FECHA DE LA SESIÓN                                     │  ║
║  │  [  Hoy, 24 Ene 2026  ▼ ]                                  │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                  ║
║  ¿Cómo quieres agregar los ejercicios?                          ║
║                                                                  ║
║  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐         ║
║  │   🎤     │  │   📷     │  │   ⌨️     │  │   ✋     │         ║
║  │   VOZ    │  │   OCR    │  │  TEXTO   │  │  MANUAL  │         ║
║  │          │  │          │  │          │  │          │         ║
║  └──────────┘  └──────────┘  └──────────┘  └──────────┘         ║
║                                                                  ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │  ℹ️ La voz captura ejercicios básicos: nombre, series,     │  ║
║  │     reps y peso. Detalles avanzados se editan después.     │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### Sub-flujo: Entrada por Voz

```
╔══════════════════════════════════════════════════════════════════╗
║         DICTAR SESIÓN                                            ║
║     ─────────────────────                                        ║
║                                                                  ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                            │  ║
║  │     "Pulsa y mantén para hablar"                          │  ║
║  │                                                            │  ║
║  │              ┌───────────┐                                 │  ║
║  │              │    🎤     │  ◄── Estado: IDLE               │  ║
║  │              │           │      Borde gris                 │  ║
║  │              └───────────┘                                 │  ║
║  │                                                            │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                  ║
║  Ejemplos de lo que puedes decir:                               ║
║                                                                  ║
║  💬 "Press banca 4 series de 8 con 80 kilos"                    ║
║  💬 "Sentadillas 3 por 5, notas: felt strong"                   ║
║  💬 "Luego curl bíceps 3x12 a 15 kg"                            ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

        │
        │ Usuario mantiene pulsado
        ▼

╔══════════════════════════════════════════════════════════════════╗
║         DICTAR SESIÓN                                            ║
║     ─────────────────────                                        ║
║                                                                  ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                            │  ║
║  │     🔴 ESCUCHANDO...                                       │  ║
║  │                                                            │  ║
║  │              ┌───────────┐                                 │  ║
║  │              │    🎤     │  ◄── Estado: LISTENING          │  ║
║  │              │   ████    │      Borde rojo + glow          │  ║
║  │              └───────────┘      Animación pulsante         │  ║
║  │                                                            │  ║
║  │  "press banca cuatro series de ocho con ochenta..."       │  ║
║  │   ▲                                                        │  ║
║  │   └── Transcripción en tiempo real (gris claro)           │  ║
║  │                                                            │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                  ║
║  ⚠️ Ambiente ruidoso detectado. Habla más cerca del micro.      ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

        │
        │ Usuario suelta
        ▼

╔══════════════════════════════════════════════════════════════════╗
║         CONFIRMAR EJERCICIOS                                     ║
║     ─────────────────────────                                    ║
║                                                                  ║
║  📅 Sesión del 24 Ene 2026                                      ║
║                                                                  ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │  ✅ Press Banca                        🟢 95%              │  ║
║  │     4 series × 8 reps @ 80 kg                              │  ║
║  │     [Editar] [Cambiar ejercicio] [✕]                       │  ║
║  ├────────────────────────────────────────────────────────────┤  ║
║  │  ✅ Sentadilla                         🟡 78%              │  ║
║  │     3 series × 5 reps                                      │  ║
║  │     Nota: "felt strong"                                    │  ║
║  │     [Editar] [Cambiar ejercicio] [✕]                       │  ║
║  ├────────────────────────────────────────────────────────────┤  ║
║  │  ✅ Curl de Bíceps                     🟢 92%              │  ║
║  │     3 series × 12 reps @ 15 kg                             │  ║
║  │     [Editar] [Cambiar ejercicio] [✕]                       │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                  ║
║  [🎤 Añadir más]  [📷 Escanear]                                 ║
║                                                                  ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │  ☐ Incluir en métricas de progresión                       │  ║
║  │    (Afecta sugerencias de peso automáticas)                │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                  ║
║  [ CANCELAR ]            [ GUARDAR SESIÓN EXTERNA ]             ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### Modelo de Datos: Sesión Externa

```dart
class ExternalSession {
  final String id;
  final DateTime date;
  final List<ExternalExercise> exercises;
  final String? notes;
  final bool includeInProgression; // Opt-in para métricas
  final bool isExternal = true;    // Marcador visual
  final DateTime addedAt;
  final String source; // 'voice', 'ocr', 'text', 'manual'
}

class ExternalExercise {
  final String name;
  final int? libraryId;
  final int series;
  final String repsRange;
  final double? weight;
  final String? notes;
  final double confidence;
  final String rawInput;
}
```

### Visualización en Historial

```
┌────────────────────────────────────────────────────────────────┐
│  ESTA SEMANA                                                    │
├────────────────────────────────────────────────────────────────┤
│  ┌──────┐                                                      │
│  │  24  │  PUSH/PULL/LEGS · DÍA A                             │
│  │ ENE  │  10:30 · 65 MIN · 12.5t                             │
│  └──────┘                                                      │
├────────────────────────────────────────────────────────────────┤
│  ┌──────┐                                                      │
│  │  22  │  📤 SESIÓN EXTERNA                  ◄── Icono distintivo
│  │ ENE  │  Añadida por voz · 3 ejercicios                     │
│  └──────┘                                     ◄── Color diferente
├────────────────────────────────────────────────────────────────┤
│  ┌──────┐                                                      │
│  │  20  │  PUSH/PULL/LEGS · DÍA B                             │
│  │ ENE  │  18:15 · 58 MIN · 11.2t                             │
│  └──────┘                                                      │
└────────────────────────────────────────────────────────────────┘
```

---

## 3.3 FLUJO: Revamp Captura Voz + OCR

### Arquitectura de Detección de Ruido

```dart
/// Niveles de calidad de audio
enum AudioQuality {
  excellent,  // SNR > 20dB - Procesar normal
  good,       // SNR 15-20dB - Procesar con warning
  fair,       // SNR 10-15dB - Sugerir acercarse
  poor,       // SNR < 10dB - Forzar fallback
}

/// Estrategia de detección
class NoiseDetectionService {
  // Analiza los primeros 500ms de audio
  Future<AudioQuality> analyzeAmbientNoise();

  // Stream de nivel de ruido durante captura
  Stream<double> get noiseLevel;

  // Sugerencias basadas en contexto
  String getSuggestion(AudioQuality quality) {
    switch (quality) {
      case AudioQuality.excellent: return null;
      case AudioQuality.good: return null;
      case AudioQuality.fair:
        return "Ambiente ruidoso. Habla más cerca del micro.";
      case AudioQuality.poor:
        return "Demasiado ruido. Usa texto o entrada manual.";
    }
  }
}
```

### Pipeline OCR Mejorado

```
┌─────────────────────────────────────────────────────────────────┐
│                     PIPELINE OCR MEJORADO                        │
└─────────────────────────────────────────────────────────────────┘

1. CAPTURA
   └── Cámara / Galería
           │
           ▼
2. PRE-PROCESAMIENTO
   ├── Detección de bordes
   ├── Ajuste de contraste automático
   ├── Corrección de perspectiva
   └── Binarización adaptativa
           │
           ▼
3. OCR (ML Kit)
   ├── Reconocimiento de texto
   └── Extracción de bloques con coordenadas
           │
           ▼
4. POST-PROCESAMIENTO
   ├── NLP contextual (fitness terms)
   ├── Corrección de errores comunes
   │   - "8anca" → "banca"
   │   - "5entadilla" → "sentadilla"
   │   - "4x1O" → "4x10"
   └── Scoring de confianza por zona
           │
           ▼
5. PREVIEW INTERACTIVO
   ├── Overlay visual sobre imagen original
   ├── Zonas resaltadas por confianza
   │   - Verde: Alta (>80%)
   │   - Amarillo: Media (60-80%)
   │   - Rojo: Baja (<60%)
   └── Edición inline por zona
           │
           ▼
6. CONFIRMACIÓN
   └── Lista editable final → Guardar
```

### Wireframe: OCR con Overlay

```
╔══════════════════════════════════════════════════════════════════╗
║         ESCANEAR ENTRENAMIENTO                                   ║
║     ────────────────────────────                                 ║
║                                                                  ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │                                                            │  ║
║  │   ┌─────────────────────────────────────────────────────┐  │  ║
║  │   │                                                     │  │  ║
║  │   │  ┌──────────────────────────────────────────────┐   │  │  ║
║  │   │  │ Press Banca 4x8 @ 80kg        │ 🟢 95%      │   │  │  ║
║  │   │  └──────────────────────────────────────────────┘   │  │  ║
║  │   │                                                     │  │  ║
║  │   │  ┌──────────────────────────────────────────────┐   │  │  ║
║  │   │  │ Sentad1lla 3x5                │ 🟡 72%      │   │  │  ║
║  │   │  └──────────────────────────────────────────────┘   │  │  ║
║  │   │          ▲                                          │  │  ║
║  │   │          └── Tap para corregir                     │  │  ║
║  │   │                                                     │  │  ║
║  │   │  ┌──────────────────────────────────────────────┐   │  │  ║
║  │   │  │ [ilegible]                    │ 🔴 35%      │   │  │  ║
║  │   │  └──────────────────────────────────────────────┘   │  │  ║
║  │   │          ▲                                          │  │  ║
║  │   │          └── Tap para escribir manualmente         │  │  ║
║  │   │                                                     │  │  ║
║  │   └─────────────────────────────────────────────────────┘  │  ║
║  │                      [Imagen escaneada]                    │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                  ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │  ℹ️ OCR funciona mejor con texto claro y legible.          │  ║
║  │     Toca las zonas marcadas para corregir.                 │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                  ║
║  [ RE-ESCANEAR ]                      [ CONFIRMAR 2 de 3 ]      ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### Sistema de Fallback Automático

```
┌─────────────────────────────────────────────────────────────────┐
│                  CASCADA DE FALLBACK                             │
└─────────────────────────────────────────────────────────────────┘

Intento 1: VOZ
    │
    ├── Éxito? → Continuar
    │
    └── Fallo?
            │
            ├── Error tipo 1: "No entendido"
            │       │
            │       ▼
            │   Mostrar: "¿Intentar de nuevo?"
            │            [🎤 Reintentar] [⌨️ Escribir]
            │
            ├── Error tipo 2: Ruido excesivo
            │       │
            │       ▼
            │   Mostrar: "Mucho ruido. Intenta escribir."
            │            [⌨️ Escribir] [✋ Manual]
            │
            └── Error tipo 3: 2+ fallos consecutivos
                    │
                    ▼
                Mostrar: "Parece difícil por voz. Prueba otra opción."
                         [⌨️ Texto] [📷 OCR] [✋ Manual]

                Auto-switch a entrada de texto
```

---

## 3.4 FLUJO: Voz Durante Entrenamiento Activo

### Comandos Soportados (v2.0)

| Comando | Variantes | Acción | Feedback |
|---------|-----------|--------|----------|
| Marcar serie | "Hecho", "Listo", "Completado" | Marca set actual | Haptic heavy + check visual |
| Siguiente | "Siguiente", "Next", "Adelante" | Navega a próximo set | Haptic medium |
| Peso | "Peso 80 kilos", "80 kg" | Ajusta peso del set | Muestra nuevo valor |
| Reps | "12 reps", "12 repeticiones" | Ajusta reps del set | Muestra nuevo valor |
| RPE | "RPE 8", "Esfuerzo 8" | Registra RPE | Muestra escala |
| Descanso | "Descanso", "Timer 90" | Inicia timer | Timer visible |
| Nota | "Nota: dolor en hombro" | Añade nota al set | Icono nota visible |

### Diseño del FAB PTT para Entrenamiento

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │           SESIÓN DE ENTRENAMIENTO                          │  ║
║  │                                                            │  ║
║  │   Press Banca                                              │  ║
║  │   ────────────                                             │  ║
║  │                                                            │  ║
║  │   Serie 2 de 4                                             │  ║
║  │   ┌───────────────────────────────────────────────────┐    │  ║
║  │   │   80 kg  ×  8 reps   [  ✓  ]                      │    │  ║
║  │   └───────────────────────────────────────────────────┘    │  ║
║  │                                                            │  ║
║  │   ...                                                      │  ║
║  │                                                            │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                  ║
║                                                                  ║
║  ┌─────────────────────────────────────────────┐                ║
║  │  Di: "Hecho", "80 kilos", "10 reps"...     │ ◄── Hint       ║
║  └─────────────────────────────────────────────┘                ║
║                                                                  ║
║  ┌────┐                                                         ║
║  │ 🎤 │ ◄── FAB pequeño, esquina inferior izquierda            ║
║  └────┘     Push to talk                                        ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

        │
        │ Usuario mantiene pulsado y dice "Hecho"
        ▼

╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │           SESIÓN DE ENTRENAMIENTO                          │  ║
║  │                                                            │  ║
║  │   Press Banca                                              │  ║
║  │   ────────────                                             │  ║
║  │                                                            │  ║
║  │   Serie 2 de 4  ✅ COMPLETADA                              │  ║
║  │   ┌───────────────────────────────────────────────────┐    │  ║
║  │   │   80 kg  ×  8 reps   [  ✓  ]  ← Verde             │    │  ║
║  │   └───────────────────────────────────────────────────┘    │  ║
║  │                                                            │  ║
║  │   ↓ Siguiente serie auto-enfocada                         │  ║
║  │                                                            │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                  ║
║  ┌─────────────────────────────────────────────┐                ║
║  │  ✓ "Hecho" reconocido                       │ ◄── Confirmación
║  └─────────────────────────────────────────────┘                ║
║                                                                  ║
║  ┌────┐                                                         ║
║  │ ✓  │ ◄── Icono cambia brevemente a check                    ║
║  └────┘                                                         ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

# 4. REGLAS DE ORO DEL SISTEMA DE VOZ

## Las 10 Reglas Inquebrantables

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                                                  ┃
┃  1. SIN PULSAR = SIN ESCUCHAR                                    ┃
┃     La app NUNCA escucha sin acción explícita del usuario.       ┃
┃                                                                  ┃
┃  2. FEEDBACK INMEDIATO                                           ┃
┃     Cada cambio de estado tiene feedback visual + audio.         ┃
┃                                                                  ┃
┃  3. PREVIEW OBLIGATORIO                                          ┃
┃     Nada se guarda sin mostrar primero qué se va a guardar.     ┃
┃                                                                  ┃
┃  4. CONFIANZA VISIBLE                                            ┃
┃     El usuario siempre ve qué tan seguro está el sistema.        ┃
┃                                                                  ┃
┃  5. EDICIÓN SIEMPRE POSIBLE                                      ┃
┃     Todo dato detectado es editable antes de confirmar.          ┃
┃                                                                  ┃
┃  6. UNDO DE 10 SEGUNDOS                                          ┃
┃     Toda acción tiene ventana de deshacer.                       ┃
┃                                                                  ┃
┃  7. FALLBACK PROACTIVO                                           ┃
┃     Tras 2 fallos, ofrecer alternativa automáticamente.          ┃
┃                                                                  ┃
┃  8. LÍMITES CLAROS                                               ┃
┃     Mostrar qué puede y qué no puede hacer la voz.               ┃
┃                                                                  ┃
┃  9. UN TAP = SIGUIENTE OPCIÓN                                    ┃
┃     Minimizar fricción en contexto de gimnasio.                  ┃
┃                                                                  ┃
┃  10. SESIONES EXTERNAS ≠ AUTOMÁTICAS                             ┃
┃      Las externas no afectan progresión sin opt-in explícito.    ┃
┃                                                                  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

---

# 5. RIESGOS Y MITIGACIÓN

## Matriz de Riesgos

| ID | Riesgo | Probabilidad | Impacto | Mitigación |
|----|--------|--------------|---------|------------|
| R1 | Usuario no entiende PTT | Media | Alto | Onboarding + tooltip en primer uso |
| R2 | Ruido de gimnasio impide uso | Alta | Alto | Detección proactiva + fallback auto |
| R3 | OCR falla con letra manuscrita | Alta | Medio | Pre-procesamiento + edición inline |
| R4 | Sesiones externas corrompen métricas | Media | Alto | Opt-in explícito para progresión |
| R5 | Latencia en procesamiento | Baja | Medio | Indicador de progreso + optimización |
| R6 | Falsos positivos en comandos | Media | Alto | Confirmación visual antes de aplicar |
| R7 | Usuario no encuentra feature | Media | Medio | FAB visible + onboarding |
| R8 | Batería consumida por voz | Baja | Bajo | Solo activo durante PTT |
| R9 | Privacidad (audio grabado) | Baja | Alto | Procesamiento 100% on-device |
| R10 | Ejercicios no reconocidos | Media | Medio | Búsqueda manual + añadir al diccionario |

## Estrategias de Mitigación Detalladas

### R1: Onboarding de PTT
```dart
class PttOnboardingOverlay extends StatelessWidget {
  // Mostrar en primer uso del feature de voz
  // 1. Animación de pulsar y mantener
  // 2. Explicación de estados
  // 3. "Entendido" para cerrar
}
```

### R2: Detección de Ruido Proactiva
```dart
Future<void> startListening() async {
  final quality = await _noiseService.analyzeAmbientNoise();

  if (quality == AudioQuality.poor) {
    _showFallbackSuggestion();
    return; // No iniciar escucha
  }

  if (quality == AudioQuality.fair) {
    _showNoiseWarning();
  }

  // Proceder con escucha
  await _speech.startListening();
}
```

### R4: Opt-in para Progresión
```dart
// En el sheet de sesión externa
CheckboxListTile(
  title: Text('Incluir en métricas de progresión'),
  subtitle: Text('Afecta las sugerencias automáticas de peso'),
  value: includeInProgression,
  onChanged: (v) => setState(() => includeInProgression = v!),
)
```

### R6: Confirmación de Comandos
```dart
// Durante entrenamiento
void onVoiceCommand(VoiceTrainingCommand cmd) {
  // Mostrar confirmación visual 1.5s antes de aplicar
  _showCommandPreview(cmd);

  Future.delayed(Duration(milliseconds: 1500), () {
    if (!_commandCancelled) {
      _applyCommand(cmd);
    }
  });
}
```

---

# 6. MÉTRICAS DE ÉXITO

## KPIs del Sistema de Voz

| Métrica | Objetivo | Medición |
|---------|----------|----------|
| Tasa de adopción | >30% usuarios activos usan voz/mes | Analytics |
| Precisión de transcripción | >85% correcto sin edición | Logs internos |
| Tiempo hasta confirmación | <5s desde soltar botón | Medición en app |
| Tasa de fallback | <15% usan fallback | Logs internos |
| Sesiones externas/usuario | >2/mes entre usuarios que lo usan | Analytics |
| NPS de feature de voz | >40 | Encuesta in-app |
| Tasa de undo | <10% (indica confianza) | Logs internos |

## Logging para Iteración

```dart
class VoiceAnalytics {
  void logVoiceSession({
    required String sessionType, // 'routine', 'training', 'external'
    required bool successful,
    required Duration listeningTime,
    required int exercisesDetected,
    required int exercisesEdited,
    required int fallbackUsed,
    required String? errorType,
    required double avgConfidence,
  });
}
```

---

# 7. CHECKLIST DE IMPLEMENTACIÓN

## Fase 1: Push To Talk Core
- [ ] Modificar `VoiceInputService` para PTT explícito
- [ ] Actualizar `VoiceMicButton` con estados visuales
- [ ] Añadir feedback audio por estado
- [ ] Implementar detección de ruido básica
- [ ] Tests unitarios de estados

## Fase 2: Sesiones Externas
- [ ] Crear modelo `ExternalSession`
- [ ] Crear `ExternalSessionSheet` UI
- [ ] Integrar en `HistoryScreen`
- [ ] Añadir badge visual para externas
- [ ] Implementar opt-in de progresión
- [ ] Tests de integración

## Fase 3: OCR Mejorado
- [ ] Implementar pre-procesamiento de imagen
- [ ] Añadir overlay interactivo
- [ ] Mostrar confianza por zona
- [ ] Edición inline en overlay
- [ ] Tests de precisión

## Fase 4: Fallbacks y UX
- [ ] Implementar cascada de fallback
- [ ] Añadir undo de 10 segundos
- [ ] Onboarding de PTT
- [ ] Tooltips y guías contextuales
- [ ] Tests de usabilidad

---

**Documento preparado para implementación. Prioridad: Fase 1 > Fase 2 > Fase 4 > Fase 3**
