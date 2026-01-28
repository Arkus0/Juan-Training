# Copilot / AI agent instructions for Juan Training

> Short, actionable guidance to get an AI agent productive in this repo.

## Quick facts (do these first) ✅
- **Platform:** Flutter (Dart 3+, Flutter 3+). Core state management = `flutter_riverpod` (Provider/StateNotifier). DB = `drift` + `sqlite3`.
- **Device-sensitive features:** OCR (`google_mlkit_text_recognition`), speech (`speech_to_text`), Android Foreground Service & MediaSession (native Kotlin). **Test these on a physical device**.
- **Must-run before running or testing:**
  1. `flutter pub get`
  2. `dart run build_runner build --delete-conflicting-outputs` (after any schema / annotated-model / Riverpod generator change)
  3. `flutter analyze` → `dart format .` → `flutter test` / `flutter run`

## Quick commands 🔧
- Install deps: `flutter pub get`
- Codegen: `dart run build_runner build --delete-conflicting-outputs`
- Analyze & format: `flutter analyze` then `dart format .`
- Run tests: `flutter test`
- Run on device: `flutter run -d <device-id>` (preferred for OCR/Voice)
- Regenerate exercise assets: `dart run bin/generate_exercises.dart`
- Prune / refresh alternatives: `dart run bin/prune_exercises.dart`

## Quick PR checks ✅
- Run a dry-run of fixes: `dart fix -n` to review suggested changes.
- Apply fixes if appropriate: `dart fix --apply` (commonly fixes trailing commas and simple style issues).
- Reformat and re-analyze: `dart format .` → `flutter analyze --no-fatal-infos` → `flutter test`.
- If you add or update dependencies: run `flutter pub get` and document any experimental APIs (e.g., some audio APIs) and the device testing required.
- When using experimental package APIs, add a short note in the PR describing the risk and if you added an ignore or wrapper for future follow-up.

## Architecture & where responsibilities live 🏗️
- `lib/providers/` — Business logic & state (Riverpod). Providers frequently use `.family` for per-exercise or per-routine lookup (see `lib/providers/create_routine_provider.dart`, `progression_provider.dart`).
- `lib/services/` — Side-effecting platform integrations (OCR parsing, voice parsing, external fetches). Add new platform bridges here.
- `lib/database/` — Drift schema, DAOs and migrations (see `lib/database/database.dart`, `schemaVersion = 4`).
- `lib/widgets/voice/` — Voice UI & orchestration (mic, sheets, training UI, undo snackbars).
- `bin/` — Utility scripts to maintain assets & JSON (e.g., `generate_exercises.dart`, `prune_exercises.dart`, `fill_names_*.dart`). Use these when updating `assets/data/*.json`.

## Project-specific patterns & conventions 📐
- **Spanish-first**: UI strings and comments are primarily in Spanish; prefer Spanish for UI-related changes and related tests.
- **Undo UX**: Destructive actions usually show a SnackBar with **DESHACER**. Always call `ScaffoldMessenger.of(context).hideCurrentSnackBar();` before `showSnackBar()` (see `lib/widgets/voice/voice_undo_snackbar.dart`).
- **Haptics**: Haptic feedback is used widely (e.g., `HapticFeedback.mediumImpact()`); follow existing patterns for tactile confirmation.
- **Providers**: Keep side-effects inside `StateNotifier` implementations; keep provider bodies pure when possible (see `voiceInputProvider.notifier` usage in voice widgets).
- **Linting choices**: Favor `const` constructors & immutability. Avoid `print` in production code (see `analysis_options.yaml` and `ci_report.txt`).

## Data & asset maintenance ✅
- Exercise library master: `assets/data/exercises.json`. Use `bin/generate_exercises.dart` to fetch/refresh images and data from external APIs.
- Alternatives mapping: `assets/data/alternativas.json` — serviced by `lib/services/alternativas_service.dart`.
- If you update the asset JSON, follow bin scripts' flow: generate → inspect `*_pruned.json` → copy into `assets/data/` and run `flutter pub get` if needed.

## Native bridges & permissions (Android) 🔌
- Native channels & entry points: see `android/app/src/main/kotlin/com/example/juan_training/MainActivity.kt`.
  - Music channel: `juan_training/music_launcher`
  - Timer channel: `com.juantraining/timer_service`
  - Media session channel: `com.juantraining/media_session`
- Timer & MediaSession features rely on foreground services and notification/listener permissions. **Always test on-device** and verify `AndroidManifest.xml` permissions.

## Database & migrations 🗄️
- Drift schema is authorative in `lib/database/database.dart`. Migration logic is implemented in `MigrationStrategy` and `schemaVersion` lives there (currently v4). After schema changes run build_runner and test migrations on device/emulator.
- Generated DB files (e.g., `database.g.dart`) are checked into the repo. **Do not edit generated files by hand.**

## Testing notes 🧪
- Unit tests & widget tests live in `test/` and commonly use `test/mocks.dart` for `ITrainingRepository` mocks.
- Some tests assume local generated artifacts; ensure `build_runner` was run after changes that impact generated outputs.
- CI workflow (`.github/workflows/flutter-tests.yml`) runs `flutter pub get` + `flutter test` on push/PR to `main`.

## Helpful file examples (look here first) 🔎
- Voice UX: `lib/widgets/voice/*` (buttons, sheets, FAB, training flows)
- Undo & feedback: `lib/widgets/voice/voice_undo_snackbar.dart`, `lib/widgets/voice/voice_feedback_widgets.dart`
- Providers: `lib/providers/create_routine_provider.dart`, `progression_provider.dart`, `paginated_exercises_provider.dart`
- DB: `lib/database/database.dart`
- Native integration: `android/.../MainActivity.kt`, `TimerForegroundService` and `MediaSessionService` implementations
- Asset scripts: `bin/generate_exercises.dart`, `bin/prune_exercises.dart`, `bin/fill_names_*.dart`
- Tests & mocks: `test/mocks.dart`, `test/providers/*`

## Quick rules & snippets 🧾
- Show a snack safely:
```dart
ScaffoldMessenger.of(context).hideCurrentSnackBar();
ScaffoldMessenger.of(context).showSnackBar(...);
```
- After editing Drift/Riverpod annotated models:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
- Update assets from scripts:
```bash
dart run bin/generate_exercises.dart
dart run bin/prune_exercises.dart
```

## What agents should NOT do 🚫
- **Never edit generated files** (e.g., `*.g.dart`, generated providers). Run the appropriate codegen instead.
- **Do not rely solely on emulators** for OCR/voice/foreground-service behavior — require device verification.
- Avoid introducing `print` statements; follow `analysis_options.yaml`.

---
If you'd like, I can open a PR with this updated file and add a short checklist to the PR template (e.g., run build_runner, update assets, device test). Any missing or unclear areas I should expand?