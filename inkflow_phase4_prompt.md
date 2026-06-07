# InkFlow — Phase 4 Master Implementation Prompt
## PDF & Image Import
### For: Google Antigravity IDE (Gemini Agent)

---

## 0. AGENT PERSONA — READ BEFORE ANYTHING ELSE

You are operating with **three simultaneous perspectives** throughout this entire task:

**As a Senior Software Engineer:**
- Every architectural decision must be intentional and documented in a one-line comment.
- Write defensive code. Every service method must handle null, empty, corrupt, and oversized inputs.
- No silent failures. Every `catch` block must either rethrow, log, or surface the error to the UI.
- New code must integrate cleanly with existing patterns — do not introduce a second way of doing something that already has a pattern.

**As a QA Engineer:**
- Before marking any task done, mentally run: happy path → empty state → error state → edge case.
- Every new file gets at least one corresponding test in `test/`.
- After every 5 tasks, run `flutter analyze` and fix ALL issues before continuing. Zero tolerance for new warnings.

**As a UI/UX Professional:**
- Every new screen and widget must use the existing `AppColors` tokens exclusively. No hardcoded hex values.
- Loading states are mandatory — never show a blank screen while async work runs.
- Error states are mandatory — never silently swallow a failed import.
- Haptic feedback on destructive actions (delete imported content).
- Every interactive element must have a minimum touch target of 48×48 dp.

---

## 1. PROJECT CONTEXT — READ IN FULL

### 1.1 Current State
Phases 0–3 are complete. The following architecture is in production and **must not be disturbed**:

- **State:** Riverpod written by hand (no `riverpod_generator` — conflicts with `isar_generator`). `ConsumerWidget` only, never `StatefulWidget` for business state.
- **Isar:** v3.1.0+1. `Notebook` and `NotePage` collections. After ANY schema change: `dart run build_runner build`.
- **Storage:** Strokes as JSON in `.ink` files. Format: `{docsDir}/notes/{notebookId}/page_{index}.ink`. `InkFileStorage` handles this. **Do not change the storage path format for strokes.**
- **Page Cache:** `PageCacheManager` holds exactly 3 pages in memory (`currentIndex - 1`, `currentIndex`, `currentIndex + 1`). Pages outside this window are evicted.
- **Canvas Layer Stack (bottom → top):**
  ```
  Layer 0 — BackgroundLayer         (vector templates, never repaints during drawing)
  Layer 1 — ImportedContentLayer    ← PHASE 4: YOU WILL BUILD THIS
  Layer 2 — StrokeHistoryLayer      (completed strokes, cached as Flutter Picture)
  Layer 3 — ActiveStrokeLayer       (live stroke only, repaints ~8ms)
  Layer 4 — ShapeLayer              (Phase 5, placeholder exists)
  Layer 5 — SelectionLayer          (Phase 5, placeholder exists)
  ```
- **Thumbnails:** `PageThumbnailService` uses `ui.PictureRecorder` + `compute` isolates. It draws strokes only. Phase 4 must update it to also draw imported content.
- **BookView:** `BookViewNotifier` maps `currentSpread` to two `EditablePagePane` instances. Both panes must receive ImportedContent data.

### 1.2 THE GHOSTING BUG — CRITICAL, DO NOT VIOLATE

`canvasStateProvider` and `undoRedoProvider` are `StateNotifierProvider.autoDispose.family<..., int>`.
A race condition previously caused `autoDispose` to erase state right as async saves fired during page switches.

**The established fix:** In the `ref.listen<PageState>` observer, the old state (`oldStrokes`, etc.) is **synchronously captured** before the autoDispose fires, then passed as an override into the async pipeline.

**Your Phase 4 obligation:**
- `importedContentProvider` MUST be `StateNotifierProvider.autoDispose.family<ImportedContentNotifier, ImportedContentState, int>`.
- During page switches, synchronously capture `oldImportedContents` in the same `ref.listen<PageState>` observer that captures `oldStrokes`, before the provider disposes.
- Apply the same override pattern — do NOT invent a new solution.

### 1.3 Design Tokens (mandatory for all new UI)
```dart
// AppColors — use these, never hardcode hex values
AppColors.background    // 0xFF0D1117
AppColors.surface       // 0xFF161B22
AppColors.border        // 0xFF21262D
AppColors.accent        // 0xFF58A6FF  ← primary interactive colour
AppColors.accentGreen   // 0xFF3FB950
AppColors.accentYellow  // 0xFFE3B341
AppColors.accentRed     // 0xFFF85149
AppColors.textPrimary   // 0xFFE6EDF3
AppColors.textSecondary // 0xFF8B949E
AppColors.textMuted     // 0xFF484F58
```

---

## 2. PREREQUISITES CHECK — DO THIS FIRST, DO NOT SKIP

Before writing a single line of new code, verify the following. Report results for each item.

**Step P-1:** Run `flutter analyze`. Output must show zero errors and zero warnings. If there are any, fix them before proceeding.

**Step P-2:** Run `flutter test`. All existing tests must pass. If any fail, fix them before proceeding.

**Step P-3:** Verify `pdfx` and `image_picker` are already in `pubspec.yaml` (they should be from Phase 0 setup). Confirm with: `grep -E "pdfx|image_picker" pubspec.yaml`

**Step P-4:** Attempt to add `file_picker` — it was intentionally removed earlier due to a `share_plus` version conflict. Since `share_plus` has since been upgraded to `^12.0.2`, test compatibility now:
```bash
flutter pub add file_picker
```
- If it resolves cleanly: keep it. Note the resolved version.
- If it still conflicts: do NOT force it. Instead, implement PDF file selection using `image_picker` for images and `open_filex` package for PDFs. Report which path you took.

**Step P-5:** Confirm the storage directory structure exists and is writable by running a quick Dart snippet in a temp test file:
```dart
final dir = await getApplicationDocumentsDirectory();
print('Docs dir: ${dir.path}');
```
Then delete the temp test file.

**Step P-6:** Read and understand these existing files before touching them:
- `lib/features/editor/data/storage/ink_file_storage.dart`
- `lib/features/editor/presentation/canvas/canvas_widget.dart`
- Whatever file contains `PageCacheManager`
- Whatever file contains `PageThumbnailService`
- The `ref.listen<PageState>` observer (the ghosting bug fix location)

Report the exact class names and file paths of these six items before proceeding.

---

## 3. BACKEND IMPLEMENTATION

Build these in exact order. Run `flutter analyze` after every task. Zero new issues permitted.

---

### TASK B-1: Storage Path Constants
**File:** `lib/core/constants/storage_paths.dart`

Add Phase 4 storage path helpers alongside existing ones. Do not change existing paths.

```
Cached PDF renders:  {docsDir}/notes/{notebookId}/imports/pdf_{pdfHash}_{pageIndex}.png
Cached free images:  {docsDir}/notes/{notebookId}/imports/img_{contentId}.png
```

The `pdfHash` is an 8-character hex hash of the source file path (use `path.hashCode.toRadixString(16).padLeft(8, '0')`). This makes cache filenames deterministic and avoids re-rendering the same PDF page twice.

---

### TASK B-2: Domain Model — ImportedContent
**File:** `lib/features/editor/domain/models/imported_content.dart`

```dart
// Represents one piece of imported content on a note page (PDF background or free image).
import 'package:isar/isar.dart';

part 'imported_content.g.dart';

enum ImportedContentType { pdfBackground, freeImage }

@embedded
class ImportedContent {
  // Identity
  late String id;           // UUID (use DateTime.now().microsecondsSinceEpoch.toString())
  @enumerated
  late ImportedContentType type;

  // Cache path (relative to docsDir — never store absolute paths, they change between installs)
  late String relativeImagePath;

  // Source reference (for display only, not required for rendering)
  late String sourceDescription; // e.g. "document.pdf — Page 3"

  // Position and transform (only used when type == freeImage)
  late double x;
  late double y;
  late double width;
  late double height;
  late double rotation; // radians, clockwise
  late double opacity;  // 0.0 to 1.0

  // Ordering
  late int zOrder; // within ImportedContentLayer, higher = drawn on top

  ImportedContent();

  factory ImportedContent.pdfBackground({
    required String id,
    required String relativeImagePath,
    required String sourceDescription,
  }) => ImportedContent()
      ..id = id
      ..type = ImportedContentType.pdfBackground
      ..relativeImagePath = relativeImagePath
      ..sourceDescription = sourceDescription
      ..x = 0 ..y = 0 ..width = 0 ..height = 0
      ..rotation = 0 ..opacity = 1.0 ..zOrder = 0;

  factory ImportedContent.freeImage({
    required String id,
    required String relativeImagePath,
    required String sourceDescription,
    required double x,
    required double y,
    required double width,
    required double height,
  }) => ImportedContent()
      ..id = id
      ..type = ImportedContentType.freeImage
      ..relativeImagePath = relativeImagePath
      ..sourceDescription = sourceDescription
      ..x = x ..y = y ..width = width ..height = height
      ..rotation = 0 ..opacity = 1.0 ..zOrder = 1;
}
```

---

### TASK B-3: Update NotePage Isar Schema
**File:** `lib/features/home/domain/models/note_page.dart` (existing)

Add one field to the existing `NotePage` collection:
```dart
List<ImportedContent> importedContents = [];
```

Do not remove or rename any existing field. Then immediately run:
```bash
dart run build_runner build
```
Confirm the `.g.dart` file regenerates without errors before continuing.

---

### TASK B-4: PDF Cache Manager
**File:** `lib/features/editor/data/storage/pdf_cache_manager.dart`

This is entirely separate from `PageCacheManager`. `PageCacheManager` manages which pages' stroke data is in memory. `PdfCacheManager` manages rendered `ui.Image` objects for PDF page textures.

Requirements:
- LRU eviction bounded at **50 rendered images** (not bytes — image byte accounting is complex, keep it simple).
- Key: `String` of format `{pdfHash}_{pageIndex}`.
- Thread-safe: all mutations go through a single async queue (use a `Completer` queue or `Mutex`-style lock).
- `get(key)` → `ui.Image?`
- `put(key, image)` — evicts LRU entry if at capacity.
- `evictAll()` — clears entire cache (called when a notebook is deleted).
- `dispose()` — releases all `ui.Image` objects (call `.dispose()` on each).

Do not write rendered images to disk inside this class — disk I/O for cached renders is handled by `PDFService`.

---

### TASK B-5: PDF Service
**File:** `lib/features/import/pdf_service.dart`

```
Responsibilities:
1. Accept a file path to a PDF document.
2. Open the document with pdfx, read page count.
3. For a requested page index: check disk cache first, then render at 2× device pixel ratio.
4. Save rendered page as PNG to the deterministic cache path (from B-1).
5. Load the PNG back as ui.Image and store in PdfCacheManager (B-4).
6. Return the ui.Image to the caller.
7. Close the PdfDocument cleanly when done with an import session.
```

Error handling requirements (all must be handled, none silently swallowed):
- File not found → throw `ImportException('PDF not found at path: $path')`
- File is not a valid PDF → throw `ImportException('File is not a valid PDF')`
- Rendering fails for a specific page → return null for that page, do not abort the whole import
- Disk write fails → log the error, return the in-memory image (cache miss on next load is acceptable)
- `PdfDocument` must always be closed in a `finally` block

```dart
// Custom exception for import errors
class ImportException implements Exception {
  final String message;
  const ImportException(this.message);
  @override
  String toString() => 'ImportException: $message';
}
```

---

### TASK B-6: Image Service
**File:** `lib/features/import/image_service.dart`

```
Responsibilities:
1. Pick an image from gallery or camera using image_picker.
2. Process the raw file: compress to max 2048×2048, quality 85, format JPEG.
3. Save processed image to the deterministic free-image cache path (from B-1).
4. Return a ui.Image loaded from the saved file.
```

Error handling requirements:
- User cancels picker → return null gracefully (not an error)
- Image is corrupt → throw `ImportException('Selected image could not be decoded')`
- Image exceeds device capabilities → resize progressively until it fits
- Disk write fails → throw `ImportException('Failed to save image to local storage')`

Processing must happen in a `compute` isolate — never block the UI thread. Match the existing pattern from `PageThumbnailService`.

---

### TASK B-7: Import Repository
**File:** `lib/features/editor/data/repositories/import_repository.dart`

```
Responsibilities:
1. Save a List<ImportedContent> to an existing NotePage in Isar.
2. Load the List<ImportedContent> for a given NotePage.
3. Add a single ImportedContent to a page.
4. Remove an ImportedContent by id from a page.
5. Update an ImportedContent (for position/rotation/opacity changes after placement).
```

All Isar writes use `isar.writeTxn()`. All reads use `isar.txn()`. Use the `IsarService` singleton.

---

## 4. FRONTEND IMPLEMENTATION

Build these in exact order. Run `flutter analyze` after every task. Zero new issues permitted.

---

### TASK F-1: ImportedContent State
**File:** `lib/features/editor/presentation/imported_content_notifier.dart`

```dart
// State class
class ImportedContentState {
  final List<ImportedContent> contents;
  final bool isLoading;
  final String? errorMessage;

  const ImportedContentState({
    this.contents = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ImportedContentState copyWith({...});
}

// Notifier — MUST match the autoDispose.family pattern of canvasStateProvider
class ImportedContentNotifier extends StateNotifier<ImportedContentState> {
  final int pageIndex;
  final ImportRepository _repository;

  ImportedContentNotifier(this.pageIndex, this._repository)
      : super(const ImportedContentState());

  Future<void> loadForPage(int notebookId) async { ... }
  Future<void> addContent(ImportedContent content) async { ... }
  Future<void> removeContent(String contentId) async { ... }
  Future<void> updateTransform({required String id, double? x, double? y,
      double? width, double? height, double? rotation, double? opacity}) async { ... }
}

// Provider — autoDispose.family keyed on pageIndex, matching canvasStateProvider pattern
final importedContentProvider = StateNotifierProvider
    .autoDispose
    .family<ImportedContentNotifier, ImportedContentState, int>(
  (ref, pageIndex) => ImportedContentNotifier(pageIndex, ImportRepository()),
);
```

**Ghosting-safe wiring:** In the same `ref.listen<PageState>` observer where `oldStrokes` is captured, add:
```dart
final oldContents = ref.read(importedContentProvider(oldPageIndex).notifier).state.contents;
```
Capture this synchronously before any `await` or dispose can fire.

---

### TASK F-2: ImportedContent Canvas Layer
**File:** `lib/features/editor/presentation/canvas/layers/imported_content_layer.dart`

```dart
// Layer 1 in the canvas stack. Draws PDF backgrounds and free images on the canvas.
class ImportedContentLayer extends CustomPainter {
  final List<ImportedContent> contents;
  final Map<String, ui.Image> loadedImages; // pre-resolved images, keyed by content.id
  final Size canvasSize;

  const ImportedContentLayer({
    required this.contents,
    required this.loadedImages,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw in zOrder ascending
    final sorted = [...contents]..sort((a, b) => a.zOrder.compareTo(b.zOrder));

    for (final content in sorted) {
      final image = loadedImages[content.id];
      if (image == null) continue; // image not yet loaded — skip, will repaint when ready

      final paint = Paint()..color = Color.fromRGBO(255, 255, 255, content.opacity);

      if (content.type == ImportedContentType.pdfBackground) {
        // Draw full-canvas background, scaled to fit
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(0, 0, size.width, size.height),
          paint,
        );
      } else {
        // Draw free image at specified position/size/rotation
        canvas.save();
        canvas.translate(content.x + content.width / 2, content.y + content.height / 2);
        canvas.rotate(content.rotation);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(-content.width / 2, -content.height / 2, content.width, content.height),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(ImportedContentLayer old) =>
      contents != old.contents || loadedImages != old.loadedImages;
}
```

**Important:** `ImportedContentLayer` receives pre-loaded `ui.Image` objects. It does NOT do async I/O. Image loading is handled upstream by the notifier and passed in as a resolved map.

---

### TASK F-3: Free Image Overlay Widget
**File:** `lib/features/editor/presentation/widgets/free_image_overlay.dart`

This widget renders **above** the canvas stack in the `NoteEditorScreen`'s `Stack`. It is NOT a canvas layer — it is a Flutter widget overlay.

Requirements:
- Displayed only when a `freeImage` type ImportedContent is selected.
- Dashed border in `AppColors.accent` around the selected image bounds.
- Four corner drag handles: 16×16 dp circles filled with `AppColors.accent`. Drag resizes the image (maintain aspect ratio if shift-equivalent is held, free resize otherwise).
- One rotation handle: 24×24 dp circle centered 32dp above the top-center of the image bounds. Drag rotates the image.
- One delete button: `AppColors.accentRed` icon button at top-right. Confirm with `HapticFeedback.mediumImpact()` on tap.
- Opacity slider: horizontal, 200dp wide, centered below the image bounds. Range 0.1 to 1.0.
- Use `GestureDetector` for this overlay (it is above the canvas, not inside it — `Listener` rule applies only to the canvas input pipeline).
- Minimum touch targets: all handles must be at least 48×48 dp with a `GestureDetector` wrapping even if the visual is smaller.

---

### TASK F-4: Import Bottom Sheet
**File:** `lib/features/import/presentation/import_bottom_sheet.dart`

Design requirements (Senior SWE + UI/UX):
- Full-width modal bottom sheet, `AppColors.surface` background, 16dp corner radius top.
- Title: "Import" in `AppColors.textPrimary`, 16sp semibold.
- Two option tiles:
  - "Import PDF" — book icon, `AppColors.accent`, subtitle: "Each page becomes a note page"
  - "Import Image" — image icon, `AppColors.accentGreen`, subtitle: "Place on current page"
- Divider between options: 1dp, `AppColors.border`.
- Cancel button at the bottom: text style, `AppColors.textSecondary`.
- Show with: `showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const ImportBottomSheet())`.

---

### TASK F-5: PDF Import Wizard Screen
**File:** `lib/features/import/presentation/pdf_import_screen.dart`

This is a full-screen modal route (not a bottom sheet — PDF import is a multi-step process).

**Step 1 — File Selection:**
- Central tap target: dashed border box, "Tap to select a PDF" label, `AppColors.accent` dashed border.
- On tap: trigger file picker (result of prerequisite P-4 — use whichever approach resolved cleanly).
- Show selected filename once chosen.

**Step 2 — Rendering Progress (shown after file selection):**
- Linear progress indicator in `AppColors.accent`.
- Label: "Rendering page {current} of {total}..."
- Progress is driven by a `Stream<double>` exposed by `PDFService.renderAll()`.
- Cancel button: aborts rendering, returns to Step 1.

**Step 3 — Confirmation:**
- "Import {pageCount} pages as note pages?" — `AppColors.textPrimary`.
- Subtitle: "This will add {pageCount} new pages to your notebook" — `AppColors.textSecondary`.
- Two buttons: "Cancel" (outlined, `AppColors.border`) and "Import" (filled, `AppColors.accent`).
- On confirm: call the import handler, pop the screen with result.

**Error state:**
- If file is invalid or rendering fails: show an `AppColors.accentRed` error card with the message. Do not pop the screen — let the user try again.

---

### TASK F-6: Update CanvasWidget
**File:** `lib/features/editor/presentation/canvas/canvas_widget.dart` (existing)

Insert `ImportedContentLayer` at Layer 1 — between `BackgroundLayer` (Layer 0) and `StrokeHistoryLayer` (Layer 2).

```dart
// In the Stack children list, insert after BackgroundLayer:
RepaintBoundary(
  child: CustomPaint(
    painter: ImportedContentLayer(
      contents: importedContentState.contents,
      loadedImages: importedContentState.loadedImages,
      canvasSize: constraints.biggest,
    ),
    child: const SizedBox.expand(),
  ),
),
```

`importedContentState` is read via `ref.watch(importedContentProvider(pageIndex))`.
`pageIndex` is already available in CanvasWidget from the existing page family pattern.

Do not reorder any other layer. Do not change `RepaintBoundary` on any existing layer.

---

### TASK F-7: Update Toolbar
**File:** `lib/features/editor/presentation/widgets/tool_bar.dart` (existing)

Add an import icon button to the existing toolbar. Place it at the right edge of the toolbar, separated from the drawing tools by a vertical divider.

- Icon: `Icons.file_upload_outlined`
- Color: `AppColors.textSecondary` (inactive), `AppColors.accent` (active/hover)
- On tap: `showModalBottomSheet` with `ImportBottomSheet`
- Do not change any existing tool buttons, their positions, or their callbacks.

---

### TASK F-8: Update NoteEditorScreen
**File:** `lib/features/editor/presentation/screens/note_editor_screen.dart` (existing)

Add the `FreeImageOverlay` widget to the existing `Stack` in `NoteEditorScreen`:
- Position: above `CanvasWidget`, below `ToolBar`.
- It is only visible (and interactive) when a freeImage content item is selected.
- Read selected content from `importedContentProvider(currentPageIndex)`.
- Do not alter the existing `CanvasWidget`, `PageNavigatorWidget`, or `ToolBar` positions.

---

### TASK F-9: Update PageThumbnailService
**File:** wherever `PageThumbnailService` lives (existing)

Add imported content rendering to the thumbnail generation pipeline:

1. Accept `List<ImportedContent>` and the pre-loaded `Map<String, ui.Image>` as additional parameters.
2. Draw imported content **before** strokes in the `ui.PictureRecorder` canvas (same layer order as the main canvas).
3. For PDF backgrounds: scale-fit to the thumbnail size.
4. For free images: draw at proportionally scaled x/y/width/height.
5. If `loadedImages` map is empty: skip imported content silently (thumbnails with strokes only are better than no thumbnail).

Do not change the `compute` isolate pattern. Do not change how strokes are rendered in thumbnails.

---

### TASK F-10: Update BookViewScreen
**File:** wherever `BookViewScreen` and `EditablePagePane` live (existing)

Each `EditablePagePane` must receive its page's `List<ImportedContent>` and pre-loaded images, and pass them to the `CanvasWidget` it hosts.

Both panes must independently watch `importedContentProvider(pageIndex)` for their respective page indices. The `BookViewNotifier`'s `currentSpread` drives the two page indices — pass each pane its own correct index.

Do not change `BookViewNotifier` logic, `currentSpread` math, or swipe gesture handling.

---

## 5. INTEGRATION TASKS

### TASK I-1: Image Loading Pipeline
The `ImportedContentNotifier` holds `ImportedContentState` which must include both:
- `List<ImportedContent> contents` — the metadata (from Isar)
- `Map<String, ui.Image> loadedImages` — the resolved images (loaded from disk/cache)

When `loadForPage()` is called:
1. Load `ImportedContent` records from `ImportRepository`.
2. For each record, check `PdfCacheManager.get(key)`.
3. If cache miss: load from disk path (`relativeImagePath`), decode to `ui.Image`, store in cache.
4. Build the `loadedImages` map.
5. Update state with both `contents` and `loadedImages`.

Loading must be non-blocking: set `isLoading = true` first, then load, then update state.

### TASK I-2: PDF Import End-to-End Flow
When the user completes the PDF import wizard:
1. `PDFService.renderAll(filePath)` → renders all pages, saves PNGs to cache paths, returns `List<ImportedContent>` (one per page, type `pdfBackground`).
2. For each rendered page: create a new `NotePage` via `PageRepository` (reuses existing page creation logic).
3. Save the `ImportedContent` record to that page via `ImportRepository`.
4. Navigate the user to the first newly created page.
5. Trigger `importedContentProvider(newPageIndex).notifier.loadForPage(notebookId)` for each new page.

### TASK I-3: Image Import End-to-End Flow
When the user selects "Import Image":
1. `ImageService.pickFromGallery()` or `pickFromCamera()` → returns a processed `ui.Image` + saves to disk.
2. Create an `ImportedContent` record (type `freeImage`) with initial position centered on canvas.
3. Add to `importedContentProvider(currentPageIndex).notifier.addContent(content)`.
4. Save to `ImportRepository`.
5. Immediately show `FreeImageOverlay` for the newly placed image.

### TASK I-4: Ghosting-Safe Page Switch Wiring
In the existing `ref.listen<PageState>` observer (the ghosting bug fix location):

```dart
ref.listen<PageState>(pageProvider, (oldPageState, newPageState) {
  if (oldPageState?.currentIndex != newPageState.currentIndex) {
    final oldPageIndex = oldPageState!.currentIndex;

    // EXISTING: capture strokes synchronously
    final oldStrokes = ref.read(canvasStateProvider(oldPageIndex)).strokes;

    // PHASE 4 ADDITION: capture imported contents synchronously
    final oldContents = ref.read(importedContentProvider(oldPageIndex)).contents;

    // EXISTING: force save strokes (async, uses captured oldStrokes)
    _forceSaveStrokes(oldPageIndex, oldStrokes);

    // PHASE 4 ADDITION: force save imported contents (async, uses captured oldContents)
    _forceSaveImportedContents(oldPageIndex, oldContents);
  }
});
```

`_forceSaveImportedContents` is a new private method that saves to `ImportRepository`. It follows the exact same pattern as `_forceSaveStrokes`.

---

## 6. QA VALIDATION CHECKLIST

Do not mark Phase 4 complete until every item below is verified. Test each on the emulator.

### Core Functionality
- [ ] Import a 1-page PDF → appears as background on a new page → can draw strokes on top
- [ ] Import a 10-page PDF → creates 10 new pages → each has its correct PDF background
- [ ] Import a 50-page PDF → loading progress shows correctly → all pages render → no OOM crash
- [ ] Import an image from gallery → appears as free image on current page → drag, resize, rotate, opacity work
- [ ] Import an image from camera → same as above
- [ ] Imported content persists after full app restart
- [ ] Undo after placing free image removes the image
- [ ] Delete a free image via overlay delete button → `HapticFeedback.mediumImpact` fires
- [ ] Delete a page that has imported content → cache files for that page are deleted from disk

### Integration Points
- [ ] BookView: both pages show their correct imported content independently
- [ ] Page thumbnails show imported content (PDF background visible in thumbnail strip)
- [ ] Switching pages during an active import does not crash or lose data (ghosting-safe)
- [ ] PageCacheManager: importing on page 5 does not load imported images for page 1 into memory
- [ ] PdfCacheManager: same PDF imported twice does not re-render (cache hit on second import)
- [ ] `flutter analyze` → 0 errors, 0 warnings, 0 hints

### Edge Cases
- [ ] User picks a file that is not a PDF → `ImportException` is thrown and shown in UI as error card, app does not crash
- [ ] User picks a corrupt image → same error handling as above
- [ ] User cancels file picker → nothing happens, no error, no navigation change
- [ ] Very large image (>15MB) → compressed to ≤2048×2048 before rendering
- [ ] PDF with no pages → error shown: "This PDF appears to be empty"
- [ ] App goes to background mid-import → import resumes or recovers gracefully on foreground

---

## 7. CLEANUP PROTOCOL

Run this protocol **after all QA checks pass**, before reporting Phase 4 complete.

### Step C-1: Dead Code Scan
Run the following and fix everything it reports:
```bash
flutter analyze --no-pub
```
Remove every unused import, unused variable, and unused parameter flagged in any new file.

### Step C-2: Debug Artefact Removal
Search for and delete all of the following across every file touched in Phase 4:
```bash
grep -rn "print(" lib/features/import/ lib/features/editor/
grep -rn "debugPrint(" lib/features/import/ lib/features/editor/
grep -rn "TODO" lib/features/import/ lib/features/editor/
grep -rn "FIXME" lib/features/import/ lib/features/editor/
grep -rn "HACK" lib/features/import/ lib/features/editor/
```
Remove every match. If a `TODO` represents genuinely deferred work (Phase 5+), convert it to a comment: `// Phase 5: <description>`.

### Step C-3: Orphan File Sweep
Check for any `.dart` files created during development that are no longer imported anywhere:
```bash
# For each new file, verify it is imported by at least one other file
# If a file has no importers and is not a main entry point, delete it
```

### Step C-4: Build Artifact Cleanup
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --debug
```
The debug APK must build cleanly with zero warnings. If it does not, fix before proceeding.

### Step C-5: Test File Verification
Confirm every new service has a corresponding test file:
- `test/features/import/pdf_service_test.dart`
- `test/features/import/image_service_test.dart`
- `test/features/editor/data/storage/pdf_cache_manager_test.dart`
- `test/features/editor/data/repositories/import_repository_test.dart`

Each test file must contain at minimum: one happy-path test, one null/empty-input test, and one error-handling test.

Run:
```bash
flutter test
```
All tests must pass.

---

## 8. FINAL AUDIT — FLUTTER INSPECTOR & DEVTOOLS

After cleanup, perform a live widget tree and performance audit. This is the Flutter equivalent of a DOM audit.

### Step A-1: Launch with DevTools
```bash
flutter run --debug
```
Then open Flutter DevTools: `flutter pub global run devtools` or use the link printed in terminal.

### Step A-2: Widget Tree Inspection (Flutter Inspector)
In the Flutter Inspector tab, expand the widget tree at the `NoteEditorScreen` level and verify:
- [ ] Canvas `Stack` has exactly 6 `RepaintBoundary` children in the correct order (0–5).
- [ ] `ImportedContentLayer` is at index 1 (after `BackgroundLayer`, before `StrokeHistoryLayer`).
- [ ] `FreeImageOverlay` is a sibling of the canvas `Stack`, not nested inside a canvas layer.
- [ ] No orphaned `ImportedContentNotifier` providers remain after navigating away from a note (use the Provider tab in DevTools if available).
- [ ] No extra `RepaintBoundary` wrappers were accidentally added to existing layers.

### Step A-3: Performance Overlay
Enable the performance overlay:
```dart
MaterialApp.router(
  showPerformanceOverlay: true, // toggle on temporarily
  ...
)
```
- [ ] Draw strokes on a page with an imported PDF background. The GPU thread must stay below 16ms.
- [ ] Scroll through the page navigator while pages have imported content thumbnails. No janky frames.
- [ ] Switch between 5 pages rapidly. No dropped frames caused by image loading.

### Step A-4: Memory Check
In DevTools → Memory tab:
- [ ] Import a 20-page PDF. Note memory usage.
- [ ] Navigate to page 1, scroll through all 20 pages, navigate back to page 1. Memory must not grow unboundedly. `PdfCacheManager` eviction is working if memory stabilises.
- [ ] Close the notebook and reopen it. Memory returns to baseline.

### Step A-5: End-to-End Flow Verification
Run this exact sequence manually on the emulator:
1. Open InkFlow → create a new notebook called "Phase 4 Test".
2. Import a multi-page PDF (use any PDF on the emulator).
3. Write 3 strokes on page 1 (PDF background visible under strokes).
4. Navigate to page 3. Import a free image from the gallery.
5. Resize, rotate, and set opacity to 60%.
6. Switch to BookView. Verify both pages show correct content.
7. Long-press page 2 thumbnail → Delete.
8. Verify page indices are still continuous (no gap).
9. Force-close the app (swipe away from recents).
10. Reopen InkFlow → open "Phase 4 Test".
11. **Verify:** PDF backgrounds are on the correct pages, free image on page 3 (now page 2) has correct position/rotation/opacity, strokes are intact.

If every step passes: **Phase 4 is complete.**

### Step A-6: Remove Debug Flags
Before committing:
```dart
// Remove this if you added it in A-3:
showPerformanceOverlay: false, // or remove the line entirely
```

---

## 9. COMPLETION REPORT

When Phase 4 is fully complete, provide a structured summary:

```
PHASE 4 COMPLETE
================
New files created: [list all new .dart files]
Existing files modified: [list all modified .dart files]
Packages added: [list any new packages and their resolved versions]
Build runner run: YES / NO (and why if NO)
flutter analyze: 0 errors, 0 warnings
flutter test: X tests passed, 0 failed
QA checklist: all XX items verified
Cleanup protocol: all 5 steps complete
DevTools audit: all 6 steps complete

Known limitations / deferred to Phase 5:
- [anything intentionally left for later]

Ready for Phase 5: YES
```
