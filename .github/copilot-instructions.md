# Copilot / AI agent instructions for Juan Training

> Short, actionable guidance to get an AI agent productive in this repo.

## Quick facts (do these first) ✅
- Platform: Flutter (Dart 3, Flutter 3+). Core state = flutter_riverpod v2; DB = Drift + sqlite3.
- Local-only features: OCR (google_mlkit_text_recognition), speech_to_text (offline), Android Foreground Service & MediaSession (native Kotlin). Test on a physical device for OCR/Voice/Foreground behavior.
- Required steps before running/tests: 1) `flutter pub get` 2) `dart run build_runner build --delete-conflicting-outputs` 3) `flutter run` (or `flutter test` / `flutter analyze`).

## Big-picture architecture 🏗️
- `lib/providers/` — business logic (Riverpod Providers). Providers are often `Provider.family` / `FutureProvider.family` for per-exercise or per-name lookups.
- `lib/services/` — side-effectful logic (OCR, voice parsing, defensive validation). Prefer adding new platform integrations here.
- `lib/database/` — Drift schema / DAOs. Schema changes require codegen via `build_runner` (critical).
- `lib/widgets/voice/*` — Voice UI + orchestration (mic, sheets, undo snackbars). Many voice patterns are centralized here.
- `lib/screens/` and `lib/widgets/` — UI components and screens; `lib/utils/design_system.dart` centralizes design tokens (colors, snackbar theme, typography).

## Project-specific conventions & patterns 📐
- Primary language for code comments and UI copy is **Spanish**. Use Spanish for UI strings and commit messages where appropriate.
- Undo UX: many destructive actions use a SnackBar with a `DESHACER` action. The pattern is to call `ScaffoldMessenger.of(context).hideCurrentSnackBar();` *before* `showSnackBar()` when showing a new SnackBar (see `lib/widgets/voice/voice_undo_snackbar.dart` and `lib/widgets/session/exercise_card.dart`).
- Haptic feedback is used liberally for confirmatory actions (e.g., `HapticFeedback.mediumImpact()`), mirror this pattern for tactile UX consistency.
- Providers: keep side-effect code in `notifier`s (e.g., `voiceInputProvider.notifier`) and keep providers pure when possible.
- Naming: `Ejercicio`, `SerieLog`, `Sesion` domain types are used — follow domain naming and shape when adding models.

## Codegen & DB workflow (non-negotiable) 🔁
- Run `dart run build_runner build --delete-conflicting-outputs` after any change to Drift schema, annotated models, or Riverpod generator usage.
- Generated files live alongside their sources; ensure you don't edit generated files manually.

## Testing & CI 🧪
- Useful commands: `flutter analyze`, `flutter test`, `dart format .`.
- CI artifacts exist (see `ci_report.txt`), but tests may rely on build_runner artifacts—generate them locally before running CI tests.

## Debugging tips & platform notes 🐞
- OCR/Voice behavior: verify on a physical device. Emulators frequently fail to reproduce camera/mic/foreground service behavior.
- Native code: Android bridges live under `android/app/src/main/kotlin` — modify with care and test on-device.

## Integration & external deps 🔌
- ML Kit: dynamic model download; test first-run behavior.
- speech_to_text: offline speech engine used; latency and recognition quality vary by device — include test cases for common command phrases in Spanish.

## Where to look for examples (important files) 🔎
- Snackbars & undo: `lib/widgets/voice/voice_undo_snackbar.dart`, `lib/widgets/voice/voice_feedback_widgets.dart`, `lib/widgets/session/exercise_card.dart`.
- Voice flow and sheets: `lib/widgets/voice/voice_input_sheet.dart`, `lib/widgets/voice/voice_training_button.dart`, `lib/widgets/voice/voice_mic_button.dart`.
- DB + models: `lib/database/` and `lib/models/` (e.g., `serie_log.dart`, `ejercicio.dart`).
- Design system tokens: `lib/utils/design_system.dart`.

## Examples & small rules (copyable) 🧾
- Show a snack safely:
```dart
ScaffoldMessenger.of(context).hideCurrentSnackBar();
ScaffoldMessenger.of(context).showSnackBar(...);
```
- After changing Drift schema:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```
- When adding / editing voice commands, add Spanish test phrases and check `voice_training_button.dart` parsing regexes.

## What agents should NOT do 🚫
- Do not edit generated files from codegen. Run generators instead.
- Do not assume emulator behavior equals device for OCR/voice/foreground services — require on-device verification.

---
If you want, I can also:
- open a PR with this file and a short checklist in the PR template, or
- expand sections with examples (e.g., common provider patterns or typical unit tests) — tell me which you'd prefer.

Please review: any missing topics or unclear items I should add?