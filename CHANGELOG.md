# Changelog

All notable changes to InkFlow are recorded here. The running app shows its
version on **Settings → About**, so you can confirm which build is installed on
any device.

Versioning: `MAJOR.MINOR.PATCH+BUILD`
- **MAJOR** – breaking changes / major reworks
- **MINOR** – new features, backwards compatible
- **PATCH** – bug fixes and small tweaks
- **BUILD** – auto-incremented on **every push to `main`** by the GitHub Actions
  workflow `.github/workflows/version-bump.yml` (runs on GitHub, so every
  collaborator gets it with no setup). A monotonic counter that never resets.
  Entries below are keyed by the semantic version; the exact `+BUILD` you see
  in-app is whatever commit you're on.

## [1.1.0] - 2026-06-21
### Added
- **Canvas 2.0 — a ground-up rebuilt drawing engine (beta, opt-in).** Turn it
  on in **Settings → Editor → "Canvas 2.0 editor"** to open notebooks in the new
  engine; the classic editor stays the default and is unchanged. Built over a
  unified element model with near-Excalidraw drawing parity:
  - One model for ink, shapes, text, images and **frames**, with multi-select
    (marquee + 8 handles + rotate), grouping, alignment/distribution, snapping
    with guides, z-ordering, and lock.
  - Full shape styling: hachure / cross-hatch / solid fills, solid / dashed /
    dotted strokes, rounded edges, arrowheads, elbow arrows, and a
    hand-drawn "rough" look.
  - **Frames** — named containers that clip and move their contents together.
  - **Element library** — save a selection as a reusable item and drop it onto
    any page (persisted on-device).
  - **Export & share** to PNG, SVG and PDF (the selection or the whole page),
    and **copy/paste** elements across pages via the system clipboard.
  - Eraser (stroke and pixel), laser pointer, and full **undo/redo** across
    every edit.
  - A redesigned read-only **Book View** with swipeable spreads and a thumbnail
    filmstrip, on each notebook's paper colour.
- Real embedded images now render on the canvas and in exports.
### Changed
- Existing notebooks are migrated into the new unified storage on first launch.
  The migration is **non-destructive** — your original `.ink` files and page
  data are left untouched, so the classic editor keeps working exactly as before.

## [1.0.2] - 2026-06-16
### Fixed
- Palm rejection is now order-independent and far more consistent. Previously a
  touch was only ignored if the stylus was already down when it landed, so a
  palm resting *before* the pen (or lingering between strokes) slipped through
  and caused stray marks or unwanted pan/zoom. Now the pen retroactively drops
  any palm already on screen, a short grace window after each stroke ignores a
  settling/re-tapping palm, and a hovering stylus pre-arms rejection. Finger
  drawing and two-finger pan/zoom are unaffected when no stylus is in use.

## [1.0.1] - 2026-06-16
### Added
- Single-source version tracking: the app version now lives only in
  `pubspec.yaml` and is read at runtime via `package_info_plus`.
- Auto-incrementing build number via a GitHub Actions workflow, so the version
  bumps on every push for all collaborators with zero local setup.
- This `CHANGELOG.md` to track what ships in each version.
### Changed
- The About screen now displays the actual installed version and build number
  instead of a hardcoded string.

## [1.0.0] - baseline
- Infinite-canvas note taking with stroke rendering, shapes, and whiteboard
  (Excalidraw-style) tools.
- Book/notebook view, page templates, autosave, lasso transform.
- PDF rendering and import, image import, export & share.
