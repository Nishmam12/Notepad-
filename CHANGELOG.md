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
