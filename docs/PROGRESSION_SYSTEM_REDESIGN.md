# 🏋️ Sistema de Progresión Automática - Rediseño Completo

## Análisis como Ingeniero Senior de Sistemas de Entrenamiento

---

## ✅ ESTADO DE IMPLEMENTACIÓN

### Archivos Implementados

| Archivo | Estado | Descripción |
|---------|--------|-------------|
| `lib/models/progression_engine_models.dart` | ✅ Completo | Modelos de datos del nuevo motor |
| `lib/services/progression_engine.dart` | ✅ Completo | Motor de progresión v2 |
| `lib/widgets/session/progression_preview.dart` | ✅ Completo | Widget de UI para mostrar predicciones |
| `lib/providers/progression_provider.dart` | ✅ Completo | Providers Riverpod para progresión |
| `lib/widgets/session/exercise_card.dart` | ✅ Integrado | UI integrada con ProgressionBadge |
| `lib/repositories/i_training_repository.dart` | ✅ Actualizado | Método getExpandedHistoryForExercise |
| `lib/repositories/drift_training_repository.dart` | ✅ Actualizado | Implementación de historial expandido |
| `lib/services/progression_calculator.dart` | ✅ Actualizado | Wrapper de compatibilidad con v1 |
| `test/services/progression_engine_test.dart` | ✅ Completo | Tests unitarios (19 tests passing) |

### Providers Disponibles

```dart
import 'package:juan_training/providers/progression_provider.dart';

// Provider sincrónico (usa historial en memoria)
final decision = ref.watch(exerciseProgressionProvider(exerciseIndex));

// Provider async (carga historial expandido del repositorio)
final asyncDecision = ref.watch(expandedProgressionProvider(exerciseName));

// Todas las decisiones de la sesión actual
final allDecisions = ref.watch(allProgressionDecisionsProvider);

// Resumen de progresión de la sesión
final summary = ref.watch(sessionProgressionSummaryProvider);
```

### Cómo Usar el Nuevo Sistema

```dart
import 'package:juan_training/services/progression_engine.dart';
import 'package:juan_training/models/progression_engine_models.dart';

// 1. Construir el contexto
final context = ExerciseProgressionContext(
  exerciseId: 'unique-id',
  exerciseName: 'Press Banca',
  state: ProgressionState.progressing,
  recentSessions: [...], // Últimas 2-4 sesiones
  consecutiveSuccesses: 1,
  consecutiveFailures: 0,
  weeksAtCurrentWeight: 2,
  category: ExerciseCategory.inferFromName('Press Banca'),
  confirmedWeight: 80.0,
  repsRange: (8, 12),
);

// 2. Calcular decisión
final decision = ProgressionEngine.instance.calculateNextSession(
  context: context,
  model: ProgressionType.dobleRepsFirst,
);

// 3. Usar la decisión
print(decision.suggestedWeight);  // 82.5
print(decision.suggestedReps);    // 8
print(decision.userMessage);      // "¡Sube a 82.5kg! Empieza con 8 reps."
print(decision.nextStepPreview);  // "Siguiente: 82.5kg × 9 reps"
```

### Widget de Preview en UI

```dart
import 'package:juan_training/widgets/session/progression_preview.dart';

// Card completo
ProgressionPreviewCard(
  decision: decision,
  compact: false,
)

// Badge pequeño
ProgressionBadge(decision: decision)
```

---

## 📋 DIAGNÓSTICO DEL SISTEMA ACTUAL

### Arquitectura Existente

```
ProgressionType (enum)
├── none        → Sin progresión
├── lineal      → +peso si reps ≥ target
├── dobleRepsFirst → Reps hasta max, luego +peso
└── rpe         → Ajuste por percepción de esfuerzo
```

### 🔴 ERRORES CRÍTICOS IDENTIFICADOS

#### 1. **Progresión "Ciega" Serie-a-Serie**
```dart
// PROBLEMA en progression_calculator.dart:30
final SerieLog? prevLog = setIndex < previousLogs.length 
    ? previousLogs[setIndex] 
    : null;
```
- Compara Serie 1 actual con Serie 1 anterior
- **Ignora el contexto de la sesión completa**
- Un usuario que hizo 4x10@100kg pero falló Serie 4, recibirá sugerencia de mantener en Serie 4, pero subir en Series 1-3 (inconsistente)

#### 2. **Mezcla Implícita de Modelos**
```dart
// El usuario puede tener ProgressionType.lineal pero...
// - Un ejercicio responde a RPE
// - Otro responde a reps
// - No hay "controlador" unificado
```
**Problema:** El modelo de progresión se configura por ejercicio, pero no hay validación de coherencia global.

#### 3. **Sin Gestión de "Días Malos"**
```dart
// PROBLEMA en _calculateLineal:
if (prevCompleted && prevReps >= targetReps) {
  return suggestedWeight: prevWeight + increment; // SIEMPRE sube
}
```
- Si el usuario tuvo un día excepcional, el sistema lo toma como "nuevo baseline"
- No hay mecanismo de **confirmación de progreso**
- Un PR accidental se convierte en la nueva expectativa

#### 4. **Incrementos Fijos Descontextualizados**
```dart
// PROBLEMA: 2.5kg siempre
weightIncrement: 2.5  // Default en ejercicio_en_rutina.dart:42
```
- 2.5kg en Press Banca (100kg) = 2.5% → Razonable
- 2.5kg en Curl Bíceps (15kg) = 16.7% → **Imposible**
- No considera el patrón del ejercicio (compuesto vs. aislamiento)

#### 5. **RPE Sin Calibración**
```dart
// PROBLEMA en _calculateRpeBased:
if (prevRpe < targetRpe - 1) {
  return suggestedWeight: prevWeight + 2.5;  // +2.5kg arbitrario
}
```
- RPE es altamente subjetivo
- Sin período de calibración del usuario
- No considera fatiga acumulada ni posición en la sesión

#### 6. **Historial Superficial**
```dart
// Solo mira la ÚLTIMA sesión
final lastSession = historyList.first;  // training_provider.dart:289
```
- Ignora tendencia de las últimas 3-4 sesiones
- No detecta estancamientos
- No identifica patrones de fatiga

#### 7. **Sin Feedback al Usuario sobre "Por Qué"**
```dart
message: '+${increment}kg 💪',  // ¿Por qué? ¿Qué pasará si no lo logro?
```
- El usuario no puede anticipar la lógica
- Si falla, no sabe si es "normal" o si debe ajustar

---

## ✅ REDISEÑO: SISTEMA DE PROGRESIÓN DETERMINISTA

### Filosofía Central

> **"El usuario debe poder predecir exactamente qué pasará en la siguiente sesión mirando solo sus últimas 2 sesiones."**

### Principios de Diseño

1. **Transparencia Total**: Cada decisión explicable en una frase
2. **Confirmación de Progreso**: 2 sesiones exitosas = subir peso
3. **Degradación Elegante**: Fallar no castiga, solo "pausa" el progreso
4. **Contexto de Sesión**: Decisión basada en la sesión completa, no serie individual
5. **Incrementos Inteligentes**: Basados en el tipo de ejercicio y peso actual

---

## 🏗️ ARQUITECTURA PROPUESTA

### Nuevo Modelo de Datos

```dart
/// Estado de progresión de un ejercicio
enum ProgressionState {
  /// Fase inicial: Recopilando datos de baseline
  calibrating,
  
  /// Progresión normal: Siguiendo el modelo elegido
  progressing,
  
  /// Consolidación: Esperando 2da sesión exitosa para confirmar
  confirming,
  
  /// Estancamiento detectado: Sugerir deload o cambio
  plateau,
  
  /// Deload activo: Reducción temporal planificada
  deloading,
}

/// Historial enriquecido para toma de decisiones
class ExerciseProgressionContext {
  final String exerciseId;
  final ProgressionState state;
  
  /// Últimas 4 sesiones (suficiente para detectar tendencias)
  final List<SessionSummary> recentSessions;
  
  /// Sesiones exitosas consecutivas (para confirmación)
  final int consecutiveSuccesses;
  
  /// Semanas en el mismo peso (para detectar plateau)
  final int weeksAtCurrentWeight;
  
  /// Tipo de ejercicio (afecta incrementos)
  final ExerciseCategory category;
  
  /// Peso actual "confirmado" (no el último intento)
  final double confirmedWeight;
  
  /// Target de reps actual
  final int targetReps;
}

/// Categorías para determinar incrementos apropiados
enum ExerciseCategory {
  /// Compuestos pesados: Sentadilla, Peso Muerto, Press Banca
  /// Incremento: 2.5kg (>60kg) o 1.25kg (<60kg)
  heavyCompound,
  
  /// Compuestos ligeros: Remo, Press Militar, Dominadas
  /// Incremento: 2.5kg (>40kg) o 1.25kg (<40kg)  
  lightCompound,
  
  /// Aislamiento: Curls, Extensiones, Laterales
  /// Incremento: 1.25kg o +1 rep
  isolation,
  
  /// Máquinas: Generalmente incrementos de 2.5-5kg fijos
  machine,
}
```

### Nueva Clase `ProgressionEngine`

```dart
/// Motor de progresión determinista
class ProgressionEngine {
  
  /// Calcula la sugerencia de la próxima sesión
  /// 
  /// REGLA CENTRAL: Basado en el RESULTADO DE SESIÓN, no series individuales
  ProgressionDecision calculateNextSession({
    required ExerciseProgressionContext context,
    required ProgressionModel model,
  }) {
    // 1. ¿Está en calibración?
    if (context.recentSessions.length < 2) {
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: context.targetReps,
        reason: 'Sesión ${context.recentSessions.length + 1}/2 de calibración',
        userMessage: 'Haz esta sesión para establecer tu baseline',
      );
    }
    
    // 2. Evaluar la última sesión COMPLETA
    final lastSession = context.recentSessions.first;
    final sessionResult = _evaluateSession(lastSession, context);
    
    // 3. Aplicar modelo de progresión
    return switch (model) {
      ProgressionModel.doubleProgression => 
        _calculateDoubleProgression(context, sessionResult),
      ProgressionModel.linearSimple => 
        _calculateLinearSimple(context, sessionResult),
      ProgressionModel.rpeAutoregulated => 
        _calculateRpeAutoregulated(context, sessionResult),
    };
  }
  
  /// Evalúa una sesión completa (no serie por serie)
  SessionResult _evaluateSession(SessionSummary session, ExerciseProgressionContext ctx) {
    final targetReps = ctx.targetReps;
    final targetSets = session.sets.length;
    
    // Contar sets "exitosos" (alcanzaron target reps)
    final successfulSets = session.sets.where((s) => s.reps >= targetReps).length;
    
    // Criterio: ≥80% de sets exitosos = sesión exitosa
    final successThreshold = (targetSets * 0.8).ceil();
    
    if (successfulSets >= targetSets) {
      return SessionResult.complete;      // 100% - Listo para subir
    } else if (successfulSets >= successThreshold) {
      return SessionResult.acceptable;    // 80%+ - Casi listo
    } else if (successfulSets >= targetSets ~/ 2) {
      return SessionResult.partial;       // 50%+ - Mantener
    } else {
      return SessionResult.failed;        // <50% - Considerar bajar
    }
  }
}
```

### Modelo de Doble Progresión Mejorado

```dart
/// Doble progresión con confirmación de 2 sesiones
ProgressionDecision _calculateDoubleProgression(
  ExerciseProgressionContext ctx, 
  SessionResult lastResult,
) {
  final (minReps, maxReps) = ctx.repsRange;
  final lastSession = ctx.recentSessions.first;
  final lastAvgReps = lastSession.averageReps;
  
  // CASO 1: Sesión completa con reps máximas
  if (lastResult == SessionResult.complete && lastAvgReps >= maxReps) {
    
    // ¿Es la 2da sesión exitosa consecutiva?
    if (ctx.consecutiveSuccesses >= 1) {
      // ✅ SUBIR PESO, resetear reps
      final increment = _getSmartIncrement(ctx.category, ctx.confirmedWeight);
      return ProgressionDecision(
        action: ProgressionAction.increaseWeight,
        suggestedWeight: ctx.confirmedWeight + increment,
        suggestedReps: minReps,
        reason: '2 sesiones exitosas a ${maxReps} reps',
        userMessage: '¡Bien! Sube a ${ctx.confirmedWeight + increment}kg, empieza con $minReps reps',
        confidence: ProgressionConfidence.high,
      );
    } else {
      // Esperando confirmación
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: ctx.confirmedWeight,
        suggestedReps: maxReps,
        reason: 'Confirmando progreso (1/2)',
        userMessage: 'Repite esta sesión. Si lo logras de nuevo, subirás peso.',
        confidence: ProgressionConfidence.medium,
      );
    }
  }
  
  // CASO 2: Sesión completa pero no en reps máximas
  if (lastResult == SessionResult.complete) {
    return ProgressionDecision(
      action: ProgressionAction.increaseReps,
      suggestedWeight: ctx.confirmedWeight,
      suggestedReps: (lastAvgReps + 1).clamp(minReps, maxReps).toInt(),
      reason: 'Progresando en reps',
      userMessage: 'Intenta ${lastAvgReps.toInt() + 1} reps hoy',
      confidence: ProgressionConfidence.high,
    );
  }
  
  // CASO 3: Sesión aceptable (80%+)
  if (lastResult == SessionResult.acceptable) {
    return ProgressionDecision(
      action: ProgressionAction.maintain,
      suggestedWeight: ctx.confirmedWeight,
      suggestedReps: ctx.targetReps,
      reason: 'Casi conseguido, repetir',
      userMessage: 'Repite el mismo objetivo. Estás cerca.',
      confidence: ProgressionConfidence.medium,
    );
  }
  
  // CASO 4: Sesión parcial o fallida
  if (lastResult == SessionResult.partial || lastResult == SessionResult.failed) {
    // ¿Es un patrón? (2+ sesiones malas)
    if (ctx.consecutiveFailures >= 2) {
      return ProgressionDecision(
        action: ProgressionAction.decreaseWeight,
        suggestedWeight: ctx.confirmedWeight - _getSmartIncrement(ctx.category, ctx.confirmedWeight),
        suggestedReps: maxReps,
        reason: '2 sesiones difíciles consecutivas',
        userMessage: 'Bajamos peso para consolidar. Es parte del proceso.',
        confidence: ProgressionConfidence.high,
      );
    }
    
    // Primera sesión mala - día malo, no castigar
    return ProgressionDecision(
      action: ProgressionAction.maintain,
      suggestedWeight: ctx.confirmedWeight,
      suggestedReps: ctx.targetReps,
      reason: 'Día difícil, mantener',
      userMessage: 'Repite el objetivo. Un día malo no cambia nada.',
      confidence: ProgressionConfidence.medium,
    );
  }
  
  // Default: Mantener
  return ProgressionDecision.maintain(ctx);
}
```

### Incrementos Inteligentes

```dart
/// Calcula el incremento apropiado según categoría y peso actual
double _getSmartIncrement(ExerciseCategory category, double currentWeight) {
  return switch (category) {
    ExerciseCategory.heavyCompound => currentWeight >= 60 ? 2.5 : 1.25,
    ExerciseCategory.lightCompound => currentWeight >= 40 ? 2.5 : 1.25,
    ExerciseCategory.isolation => 1.25,  // Siempre pequeño
    ExerciseCategory.machine => 2.5,     // Las máquinas suelen tener incrementos fijos
  };
}

/// Auto-detecta la categoría basándose en el nombre del ejercicio
ExerciseCategory _inferCategory(String exerciseName) {
  final name = exerciseName.toLowerCase();
  
  // Compuestos pesados
  if (name.contains('sentadilla') || 
      name.contains('peso muerto') ||
      name.contains('press banca') ||
      name.contains('squat') ||
      name.contains('deadlift') ||
      name.contains('bench')) {
    return ExerciseCategory.heavyCompound;
  }
  
  // Compuestos ligeros
  if (name.contains('remo') ||
      name.contains('press militar') ||
      name.contains('dominada') ||
      name.contains('row') ||
      name.contains('pull')) {
    return ExerciseCategory.lightCompound;
  }
  
  // Máquinas
  if (name.contains('máquina') ||
      name.contains('machine') ||
      name.contains('polea') ||
      name.contains('cable')) {
    return ExerciseCategory.machine;
  }
  
  // Default: aislamiento
  return ExerciseCategory.isolation;
}
```

---

## 🎨 INTEGRACIÓN UX/UI

### Pantalla de Sesión: Indicador de Progresión

```
┌─────────────────────────────────────────┐
│ PRESS BANCA                    ⓘ        │
│ ─────────────────────────────────────── │
│                                          │
│   📊 OBJETIVO HOY                        │
│   ┌─────────────────────────────────┐   │
│   │  80kg × 8 reps                  │   │
│   │  ────────────────────────────── │   │
│   │  ⬆️ +2 reps vs semana pasada    │   │
│   │  🎯 Si lo logras: 82.5kg × 6    │   │
│   └─────────────────────────────────┘   │
│                                          │
│   📋 SERIES                              │
│   ┌────┬────────┬────────┬─────┐        │
│   │ #  │   KG   │  REPS  │  ✓  │        │
│   ├────┼────────┼────────┼─────┤        │
│   │ 1  │ [80  ] │ [ 8  ] │ [✓] │        │
│   │ 2  │ [80  ] │ [ 8  ] │ [ ] │        │
│   │ 3  │ [80  ] │ [ 8  ] │ [ ] │        │
│   └────┴────────┴────────┴─────┘        │
└─────────────────────────────────────────┘
```

### Widget de Predicción

```dart
/// Widget que muestra claramente qué pasará después
class ProgressionPreview extends StatelessWidget {
  final ProgressionDecision decision;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(decision.confidence),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getBorderColor(decision.action)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getIcon(decision.action), size: 20),
              const SizedBox(width: 8),
              Text(
                'PRÓXIMA SESIÓN',
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${decision.suggestedWeight}kg × ${decision.suggestedReps}',
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            decision.userMessage,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
```

### Feedback Post-Serie

```dart
/// Feedback contextual después de completar una serie
void _showSetCompletionFeedback(SerieLog log, ProgressionDecision decision) {
  final targetReps = decision.suggestedReps;
  
  String message;
  Color color;
  
  if (log.reps >= targetReps + 2) {
    message = '¡Excelente! +${log.reps - targetReps} sobre objetivo';
    color = Colors.green;
  } else if (log.reps >= targetReps) {
    message = '✓ Objetivo cumplido';
    color = Colors.amber;
  } else if (log.reps >= targetReps - 1) {
    message = 'Casi. -1 rep del objetivo';
    color = Colors.orange;
  } else {
    message = 'Serie difícil. Ajusta si es necesario.';
    color = Colors.red[300]!;
  }
  
  // Snackbar discreto, no intrusivo
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color.withOpacity(0.9),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
```

---

## 📱 EJEMPLOS DE USO REAL

### Escenario 1: Progresión Normal

```
SEMANA 1: Press Banca 80kg × 8,8,8 ✓
SEMANA 2: Press Banca 80kg × 9,9,9 ✓  
SEMANA 3: Press Banca 80kg × 10,10,10 ✓ (máx reps alcanzado)
SEMANA 4: Press Banca 80kg × 10,10,10 ✓ (confirmación)
        → Sistema: "¡Sube a 82.5kg × 8 reps!"
SEMANA 5: Press Banca 82.5kg × 8,8,7 (parcial)
        → Sistema: "Repite 82.5kg × 8. Un día malo no cambia nada."
SEMANA 6: Press Banca 82.5kg × 8,8,8 ✓
        → Sistema: "82.5kg confirmado. Siguiente: intenta 9 reps."
```

### Escenario 2: Día Malo (No Castigar)

```
SEMANA 1: Sentadilla 100kg × 10,10,10 ✓
SEMANA 2: Sentadilla 100kg × 7,6,6 ✗ (Día malo: mal sueño, estrés)
        → Sistema: "Repite 100kg × 10. Un día difícil no cambia tu baseline."
SEMANA 3: Sentadilla 100kg × 10,10,9 ✓
        → Sistema: "Volviste a tu nivel. Continúa."
```

### Escenario 3: Estancamiento Real

```
SEMANA 1: Peso Muerto 120kg × 8,8,8 ✓
SEMANA 2: Peso Muerto 122.5kg × 6,5,5 ✗
SEMANA 3: Peso Muerto 122.5kg × 7,6,6 ✗
SEMANA 4: Peso Muerto 122.5kg × 6,6,5 ✗
        → Sistema: "Detectado estancamiento. Sugerencia: Baja a 115kg × 10 
                   para consolidar. Volverás a 122.5kg en 3 semanas."
```

### Escenario 4: PR Inesperado (No Tomar Como Baseline)

```
SEMANA 1: Curl Bíceps 15kg × 12,12,12 ✓
SEMANA 2: Curl Bíceps 15kg × 15,14,13 ✓ (¡PR! Día excepcional)
        → Sistema: "¡Gran sesión! Pero confirmemos antes de subir."
SEMANA 3: Curl Bíceps 15kg × 12,12,11 (normal, no es el PR)
        → Sistema: "Mantén 15kg × 12. El PR fue excepcional, 
                   tu baseline real está en 12 reps."
```

---

## 🔧 IMPLEMENTACIÓN: CAMBIOS REQUERIDOS

### Archivos a Modificar

1. **`lib/models/progression_type.dart`**
   - Añadir `ProgressionState`, `ExerciseCategory`
   - Expandir `ProgressionDecision` con `confidence`, `userMessage`

2. **`lib/services/progression_calculator.dart`**
   - Reemplazar con `ProgressionEngine`
   - Implementar lógica de sesión completa vs serie individual

3. **`lib/models/ejercicio_en_rutina.dart`**
   - Añadir `category: ExerciseCategory`
   - Añadir `confirmedWeight` (peso validado, no último intento)

4. **`lib/providers/training_provider.dart`**
   - Guardar historial de últimas 4 sesiones (no solo 1)
   - Calcular `consecutiveSuccesses` y `consecutiveFailures`

5. **`lib/widgets/session/exercise_card.dart`**
   - Añadir `ProgressionPreview` widget
   - Mostrar "qué pasará si logro esto"

6. **`lib/database/database.dart`**
   - Añadir columnas: `confirmed_weight`, `exercise_category`, `consecutive_successes`

### Migración de Datos

```dart
/// Migración segura del esquema
Future<void> migrateToProgressionV2() async {
  // 1. Añadir nuevas columnas con defaults
  await db.execute('''
    ALTER TABLE routine_exercises 
    ADD COLUMN exercise_category TEXT DEFAULT 'isolation';
  ''');
  
  // 2. Inferir categorías de ejercicios existentes
  final exercises = await db.query('routine_exercises');
  for (final ex in exercises) {
    final category = _inferCategory(ex['nombre']);
    await db.update(
      'routine_exercises',
      {'exercise_category': category.name},
      where: 'id = ?',
      whereArgs: [ex['id']],
    );
  }
  
  // 3. Marcar confirmed_weight = último peso exitoso
  // (Query de historial, etc.)
}
```

---

## 📊 MÉTRICAS DE ÉXITO

### KPIs a Trackear

1. **Tasa de Progresión Real**
   - % de ejercicios que suben peso en 4 semanas
   - Target: >60% de ejercicios progresan

2. **Días de "Abandono"**
   - Sesiones no completadas (<50% de series)
   - Target: <5% de sesiones

3. **Precisión de Predicción**
   - ¿El usuario logró el objetivo predicho?
   - Target: >75% de precisión

4. **Reversiones**
   - Veces que el sistema sugiere bajar peso
   - Target: <10% de sugerencias (pero cuando ocurre, que sea apropiado)

---

## ✅ CHECKLIST DE IMPLEMENTACIÓN

- [ ] Crear `ProgressionEngine` con lógica de sesión completa
- [ ] Implementar `ExerciseCategory` auto-detección
- [ ] Añadir sistema de "confirmación de 2 sesiones"
- [ ] Migrar historial a guardar últimas 4 sesiones
- [ ] Crear widget `ProgressionPreview`
- [ ] Implementar feedback post-serie contextual
- [ ] Añadir analytics para medir precisión
- [ ] Tests unitarios para cada escenario
- [ ] Migración de datos existentes
- [ ] Documentación de usuario sobre el sistema

---

## 🎯 RESUMEN EJECUTIVO

| Problema Actual | Solución Propuesta |
|-----------------|-------------------|
| Progresión serie-a-serie | Evaluación de sesión completa |
| Subida agresiva tras 1 éxito | Confirmación de 2 sesiones |
| Castigo por día malo | "Un día malo no cambia nada" |
| Incrementos fijos (2.5kg) | Incrementos según categoría |
| RPE sin calibración | Estado `calibrating` inicial |
| Usuario no puede predecir | Widget "qué pasará si..." |
| Historial superficial | Últimas 4 sesiones analizadas |

**Resultado esperado:** Un sistema donde el usuario puede decir con confianza:
> "La semana pasada hice 80kg×10, esta semana repetiré para confirmar, y si lo logro, la siguiente subiré a 82.5kg×8."
