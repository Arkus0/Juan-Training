# CONTROLADOR DE PROGRESIÓN v3

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        PROGRESSION CONTROLLER                           │
│                     (Orquestador / Máquina de Estados)                  │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐      │
│  │  EXECUTION DATA  │  │ PROGRESSION MODEL│  │    DECISION      │      │
│  │  (Datos Crudos)  │  │  (Estrategia)    │  │   (Resultado)    │      │
│  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤      │
│  │ - SessionHistory │  │ - Linear         │  │ - Action         │      │
│  │ - CurrentWeight  │  │ - Double         │  │ - NewWeight      │      │
│  │ - TargetReps     │  │ - RPE/RIR        │  │ - UserMessage    │      │
│  │ - Category       │  │ - Custom         │  │ - NextPreview    │      │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
```

## Separación de Responsabilidades

### Capa 1: ExecutionData (Datos Crudos)
- Contiene **solo hechos observables**
- No hace cálculos ni decisiones
- Inmutable después de creación

```dart
class ExecutionData {
  final String exerciseName;
  final ExerciseCategory category;
  final double confirmedWeight;        // Peso actual confirmado
  final (int, int) repsRange;          // (min, max)
  final List<SessionExecutionData> sessionHistory;
  final int weeksAtCurrentWeight;
}
```

### Capa 2: ProgressionModel (Estrategia)
- Implementa **un algoritmo específico**
- Intercambiable sin romper el sistema
- No conoce estado global

```dart
abstract class ProgressionModel {
  String get name;
  String get description;
  
  ProgressionDecision calculate({
    required ExecutionData data,
    required ControllerState currentState,
    required ProgressionThresholds thresholds,
  });
  
  ControllerState? shouldTransition(...);  // Puede sugerir cambio de estado
}
```

### Capa 3: ProgressionController (Orquestador)
- Mantiene **máquina de estados**
- Aplica **reglas de transición**
- Delega cálculo al modelo activo

```dart
class ProgressionController {
  ControllerState _state;
  ProgressionModel _model;
  ProgressionThresholds _thresholds;
  
  ProgressionDecision calculate(ExecutionData data);
  void setModel(ProgressionModel newModel);
  void setThresholds(ProgressionThresholds newThresholds);
}
```

---

## Diagrama de Estados

```
                    ┌──────────────────┐
                    │    CALIBRATING   │ ←─── Inicio (0-1 sesiones)
                    │    (calibrando)  │
                    └────────┬─────────┘
                             │ sessionHistory.length >= 2
                             ▼
     ┌──────────────────────────────────────────────────────────────┐
     │                                                              │
     │  ┌──────────────┐    éxito    ┌──────────────┐              │
     │  │  PROGRESSING │ ──────────► │  CONFIRMING  │              │
     │  │ (progresando)│ ◄────────── │ (confirmando)│              │
     │  └──────────────┘   fracaso   └──────┬───────┘              │
     │         │                            │                       │
     │         │ 3+ fracasos                │ 2do éxito             │
     │         ▼                            ▼                       │
     │  ┌──────────────┐           ┌──────────────┐                │
     │  │   PLATEAU    │           │   PROGRESS   │ (subir peso)   │
     │  │  (estancado) │           │   ACHIEVED   │                │
     │  └──────┬───────┘           └──────────────┘                │
     │         │                                                    │
     │         │ automático                                         │
     │         ▼                                                    │
     │  ┌──────────────┐                                           │
     │  │   DELOADING  │ ──► consecutiveSuccesses >= 1 ──►        │
     │  │   (deload)   │              vuelve a PROGRESSING         │
     │  └──────────────┘                                           │
     │                                                              │
     │  ┌──────────────┐           ┌──────────────┐                │
     │  │   FATIGUED   │ ◄──────── │ averageRpe   │                │
     │  │   (fatiga)   │    ≥9     │ alto 3+ ses  │                │
     │  └──────────────┘           └──────────────┘                │
     │                                                              │
     └──────────────────────────────────────────────────────────────┘
```

---

## Estados Detallados

| Estado | Emoji | Condición Entrada | Comportamiento | Salida |
|--------|-------|-------------------|----------------|--------|
| `calibrating` | ⚙️ | 0-1 sesiones | Recopilar datos | → `progressing` (2 sesiones) |
| `progressing` | 📈 | ≥2 sesiones | Seguir modelo activo | → `confirming` (1 éxito) |
| `confirming` | 🔄 | 1 éxito consecutivo | Esperar confirmación | → subir peso (2º éxito) |
| `plateau` | ⚠️ | 3+ fracasos | Iniciar deload | → `deloading` |
| `deloading` | 🔽 | Después de plateau | Peso reducido | → `progressing` (1 éxito) |
| `fatigued` | 😓 | RPE ≥9 consistente | Reducir intensidad | → `progressing` (RPE <9) |
| `regression` | ↩️ | Peso demasiado alto | Bajar peso significativo | → `progressing` |

---

## Reglas de Transición (Explícitas)

```dart
// Regla 1: Calibración → Progresión
if (sessionHistory.length >= 2) {
  transition(calibrating → progressing)
  reason: "2 sesiones completadas"
}

// Regla 2: Progresión → Confirmación
if (consecutiveSuccesses == 1 && confirmationSessions > 1) {
  transition(progressing → confirming)
  reason: "1 éxito, esperando confirmación"
}

// Regla 3: Confirmación → Progresión (éxito)
if (consecutiveSuccesses >= confirmationSessions) {
  transition(confirming → progressing)
  action: INCREASE_WEIGHT
  reason: "Confirmado, subir peso"
}

// Regla 4: Confirmación → Progresión (fracaso)
if (consecutiveFailures > 0) {
  transition(confirming → progressing)
  reason: "Confirmación fallida, reintentar"
}

// Regla 5: Progresión → Estancamiento
if (consecutiveFailures >= plateauThreshold) {
  transition(progressing → plateau)
  reason: "N fracasos consecutivos"
}

// Regla 6: Estancamiento → Deload
if (state == plateau) {
  transition(plateau → deloading)
  reason: "Iniciando deload"
}

// Regla 7: Deload → Progresión
if (consecutiveSuccesses >= 1) {
  transition(deloading → progressing)
  reason: "Deload completado"
}

// Regla 8: Cualquier estado → Fatiga
if (averageRpe >= fatigueRpeThreshold) {
  transition(* → fatigued)
  reason: "RPE consistentemente alto"
}
```

---

## Umbrales Configurables

```dart
class ProgressionThresholds {
  /// % mínimo de series exitosas para considerar sesión "exitosa"
  final double successRate = 0.80;  // 80%
  
  /// Sesiones exitosas consecutivas para subir peso
  final int confirmationSessions = 2;
  
  /// Sesiones fallidas consecutivas para detectar estancamiento
  final int plateauThreshold = 3;
  
  /// RPE promedio para detectar fatiga
  final double fatigueRpeThreshold = 9.0;
  
  /// Semanas máximas en el mismo peso antes de forzar cambio
  final int maxWeeksAtWeight = 4;
}
```

### Presets de Umbrales

| Preset | successRate | confirmation | plateau | RPE fatiga |
|--------|-------------|--------------|---------|------------|
| `aggressive` (principiantes) | 75% | 1 | 2 | 9.5 |
| `defaults` (intermedios) | 80% | 2 | 3 | 9.0 |
| `conservative` (avanzados) | 85% | 3 | 4 | 8.5 |

---

## Modelos de Progresión (Intercambiables)

### 1. LinearProgressionModel
```
Reglas:
- Éxito → confirmar → subir peso
- Fracaso → mantener
- 3+ fracasos → deload
```

### 2. DoubleProgressionModel
```
Reglas:
- Éxito → +1 rep (si no está en max)
- Éxito en max reps × 2 → subir peso, volver a min reps
- Fracaso → mantener
```

### 3. RpeProgressionModel
```
Reglas:
- RPE < 7 → subir peso
- RPE 7-9 → mantener (zona óptima)
- RPE > 9 × 3 → fatiga, reducir
```

---

## Ejemplos de Transición

### Ejemplo 1: Flujo Exitoso
```
Sesión 1: 60kg × 8,8,7 → calibrating
Sesión 2: 60kg × 8,8,8 → progressing (calibración completa)
Sesión 3: 60kg × 8,8,8 ✓ → confirming (1/2)
Sesión 4: 60kg × 8,8,8 ✓ → progressing + SUBIR a 62.5kg
Sesión 5: 62.5kg × 8,8,7 → progressing (día difícil, OK)
Sesión 6: 62.5kg × 8,8,8 ✓ → confirming (1/2)
...
```

### Ejemplo 2: Día Malo No Castiga
```
Sesión 1: 60kg × 8,8,8 ✓ → confirming (1/2)
Sesión 2: 60kg × 6,6,5 ✗ → progressing (vuelve, no pasa nada)
Sesión 3: 60kg × 8,8,8 ✓ → confirming (1/2 de nuevo)
Sesión 4: 60kg × 8,8,8 ✓ → progressing + SUBIR a 62.5kg
```

### Ejemplo 3: Estancamiento y Deload
```
Sesión 1: 70kg × 6,5,5 ✗ → progressing
Sesión 2: 70kg × 5,5,5 ✗ → progressing (2º fracaso)
Sesión 3: 70kg × 5,5,4 ✗ → plateau (3er fracaso!)
Sesión 4: automático → deloading, sugerir 65kg
Sesión 5: 65kg × 8,8,8 ✓ → progressing (deload completado)
Sesión 6: 67.5kg × 8,8,8 ✓ → confirming...
```

### Ejemplo 4: Doble Progresión
```
Modelo: DoubleProgressionModel
Rango: 8-12 reps

Sesión 1: 50kg × 8,8,8 ✓ → progressing
Sesión 2: 50kg × 9,9,9 ✓ → progressing (+1 rep)
Sesión 3: 50kg × 10,10,10 ✓ → progressing (+1 rep)
Sesión 4: 50kg × 11,11,11 ✓ → progressing (+1 rep)
Sesión 5: 50kg × 12,12,12 ✓ → confirming (max reps, 1/2)
Sesión 6: 50kg × 12,12,12 ✓ → progressing + SUBIR a 52.5kg × 8
Sesión 7: 52.5kg × 8,8,8 ✓ → progressing (reinicia ciclo)
```

### Ejemplo 5: RPE-Based
```
Modelo: RpeProgressionModel

Sesión 1: 60kg × 8 (RPE 6) → subir peso
Sesión 2: 62.5kg × 8 (RPE 7) → mantener (zona óptima)
Sesión 3: 62.5kg × 8 (RPE 8) → mantener
Sesión 4: 62.5kg × 8 (RPE 9.5) → observar
Sesión 5: 62.5kg × 8 (RPE 9.5) → observar
Sesión 6: 62.5kg × 7 (RPE 10) → fatigued! reducir a 60kg
```

---

## Intercambiar Modelo Sin Romper UX

```dart
// El controller mantiene el estado
final controller = ProgressionController();

// Usuario cambia de Lineal a Doble Progresión
controller.setModel(const DoubleProgressionModel());

// El estado se mantiene (progressing, confirming, etc.)
// Solo cambia la lógica de cálculo

// Siguiente calculate() usa el nuevo modelo
final decision = controller.calculate(data);
```

### Qué se preserva al cambiar modelo:
- ✅ Estado actual (progressing, confirming, etc.)
- ✅ Historial de sesiones
- ✅ Peso confirmado
- ✅ Umbrales configurados

### Qué cambia:
- ⚡ Lógica de cuándo subir peso/reps
- ⚡ Mensajes al usuario
- ⚡ Criterios de éxito/fracaso

---

## Comunicación con Usuario

### Mensajes por Estado

| Estado | Icono | Mensaje |
|--------|-------|---------|
| `calibrating` | ⚙️ | "Sesión X de calibración. Establece tu baseline." |
| `progressing` | 📈 | "Continúa con el objetivo." |
| `confirming` | 🔄 | "Repite para confirmar. 1/2" |
| `plateau` | ⚠️ | "3 sesiones difíciles. Considera un deload." |
| `deloading` | 🔽 | "Deload: baja a Xkg para consolidar." |
| `fatigued` | 😓 | "RPE alto. Baja intensidad para recuperar." |

### Next Step Preview (siempre visible)
```
"Si éxito: 62.5kg × 8"
"Próximo hito: confirmar para subir peso"
"Después del deload: volver a progresar"
```

---

## Pseudocódigo del Controlador

```
function calculate(data: ExecutionData) -> ProgressionDecision:
    // 1. EVALUAR TRANSICIONES DE ESTADO
    newState = determineState(data)
    if newState != currentState:
        recordTransition(currentState, newState)
        currentState = newState
    
    // 2. DELEGAR AL MODELO ACTIVO
    decision = activeModel.calculate(
        data: data,
        currentState: currentState,
        thresholds: thresholds
    )
    
    return decision


function determineState(data: ExecutionData) -> ControllerState:
    // Regla: Calibración
    if data.sessionHistory.length < 2:
        return CALIBRATING
    
    // Regla: Fatiga (prioridad alta)
    if data.averageRpe >= thresholds.fatigueRpe:
        return FATIGUED
    
    // Regla: Estancamiento
    if data.consecutiveFailures >= thresholds.plateauThreshold:
        if currentState != DELOADING:
            return PLATEAU
    
    // Regla: Plateau → Deload
    if currentState == PLATEAU:
        return DELOADING
    
    // Regla: Deload completado
    if currentState == DELOADING and data.consecutiveSuccesses >= 1:
        return PROGRESSING
    
    // Regla: Confirmación
    if currentState == PROGRESSING and data.consecutiveSuccesses == 1:
        return CONFIRMING
    
    // Regla: Confirmación exitosa
    if currentState == CONFIRMING and data.consecutiveSuccesses >= 2:
        return PROGRESSING  // El modelo aplicará subida de peso
    
    // Regla: Confirmación fallida
    if currentState == CONFIRMING and data.consecutiveFailures > 0:
        return PROGRESSING
    
    // Default
    return currentState
```

---

## Archivos Creados

```
lib/
  services/
    progression_controller.dart    ← NUEVO: Controlador central
  models/
    progression_engine_models.dart ← EXISTENTE: Modelos base
```

## Uso

```dart
// Crear controlador
final controller = ProgressionController(
  model: const DoubleProgressionModel(),
  thresholds: ProgressionThresholds.defaults,
);

// Preparar datos de ejecución
final data = ExecutionData(
  exerciseName: 'Sentadilla',
  category: ExerciseCategory.heavyCompound,
  confirmedWeight: 80.0,
  repsRange: (8, 12),
  sessionHistory: [...],
);

// Calcular decisión
final decision = controller.calculate(data);

// Mostrar al usuario
print(decision.userMessage);  // "Repite para confirmar. Si éxito: +2.5kg"
print(controller.state);      // confirming
```
