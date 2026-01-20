## 2025-02-18 - Optimized Training Session Rendering
**Learning:** The `TrainingSessionScreen` was watching the entire `TrainingState`. Since `updateLog` replaces the `exercises` list (immutability), every keystroke in a weight input triggered a full rebuild of the `ListView` and all `ExerciseCard`s. This is O(N*M) where N is exercises and M is chars typed.
**Action:** Refactored `TrainingSessionScreen` to use `ref.watch(select(...))` for only top-level metadata (length, timer). Extracted `SessionExerciseCard` to watch only its specific exercise index. This isolates rebuilds to the single row being edited.

## 2025-02-19 - Optimized Exercise Search
**Learning:** In `SearchExerciseScreen`, the `Fuzzy` search index (O(N) to build) was being re-instantiated on every keystroke because the text controller listener triggered `setState`.
**Action:** Memoized the `Fuzzy` instance within the state. It is now only rebuilt when the exercise list reference changes, reducing typing latency significantly.

## 2025-02-21 - Granular Session Set Updates
**Learning:** Even with `SessionExerciseCard` optimized, typing in a set input caused the entire card to rebuild because it watched the whole `Exercise` object. This meant all sibling sets were rebuilt unnecessarily.
**Action:** Refactored `SessionSetRow` to be a `ConsumerStatefulWidget` that watches its own specific log entry. The parent `SessionExerciseCard` now only watches the exercise name and log count. Typing performance is now O(1) regarding the number of sets/exercises.
