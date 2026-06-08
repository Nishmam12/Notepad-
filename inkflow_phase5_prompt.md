# InkFlow — Phase 5 Master Implementation Prompt
## Shapes & Selection (Lasso, Vector Shapes, Text Boxes, SVG Import)
### For: Google Antigravity IDE (Gemini Agent)

---

## 0. AGENT PERSONA — READ AND MAINTAIN THROUGHOUT

You operate with three simultaneous perspectives at all times.

**As a Senior Software Engineer:**
- Phase 5 introduces algorithmic complexity (geometric classification, hit testing, lasso path math) that must run in `compute` isolates — never on the UI thread.
- Every new architectural pattern must mirror the existing ones: `autoDispose.family`, `if (!mounted) return`, synchronous ghosting-safe capture in `ref.listen`. Invent nothing new.
- Shape rendering uses the Flutter Canvas API directly. Every shape type maps to one or two `canvas.draw*()` calls. No third-party drawing libraries.
- Defensive code on all geometry: strokes with fewer than 3 points cannot be classified. Division by zero in regression math must be caught. Null bounds must be handled.

**As a QA Engineer:**
- Run `flutter analyze` every five tasks. Zero new warnings tolerated.
- Every shape type must be tested: happy path (clean draw), ambiguous input (messy draw, falls back to polyline), and minimum input (too few points, recognition skipped).
- Lasso hit testing must be tested with: nothing selected, one element selected, mixed strokes and shapes selected, and a lasso that encloses zero elements.
- Every new `autoDispose.family` provider must be tested for the unmounted race condition.

**As a UI/UX Professional:**
- All new UI uses `AppColors` tokens exclusively. Zero hardcoded hex values.
- Shape drawing must give real-time visual feedback: preview the recognised shape during the draw gesture before the user lifts the pen.
- The `SelectionOverlay` must feel identical to the existing `FreeImageOverlay` in interaction quality — consistent handle sizes, identical delete confirmation pattern, same haptic feedback.
- Shape toolbar appears as a contextual secondary panel, not a modal. It slides in beneath the primary toolbar with an animation consistent with existing toolbar transitions.
- Minimum touch target on all handles: 48×48 dp.

---

## 1. FULL PROJECT CONTEXT — READ BEFORE WRITING A SINGLE LINE

### 1.1 Completed Phases
Phases 0–4 are complete and must not be disturbed.

| Phase | Content |
|---|---|
| 0 | Environment, architecture, Isar init |
| 1 | Canvas engine, Listener input, perfect_freehand strokes, Toolbar |
| 2 | Erasers, colours, export |
| 3 | Multi-page, LRU PageCacheManager, BookView spreads, PageThumbnailService |
| 4 | PDF rasterisation, image import, ImportedContentLayer, PdfCacheManager, FreeImageOverlay |

### 1.2 Canvas Layer Stack — Current + Phase 5 Additions
```
Layer 0 — BackgroundLayer          DONE (Phase 1) — vector templates, never repaints during drawing
Layer 1 — ImportedContentLayer     DONE (Phase 4) — PDF backgrounds, free images
Layer 2 — StrokeHistoryLayer       DONE (Phase 1) — completed strokes as Flutter Picture
Layer 3 — ActiveStrokeLayer        DONE (Phase 1) — live stroke only, hot path
Layer 4 — ShapeLayer               ← PHASE 5: BUILD THIS
Layer 5 — SelectionLayer           ← PHASE 5: BUILD THIS
```

### 1.3 Established Patterns — Follow Exactly, No Exceptions

**Provider pattern (autoDispose.family):**
```dart
final shapeProvider = StateNotifierProvider
    .autoDispose
    .family<ShapeNotifier, ShapeState, int>(
  (ref, pageIndex) => ShapeNotifier(pageIndex, ref.read(shapeRepositoryProvider)),
);
```

**Unmounted guard (every async method in every Notifier):**
```dart
Future<void> loadShapes(int notebookId) async {
  final shapes = await _repository.getShapesForPage(notebookId, pageIndex);
  if (!mounted) return; // MANDATORY — provider may have been disposed during await
  state = state.copyWith(shapes: shapes, isLoading: false);
}
```

**Ghosting-safe page switch capture (in the existing ref.listen<PageState> observer):**
```dart
// The existing observer already captures oldStrokes and oldImportedContents.
// ADD these two lines synchronously alongside them:
final oldShapes = ref.read(shapeProvider(oldPageIndex)).shapes;
// Then pass oldShapes to _forceSaveShapes(oldPageIndex, oldShapes)
```
Do not restructure the observer. Add only what is shown above.

### 1.4 Android Build System — DO NOT TOUCH
The `android/build.gradle.kts` contains a `subprojects` reflection hook that forces `compileSdk 36` across all plugins. Do not modify this file. If a new package fails to build, check its Android namespace/compileSdk requirement and report it — do not attempt your own Gradle fixes.

### 1.5 file_picker Version Lock
`file_picker` is pinned at `8.3.7`. Do not upgrade it. If SVG import via file_picker fails, report the error — do not change the version.

### 1.6 Design Tokens
```dart
AppColors.background    // 0xFF0D1117
AppColors.surface       // 0xFF161B22
AppColors.border        // 0xFF21262D
AppColors.accent        // 0xFF58A6FF   ← primary interactive colour
AppColors.accentGreen   // 0xFF3FB950
AppColors.accentYellow  // 0xFFE3B341
AppColors.accentRed     // 0xFFF85149
AppColors.textPrimary   // 0xFFE6EDF3
AppColors.textSecondary // 0xFF8B949E
AppColors.textMuted     // 0xFF484F58
```

---

## 2. PREREQUISITES CHECK — DO THIS FIRST

Verify every item and report results before writing any Phase 5 code.

**P-1:** Run `flutter analyze`. Zero errors, zero warnings required. Fix anything found first.

**P-2:** Run `flutter test`. All existing tests must pass. Fix failures before continuing.

**P-3:** Confirm `flutter_svg` is in `pubspec.yaml`:
```bash
grep "flutter_svg" pubspec.yaml
```
If absent, add it: `flutter pub add flutter_svg` — then verify it does not conflict with existing packages.

**P-4:** Locate and report the exact file path of each of the following — you will modify these files later and must know them now:
- The `NotePage` Isar collection (contains the shapes list addition target)
- The `CanvasWidget` (Layer stack lives here)
- The `RawPointerListener` or equivalent input capture widget
- The `ref.listen<PageState>` observer (ghosting-safe capture lives here)
- The `ToolBar` widget file
- The `NoteEditorScreen` file
- The `PageThumbnailService` file
- The `UndoRedoStack` and its `Command` abstract class

**P-5:** Read the existing `FreeImageOverlay` implementation completely. The `SelectionOverlay` you build in Phase 5 must match its interaction patterns, handle sizes, and animation approach.

**P-6:** Confirm your understanding of the canvas layer insertion rule: **each layer is wrapped in exactly one `RepaintBoundary`.** You must not add a second `RepaintBoundary` to an existing layer and must not omit it from a new one.

---

## 3. BACKEND IMPLEMENTATION

Build in exact order. `flutter analyze` after every task. Zero new issues.

---

### TASK B-1: ShapeType Enum
**File:** `lib/features/editor/domain/models/shape_type.dart`

```dart
// Enumerates all supported shape types in InkFlow.
enum ShapeType {
  line,
  arrow,
  circle,
  rectangle,
  triangle,
  polygon,    // generalised N-sided polygon from freehand
  textBox,    // keyboard-input text placed on canvas
  svgImage,   // imported SVG vector graphic
}
```

---

### TASK B-2: ShapeElement Domain Model
**File:** `lib/features/editor/domain/models/shape_element.dart`

```dart
// Represents one vector shape, text box, or SVG element on a note page.
import 'package:isar/isar.dart';
import 'shape_type.dart';
part 'shape_element.g.dart';

@embedded
class ShapeElement {
  // Identity
  late String id;
  @enumerated
  late ShapeType type;

  // Stroke appearance
  late int color;         // ARGB int (e.g. 0xFF58A6FF)
  late double strokeWidth;
  late bool hasFill;
  late int fillColor;     // ARGB int, used when hasFill == true
  late double opacity;    // 0.0 to 1.0

  // Geometry — interpreted based on type
  // For line/arrow: [startX, startY, endX, endY]
  // For circle: [centerX, centerY, radiusX, radiusY]
  // For rectangle: [left, top, right, bottom]
  // For triangle/polygon: [x0,y0, x1,y1, x2,y2, ...] flat list of vertices
  // For textBox: [left, top, right, bottom] (bounding box)
  // For svgImage: [left, top, right, bottom]
  late List<double> geometryData;

  // Transform
  late double rotation; // radians, clockwise around shape centre

  // Text fields (type == textBox only)
  late String text;
  late double fontSize;
  late String fontFamily; // e.g. 'Roboto'
  late bool isBold;
  late bool isItalic;

  // SVG fields (type == svgImage only)
  late String svgRelativePath; // relative path to cached .svg file

  // Ordering
  late int zOrder;

  ShapeElement();

  // Named constructors for common types
  factory ShapeElement.line({required String id, required Offset start,
      required Offset end, required int color, required double strokeWidth}) {
    return ShapeElement()
      ..id = id ..type = ShapeType.line ..color = color
      ..strokeWidth = strokeWidth ..hasFill = false ..fillColor = 0
      ..opacity = 1.0 ..rotation = 0 ..text = '' ..fontSize = 16
      ..fontFamily = 'Roboto' ..isBold = false ..isItalic = false
      ..svgRelativePath = '' ..zOrder = 0
      ..geometryData = [start.dx, start.dy, end.dx, end.dy];
  }

  // Add equivalent factory constructors for: arrow, circle, rectangle,
  // triangle, polygon, textBox, svgImage.
  // Each follows the same pattern — only geometryData layout differs.
}
```

---

### TASK B-3: Update NotePage Isar Schema
**File:** `lib/features/home/domain/models/note_page.dart` (existing)

Add one field. Do not change, remove, or reorder any existing field:
```dart
List<ShapeElement> shapes = [];
```

Then immediately run:
```bash
dart run build_runner build --delete-conflicting-outputs
```
Confirm all `.g.dart` files regenerate without errors before continuing.

---

### TASK B-4: Shape Geometry Service
**File:** `lib/features/editor/domain/services/shape_geometry.dart`

Pure static utility class. No state, no dependencies. All methods are synchronous.

Required methods:
```dart
// Returns the axis-aligned bounding Rect of a list of points.
static Rect boundingRect(List<Offset> points)

// Returns the centroid (geometric centre) of a list of points.
static Offset centroid(List<Offset> points)

// Ramer-Douglas-Peucker simplification.
// epsilon: minimum distance threshold (use 8.0 as default).
// Returns a simplified list of Offset points.
static List<Offset> rdpSimplify(List<Offset> points, double epsilon)

// Returns true if the start and end of a point list are within closeThreshold dp of each other.
static bool isClosed(List<Offset> points, double closeThreshold)

// Linear regression R² coefficient for a list of points.
// R² close to 1.0 means the points approximate a straight line.
static double linearR2(List<Offset> points)

// Angle in radians between three points (vertex is the middle point).
static double angleBetween(Offset a, Offset vertex, Offset b)

// Returns the Rect from geometry data interpreted as [left, top, right, bottom].
static Rect rectFromGeometry(List<double> data)

// Returns the start and end Offset for a line/arrow from geometry data [x0,y0,x1,y1].
static (Offset, Offset) lineFromGeometry(List<double> data)

// Returns a list of Offset vertices from flat geometry data [x0,y0,x1,y1,...].
static List<Offset> verticesFromGeometry(List<double> data)
```

Write unit tests in `test/features/editor/domain/services/shape_geometry_test.dart`.

---

### TASK B-5: Shape Recogniser Service
**File:** `lib/features/editor/domain/services/shape_recognizer.dart`

This is the most algorithmically complex service in Phase 5. It must run inside a `compute` isolate — it must be a top-level function, not a class method, because `compute` cannot capture closures over non-serialisable objects.

```dart
// Top-level function — safe to pass to compute()
// Input: raw stroke points as List<Offset>
// Output: RecognitionResult (type + geometryData), or null if unrecognisable
RecognitionResult? recogniseShape(List<Offset> rawPoints)
```

**Recognition decision tree (implement in this order):**

```
1. If rawPoints.length < 6: return null (too few points to classify)

2. Simplify with RDP (epsilon = 8.0) → simplifiedPoints

3. LINE CHECK:
   - linearR2(rawPoints) > 0.93
   → ShapeType.line, geometryData = [first.dx, first.dy, last.dx, last.dy]

4. ARROW CHECK (only if LINE CHECK passes):
   - Line endpoint check: compute vectors from second-to-last to last and
     from second-to-last to third-to-last. If the angle is < 45° (acute V shape),
     it is an arrow. Add arrowhead data to geometryData.

5. CIRCLE CHECK:
   - isClosed(simplifiedPoints, 30.0) == true
   - AND simplifiedPoints.length >= 8 (need enough points to form a loop)
   - Compute centroid. Compute average distance from centroid.
   - Compute variance of distances. If variance / avgRadius < 0.15 → circle
   - geometryData = [cx - r, cy - r, cx + r, cy + r] (bounding rect of circle)

6. RECTANGLE CHECK:
   - isClosed(simplifiedPoints, 30.0) == true
   - rdpSimplify(simplifiedPoints, 15.0).length == 4 (exactly 4 corners)
   - All four angles via angleBetween() are within 20° of 90°
   → geometryData = [minX, minY, maxX, maxY] of the four vertices

7. TRIANGLE CHECK:
   - isClosed(simplifiedPoints, 30.0) == true
   - rdpSimplify(simplifiedPoints, 15.0).length == 3 (exactly 3 corners)
   → geometryData = [v0.dx, v0.dy, v1.dx, v1.dy, v2.dx, v2.dy]

8. POLYGON CHECK (fallback for closed shapes):
   - isClosed(simplifiedPoints, 30.0) == true
   - rdpSimplify(simplifiedPoints, 12.0).length between 5 and 12
   → geometryData = flat list of all simplified vertex coordinates

9. If none matched: return null (caller keeps it as a regular stroke)
```

**RecognitionResult:**
```dart
class RecognitionResult {
  final ShapeType type;
  final List<double> geometryData;
  const RecognitionResult(this.type, this.geometryData);
}
```

Write tests in `test/features/editor/domain/services/shape_recognizer_test.dart`.
Test data: synthesise approximate circle points, line points, rectangle points, and random noise.

---

### TASK B-6: Lasso Hit Tester
**File:** `lib/features/editor/domain/services/lasso_hit_tester.dart`

Top-level function (safe for `compute`):
```dart
// Returns the IDs of strokes and shapes whose centroid or any point
// falls inside the lasso path.
LassoHitResult testLasso({
  required List<Offset> lassoPath,
  required List<Stroke> strokes,         // existing Stroke model from Phase 1
  required List<ShapeElement> shapes,
})
```

**Hit testing logic:**
```dart
// Build a Flutter Path from the lasso points:
final path = Path()..addPolygon(lassoPath, true);

// For each Stroke: a stroke is selected if ANY of its points is inside the path.
// Use path.contains(Offset) — this uses ray-casting (already handles concave lassos).

// For each ShapeElement: a shape is selected if its centroid is inside the path.
// Centroid = ShapeGeometry.centroid(ShapeGeometry.verticesFromGeometry(shape.geometryData))

// TextBox: treat as rectangle, centre point must be inside lasso.
// SvgImage: treat as rectangle, centre point must be inside lasso.
```

```dart
class LassoHitResult {
  final Set<String> selectedStrokeIds;
  final Set<String> selectedShapeIds;
  const LassoHitResult(this.selectedStrokeIds, this.selectedShapeIds);
  bool get isEmpty => selectedStrokeIds.isEmpty && selectedShapeIds.isEmpty;
}
```

Write tests in `test/features/editor/domain/services/lasso_hit_tester_test.dart`.

---

### TASK B-7: Shape Repository
**File:** `lib/features/editor/data/repositories/shape_repository.dart`

Follows the same pattern as `ImportRepository` (Isar embedded objects via `NotePage`).

```dart
// Load all shapes for a page
Future<List<ShapeElement>> getShapesForPage(int notebookId, int pageIndex)

// Persist full shapes list for a page (replaces entire embedded list)
Future<void> saveShapesForPage(int notebookId, int pageIndex, List<ShapeElement> shapes)

// Add a single shape to a page
Future<void> addShape(int notebookId, int pageIndex, ShapeElement shape)

// Remove a shape by id
Future<void> removeShape(int notebookId, int pageIndex, String shapeId)

// Update a single shape's transform or appearance
Future<void> updateShape(int notebookId, int pageIndex, ShapeElement updated)
```

All writes: `isar.writeTxn()`. All reads: `isar.txn()`. Use the `IsarService` singleton. No direct Isar access outside this repository.

---

### TASK B-8: Undo/Redo Commands for Shapes
**Files:**
- `lib/features/editor/domain/undo_redo/shape_add_command.dart`
- `lib/features/editor/domain/undo_redo/shape_delete_command.dart`
- `lib/features/editor/domain/undo_redo/shape_transform_command.dart`
- `lib/features/editor/domain/undo_redo/lasso_move_command.dart`
- `lib/features/editor/domain/undo_redo/lasso_delete_command.dart`

Each implements the existing `Command` abstract class with `execute()` and `undo()`.

```dart
// ShapeAddCommand: execute = add shape, undo = remove shape
// ShapeDeleteCommand: execute = remove shape, undo = restore shape
// ShapeTransformCommand: stores before/after ShapeElement, execute = apply after, undo = apply before
// LassoMoveCommand: stores Map<String, Offset> (id → delta), applies/reverses to all selected
// LassoDeleteCommand: stores List<Stroke> + List<ShapeElement> deleted; undo restores all
```

Register these in the `UndoRedoStack` — check how `StrokeAddCommand` is registered there and follow the same pattern.

---

## 4. FRONTEND IMPLEMENTATION

Build in exact order. `flutter analyze` after every task. Zero new issues.

---

### TASK F-1: Shape State & Notifier
**File:** `lib/features/editor/presentation/shape_notifier.dart`

```dart
class ShapeState {
  final List<ShapeElement> shapes;
  final bool isLoading;
  final String? errorMessage;

  const ShapeState({
    this.shapes = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ShapeState copyWith({List<ShapeElement>? shapes, bool? isLoading, String? errorMessage}) => ...;
}

class ShapeNotifier extends StateNotifier<ShapeState> {
  final int pageIndex;
  final ShapeRepository _repository;

  ShapeNotifier(this.pageIndex, this._repository) : super(const ShapeState());

  Future<void> loadForPage(int notebookId) async {
    state = state.copyWith(isLoading: true);
    final shapes = await _repository.getShapesForPage(notebookId, pageIndex);
    if (!mounted) return; // unmounted guard — MANDATORY
    state = state.copyWith(shapes: shapes, isLoading: false);
  }

  Future<void> addShape(ShapeElement shape) async { ... if (!mounted) return; ... }
  Future<void> removeShape(String id) async { ... if (!mounted) return; ... }
  Future<void> updateShape(ShapeElement updated) async { ... if (!mounted) return; ... }
  void clearShapes() { if (!mounted) return; state = state.copyWith(shapes: []); }
}

// Provider — autoDispose.family keyed on pageIndex
final shapeProvider = StateNotifierProvider
    .autoDispose
    .family<ShapeNotifier, ShapeState, int>(
  (ref, pageIndex) => ShapeNotifier(pageIndex, ShapeRepository()),
);
```

---

### TASK F-2: Selection State & Notifier
**File:** `lib/features/editor/presentation/selection_notifier.dart`

Selection is transient — it does not persist across page switches. Use `autoDispose` without family.

```dart
class SelectionState {
  final Set<String> selectedStrokeIds;
  final Set<String> selectedShapeIds;
  final Rect? selectionBounds;      // combined bounding box of all selected elements
  final bool isTransforming;        // true while drag/resize/rotate is in progress

  const SelectionState({
    this.selectedStrokeIds = const {},
    this.selectedShapeIds = const {},
    this.selectionBounds,
    this.isTransforming = false,
  });

  bool get hasSelection => selectedStrokeIds.isNotEmpty || selectedShapeIds.isNotEmpty;
  SelectionState copyWith({...});
}

class SelectionNotifier extends StateNotifier<SelectionState> {
  SelectionNotifier() : super(const SelectionState());

  void setSelection(LassoHitResult result, Rect bounds) { ... }
  void clearSelection() { ... }
  void moveSelection(Offset delta) { ... }     // updates bounds, notifies shape/canvas providers
  void scaleSelection(double scaleFactor) { ... }
  void rotateSelection(double deltaRadians) { ... }
  void deleteSelection() { ... }
  void beginTransform() { state = state.copyWith(isTransforming: true); }
  void endTransform() { state = state.copyWith(isTransforming: false); }
}

final selectionProvider = StateNotifierProvider
    .autoDispose<SelectionNotifier, SelectionState>(
  (ref) => SelectionNotifier(),
);
```

---

### TASK F-3: ShapeLayer — Layer 4
**File:** `lib/features/editor/presentation/canvas/layers/shape_layer.dart`

```dart
// Layer 4: draws all committed ShapeElements above strokes, below selection UI.
class ShapeLayer extends CustomPainter {
  final List<ShapeElement> shapes;

  const ShapeLayer({required this.shapes});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw in zOrder ascending
    final sorted = [...shapes]..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    for (final shape in sorted) {
      _drawShape(canvas, shape);
    }
  }

  void _drawShape(Canvas canvas, ShapeElement shape) {
    canvas.save();
    // Apply rotation around shape centre
    final centre = _shapeCentre(shape);
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(shape.rotation);
    canvas.translate(-centre.dx, -centre.dy);

    final strokePaint = Paint()
      ..color = Color(shape.color).withOpacity(shape.opacity)
      ..strokeWidth = shape.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Color(shape.fillColor).withOpacity(shape.hasFill ? shape.opacity : 0)
      ..style = PaintingStyle.fill;

    switch (shape.type) {
      case ShapeType.line:
        final (start, end) = ShapeGeometry.lineFromGeometry(shape.geometryData);
        canvas.drawLine(start, end, strokePaint);

      case ShapeType.arrow:
        // Draw line + arrowhead polygon at endpoint
        // geometryData: [startX, startY, endX, endY, arrowTip1X, arrowTip1Y, arrowTip2X, arrowTip2Y]
        final start = Offset(shape.geometryData[0], shape.geometryData[1]);
        final end = Offset(shape.geometryData[2], shape.geometryData[3]);
        canvas.drawLine(start, end, strokePaint);
        final arrowPath = Path()
          ..moveTo(shape.geometryData[4], shape.geometryData[5])
          ..lineTo(end.dx, end.dy)
          ..lineTo(shape.geometryData[6], shape.geometryData[7])
          ..close();
        canvas.drawPath(arrowPath, strokePaint..style = PaintingStyle.fill);

      case ShapeType.circle:
        final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
        if (shape.hasFill) canvas.drawOval(rect, fillPaint);
        canvas.drawOval(rect, strokePaint);

      case ShapeType.rectangle:
        final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
        if (shape.hasFill) canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, strokePaint);

      case ShapeType.triangle:
      case ShapeType.polygon:
        final vertices = ShapeGeometry.verticesFromGeometry(shape.geometryData);
        final path = Path()..addPolygon(vertices, true);
        if (shape.hasFill) canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);

      case ShapeType.textBox:
        // Text rendering via drawParagraph — see text rendering section below
        _drawTextBox(canvas, shape);

      case ShapeType.svgImage:
        // SVG rendering is handled by a separate SvgRenderLayer overlay widget, not here.
        // Draw a dashed placeholder rect while the SVG is loaded asynchronously.
        _drawSvgPlaceholder(canvas, shape, strokePaint);
    }

    canvas.restore();
  }

  // Text box rendering using Flutter's paragraph builder
  void _drawTextBox(Canvas canvas, ShapeElement shape) {
    final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: shape.fontSize,
        fontFamily: shape.fontFamily,
        fontWeight: shape.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: shape.isItalic ? FontStyle.italic : FontStyle.normal,
      ),
    )..pushStyle(ui.TextStyle(color: Color(shape.color).withOpacity(shape.opacity)))
     ..addText(shape.text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: rect.width));
    canvas.drawParagraph(paragraph, rect.topLeft);
  }

  Offset _shapeCentre(ShapeElement shape) {
    final verts = ShapeGeometry.verticesFromGeometry(shape.geometryData);
    return ShapeGeometry.centroid(verts.isEmpty
        ? [Offset(shape.geometryData[0], shape.geometryData[1])]
        : verts);
  }

  void _drawSvgPlaceholder(Canvas canvas, ShapeElement shape, Paint paint) {
    final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
    // Draw a simple dashed rectangle as placeholder
    canvas.drawRect(rect, paint..color = paint.color.withOpacity(0.4));
  }

  @override
  bool shouldRepaint(ShapeLayer old) => shapes != old.shapes;
}
```

**Note on SVG rendering:** SVG elements use `flutter_svg`'s `SvgPicture.file()` widget rendered as an `Positioned` overlay on top of the canvas `Stack`. They are NOT drawn inside `ShapeLayer` because SVG requires a widget context. The `ShapeLayer` draws a placeholder rect; the SVG overlay widget covers it.

---

### TASK F-4: SelectionLayer — Layer 5
**File:** `lib/features/editor/presentation/canvas/layers/selection_layer.dart`

```dart
// Layer 5: draws the selection bounding box and lasso preview path.
// Handles are drawn in SelectionOverlay (a widget above the Stack), not here.
class SelectionLayer extends CustomPainter {
  final SelectionState selectionState;
  final List<Offset>? lassoPreviewPath; // null when lasso tool is not active

  const SelectionLayer({required this.selectionState, this.lassoPreviewPath});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw lasso preview (animated dashed line while user is drawing)
    if (lassoPreviewPath != null && lassoPreviewPath!.length > 1) {
      final lassoPaint = Paint()
        ..color = AppColors.accent.withOpacity(0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()..addPolygon(lassoPreviewPath!, false);
      canvas.drawPath(path, lassoPaint);
      // Draw dashed fill for lasso area
      final fillPaint = Paint()
        ..color = AppColors.accent.withOpacity(0.08)
        ..style = PaintingStyle.fill;
      canvas.drawPath(Path()..addPolygon(lassoPreviewPath!, true), fillPaint);
    }

    // Draw selection bounding box (dashed border)
    if (selectionState.hasSelection && selectionState.selectionBounds != null) {
      final bounds = selectionState.selectionBounds!.inflate(4.0);
      final selectionPaint = Paint()
        ..color = AppColors.accent
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawRect(bounds, selectionPaint);
    }
  }

  @override
  bool shouldRepaint(SelectionLayer old) =>
      selectionState != old.selectionState ||
      lassoPreviewPath != old.lassoPreviewPath;
}
```

---

### TASK F-5: Shape Input Handler
**File:** `lib/features/editor/presentation/canvas/input/shape_input_handler.dart`

Activated when the toolbar's active tool is `ToolType.shape`.

```dart
// Captures pointer events, builds a raw point list, then on PointerUpEvent:
// 1. Runs ShapeRecognizer.recogniseShape() in a compute isolate.
// 2. If a shape is recognised: creates ShapeElement, dispatches ShapeAddCommand.
// 3. If not recognised: falls back to adding a regular freehand Stroke.
// During the draw: shows a "preview" of the raw points as a thin dashed path
// using the ActiveStrokeLayer's normal rendering (reuses existing live stroke display).
```

Signature:
```dart
class ShapeInputHandler {
  final void Function(ShapeElement shape) onShapeRecognised;
  final void Function(List<StrokePoint> points) onShapeFallback; // falls back to stroke
  final ToolState toolState; // for color, strokeWidth

  void onPointerDown(PointerDownEvent event) { ... }
  void onPointerMove(PointerMoveEvent event) { ... }
  void onPointerUp(PointerUpEvent event) async {
    // Run recognition in compute isolate
    final result = await compute(recogniseShape, _rawPoints.map((p) => p.toOffset()).toList());
    if (result != null) {
      final shape = _buildShapeElement(result, toolState);
      onShapeRecognised(shape);
    } else {
      onShapeFallback(_rawPoints);
    }
    _rawPoints.clear();
  }
}
```

---

### TASK F-6: Lasso Input Handler
**File:** `lib/features/editor/presentation/canvas/input/lasso_input_handler.dart`

Activated when the toolbar's active tool is `ToolType.lasso`.

```dart
// Captures raw pointer events to build the lasso path.
// On PointerUpEvent: closes the path, runs LassoHitTester in a compute isolate,
// dispatches selection results to SelectionNotifier.
// During draw: continuously updates lassoPreviewPath in SelectionLayer.

class LassoInputHandler {
  final void Function(LassoHitResult result, Rect bounds) onLassoComplete;
  final void Function(List<Offset> previewPath) onLassoUpdate;
  final List<Stroke> currentStrokes;      // from canvasStateProvider
  final List<ShapeElement> currentShapes; // from shapeProvider

  void onPointerDown(PointerDownEvent event) { ... }
  void onPointerMove(PointerMoveEvent event) {
    _lassoPath.add(event.localPosition);
    onLassoUpdate(_lassoPath);
  }
  void onPointerUp(PointerUpEvent event) async {
    if (_lassoPath.length < 3) { _lassoPath.clear(); return; }
    final result = await compute(_runHitTest, _LassoHitTestInput(
      lassoPath: _lassoPath,
      strokes: currentStrokes,
      shapes: currentShapes,
    ));
    if (!result.isEmpty) {
      final bounds = _computeSelectionBounds(result, currentStrokes, currentShapes);
      onLassoComplete(result, bounds);
    }
    _lassoPath.clear();
    onLassoUpdate([]);
  }
}
```

---

### TASK F-7: Selection Overlay Widget
**File:** `lib/features/editor/presentation/widgets/selection_overlay.dart`

Rendered above the canvas `Stack` in `NoteEditorScreen`, same position as `FreeImageOverlay`.
Visible only when `selectionState.hasSelection == true`.

Requirements — match `FreeImageOverlay` quality exactly:
- Dashed `AppColors.accent` border around `selectionState.selectionBounds`.
- Four corner drag handles: 16×16 dp circles, `AppColors.accent` fill. Drag moves the entire selection.
- One rotation handle: 24×24 dp circle 32dp above top-centre. Drag rotates the selection.
- Delete button: `AppColors.accentRed`, top-right corner, `HapticFeedback.mediumImpact()` on tap.
- "Deselect" button: small text button below the selection bounds. Calls `selectionProvider.notifier.clearSelection()`.
- All gesture handling via `GestureDetector` (overlay widget, not canvas — consistent with `FreeImageOverlay`).
- Every handle has a 48×48 dp minimum touch target.

On move gesture: call `selectionProvider.notifier.moveSelection(delta)` then commit a `LassoMoveCommand`.
On delete: call `selectionProvider.notifier.deleteSelection()` then commit a `LassoDeleteCommand`.

---

### TASK F-8: Shape Toolbar Widget
**File:** `lib/features/editor/presentation/widgets/shape_toolbar.dart`

A secondary contextual toolbar that appears below the primary `ToolBar` when the shape tool is active.

Design:
- Background: `AppColors.surface`, 8dp corner radius, 1dp `AppColors.border` stroke.
- Slides up from below the primary toolbar with a 200ms ease-out animation.
- Dismissed (slides back down) when the user switches to a non-shape tool.
- Contents:
  - Shape type row: 8 icons for line, arrow, circle, rectangle, triangle, polygon, textBox, SVG.
    Active shape type highlighted with `AppColors.accent` background.
  - Fill toggle: `Icons.format_color_fill_outlined`. Toggles `hasFill`.
  - Stroke width: small slider, range 1.0–12.0, 1dp steps.
  - Colour indicator: tappable circle showing current colour, opens colour picker on tap.

State: this toolbar reads from and writes to `ToolNotifier` (existing). Add a `selectedShapeType` field to `ToolState` if not already present.

---

### TASK F-9: Text Box Overlay Widget
**File:** `lib/features/editor/presentation/widgets/text_box_overlay.dart`

Shown when the user:
- Selects the TextBox shape type and taps the canvas, OR
- Double-taps an existing `ShapeType.textBox` element.

Design:
- Transparent `TextField` positioned exactly over the textBox's `geometryData` bounds.
- Background: `AppColors.surface` with 0.9 opacity.
- Border: 1dp dashed `AppColors.accent`.
- Font controls row above the box: font family picker (Roboto, Serif, Monospace), size slider (8–72), bold toggle, italic toggle, colour picker.
- Committed by: tapping outside the box, or pressing the Done key on the keyboard.
- On commit: update the `ShapeElement.text` and close the overlay.

---

### TASK F-10: SVG Import Flow
**File:** Update `lib/features/import/image_service.dart` (add SVG handling)

When the user selects "Import SVG" from the import bottom sheet:
1. Use `file_picker 8.3.7` with `type: FileType.custom, allowedExtensions: ['svg']`.
2. Copy the SVG file to `{docsDir}/notes/{notebookId}/imports/svg_{id}.svg`.
3. Store the relative path in `ShapeElement.svgRelativePath`.
4. Create a `ShapeElement` of type `svgImage` with `geometryData` for initial centred placement.
5. Add the shape via `shapeProvider.notifier.addShape(shape)`.

SVG rendering widget:
```dart
// In NoteEditorScreen's Stack, above the canvas, render SVG overlays:
for (final shape in svgShapes)
  if (shape.type == ShapeType.svgImage)
    Positioned(
      left: shape.geometryData[0],
      top: shape.geometryData[1],
      width: shape.geometryData[2] - shape.geometryData[0],
      height: shape.geometryData[3] - shape.geometryData[1],
      child: Transform.rotate(
        angle: shape.rotation,
        child: Opacity(
          opacity: shape.opacity,
          child: SvgPicture.file(File(absolutePath(shape.svgRelativePath))),
        ),
      ),
    ),
```

SVG shapes also appear in the selection box if their centre is inside the lasso.

---

## 5. INTEGRATION TASKS

### TASK I-1: Update CanvasWidget
**File:** `lib/features/editor/presentation/canvas/canvas_widget.dart` (existing)

Insert Layer 4 and Layer 5 at the correct positions in the existing `Stack`:

```dart
// After Layer 3 (ActiveStrokeLayer), add:

// Layer 4 — ShapeLayer
RepaintBoundary(
  child: CustomPaint(
    painter: ShapeLayer(
      shapes: ref.watch(shapeProvider(pageIndex)).shapes,
    ),
    child: const SizedBox.expand(),
  ),
),

// Layer 5 — SelectionLayer
RepaintBoundary(
  child: CustomPaint(
    painter: SelectionLayer(
      selectionState: ref.watch(selectionProvider),
      lassoPreviewPath: ref.watch(_lassoPreviewProvider),
    ),
    child: const SizedBox.expand(),
  ),
),
```

Use a separate lightweight `StateProvider<List<Offset>?>` called `_lassoPreviewProvider` for the lasso path preview — this avoids coupling the `LassoInputHandler` directly to `SelectionNotifier` for the in-progress preview.

Do not change the `RepaintBoundary` of any existing layer.

### TASK I-2: Update RawPointerListener
Route pointer events to the correct input handler based on the active tool:

```dart
// In the existing pointer event routing logic, add:
case ToolType.shape:
  _shapeInputHandler.onPointerDown/Move/Up(event);
case ToolType.lasso:
  _lassoInputHandler.onPointerDown/Move/Up(event);
```

`ToolType.shape` and `ToolType.lasso` must be added to the existing `ToolType` enum if not already present.

### TASK I-3: Update ToolBar
Add two new tool buttons to the existing toolbar:
- Shape tool: `Icons.pentagon_outlined`. Label: "Shape". Activates shape tool mode.
- Lasso tool: `Icons.gesture`. Label: "Select". Activates lasso mode.

Follow the existing pattern for tool button selection highlighting (active = `AppColors.accent` tint).
Do not move or resize any existing tool button.

### TASK I-4: Update NoteEditorScreen
Add new overlays to the existing `Stack` in `NoteEditorScreen`:
1. `SelectionOverlay` — above canvas, below toolbar.
2. `TextBoxOverlay` — above `SelectionOverlay`, shown only when editing a text box.
3. SVG shape widget loop — above `ImportedContentLayer` but below `SelectionOverlay`.

### TASK I-5: Ghosting-Safe Page Switch
In the existing `ref.listen<PageState>` observer, add synchronous capture for shapes:
```dart
// ADD alongside existing oldStrokes and oldImportedContents captures:
final oldShapes = ref.read(shapeProvider(oldPageIndex)).shapes;
// ADD alongside existing force-save calls:
await _forceSaveShapes(oldPageIndex, oldShapes);
```

`_forceSaveShapes` is a new private method calling `ShapeRepository.saveShapesForPage`. It follows the exact pattern of the existing stroke and imported content save methods.

### TASK I-6: Update PageThumbnailService
Add shape rendering to the thumbnail `ui.PictureRecorder` canvas:
- Draw shapes after imported content, before strokes (matching the visual layer order).
- Use the same `Paint` setup as `ShapeLayer._drawShape()`.
- Skip SVG shapes in thumbnails — draw their placeholder rect instead.
- If shape list is empty: skip silently.

### TASK I-7: Update BookViewScreen
Each `EditablePagePane` must receive its page's `List<ShapeElement>` and selection state:
- Watch `shapeProvider(pageIndex)` for the respective page.
- Pass `shapes` to the `CanvasWidget` it hosts.
- `SelectionOverlay` is shared between both panes — selection is cleared when the active pane changes.

### TASK I-8: Update Import Bottom Sheet
Add "Import SVG" as a third option:
- Icon: `Icons.draw_outlined`, colour `AppColors.accentPurple`.
- Subtitle: "Place vector graphic on current page".

---

## 6. QA VALIDATION CHECKLIST

Do not mark Phase 5 complete until every item is verified on the emulator.

### Shape Recognition
- [ ] Draw a rough circle → snaps to clean circle
- [ ] Draw a rough rectangle → snaps to clean rectangle
- [ ] Draw a rough triangle → snaps to clean triangle
- [ ] Draw an arrow → line with arrowhead at endpoint
- [ ] Draw a completely random scribble → falls back to regular freehand stroke (no crash)
- [ ] Draw with only 3 points (very quick tap) → recognition skipped gracefully

### Shape Editing
- [ ] Shape tool active → secondary toolbar slides in; switching away → slides out
- [ ] Change shape colour, stroke width, fill — changes reflected immediately in ShapeLayer
- [ ] Undo after placing shape → shape removed from canvas and Isar
- [ ] Redo after undo → shape restored exactly

### Lasso Selection
- [ ] Lasso around one stroke → stroke selected, bounding box appears
- [ ] Lasso around two shapes and one stroke → all three selected, combined bounds shown
- [ ] Lasso in empty area → nothing selected, no crash
- [ ] Move selection → all elements move together by correct delta
- [ ] Delete selection → `HapticFeedback.mediumImpact` fires, all elements removed, `LassoDeleteCommand` committed
- [ ] Undo after lasso delete → all deleted elements restored

### Text Box
- [ ] Tap canvas in TextBox mode → text box appears, keyboard opens
- [ ] Type text → text appears in canvas text box
- [ ] Tap outside → text committed, keyboard dismisses, `ShapeAddCommand` pushed to undo stack
- [ ] Double-tap existing text box → keyboard reopens, text editable
- [ ] Change font, size, bold, italic → reflected immediately in canvas render

### SVG Import
- [ ] Import an SVG file → appears on canvas at correct position
- [ ] Lasso the SVG element → included in selection
- [ ] Move via selection → updates `geometryData`
- [ ] SVG visible in page thumbnail

### Persistence
- [ ] Shapes persist after app force-close and reopen
- [ ] Correct shapes appear on correct pages
- [ ] Shape data survives Isar schema migration from Phase 4 (no data loss in `importedContents`)
- [ ] Page switch during active lasso draw → no crash, no data loss

### Integration
- [ ] BookView: each pane shows its own page's shapes independently
- [ ] PDF background page + shapes on same page → correct render order (PDF below shapes below strokes)
- [ ] Page thumbnails show shapes
- [ ] `flutter analyze` → 0 errors, 0 warnings, 0 hints

---

## 7. CLEANUP PROTOCOL

Run after all QA checks pass.

### C-1: Dead Code Scan
```bash
flutter analyze --no-pub
```
Fix every flagged unused import, variable, and parameter across all new files.

### C-2: Debug Artefact Removal
```bash
grep -rn "print(\|debugPrint(\|TODO\|FIXME\|HACK" \
  lib/features/editor/domain/services/ \
  lib/features/editor/presentation/canvas/ \
  lib/features/editor/presentation/widgets/ \
  lib/features/import/
```
Remove every match. Convert unresolved TODO items to `// Phase 6: <description>`.

### C-3: Orphan File Sweep
For every new `.dart` file created in Phase 5: verify it is imported by at least one other file. Delete any that are not.

### C-4: Geometry Test Data Cleanup
Delete any `.svg`, `.png`, or `.pdf` test files added to the project root during development.

### C-5: Full Rebuild Verification
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --debug
```
The APK must build cleanly. If any Gradle error appears referencing `compileSdk` or `namespace`, report it and check the `android/build.gradle.kts` reflection hook — do not attempt your own fix.

### C-6: Run All Tests
```bash
flutter test
```
All tests must pass. Minimum test files added in Phase 5:
- `test/features/editor/domain/services/shape_geometry_test.dart`
- `test/features/editor/domain/services/shape_recognizer_test.dart`
- `test/features/editor/domain/services/lasso_hit_tester_test.dart`
- `test/features/editor/data/repositories/shape_repository_test.dart`

---

## 8. FINAL AUDIT — FLUTTER INSPECTOR & DEVTOOLS

### Step A-1: Launch with DevTools
```bash
flutter run --debug
```
Open Flutter DevTools from the link in the terminal.

### Step A-2: Widget Tree Inspection
In Flutter Inspector, expand to `NoteEditorScreen`'s `Stack` and verify:
- [ ] Canvas inner `Stack` has exactly **6** `RepaintBoundary` children (Layers 0–5).
- [ ] `ShapeLayer` is at index 4, `SelectionLayer` at index 5.
- [ ] `SelectionOverlay` is a sibling of the canvas `Stack`, not nested inside any canvas layer.
- [ ] `TextBoxOverlay` is a sibling of `SelectionOverlay`, above it in the stack.
- [ ] SVG overlay `Positioned` widgets are present in the `Stack` (outside the canvas inner `Stack`).
- [ ] No `RepaintBoundary` has been added to or removed from Layers 0–3.
- [ ] No orphaned providers remain after navigating away from the editor.

### Step A-3: Performance Overlay
Enable temporarily:
```dart
showPerformanceOverlay: true,
```
- [ ] Draw shapes with lasso on a page that also has a PDF background — GPU thread stays below 16ms.
- [ ] Rapid lasso drawing updates `SelectionLayer` without dropping frames.
- [ ] Shape recognition (on pen-up) does not cause a visible frame drop (it runs in `compute`).

### Step A-4: Memory Check
In DevTools → Memory:
- [ ] Place 50 shapes on one page. Switch to another page and back. Memory stabilises.
- [ ] SVG imports do not accumulate stale `SvgPicture` instances.
- [ ] `PdfCacheManager` still evicts correctly when pages with shapes are navigated.

### Step A-5: End-to-End Validation Flow
Execute this exact sequence on the emulator:
1. Open InkFlow → open an existing notebook from Phase 4.
2. Navigate to the PDF-background page. Draw a rectangle shape on top of the PDF.
3. Switch to lasso tool. Lasso both the rectangle and one existing stroke.
4. Move the selection 100px right and 50px down. Verify both elements moved.
5. Place a text box. Type "InkFlow Phase 5". Set font to bold, size 24.
6. Import an SVG file. Resize it using the selection handles.
7. Switch to BookView. Verify shapes on both pages render correctly.
8. Force-close the app. Reopen.
9. **Verify:** Rectangle, moved stroke, text box, SVG are all present with correct position/style.
10. Undo three times. Verify the three most recent actions are reversed correctly.

If every step passes: **Phase 5 is complete.**

### Step A-6: Remove Debug Flags
```dart
showPerformanceOverlay: false, // or remove the line entirely
```

---

## 9. COMPLETION REPORT

When Phase 5 is fully done, provide:

```
PHASE 5 COMPLETE
================
New files created       : [list all new .dart files]
Existing files modified : [list all modified .dart files]
Packages added          : [list any new packages and resolved versions]
Build runner run        : YES / NO (and reason if NO)
flutter analyze         : 0 errors, 0 warnings
flutter test            : X tests passed, 0 failed
QA checklist            : all items verified
Cleanup protocol        : all 6 steps complete
DevTools audit          : all 6 steps complete

Deferred to Phase 6:
- [anything intentionally left — mark as // Phase 6: comment in code]

Ready for Phase 6 (Performance & Launch): YES
```
