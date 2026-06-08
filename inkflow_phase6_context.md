# InkFlow — Project Context File (End of Phase 6)

This file provides the AI agent or LLM (e.g., Claude) with the full context of the InkFlow project up to the end of **Phase 6**.

---

## What This Project Is

InkFlow is an **Android-first Flutter note-taking app** that provides — for free — every feature
that competing apps (Goodnotes, Notability, Squid, Nebo) lock behind paywalls. Core philosophy:
no artificial limitations. Unlimited pages, unlimited templates, PDF import, pressure-sensitive
pens, shape tools, lasso selection, watermark-free export — all free.

The app is built with Flutter/Dart and will ship on Android first, then iOS (Flutter makes the
port trivial). There is no backend yet — Phase 1 through 6 are fully offline-first.

---

## Current Project State

**Phase 0 through 6 are complete.** 
The core features implemented so far include:
- **Phase 0:** Project creation, folder structure setup, architecture design.
- **Phase 1:** Core Canvas Engine with sub-16ms latency, RepaintBoundary layers, raw PointerEvent listener, perfect_freehand stroke rendering, Riverpod state management, Isar local database for metadata, binary file storage for ink data.
- **Phase 2:** Page templates (blank, ruled, grid, dots) and PDF export.
- **Phase 3:** Multi-page navigation and two-page Book View.
- **Phase 4:** PDF, Image, and SVG import functionality with scaling, rotation, and repositioning.
- **Phase 5:** Shape recognition (Ramer-Douglas-Peucker + regression), Shape tools (Line, Arrow, Rectangle, Circle, Triangle, Polygon, Text Box, SVG placeholder), Lasso Selection, selection overlays, and undo/redo support for all shape and lasso actions.
- **Phase 6:** Performance optimizations (StrokePictureCache, PageCacheManager, background Isolate for PDF rendering and export), hardened persistence (auto-recovery `.bak` and `.tmp` files, AutosaveManager), UI/UX polish (Settings/About screens, tablet-optimized responsive layout for Editor toolbars and sidebars, accessibility improvements), global error boundaries, and robust zero-warning code quality.

**The next task is Phase 7: Sync & AI (Post-launch).** 

---

## Architecture — Six Layers

### Layer 01 — Presentation
Flutter widget tree. Screens are thin — no business logic. They only read from Riverpod
providers and call domain services.

### Layer 02 — Canvas Engine
Six stacked CustomPainter widgets, each in a RepaintBoundary.
Stack order bottom → top:
0. `BackgroundLayer`       — vector templates, never repaints during drawing
1. `ImportedContentLayer`  — PDF pages / images, locked background
2. `StrokeHistoryLayer`    — completed strokes, cached as Flutter Picture (optimized via StrokePictureCache)
3. `ActiveStrokeLayer`     — ONLY the live in-progress stroke, repaints every ~8ms
4. `ShapeLayer`            — vector shapes, text boxes, and SVG placeholders
5. `SelectionLayer`        — selection handles, UI overlay (Lasso)

**Critical**: Only `ActiveStrokeLayer` repaints during input. Everything else uses
`RepaintBoundary` to cache as GPU textures.

### Layer 03 — Input Pipeline
Use `Listener` widget, NOT `GestureDetector`. Listener fires raw PointerEvents at the
device's native polling rate. Extract `event.pressure` for pressure-sensitive strokes.
`perfect_freehand` converts raw points into smooth stroke outlines. Shape and Lasso input routing handles complex gestures.

### Layer 04 — State Management (Riverpod)
Write providers manually — no code generation.
Key providers:
- `NoteListNotifier extends StateNotifier<List<Notebook>>` — CRUD for notebooks
- `CanvasStateNotifier extends StateNotifier<CanvasState>` — live stroke data
- `ToolNotifier extends StateNotifier<ToolState>` — active tool, color, size, shape selection
- `PageNotifier extends StateNotifier<PageState>` — current page, total pages
- `UndoRedoStack extends StateNotifier<UndoRedoState>` — Command pattern history (strokes, shapes, lasso)
- `ShapeNotifier`, `SelectionNotifier`, `SettingsNotifier`

### Layer 05 — Data Layer & Concurrency
- **Isar**: stores `Notebook` and `NotePage` metadata (including `ShapeElement` and `ImportedContent`)
- **Binary files**: stroke data stored as `.ink` files (one per page) in app documents directory. Features an atomic rename recovery system.
- **Isolates**: PDF rendering (`pdfx`) and exporting are completely offloaded to background isolates using `compute` to prevent UI thread jank.

### Layer 06 — Sync Layer
**Phase 7 Focus**. Currently offline-only, but designed to sync in the future.

---

## Coding Conventions

1. **Riverpod Providers**: Always write providers manually. No code generation.
2. **State Widgets**: Never use `StatefulWidget` for business state. Use `ConsumerWidget` with Riverpod. Always use `autoDispose` for providers tied to a screen.
3. **Canvas Input**: Do not use `GestureDetector` on the canvas. Use `Listener` only.
4. **Canvas Painting**: Use `RepaintBoundary` on every canvas layer.
5. **Isar Models**: After defining any Isar collection, run `dart run build_runner build`. Do not store large stroke data in Isar.

---

## Development Phases

| Phase | Title | Weeks | Status |
|---|---|---|---|
| 0 | Study & Foundation | 1–2 | ✅ DONE |
| 1 | Core Canvas Engine | 3–6 | ✅ DONE |
| 2 | Templates & Export | 7–8 | ✅ DONE |
| 3 | Multi-Page & Book View | 9–10 | ✅ DONE |
| 4 | PDF & Image Import | 11–14 | ✅ DONE |
| 5 | Shapes & Selection | 15–18 | ✅ DONE |
| 6 | Performance & Launch | 19–21 | ✅ DONE |
| 7 | Sync & AI (post-launch) | 22+ | 🔄 NEXT |

---

## Next Steps for Phase 7
Phase 7 focuses on Cloud Sync, User Authentication, Real-time collaboration, and AI integrations (OCR, handwriting recognition).
