## 2026-01-21 - Swipe-to-Delete for Routines
**Learning:** Destructive actions for primary entities (like Routines) must be discoverable but safe. "Hidden" deletion (missing button) frustrates users, while Swipe-to-Dismiss provides an intuitive, gestural shortcut common in mobile apps.
**Action:** When implementing list views for manageable entities, always consider the "Remove" lifecycle and prefer Swipe-to-Dismiss + Undo SnackBar over complex modal dialogs for smoother flow.
