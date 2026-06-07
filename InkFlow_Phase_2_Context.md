# InkFlow — Phase 2 Context File

Read this file fully before writing any code.

## Project Summary

InkFlow is an **Android-first Flutter note-taking app** designed to remove the artificial paywalls found in modern note apps. The product philosophy is simple:

- Unlimited notebooks and pages
- PDF import and annotation
- Pressure-sensitive pen input
- Shape tools and lasso tools
- Watermark-free export
- No artificial limitations on core features

The app is built in Flutter/Dart and ships on Android first, then iOS.

---

## Current State

### Phase 0
Complete.

The following already exists:
- Flutter project created
- `pubspec.yaml` configured and `flutter pub get` passes
- Full feature-first folder structure under `lib/`
- Test folder structure under `test/`

### Phase 1
Assume Phase 1 is complete unless the repository says otherwise.

Phase 1 focused on the core canvas engine:
- app colors and theme
- Isar setup
- notebook/page models
- repository and home state
- note editor shell
- stroke models
- raw pointer input
- canvas layers
- undo/redo
- pen toolbar
- `.ink` stroke persistence

### Phase 2
**Phase 2 title: Templates & Export**

This phase should add the note presentation layer and export pipeline without touching sync, auth, or cloud features.

---

## Core Architecture Reminders

### Technology Stack
- Flutter
- Dart
- Riverpod for state management
- GoRouter for routing
- Isar for metadata
- local filesystem for binary stroke/page storage
- `printing` and `share_plus` for export-related flows

### Rules to Follow
- Do not add new packages unless explicitly approved
- Do not use `StatefulWidget` for business state
- Use `ConsumerWidget` + Riverpod providers
- Keep file names in snake_case
- One class per file
- Add a one-sentence comment at the top of every new file
- Use `Listener`, not `GestureDetector`, for canvas input
- Keep `RepaintBoundary` on every canvas layer
- Do not introduce sync, auth, collaboration, or AI in Phase 2

---

## Existing Folder Structure

Use the existing feature-first layout. Relevant paths for Phase 2:

```text
lib/
├── core/
│   ├── constants/
│   ├── utils/
│   └── theme/
├── features/
│   ├── home/
│   ├── editor/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── canvas/
│   │   ├── domain/
│   │   ├── data/
│   │   └── ...
│   ├── import/
│   ├── export/
│   └── settings/
└── shared/
    └── isar/
```

---

## Phase 2 Product Goal

Phase 2 should let the user:

1. choose from built-in paper templates,
2. switch note paper backgrounds quickly,
3. preview templates before applying them,
4. export notes cleanly without watermarks,
5. export in a format that preserves handwriting quality.

The app should continue to feel fast and lightweight.

---

## Phase 2 Feature Scope

### Templates
Implement a template system that supports:
- blank paper
- ruled paper
- dotted paper
- grid paper
- engineering grid
- dark variant of each template when theme requires it
- configurable template color and opacity if possible without overcomplicating the first version

Template rendering should stay efficient and should not repaint more than necessary.

### Export
Implement export for the current note with:
- PDF export
- watermark-free output
- preserve stroke quality
- include background/template in export
- include imported images if the editor already supports them
- maintain page order correctly

Export should be done locally first. No cloud export pipeline.

---

## Suggested Phase 2 Task Order

Use this order unless a blocker appears:

1. Create template-related domain models
2. Create template presets/constants
3. Add a template service or repository
4. Implement template rendering in the editor canvas
5. Add a template picker UI
6. Add export domain models or config objects
7. Implement export service for PDF generation
8. Add export UI from the editor toolbar or overflow menu
9. Wire export into note data and page rendering
10. Add tests for template selection and export basics

---

## Implementation Guidance

### Templates
Templates should be treated as a canvas background layer, not as flattened image assets unless absolutely necessary. Prefer vector or procedural rendering so the app stays sharp on all device densities.

A template system should ideally support:
- page size awareness
- orientation awareness
- light/dark mode variations
- preview thumbnails
- future custom user templates

### Export
Export should be deterministic and reproducible.

Important behaviors:
- export should use the same page data the user sees
- preserve pen strokes at full resolution
- avoid blurry raster output where possible
- keep file names predictable
- handle multi-page notes gracefully

### UI
Keep the UI minimal and engineering-focused:
- fast access to template switching
- simple export action
- no clutter
- no overdesigned animations

---

## Recommended Files for Phase 2

These are likely candidates for new work. Adjust if the repo already contains some of them.

### Template Side
- `lib/features/editor/domain/models/template.dart`
- `lib/features/editor/domain/models/template_kind.dart`
- `lib/features/editor/domain/services/template_service.dart`
- `lib/features/editor/presentation/widgets/template_picker.dart`
- `lib/features/editor/presentation/canvas/layers/template_layer.dart`

### Export Side
- `lib/features/export/domain/models/export_options.dart`
- `lib/features/export/domain/services/export_service.dart`
- `lib/features/export/data/...`
- `lib/features/export/presentation/...`

If a better structure already exists in the repository, follow it.

---

## Phase 2 Non-Goals

Do not implement:
- sync
- authentication
- collaboration
- AI features
- OCR
- handwriting search
- cloud backup
- PDF import pipeline overhaul
- shape recognition overhaul
- iOS-specific polish beyond what Flutter already gives for free

---

## Development Expectations

Work one file at a time.

After each file:
- show the full file contents
- run analysis or tests relevant to that file
- fix issues before moving on

Do not batch unrelated changes unless a task explicitly requires it.

---

## Final Phase 2 Deliverable

By the end of Phase 2, the app should be able to:

- open a note
- change the paper template
- preview different paper styles
- export the note to PDF cleanly
- keep handwriting and backgrounds readable in the exported file

This is the base for later phases like multi-page book view and PDF/image import.
