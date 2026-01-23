# Auditoría Técnica - Issues Pendientes

> Generado: 2026-01-23
> Última revisión de código completa realizada.
> Este documento lista issues identificados pero NO corregidos.

---

## Fixes Aplicados (Referencia)

Los siguientes issues fueron corregidos en commits `aef0640` y `00b739c`:

- ✅ Timer restore cuando endTime en pasado
- ✅ Race condition en discard session
- ✅ Diálogo sospechoso múltiple (flag dialogShowing)
- ✅ Hard limits peso/reps (600kg / 100 reps)
- ✅ Feedback visual sesión guardada
- ✅ Timezone-aware streak calculation
- ✅ Diálogo descarte simplificado
- ✅ finishSession atómico
- ✅ Outliers en estimate1RM

---

## Issues Pendientes por Prioridad

### 🔴 CRÍTICO

#### 1. Sort de días sin orElse puede crashear silenciosamente

**Archivo:** `lib/repositories/drift_training_repository.dart:64-67`

```dart
dias.sort((a, b) {
  final dayA = days.firstWhere((d) => d.id == a.id);  // ← Sin orElse
  final dayB = days.firstWhere((d) => d.id == b.id);
  return dayA.dayIndex.compareTo(dayB.dayIndex);
});
```

**Problema:** Si hay inconsistencia entre `dias` y `days` (corrupción de BD o migración fallida), lanza `StateError`. El try-catch externo devuelve lista vacía → rutinas desaparecen sin explicación.

**Fix sugerido:**
```dart
dias.sort((a, b) {
  final dayA = days.firstWhereOrNull((d) => d.id == a.id);
  final dayB = days.firstWhereOrNull((d) => d.id == b.id);
  if (dayA == null || dayB == null) return 0; // Mantener orden original si hay inconsistencia
  return dayA.dayIndex.compareTo(dayB.dayIndex);
});
```

---

### 🟠 ALTO

#### 2. Auto-complete con delay arbitrario puede marcar set incorrecto

**Archivo:** `lib/widgets/session/focused_set_row.dart:361-369`

```dart
Future.delayed(const Duration(milliseconds: 100), () {
  widget.onCompleted(true);
});
```

**Problema:** Si el usuario navega a otro set antes de que el delay termine, se marca el set incorrecto.

**Fix sugerido:** Usar un token/ID de set y verificar que sigue siendo el mismo antes de completar:
```dart
final currentSetId = widget.setId;
Future.delayed(const Duration(milliseconds: 100), () {
  if (mounted && widget.setId == currentSetId) {
    widget.onCompleted(true);
  }
});
```

---

#### 3. Superset con ejercicio eliminado mid-session causa timer inconsistente

**Archivos:**
- `lib/providers/training_provider.dart` (`_shouldStartTimerForSuperset`, `_getSupersetRestTime`)

**Problema:** Si el usuario elimina un ejercicio que pertenece a un superset durante la sesión, las funciones que iteran sobre `state.exercises` buscando por `supersetId` pueden no encontrar todos los ejercicios esperados, causando:
- Timer que no inicia cuando debería
- Timer que inicia cuando no debería
- Cálculo incorrecto del tiempo de descanso del superset

**Fix sugerido:** Validar existencia de todos los ejercicios del superset antes de operar, o limpiar `supersetId` de ejercicios huérfanos.

---

### 🟡 MEDIO

#### 4. `didChangeAppLifecycleState` no sincroniza con timer Android

**Archivo:** `lib/widgets/session/rest_timer_bar.dart:255-260`

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _updateDisplay();  // ← Solo actualiza display, no verifica timer nativo
  }
}
```

**Problema:** Si Android mata el servicio de timer mientras la app está en background, Dart no lo detecta. El timer visual puede mostrar tiempo incorrecto.

**Fix sugerido:** Al volver a foreground, consultar `TimerPlatformService` para verificar estado real del timer nativo y sincronizar.

---

#### 5. "Día malo" no persiste entre sesiones

**Archivo:** `lib/services/error_tolerance_system.dart` (`BadDayResult`)

**Problema:** El `BadDayResult` se calcula en tiempo real, pero el flag `affectsProgression: false` no se guarda en la BD. La próxima vez que se calcule progresión, no sabe que la sesión anterior fue un "día malo aislado".

**Impacto:** La progresión podría castigar incorrectamente al usuario por un día malo aislado en la siguiente sesión.

**Fix sugerido:** Guardar flag `isBadDay` en la tabla `Sessions` para que el motor de progresión lo considere.

---

#### 6. Ghost values sin indicación visual de interactividad

**Archivo:** `lib/widgets/session/focused_set_row.dart`

**Problema:** Los valores de sesión anterior (ghost values) aparecen en gris pero no hay indicación de que tocarlos los copiará. El método `copyPreviousSet` existe pero no está expuesto visualmente.

**Fix sugerido:** Añadir tooltip o animación sutil que indique que los valores grises son "tocables para copiar".

---

### 🟢 BAJO

#### 7. `nextIncompleteSet` no considera ejercicios añadidos dinámicamente

**Archivo:** `lib/providers/training_provider.dart`

**Problema:** El getter `nextIncompleteSet` itera en orden lineal. Si el usuario añade un ejercicio al final y luego edita uno anterior, el auto-focus podría saltar de forma confusa.

**Impacto:** UX confusa en casos edge, no crítico.

---

## Deuda Técnica (NO urgente, para refactorización futura)

### `TrainingSessionNotifier` - 1000+ líneas

**Archivo:** `lib/providers/training_provider.dart`

**Problema:** Hace demasiado:
- Gestión de estado de ejercicios
- Gestión de timer de descanso
- Gestión de persistencia
- Comunicación con plataforma Android
- Cálculo de siguiente set incompleto

**Refactorización sugerida:** Dividir en:
1. `TrainingSessionNotifier` - Solo estado de ejercicios
2. `RestTimerController` - Timer específico
3. `SessionPersistenceService` - Save/restore

---

### `DriftTrainingRepository` - 1300+ líneas

**Archivo:** `lib/repositories/drift_training_repository.dart`

**Problema:** Mezcla:
- CRUD de rutinas
- CRUD de sesiones
- Análisis y métricas

**Refactorización sugerida:** Dividir en repositorios especializados:
1. `RoutineRepository`
2. `SessionRepository`
3. `AnalyticsRepository`

---

### Zonas Frágiles (cambiar con cuidado)

1. **`EjercicioEnRutina` → `Ejercicio` mapping** (`training_provider.dart:262-284`)
   - Conversión manual entre modelos. Si añades campo a uno, debes recordar añadirlo al otro.

2. **IDs con sufijo `_target`** (`drift_training_repository.dart:375-407`)
   - Los IDs de ejercicios/sets target tienen `_target` appended. Cambiar esta lógica rompe separación completados/objetivo.

3. **Migraciones de BD sin reversibilidad** (`database.dart:178-206`)
   - Las migraciones usan try-catch vacíos. Si una migración falla parcialmente, BD queda en estado inconsistente.

---

## Recomendaciones si vuelves en 6-12 meses

1. **Primer paso:** Escribir test de integración del flujo completo:
   ```
   startSession → updateLog → completeSet → finishSession → verify DB
   ```

2. **Segundo paso:** Refactorizar `TrainingSessionNotifier` ANTES de añadir features.

3. **Tercer paso:** Revisar este documento y decidir qué fixes siguen siendo relevantes.

---

*Este documento es para referencia interna. No afecta el funcionamiento de la app.*
