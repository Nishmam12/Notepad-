# InkFlow Project Context & Handover Document

## 1. Project Overview
InkFlow is an **Android-first Flutter note-taking app** emphasizing zero artificial limitations. Core functionalities include unlimited pages, pressure-sensitive pens, PDF handling (upcoming), vector-based backgrounds, and lasso selection. It is purely offline-first through Phase 6.

## 2. Architectural Paradigm
- **UI Framework:** Flutter (Android/iOS).
- **State Management:** Riverpod (`flutter_riverpod`). **Strictly written by hand** (no `riverpod_generator`) due to analyzer version conflicts with `isar_generator`. We use `ConsumerWidget` instead of `StatefulWidget`.
- **Database (Metadata):** Isar (v3.1.0+1). Stores `Notebook` and `NotePage` schema.
- **Storage (Heavy Data):** 
  - Strokes: Raw JSON encoded `.ink` binary/text files stored in the `getApplicationDocumentsDirectory()`. Format: `page_{index}.ink`.
  - Thumbnails: `ui.Image` encoded as `.png` generated asynchronously.

## 3. Progress: Phases Completed
- **Phase 0:** Environment foundation and strict architectural guidelines.
- **Phase 1:** Core Canvas Engine (Layers, Input Pipeline via `Listener`, `perfect_freehand` strokes, Toolbar, Isar initialization).
- **Phase 2:** Advanced toolsets (Erasers, Colors) and Export functionality.
- **Phase 3:** Multi-Page & Book View **(Just Completed)**.

## 4. Phase 3 In-Depth Details (Current Code State)

### 4.1 Page Operations & Caching
- **Isar Metadata:** `NotePage` has an enforced continuous `pageIndex`. `PageRepository` acts as the interface to reorder/duplicate/delete without index gaps.
- **Storage:** `InkFileStorage` handles raw disk reads/writes of strokes scoped to `page_{index}.ink`. We recently hardened it to catch `FormatException` if empty files are loaded.
- **LRU Memory Management:** The `PageCacheManager` restricts the active memory footprint to precisely 3 pages (`currentIndex - 1` to `currentIndex + 1`). Pages drifting outside of this window are forcibly evicted to prevent memory bloat.

### 4.2 State Management (Riverpod Dynamics)
- **AutoDispose & Families:** To prevent overlapping histories across pages, `canvasStateProvider` and `undoRedoProvider` are defined as `StateNotifierProvider.autoDispose.family<..., int>`.
- **The autoDispose Ghosting Bug (Resolved):** We ran into critical race conditions where `autoDispose` erased the `List<Stroke>` from memory right as the asynchronous `_forceSave` tried to commit them during page switches. **Fix:** We synchronously capture the `oldStrokes` within the `ref.listen<PageState>` observer before disposing, passing them down the pipeline as overrides.

### 4.3 Background Operations
- **Thumbnail Generation:** Handled by `PageThumbnailService`. `ui.PictureRecorder` draws strokes on a background canvas and scales them down. Then, `compute` isolates handle PNG encoding and disk I/O so the UI never drops frames. Missing/corrupted image handles have been hardened.

### 4.4 User Interfaces
- **NoteEditorScreen:** Features an infinite scrollable vertical/horizontal canvas stack. The `PageNavigatorWidget` sits at the bottom, offering a horizontal scroll of lazy-loaded page thumbnails with Long-Press operations (Insert, Duplicate, Delete).
- **BookViewScreen:** A specialized two-pane mathematical spread implementation. Driven by `BookViewNotifier`, it maps `currentSpread` into exactly two `EditablePagePane` instances. Swiping gestures traverse spreads.

## 5. Upcoming: Phase 4
Phase 4 focuses on **PDF & Image Import**. 
- Dependencies already configured (`pdfx`, `image_picker`).
- Conceptually, PDF pages will be extracted as backend textures and injected into the `ImportedContentLayer` underlying the stroke layers.

---
**Note to AI (Claude):** Do not attempt to refactor `autoDispose.family` logic in the Canvas without consulting the "ghosting bug" race condition context above. Isar schema generation requires `dart run build_runner build` locally.
