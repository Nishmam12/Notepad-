# InkFlow Project Context & Handover Document

## 1. Project Overview
InkFlow is an **Android-first Flutter note-taking app** emphasizing zero artificial limitations. Core functionalities include unlimited pages, pressure-sensitive pens, PDF/Image handling, vector-based backgrounds, and lasso selection. It is purely offline-first through Phase 6.

## 2. Architectural Paradigm
- **UI Framework:** Flutter (Android/iOS).
- **State Management:** Riverpod (`flutter_riverpod`). **Strictly written by hand** (no `riverpod_generator`) due to analyzer version conflicts with `isar_generator`. We use `ConsumerWidget` instead of `StatefulWidget`.
- **Database (Metadata):** Isar (v3.1.0+1). Stores `Notebook`, `NotePage`, and `ImportedContent` schema.
- **Storage (Heavy Data):** 
  - Strokes: Raw JSON encoded `.ink` binary/text files stored in the `getApplicationDocumentsDirectory()`. Format: `page_{index}.ink`.
  - Thumbnails/Images: Cached `ui.Image` encoded asynchronously to prevent UI stalling. PDFs are rasterized to disk via `pdfx`.

## 3. Progress: Phases Completed
- **Phase 0:** Environment foundation and strict architectural guidelines.
- **Phase 1:** Core Canvas Engine (Layers, Input Pipeline via `Listener`, `perfect_freehand` strokes, Toolbar, Isar initialization).
- **Phase 2:** Advanced toolsets (Erasers, Colors) and Export functionality.
- **Phase 3:** Multi-Page & Book View.
- **Phase 4:** PDF & Image Import **(Just Completed)**.

## 4. Phase 3 & 4 In-Depth Details (Current Code State)

### 4.1 Page Operations & LRU Caching
- **Isar Metadata:** `NotePage` has an enforced continuous `pageIndex`. `PageRepository` acts as the interface to reorder/duplicate/delete without index gaps.
- **LRU Memory Management:** The `PageCacheManager` and `PdfCacheManager` restrict the active memory footprint. The page cache keeps exactly 3 pages active (`currentIndex - 1` to `currentIndex + 1`) while the PDF cache gracefully drops distant rasterized images.

### 4.2 State Management (Riverpod Dynamics)
- **AutoDispose & Families:** To prevent overlapping histories across pages, `canvasStateProvider`, `undoRedoProvider`, and `importedContentProvider` are defined as `StateNotifierProvider.autoDispose.family<..., int>`.
- **The autoDispose Unmounted Bugs:** We ran into race conditions where async methods (like saving strokes or loading PDFs) tried to mutate state after `autoDispose` occurred. **Fixes:** Stroke saving utilizes synchronous overrides via `ref.listen` before disposal. Async load operations now strictly check `if (!mounted) return;` before updating state.

### 4.3 PDF & Image Import Architecture
- **ImportedContentLayer:** Sat below the `StrokeHistoryLayer`. It draws the loaded `ui.Image` assets.
- **FreeImageOverlay:** A stacked `InteractiveViewer` built strictly to handle pinch-to-zoom, pan, and transform gestures *only* for the active `ImportedContent` (the image/PDF currently being adjusted) before it gets locked into the background layer.
- **Isar Embedded Schema:** `ImportedContent` is embedded into `NotePage` to allow seamless fetching of transformations without extra database joins.

### 4.4 Gradle / Build System Hurdles
- **FilePicker Compatibility:** We had to downgrade `file_picker` to version `8.3.7` to avoid severe plugin incompatibilities regarding the Android `namespace` directive and built-in Kotlin settings.
- **Compile SDK Override:** Transitive Android dependencies (like `flutter_plugin_android_lifecycle`) strictly demanded `compileSdk 36`. Since older plugins like `file_picker` hardcode `compileSdk 34` internally, we had to implement a forceful reflection hook in `android/build.gradle.kts` within a `subprojects` block to dynamically rewrite all plugins' compile API versions to `36`. 

## 5. Upcoming: Phase 5
Phase 5 focuses on **Shapes & Selection**. 
- Conceptually, this will introduce vector shapes and a lasso tool.
- The `SelectionLayer` (Layer 5) will be built on top of all existing layers to handle UI handles and bounding boxes.

---
**Note to AI (Claude):** Do not attempt to refactor `autoDispose.family` logic in the Canvas without consulting the "unmounted" race condition context above. Isar schema generation requires `dart run build_runner build` locally. If encountering Android compilation errors, verify the reflection hook in `android/build.gradle.kts`.
