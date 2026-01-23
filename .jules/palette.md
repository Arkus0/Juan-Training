# Palette's Journal

## 2024-05-23 - Hidden Interactions in Data Rows
**Learning:** Critical interactive elements (like copying previous workout data) were implemented as simple `Container`s with `GestureDetector`, providing no visual affordance or accessibility cues.
**Action:** Audit "data-like" interactive elements and wrap them in `InkWell` + `Tooltip` to make them discoverable and keyboard-accessible.

## 2024-05-24 - Destructive Action Safety
**Learning:** Users hesitate to manage routines if deletion is permanent and immediate. The "Swipe to Delete" pattern requires a safety net.
**Action:** Always pair destructive list actions (Swipe/Delete) with a prominent "Undo" SnackBar to build user confidence in managing their data.

## 2024-05-25 - Standardizing Interactive Elements
**Learning:** Custom "buttons" built with `GestureDetector` + `Container` lack native touch feedback (ripples) and accessibility semantics, making the UI feel "dead" and harder to use for screen readers.
**Action:** Replace ad-hoc interactive containers with `Material` + `InkWell` + `Tooltip` to ensure consistent visual feedback and accessibility compliance across the app.

## 2026-01-22 - Accessible Visualizations
**Learning:** Purely visual representations (like the plate calculator) are invisible to screen readers, excluding users from key information.
**Action:** Always wrap custom visual widgets in `Semantics` with a descriptive `label` that summarizes the visual data (e.g., "Plates: 20kg, 10kg").

## 2026-05-25 - Micro-Interactions in Inputs
**Learning:** Icon buttons inside input fields (like calculators) often lack touch targets and semantics when implemented with raw `GestureDetector`.
**Action:** Use composed `Tooltip` + `Material` + `InkWell` patterns even for small secondary actions to maintain accessibility and consistency.
