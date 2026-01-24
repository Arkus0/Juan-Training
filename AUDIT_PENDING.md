# Auditoría Técnica - Issues Pendientes

> Generado: 2026-01-23
> Última actualización: 2026-01-24
> Este documento lista issues identificados y su estado.

---

## Fixes Aplicados (Referencia)

### Commits `aef0640` y `00b739c`:
- ✅ Timer restore cuando endTime en pasado
- ✅ Race condition en discard session
- ✅ Diálogo sospechoso múltiple (flag dialogShowing)
- ✅ Hard limits peso/reps (600kg / 100 reps)
- ✅ Feedback visual sesión guardada
- ✅ Timezone-aware streak calculation
- ✅ Diálogo descarte simplificado
- ✅ finishSession atómico
- ✅ Outliers en estimate1RM

### Commit `411014b` - Issues de auditoría pendientes:
- ✅ Sort de días usa `firstWhereOrNull` para evitar StateError
- ✅ Auto-complete verifica setId antes de completar
- ✅ Validación defensiva en funciones de superset
- ✅ `didChangeAppLifecycleState` sincroniza con TimerPlatformService
- ✅ Campo `isBadDay` añadido a Sessions (migración v4)
- ✅ Ghost values con indicación visual mejorada
- ✅ Documentación de `nextIncompleteSet`

### Commit `c66c334` - Dependencias y refactorización:
- ✅ Dependencias actualizadas a versiones recientes
- ✅ Eliminadas dependencias no usadas (timer_count_down, reorderables, etc.)
- ✅ Creado `RoutineRepository` como ejemplo de extracción

---

## Issues Pendientes por Prioridad

### ~~🔴 CRÍTICO~~ ✅ COMPLETADO

#### ~~1. Sort de días sin orElse puede crashear silenciosamente~~

~~**Archivo:** `lib/repositories/drift_training_repository.dart:64-67`~~

**Estado:** ✅ CORREGIDO en commit `411014b`

---

### ~~🟠 ALTO~~ ✅ COMPLETADO

#### ~~2. Auto-complete con delay arbitrario puede marcar set incorrecto~~

**Estado:** ✅ CORREGIDO - Ahora verifica `widget.log.id` antes de completar

---

#### ~~3. Superset con ejercicio eliminado mid-session causa timer inconsistente~~

**Estado:** ✅ CORREGIDO - Validación defensiva de índices añadida

---

### ~~🟡 MEDIO~~ ✅ COMPLETADO

#### ~~4. `didChangeAppLifecycleState` no sincroniza con timer Android~~

**Estado:** ✅ CORREGIDO - Sincroniza con `TimerPlatformService.instance.state`

---

#### ~~5. "Día malo" no persiste entre sesiones~~

**Estado:** ✅ CORREGIDO - Campo `isBadDay` añadido a tabla Sessions (migración v4)

---

#### ~~6. Ghost values sin indicación visual de interactividad~~

**Estado:** ✅ CORREGIDO - Tooltip añadido + borde destacado cuando input vacío

---

### ~~🟢 BAJO~~ ✅ DOCUMENTADO

#### ~~7. `nextIncompleteSet` no considera ejercicios añadidos dinámicamente~~

**Estado:** ✅ DOCUMENTADO - Comentario explica el comportamiento lineal

---

## Deuda Técnica (EN PROGRESO)

### ~~`DriftTrainingRepository` - 1300+ líneas~~ ✅ COMPLETADO

**Archivo:** `lib/repositories/drift_training_repository.dart`

**Estado:** ✅ COMPLETADO

**Progreso:**
- ✅ `RoutineRepository` extraído (`lib/repositories/routine_repository.dart`)
- ✅ `SessionRepository` extraído (`lib/repositories/session_repository.dart`)
- ✅ `AnalyticsRepository` extraído (`lib/repositories/analytics_repository.dart`)
- ✅ `DriftTrainingRepository` refactorizado para delegar a repositorios especializados

**Resultado:**
- `drift_training_repository.dart`: ~125 líneas (facade que delega)
- `routine_repository.dart`: ~220 líneas
- `session_repository.dart`: ~470 líneas
- `analytics_repository.dart`: ~540 líneas

**Beneficios:**
- Separación clara de responsabilidades
- Cada repositorio es testeable de forma independiente
- API pública (`ITrainingRepository`) sin cambios

---

### ~~`TrainingSessionNotifier` - 1000+ líneas~~ ✅ COMPLETADO

**Archivo:** `lib/providers/training_provider.dart`

**Estado:** ✅ COMPLETADO

**Resultado:**
- `training_provider.dart`: **802 líneas** (antes ~1160, reducción del 30%)
- `rest_timer_controller.dart`: ~340 líneas
- `session_persistence_service.dart`: ~100 líneas

**Refactorización realizada:**
1. ✅ `RestTimerController` creado e integrado
   - Lógica de timer de descanso encapsulada
   - Manejo de superseries (`shouldStartTimerForSuperset`)
   - Persistencia en SharedPreferences
   - Comunicación con TimerPlatformService
2. ✅ `SessionPersistenceService` creado e integrado
   - Debouncing de saves
   - Flush de saves pendientes
   - Restore de sesión con manejo de errores
3. ✅ `TrainingSessionNotifier` refactorizado para delegar
   - Timer: delega a `RestTimerController`
   - Persistencia: delega a `SessionPersistenceService`
   - Solo mantiene lógica de ejercicios/estado

**Beneficios:**
- Separación clara de responsabilidades
- Cada clase es testeable de forma independiente
- API pública sin cambios (compatibilidad total)
- Código más mantenible y comprensible

---

### Zonas Frágiles (cambiar con cuidado)

1. **`EjercicioEnRutina` → `Ejercicio` mapping** (`training_provider.dart:229-251`)
   - Conversión manual entre modelos. Si añades campo a uno, debes recordar añadirlo al otro.

2. **IDs con sufijo `_target`** (`drift_training_repository.dart:375-407`)
   - Los IDs de ejercicios/sets target tienen `_target` appended. Cambiar esta lógica rompe separación completados/objetivo.

3. **Migraciones de BD sin reversibilidad** (`database.dart:178-206`)
   - Las migraciones usan try-catch vacíos. Si una migración falla parcialmente, BD queda en estado inconsistente.

4. ~~**RestTimerState duplicación temporal**~~ ✅ RESUELTO
   - `RestTimerState` ahora solo existe en `rest_timer_controller.dart`
   - El provider lo importa y usa sin duplicación

---

## Recomendaciones si vuelves en 6-12 meses

1. **Primer paso:** Escribir tests unitarios para los servicios extraídos:
   ```
   // RestTimerController
   - start/stop/pause/resume timer
   - superset logic (shouldStartTimerForSuperset)
   - persistence in SharedPreferences

   // SessionPersistenceService
   - debounced saves
   - flush pending saves
   - restore with error handling
   ```

2. **Segundo paso:** Escribir test de integración del flujo completo:
   ```
   startSession → updateLog → completeSet → finishSession → verify DB
   ```

3. **Tercer paso:** Revisar este documento y decidir qué mejoras adicionales son relevantes.

---

*Este documento es para referencia interna. No afecta el funcionamiento de la app.*
