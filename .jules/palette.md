# Palette's Journal

## 2024-05-23 - Hidden Interactions in Data Rows
**Learning:** Critical interactive elements (like copying previous workout data) were implemented as simple `Container`s with `GestureDetector`, providing no visual affordance or accessibility cues.
**Action:** Audit "data-like" interactive elements and wrap them in `InkWell` + `Tooltip` to make them discoverable and keyboard-accessible.
