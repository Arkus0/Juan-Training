# Guía de portado: Juan-Training → Repo de Nutrición

Resumen rápido

- Objetivo: Facilitar que el agente del repo de nutrición integre funcionalidades de Juan-Training sin copiar toda la app tal cual. Esta guía prioriza archivos, pasos de integración, comandos concretos y una QA checklist mínima.

Prioridad de elementos a portar (razón y esfuerzo estimado)

1. `lib/providers/` — múltiples providers críticos (ej.: `trainingProvider`, `sesionesHistoryStreamProvider`, `rutinasStreamProvider`, `createRoutineProvider`, `paginatedExercisesProvider`).
   - Razón: Lógica de negocio y estado.  
   - Esfuerzo: High

2. `pubspec.yaml` (dependencias) — `flutter_riverpod`, `drift`, `drift_dev`, `build_runner`, `sqlite3_flutter_libs`, `google_mlkit_text_recognition`, `speech_to_text`, `flutter_local_notifications` (si aplica).
   - Razón: Necesario para reproducir el entorno y generar código.
   - Esfuerzo: Medium

3. `lib/database/database.dart` (+ opcional `database.g.dart` si se desea copiar) — `AppDatabase`, `schemaVersion`, `MigrationStrategy`.
   - Razón: Persistencia y migraciones.  
   - Esfuerzo: Medium

4. `lib/repositories/` — implementaciones que usan Drift (e.g., `DriftTrainingRepository`), interfaces (`ITrainingRepository`).
   - Razón: Abstracción necesaria para desacoplar persistencia.
   - Esfuerzo: Medium

5. `lib/services/` — servicios nativos/bridges (timer, media session, haptics, OCR/voice helpers).
   - Razón: Features dependientes de plataforma.  
   - Esfuerzo: Medium

6. `assets/data/` — `exercises.json`, `alternativas.json` y `assets/img/ejercicios/`.
   - Razón: Datos y media de la librería de ejercicios.
   - Esfuerzo: Low

7. `bin/` scripts — `generate_exercises.dart`, `prune_exercises.dart`.
   - Razón: Para regenerar assets/JSON sin copiar manualmente.
   - Esfuerzo: Low

Notas sobre Riverpod 3

- El repo original usa API de Riverpod (StateNotifier, StreamProvider, etc.). La migración a Riverpod 3 puede ser un cambio grande para providers que quieran pasarse a `Notifier`/`AsyncNotifier`.
- Recomendación: migración incremental. Actualizar `pubspec.yaml` del destino a `flutter_riverpod: ^3.x`, ejecutar `flutter pub get`, compilar y arreglar errores. Priorizar providers con side-effects y tests asociados.

Pasos de integración (comando a comando)

1. Clonar y crear branch

   ```bash
   git checkout -b feature/port-juan-training
   ```

2. Actualizar `pubspec.yaml` en repo destino (agregar dependencias necesarias) y ejecutar:

   ```bash
   flutter pub get
   ```

3. Copiar los archivos prioritarios (ver lista arriba). Preferible copiar interfaces (`ITrainingRepository`), providers y DB, y adaptar rutas/namespaces.

4. Generar código (si copias archivos con anotaciones `@DriftDatabase`, build_runner):

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

5. Ejecutar análisis y tests:

   ```bash
   flutter analyze
   flutter test
   ```

6. Ejecutar app en dispositivo (preferible físico para OCR/Voice/Foreground services):

   ```bash
   flutter run -d <device-id>
   ```

QA checklist mínima

- App arranca sin errores y solicita permisos necesarios (mic, cámara, notificaciones) si las features nativas están activas.
- Crear y guardar una sesión completa, verificar que aparece en `History` y que los metadatos (duración, volumen, series) son correctos.
- Exportar sesión y exportar historial completo (funciones de share) y verificar formato.
- Ejecutar `flutter test` y asegurar que los tests críticos pasan.
- Validar `flutter analyze` limpio y aplicar `dart format .`.

Preguntas abiertas para el mantenedor del repo destino

1. ¿Mantendrán Drift como capa de persistencia o prefieren otra solución (Hive, sembast o backend)?
2. ¿Desean portar ahora las integraciones nativas (timer/MediaSession) o las quieren en un PR posterior (stubs primero)?
3. ¿Política de migración de Riverpod: migración completa a `Notifier/AsyncNotifier` o migración gradual?
4. ¿Desean incluir todos los assets (`assets/data/*.json`) o usar un paquete/asset servidor externo?

Uso del script de ayuda `scripts/extract_providers.dart`

- Ejecuta `dart run scripts/extract_providers.dart` para obtener un listado rápido de declarations de providers y los archivos donde están definidos.

---

Si quieres, puedo crear un PR preparatorio en este repo que incluya este documento y el script de extracción, y opcionalmente un `CHANGELOG.md` y checklist de PR para facilitar la integración en el repo destino.
