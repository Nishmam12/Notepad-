# InkFlow — Agent Handover Context

This file serves as a complete brain-dump of the current state of **InkFlow**, an Android-first Flutter note-taking app. Use this context file to quickly onboard a new AI agent or developer to the project.

---

## Project Overview
InkFlow is a free, offline-first note-taking app that provides premium features (unlimited pages, templates, PDF import, pressure-sensitive pens) without artificial limitations or paywalls.

**Core Stack:**
*   **Framework:** Flutter (Android first, iOS later)
*   **State Management:** Riverpod (`flutter_riverpod` only, NO code-generation/annotations like `riverpod_generator`)
*   **Drawing Engine:** Raw pointer `Listener` + `perfect_freehand`
*   **Database:** Isar (`isar`, `isar_flutter_libs`) for metadata
*   **File Storage:** Raw binary `.ink` storage for strokes (handled via path_provider)

---

## Architecture (The 6 Layers)
1.  **Presentation (UI):** Thin widgets using `ConsumerWidget`. Business logic lives in Riverpod notifiers.
2.  **Canvas Engine:** A `Stack` of `CustomPainter` widgets, each wrapped in a `RepaintBoundary` to cache GPU textures. 
    *   *Bottom to Top:* `BackgroundLayer` (Templates) → `ImportedContentLayer` (PDFs) → `StrokeHistoryLayer` (Completed strokes) → `ActiveStrokeLayer` (Live stroke) → `ShapeLayer` → `SelectionLayer`.
    *   *Performance Key:* Only the `ActiveStrokeLayer` repaints during active drawing (every ~8ms).
3.  **Input Pipeline:** Uses `RawPointerListener` (a wrapper around `Listener`) to catch raw `PointerEvent`s natively. Extracts pressure data (`event.pressure`).
4.  **State Management:** `StateNotifierProvider` used exclusively. Key providers: `toolProvider`, `canvasStateProvider`, `undoRedoProvider`.
5.  **Data Layer:** Isar stores `Notebook` and `NotePage` metadata. Strokes are saved to device documents directory.
6.  **Sync Layer:** Out of scope for now (Phase 7+).

---

## What Has Been Completed So Far

### Phase 1: Core Canvas Engine (✅ DONE)
*   Initialized project with `AppColors` and `AppTheme` (Dark engineering aesthetic).
*   Configured Isar singleton and built `Notebook` / `NotePage` collections.
*   Built the Home Screen with a GridView of notebooks.
*   Implemented `NoteEditorScreen` with the layered `CanvasWidget`.
*   Built `RawPointerListener` which correctly catches stylus/touch input and ignores unwanted gesture arena conflicts.
*   Wired `perfect_freehand` to render smooth paths.
*   Implemented `UndoRedoStack` using the Command pattern.
*   Built the `ToolBar` with Pen, Eraser, Undo, Redo, Color picker, and Size slider.
*   **Eraser Hotfix:** Implemented mathematical point-to-line-segment distance calculation so fast finger-swipes with sparse points can be cleanly erased.
*   **UI Hotfix:** Wrapped the Toolbar in a horizontal `SingleChildScrollView` to fix overflow issues on narrower screens (like the Pixel 7 Pro).

### Phase 2: Templates & Export (✅ DONE)
*   **Dynamic Templates:** Built `TemplateType` (Blank, Ruled, Dotted, Grid, Engineering) and a vector-based `TemplatePainter`. Automatically adapts to Dark/Light themes.
*   **Template Picker:** Added a bottom sheet UI allowing the user to switch templates with live canvas updates.
*   **High-Res Export Pipeline:** Built `CanvasExportService` which uses `ui.PictureRecorder` to silently redraw the entire canvas (template + strokes) at exact A4 dimensions and 300 DPI without watermarks.
*   **Native Sharing:** Built `ExportShareService` utilizing `share_plus` to write the rendered image to a temporary `.png` and invoke the Android native share sheet.

---

## What is Next?

### Phase 3: Multi-Page & Book View (⏳ NEXT)
Currently, the canvas is a fixed `Size.infinite` shell bound to the screen size. Phase 3 will introduce:
1.  An infinite or vertically scrolling canvas (`InteractiveViewer` or custom Pan/Zoom architecture).
2.  Pagination (Multiple `NotePage` instances per `Notebook`).
3.  A "Book View" to swipe between pages.
4.  A dedicated "Pan Tool" or two-finger panning logic to prevent drawing while scrolling.

---

## Agent Instructions for the Next Developer
1. **Never use `GestureDetector`** on the canvas layer, continue using `Listener`.
2. **Never use code generation** for Riverpod. Write `StateNotifier` classes manually.
3. If Isar models are modified, remember to run: `dart run build_runner build`.
4. Check `.gitignore` — we have explicitly ignored `/android/build/` to prevent Gradle cache commits.
5. All UI components should stick to the `AppColors` dark engineering theme. Do not invent new colors without matching the established tokens.
