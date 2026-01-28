# SPEC: PORTAR ‘ALMA’ DE JUAN-TRAINING (versión minimal para rehacer desde cero)

Objetivo

Proveer una especificación clara y un *starter bundle* ligero que permita a otro equipo/agent recrear la funcionalidad esencial de Juan-Training en otro repositorio (p. ej. app de nutrición) sin copiar la app: conservar el dominio, UX y contratos, permitiendo reimplementación desde cero.

Principios que deben preservarse

- Español-first y copy conciso en UI.
- Flujos offline-first y local-first (persistencia local con migraciones). 
- Baja fricción para registrar entrenamientos (voz/manual/scan) y exportar datos. 
- UX con acciones reversibles (DESHACER) y haptics.
- Arquitectura limpia: modelos → repositorios → providers/controllers → UI → servicios plataforma.

Modelos clave

- Sesion (Sesion): id, fecha, durationSeconds?, totalVolume, ejerciciosCompletados[], rutinaId?, dayName?
- Ejercicio (Ejercicio): id/nombre, logs (SerieLog[])
- SerieLog (SerieLog): peso (double), reps (int), completed (bool), rpe? (int)
- Rutina (Rutina): id, nombre, ejerciciosPlantilla

API pública mínima (contratos)

1) ITrainingRepository
- Future<void> saveSession(Sesion s)
- Stream<List<Sesion>> watchSessions()
- Future<void> deleteSession(String id)
- Future<List<Rutina>> getRutinas()

2) ITimerService (pseudocódigo)
- void start(int seconds)
- void stop()
- Stream<int> remaining$

3) IVoiceInputService
- Future<Sesion?> listenAndParse()

Flujos importantes que replicar

- Sesión: startSession → recordSeries → completeSet → undoSet → finishSession → persistir y emitir por watchSessions
- Historial: watchSessions expone stream; UI agrupa sesiones por etiqueta: ESTA SEMANA, SEMANA PASADA, ESTE MES, MMMM YYYY
- Export: texto human-readable + JSON (para share)

Tests de aceptación mínimos (automatizables)

- Unit: controladora de sesión (start/addSet/finish/undo) — comprobar transiciones de estado y valores calculados (totalVolume, completedSetsCount).  
- Unit: in-memory repo — guardar, emitir por stream, eliminar.  
- Widget: HistoryScreen — muestra agrupación correctas y permite exportar.
- Integration (manual): crear sesión en dispositivo, finalizar, verificar en historial y export.

Recomendación de desarrollo por fases

1. Minimal MVP: modelos + in-memory repo + training controller + HistoryScreen + tests unitarios (alta prioridad).  
2. Persistencia local con Drift (o alternativa): implementar migraciones en PR separado.  
3. Servicios nativos (voice/ocr/timer/media): opcional y por PRs separados, inicialmente stubs. 

Entregables para el agent que re-haga la app

- Implementación desde cero en repo destino siguiendo la especificación de modelos y contratos.  
- Tests unitarios mínimos que cubran la lógica del dominio.  
- UI mínima para validar (History, Session flow) con texto en español.  

Guía de uso del starter bundle (lo que se incluye en este repo)

- `lib/models/` — modelos ligeros con helpers para cálculo.
- `lib/repositories/i_training_repository.dart` — interfaz descriptiva.
- `lib/repositories/in_memory_training_repository.dart` — implementación simple con StreamController (útil para tests y prototipado).
- `lib/providers/training_session_controller.dart` — Notifier-based controller con start/addSet/finish/undo.
- `test/` — tests unitarios que sirven de referencia para la futura implementación en el repo destino.

Notas para el agente del repo destino

- Mantén las interfaces: es fácil reemplazar `InMemory` por `Drift` o por un servicio remoto sin cambiar UI/Providers si respetas `ITrainingRepository`.
- Si el destino usa Riverpod 3: adapta `training controller` a `Notifier`/`AsyncNotifier` (ejemplificado). Si no, adapta internamente manteniendo los métodos expuestos.
- Implementa los services nativos solo si el equipo puede testear en dispositivo (OCR/voice/foreground services).

Siguientes pasos sugeridos

1. Implementar MVP con `InMemory` repo y controller en el repo destino como primer PR.  
2. Agregar tests unitarios y de widget que validen el comportamiento.  
3. Introducir persistencia (Drift) en PR separado con migrations y codegen.

---

Si quieres, creo ahora el starter bundle mínimo en este repo (modelos + interfaces + in-memory repo + controller + tests). Dime si quieres que use `Notifier` (Riverpod 3) o `StateNotifier` (más compatible con versiones previas).