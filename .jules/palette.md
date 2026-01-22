## 2024-05-23 - Swipe-to-Dismiss Pattern for Routines
**Learning:** For list items like Routines, use `Dismissible` with `endToStart` direction and a red background with a trash icon.
**Action:** Always couple this with an 'Undo' `SnackBar` and `HapticFeedback.mediumImpact()` to provide a safe and tactile experience without blocking confirmation dialogs. Restore data using the repository's save method.
