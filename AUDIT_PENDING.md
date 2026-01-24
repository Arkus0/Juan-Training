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

### `DriftTrainingRepository` - 1300+ líneas

**Archivo:** `lib/repositories/drift_training_repository.dart`

**Estado:** 🔄 EN PROGRESO

**Progreso:**
- ✅ `RoutineRepository` extraído (`lib/repositories/routine_repository.dart`)
- ⏳ `SessionRepository` - Pendiente
- ⏳ `AnalyticsRepository` - Pendiente

**Patrón a seguir:** Ver `RoutineRepository` como ejemplo de extracción.

---

### `TrainingSessionNotifier` - 1000+ líneas

**Archivo:** `lib/providers/training_provider.dart`

**Estado:** ⏳ PENDIENTE

**Refactorización sugerida:** Dividir en:
1. `TrainingSessionNotifier` - Solo estado de ejercicios
2. `RestTimerController` - Timer específico
3. `SessionPersistenceService` - Save/restore

**Recomendación:** Hacer después de completar la refactorización del repositorio.

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
