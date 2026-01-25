# Voice System UX Design - Juan Training

## Documento de Diseño UX para Sistema de Voz
### Versión 2.0 - Rediseño Push-To-Talk

---

## 1. DIAGNÓSTICO DEL SISTEMA ACTUAL

### 1.1 Problemas Identificados

| Problema | Impacto | Severidad |
|----------|---------|-----------|
| **Modo continuo ambiguo** | Usuario no sabe si la app escucha o no | CRÍTICO |
| **Sin límites claros** | Usuario espera funciones que no existen | ALTO |
| **Contexto no visible** | No se muestra qué campo se modificará | ALTO |
| **Sin undo** | Errores por voz no se pueden revertir fácilmente | MEDIO |
| **Sin sesiones externas** | No se puede registrar entrenamientos fuera de la app | MEDIO |

### 1.2 Lo Que Funciona Bien

- ✅ Parsing de ejercicios con series, reps, peso
- ✅ Feedback de audio según confianza del match
- ✅ Preview editable antes de confirmar
- ✅ Sistema de correcciones ("no, quise decir...")
- ✅ Reconocimiento offline (privacidad total)
- ✅ Vibración háptica en inicio/fin

---

## 2. DECISIONES DE DISEÑO

### 2.1 PRINCIPIO BASE: Push-To-Talk OBLIGATORIO

**Decisión:** Eliminar el "modo continuo" como opción visible. La voz SOLO escucha mientras el botón está activo.

**Comportamiento exacto:**

```
INICIO DE ESCUCHA:
├── Usuario toca/mantiene botón de micrófono
├── Vibración háptica inmediata (mediumImpact)
├── Tono de audio "inicio" (opcional, configurable)
├── Cambio visual inmediato:
│   ├── Botón cambia a rojo con glow pulsante
│   └── Texto "ESCUCHANDO..." aparece
└── Micrófono comienza a capturar

FIN DE ESCUCHA:
├── Usuario suelta botón O toca para detener
├── Vibración háptica (heavyImpact)
├── Tono de audio "fin" (opcional)
├── Cambio visual:
│   ├── Botón vuelve a estado normal
│   └── Texto cambia a "Procesando..."
└── Se procesa la transcripción

SI NO SE ENTIENDE:
├── Mostrar "No entendido" con ícono de warning
├── Opción de "Reintentar" visible
└── No aplicar ningún cambio silencioso
```

**Regla de oro:** Si el usuario no está tocando el botón → la app NO escucha. Nunca.

### 2.2 CONTEXTO 1: Crear Rutinas por Voz

**Decisión:** Opción A - Voz estructurada básica (YA IMPLEMENTADO, solo mejorar UX)

**Qué SÍ captura la voz:**
- ✅ Nombre del ejercicio
- ✅ Número de series
- ✅ Repeticiones (número o rango)
- ✅ Peso objetivo (si se menciona)
- ✅ Notas ("nota: usar cinturón")
- ✅ Superseries ("superserie con X e Y")

**Qué NO captura:**
- ❌ Tempo de ejecución
- ❌ Descanso entre series
- ❌ RPE objetivo
- ❌ Variaciones de agarre
- ❌ Métodos avanzados (drop sets, rest-pause detallado)

**Cambios de UI requeridos:**

```
┌─────────────────────────────────────────────────────────┐
│                   DICTADO POR VOZ                       │
├─────────────────────────────────────────────────────────┤
│  ╭─────────────────────────────────────────────────╮    │
│  │ ℹ️  La voz captura: ejercicio, series, reps,   │    │
│  │     peso y notas. Detalles avanzados se         │    │
│  │     ajustan después manualmente.                │    │
│  ╰─────────────────────────────────────────────────╯    │
│                                                         │
│                    [ 🎤 PULSAR ]                        │
│                  "Mantén para hablar"                   │
│                                                         │
│  Ejemplos:                                              │
│  • "Press banca 4 series de 8"                          │
│  • "Sentadilla 5x5 a 100 kilos"                         │
│  • "Curl bíceps 3x12, nota: usar barra Z"               │
└─────────────────────────────────────────────────────────┘
```

### 2.3 CONTEXTO 2: Entrenamiento (Logging por Voz)

**Decisión:** Ampliar capacidades + mostrar contexto claro

**Qué SÍ puede dictar durante entrenamiento:**
- ✅ Peso: "80 kilos", "100 kg"
- ✅ Repeticiones: "10 reps", "8 repeticiones"
- ✅ Combinado: "80 por 10", "100 kilos por 8"
- ✅ RPE: "RPE 8", "esfuerzo 9"
- ✅ Notas: "nota: sentí fuerte hoy"
- ✅ Marcar hecho: "hecho", "listo", "completado"
- ✅ Siguiente: "siguiente", "próxima"
- ✅ Descanso: "descanso 90 segundos"

**Cambios de UI requeridos - Overlay con contexto:**

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│            🔴 ESCUCHANDO...                             │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  MODIFICANDO:                                     │  │
│  │  ══════════════════════════════════════════════   │  │
│  │  📍 Press Banca - Serie 2 de 4                    │  │
│  │                                                   │  │
│  │  Campos activos:                                  │  │
│  │  [Peso: 80kg] [Reps: --] [RPE: --]               │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  Transcripción: "ochenta kilos diez reps..."           │
│                                                         │
│  ────────────────────────────────────────────────────   │
│  Di: "80 kilos", "10 reps", "RPE 8", "hecho"           │
│                                                         │
│           [ Toca en cualquier lugar para detener ]      │
└─────────────────────────────────────────────────────────┘
```

**Binding de contexto:**
- La voz SIEMPRE afecta SOLO la serie activa actual
- Nunca modifica series pasadas sin confirmación
- Nunca modifica todo el ejercicio de golpe

### 2.4 CONTEXTO 3: Historial (Sesiones Externas)

**Nueva funcionalidad:** Permitir agregar entrenamientos realizados fuera de la app.

**Modos de entrada:**

| Modo | Descripción | Cuándo usar |
|------|-------------|-------------|
| **Voz** | Dictar sesión completa | Entrada rápida, datos básicos |
| **Manual** | Formularios tap-by-tap | Máxima precisión |
| **Híbrido** | Voz + edición manual | Balance velocidad/precisión |

**Ejemplos de input por voz:**
- "Sesión del lunes: press banca 4 series de 8 con 80 kilos"
- "Ayer entrené pierna: sentadillas 5x5 a 100, prensa 4x12"
- "Entrenamiento de hace 3 días: espalda completa"

**Qué extrae:**
- Fecha (relativa o absoluta, confirma si ambigua)
- Ejercicios con series/reps/peso
- Notas por ejercicio

**Flujo UX:**

```
1. Usuario accede a Historial → Botón "+" o "Agregar sesión"

2. Selector de modo:
   ┌─────────────────────────────────────┐
   │     AGREGAR SESIÓN EXTERNA          │
   ├─────────────────────────────────────┤
   │  ┌─────────┐  ┌─────────┐           │
   │  │   🎤    │  │   ✏️    │           │
   │  │  Voz    │  │ Manual  │           │
   │  └─────────┘  └─────────┘           │
   └─────────────────────────────────────┘

3. Si elige VOZ:
   ┌─────────────────────────────────────┐
   │     DICTAR SESIÓN PASADA            │
   ├─────────────────────────────────────┤
   │  📅 Fecha: [Hoy ▼]                  │
   │                                     │
   │  ℹ️ Di la fecha y ejercicios.       │
   │  Ejemplo: "Ayer: press 4x8, remo    │
   │  3x12 a 50 kilos"                   │
   │                                     │
   │          [ 🎤 PULSAR ]              │
   └─────────────────────────────────────┘

4. Después de dictar:
   ┌─────────────────────────────────────┐
   │     CONFIRMAR SESIÓN                │
   ├─────────────────────────────────────┤
   │  📅 Lunes, 20 Enero 2026            │
   │                                     │
   │  ┌─────────────────────────────┐    │
   │  │ Press Banca         4x8    │ ✏️ │
   │  │ 80 kg                      │    │
   │  └─────────────────────────────┘    │
   │  ┌─────────────────────────────┐    │
   │  │ Remo con Barra      3x12   │ ✏️ │
   │  │ 50 kg                      │    │
   │  └─────────────────────────────┘    │
   │                                     │
   │  [CANCELAR]  [GUARDAR EN HISTORIAL] │
   └─────────────────────────────────────┘

5. En historial, sesión aparece con badge:
   ┌─────────────────────────────────────┐
   │ 📱 20 Ene - Sesión externa          │
   │ ↳ Press Banca, Remo...              │
   └─────────────────────────────────────┘
```

**Reglas de integridad:**
- Sesiones externas NO afectan métricas de progresión automática por defecto
- Opción de "incluir en estadísticas" con opt-in explícito
- Siempre marcadas visualmente como "externas"
- Undo disponible por 30 segundos después de guardar

---

## 3. FEEDBACK Y ESTADOS VISUALES

### 3.1 Estados del Sistema de Voz

| Estado | Visual | Audio | Háptico |
|--------|--------|-------|---------|
| **Idle** | Botón gris, "Pulsar para hablar" | - | - |
| **Listening** | Botón rojo pulsante, "ESCUCHANDO..." | Tono inicio (523Hz) | Medium impact |
| **Processing** | Barra progreso, "Procesando..." | - | - |
| **Success** | Check verde, preview de datos | Tono éxito (659Hz) | Light impact |
| **Not Understood** | Warning amarillo, "No entendido" | Tono error (349Hz) | - |
| **Error** | Rojo, mensaje de error | - | - |

### 3.2 Feedback Visual Detallado

**Botón de micrófono - Estados:**

```
IDLE:
┌──────────┐
│   🎤     │  Gris, borde sutil
│  Dictar  │
└──────────┘

LISTENING:
┌──────────┐
│   🎤     │  Rojo, glow pulsante, sombra roja
│ Escucha..│  Borde animado
└──────────┘

PROCESSING:
┌──────────┐
│   ⏳     │  Gris con spinner
│ Procesa..│
└──────────┘

NOT_UNDERSTOOD:
┌──────────┐
│   ⚠️     │  Amarillo/naranja
│ Reintentar│
└──────────┘
```

---

## 4. REGLAS DE ORO DEL SISTEMA DE VOZ

### 4.1 Principios Inquebrantables

1. **Push-To-Talk siempre**
   - Si no hay dedo en el botón → no hay escucha
   - Nunca escucha en segundo plano
   - Nunca activa automáticamente

2. **Límites claros siempre visibles**
   - Texto explícito de qué captura y qué no
   - Ejemplos concretos siempre accesibles
   - Sin promesas implícitas de "magia"

3. **Contexto antes de acción**
   - Mostrar QUÉ se va a modificar ANTES de hacerlo
   - Serie activa claramente indicada
   - Campos afectados resaltados

4. **Confirmación antes de guardar**
   - Preview editable obligatorio
   - Nunca guardar sin confirmación visual
   - Especialmente para historial y datos persistentes

5. **Undo siempre disponible**
   - Toda acción por voz reversible
   - Snackbar con "DESHACER" por 5 segundos
   - Historial de acciones recientes

6. **No hay errores silenciosos**
   - Si no entiende → mostrar "No entendido"
   - Si hay ambigüedad → pedir clarificación
   - Nunca asumir sin indicar

### 4.2 Qué Nunca Hacer

❌ Escuchar sin indicador visual activo
❌ Modificar datos sin preview
❌ Asumir fecha/contexto sin confirmar
❌ Sobrescribir sin mostrar qué se sobrescribe
❌ Guardar en historial sin confirmación
❌ Afectar métricas de progresión sin opt-in

---

## 5. RIESGOS Y MITIGACIONES

### 5.1 Matriz de Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Usuario habla sin querer | Media | Bajo | Push-To-Talk elimina esto |
| Reconocimiento incorrecto | Media | Medio | Preview editable + undo |
| Confusión de contexto | Baja | Alto | Mostrar serie/campo activo |
| Datos erróneos en historial | Baja | Alto | Confirmación obligatoria |
| Pérdida de confianza | Media | Alto | Límites claros + sin "magia" |

### 5.2 Escenarios de Fallo y Respuestas

**Escenario 1: Ruido de gimnasio interfiere**
- Mitigación: Push-To-Talk limita ventana de captura
- Feedback: Si no entiende, "No entendido" claro
- Acción: Opción de reintentar o usar teclado

**Escenario 2: Usuario dice algo fuera de alcance**
- Ejemplo: "Ponme música motivacional"
- Respuesta: "No entendido. La voz aquí solo modifica peso, reps o notas."
- No intentar "adivinar" intención

**Escenario 3: Fecha ambigua en sesión externa**
- Ejemplo: "La semana pasada entrené..."
- Respuesta: Selector de fecha con sugerencia
- Confirmar explícitamente antes de guardar

---

## 6. MÉTRICAS DE ÉXITO

### 6.1 KPIs de UX

| Métrica | Objetivo | Cómo medir |
|---------|----------|------------|
| Tasa de "No entendido" | < 15% | Logs de estado |
| Uso de undo | < 10% de acciones | Logs de undo |
| Tiempo para completar (voz vs manual) | Voz 40% más rápido | A/B testing |
| NPS del sistema de voz | > 7/10 | Encuesta in-app |
| Tasa de abandono mid-dictado | < 20% | Logs de cancelación |

### 6.2 Señales de Problema

🚨 Si estos números suben, algo está mal:
- Tasa de undo > 20%
- Cancelaciones mid-dictado > 30%
- Reportes de "la voz no hace lo que espero"
- Usuarios desactivando feature de voz

---

## 7. IMPLEMENTACIÓN TÉCNICA

### 7.1 Cambios Requeridos

**voice_input_sheet.dart:**
- Eliminar toggle de "modo continuo" de UI
- Añadir banner de límites de voz
- Mejorar texto de estado "No entendido"

**voice_training_button.dart:**
- Añadir contexto de serie activa en overlay
- Mostrar campos que se modificarán
- Añadir estado "Not understood"

**voice_input_provider.dart:**
- Añadir estado `notUnderstood`
- Implementar historial de acciones para undo
- Método `undoLastAction()`

**Nueva pantalla:**
- `external_session_screen.dart` para subir sesiones

**Nuevos widgets:**
- `VoiceCapabilitiesBanner` - Banner informativo
- `VoiceContextIndicator` - Muestra qué se modificará
- `VoiceUndoSnackbar` - Snackbar con undo

### 7.2 Orden de Implementación

1. ✅ Push-To-Talk obligatorio (eliminar modo continuo)
2. ✅ Banner de límites en creación de rutinas
3. ✅ Overlay con contexto en entrenamiento
4. ✅ Estado "No entendido" con feedback
5. ✅ Sistema de undo
6. ✅ Pantalla de sesiones externas

---

## 8. RESUMEN EJECUTIVO

### Antes vs Después

| Aspecto | Antes | Después |
|---------|-------|---------|
| Activación | Ambigua (tap vs long press vs continuo) | Push-To-Talk claro |
| Límites | Implícitos | Explícitos con banner |
| Contexto | No visible | Serie y campos mostrados |
| Errores | Silenciosos a veces | Siempre "No entendido" |
| Reversibilidad | Limitada | Undo en toda acción |
| Sesiones externas | No existe | Nuevo flujo completo |

### Mentalidad de Diseño

> "En el gimnasio, la voz debe ahorrar fricción, no crear dudas.
> Si el usuario duda → el sistema está mal diseñado."

El sistema de voz rediseñado prioriza:
1. **Control** sobre conveniencia
2. **Claridad** sobre brevedad
3. **Predicibilidad** sobre "inteligencia"
4. **Transparencia** sobre "magia"

---

*Documento creado: Enero 2026*
*Autor: Senior Mobile UX Engineer - Voice Interfaces*
