# InkFlow — Agent Context File

This file gives the AI agent the full context of the InkFlow project.
Read this entire file before writing any code or making any decisions.

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

**Phase 0 is complete.** The following has already been done:

- Flutter project created: `flutter create inkflow --org com.inkflow --platforms android,ios`
- `pubspec.yaml` configured with all Phase 1–6 dependencies (see below)
- Full feature-first folder structure created under `lib/`
- Test folder structure created under `test/`
- `flutter pub get` passes cleanly

**Phase 1 has NOT started yet.** The app currently shows a placeholder HomeScreen.
The next task is Phase 1: Core Canvas Engine. See the IMMEDIATE TASK section at the bottom.

---

## Confirmed Working pubspec.yaml

```yaml
name: inkflow
description: A note-taking app with no artificial limitations.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  get_it: ^7.7.0
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1
  path_provider: ^2.1.3
  perfect_freehand: ^2.5.1
  pdfx: ^2.6.0
  image_picker: ^1.1.2
  image: ^4.2.0
  flutter_svg: ^2.0.10+1
  printing: ^5.13.1
  share_plus: ^12.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.11
  isar_generator: ^3.1.0+1
  mocktail: ^1.0.4

flutter:
  uses-material-design: true
```

**Packages intentionally excluded and why:**
- `riverpod_annotation` / `riverpod_generator` / `injectable` / `injectable_generator` —
  conflict with `isar_generator` over `analyzer` version. Write Riverpod providers manually.
- `messagepack_dart` — doesn't exist on pub.dev. Binary stroke storage will be added in Phase 1
  using the correct package `enough_serialization` or raw `ByteData`. Confirm before adding.
- `file_picker` — conflicts with `share_plus`. Add back at Phase 5 with compatible versions.

---

## Folder Structure (Already Created)

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── router.dart
├── core/
│   ├── constants/
│   ├── utils/
│   └── theme/
├── features/
│   ├── home/
│   │   ├── presentation/screens/
│   │   ├── presentation/widgets/
│   │   ├── domain/models/
│   │   └── data/repositories/
│   ├── editor/
│   │   ├── presentation/screens/
│   │   ├── presentation/widgets/
│   │   ├── presentation/canvas/layers/
│   │   ├── presentation/canvas/input/
│   │   ├── presentation/canvas/shapes/
│   │   ├── domain/models/
│   │   ├── domain/services/
│   │   ├── domain/undo_redo/
│   │   ├── data/repositories/
│   │   └── data/storage/
│   ├── import/
│   ├── export/
│   └── settings/
└── shared/
    ├── widgets/
    └── isar/
```

---

## Architecture — Six Layers

### Layer 01 — Presentation
Flutter widget tree. Screens are thin — no business logic. They only read from Riverpod
providers and call domain services.

### Layer 02 — Canvas Engine
Six stacked CustomPainter widgets, each in a RepaintBoundary.
Stack order bottom → top:
```
0. BackgroundLayer       — vector templates, never repaints during drawing
1. ImportedContentLayer  — PDF pages / images, locked background
2. StrokeHistoryLayer    — completed strokes, cached as Flutter Picture
3. ActiveStrokeLayer     — ONLY the live in-progress stroke, repaints every ~8ms
4. ShapeLayer            — vector shapes, text boxes
5. SelectionLayer        — selection handles, UI overlay
```
**Critical**: Only `ActiveStrokeLayer` repaints during input. Everything else uses
`RepaintBoundary` to cache as GPU textures. This is how sub-16ms latency is achieved.

### Layer 03 — Input Pipeline
Use `Listener` widget, NOT `GestureDetector`. Listener fires raw PointerEvents at the
device's native polling rate. Extract `event.pressure` for pressure-sensitive strokes.
`perfect_freehand` converts raw points into smooth stroke outlines.

### Layer 04 — State Management (Riverpod)
Write providers manually — no code generation.
Key providers:
- `NoteListNotifier extends StateNotifier<List<Notebook>>` — CRUD for notebooks
- `CanvasStateNotifier extends StateNotifier<CanvasState>` — live stroke data
- `ToolNotifier extends StateNotifier<ToolState>` — active tool, color, size
- `PageNotifier extends StateNotifier<PageState>` — current page, total pages
- `UndoRedoStack extends StateNotifier<UndoRedoState>` — Command pattern history

### Layer 05 — Data Layer
- Isar: stores Notebook and NotePage metadata
- Binary files: stroke data stored as `.ink` files (one per page) in app documents directory
- Path: `getApplicationDocumentsDirectory()/notes/{notebookId}/{pageId}.ink`

### Layer 06 — Sync Layer
**NOT in scope yet.** Do not implement any sync, auth, or cloud features until Phase 7.

---

## Coding Conventions

**Riverpod — always write providers manually like this:**
```dart
// Notifier
class ToolNotifier extends StateNotifier<ToolState> {
  ToolNotifier() : super(ToolState.initial());
  
  void setColor(Color color) => state = state.copyWith(color: color);
  void setSize(double size) => state = state.copyWith(size: size);
}

// Provider
final toolProvider = StateNotifierProvider<ToolNotifier, ToolState>(
  (ref) => ToolNotifier(),
);
```

**Never use `StatefulWidget` for business state.** Use `ConsumerWidget` with Riverpod.

**Always use `autoDispose` for providers that are tied to a screen:**
```dart
final canvasStateProvider = StateNotifierProvider.autoDispose<CanvasStateNotifier, CanvasState>(
  (ref) => CanvasStateNotifier(),
);
```

**Isar collections:**
```dart
@collection
class Notebook {
  Id id = Isar.autoIncrement;
  late String title;
  late DateTime createdAt;
  late DateTime modifiedAt;
}
```

**After defining any Isar collection, run:**
```bash
dart run build_runner build
```

**Canvas layers follow this pattern:**
```dart
class ActiveStrokeLayer extends CustomPainter {
  final List<Offset> currentStrokePoints;
  final Color strokeColor;
  final double strokeSize;

  const ActiveStrokeLayer({
    required this.currentStrokePoints,
    required this.strokeColor,
    required this.strokeSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (currentStrokePoints.isEmpty) return;
    // draw using perfect_freehand here
  }

  @override
  bool shouldRepaint(ActiveStrokeLayer oldDelegate) =>
      currentStrokePoints != oldDelegate.currentStrokePoints;
}
```

**File naming:** snake_case for all files. One class per file. File name matches class name.

**Import order:** dart: → package: → relative. Always use relative imports within features.

---

## Theme & Design Tokens

Dark engineering aesthetic. Use these colors consistently:

```dart
// lib/core/constants/app_colors.dart
class AppColors {
  static const background    = Color(0xFF0D1117);
  static const surface       = Color(0xFF161B22);
  static const border        = Color(0xFF21262D);
  static const accent        = Color(0xFF58A6FF); // primary blue
  static const accentGreen   = Color(0xFF3FB950);
  static const accentYellow  = Color(0xFFE3B341);
  static const accentPurple  = Color(0xFFBC8CFF);
  static const accentRed     = Color(0xFFF85149);
  static const textPrimary   = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted     = Color(0xFF484F58);
}
```

---

## Development Phases

| Phase | Title | Weeks | Status |
|---|---|---|---|
| 0 | Study & Foundation | 1–2 | ✅ DONE |
| 1 | Core Canvas Engine | 3–6 | 🔄 NEXT |
| 2 | Templates & Export | 7–8 | ⏳ |
| 3 | Multi-Page & Book View | 9–10 | ⏳ |
| 4 | PDF & Image Import | 11–14 | ⏳ |
| 5 | Shapes & Selection | 15–18 | ⏳ |
| 6 | Performance & Launch | 19–21 | ⏳ |
| 7 | Sync & AI (post-launch) | 22+ | ⏳ |

---

## Phase 1 — Complete Task List

Build these in order. Do not skip ahead or implement Phase 2+ features.

1. `lib/core/constants/app_colors.dart` — AppColors class
2. `lib/core/theme/app_theme.dart` — ThemeData using AppColors
3. `lib/shared/isar/isar_service.dart` — Isar singleton, openDatabase()
4. `lib/features/home/domain/models/notebook.dart` — Isar @collection with id, title, createdAt, modifiedAt, pageCount
5. `lib/features/home/domain/models/note_page.dart` — Isar @collection with id, notebookId, pageIndex, createdAt
6. Run `dart run build_runner build` to generate Isar schema files
7. `lib/features/home/data/repositories/note_repository.dart` — CRUD: createNotebook, getAllNotebooks, deleteNotebook, updateNotebook
8. `lib/features/home/presentation/home_notifier.dart` — StateNotifier wrapping NoteRepository, exposes notebooks as state
9. Update `lib/main.dart` — init Isar before runApp, wrap with ProviderScope
10. `lib/features/home/presentation/screens/home_screen.dart` — GridView of notebooks, FAB to create new, long-press to delete, tap to navigate to editor
11. `lib/app/router.dart` — add `/note/:id` route pointing to NoteEditorScreen
12. `lib/features/editor/presentation/screens/note_editor_screen.dart` — full-screen canvas shell with Scaffold, floating ToolBar
13. `lib/features/editor/domain/models/stroke_point.dart` — x, y, pressure fields
14. `lib/features/editor/domain/models/stroke.dart` — id, color (int), size, opacity, List<StrokePoint>
15. `lib/features/editor/presentation/canvas/input/raw_pointer_listener.dart` — Listener widget capturing PointerDown/Move/Up, extracting pressure
16. `lib/features/editor/presentation/canvas/layers/background_layer.dart` — white/dark blank canvas for now (templates in Phase 2)
17. `lib/features/editor/presentation/canvas/layers/stroke_history_layer.dart` — draws List<Stroke> using perfect_freehand
18. `lib/features/editor/presentation/canvas/layers/active_stroke_layer.dart` — draws current live stroke only using perfect_freehand
19. `lib/features/editor/presentation/canvas/canvas_widget.dart` — assembles all layers in a Stack with RepaintBoundary on each
20. `lib/features/editor/presentation/canvas_notifier.dart` — StateNotifier managing currentStrokePoints, completedStrokes
21. Wire CanvasWidget into NoteEditorScreen with the Listener capturing pointer events
22. `lib/features/editor/domain/undo_redo/command.dart` — abstract Command class with execute() and undo()
23. `lib/features/editor/domain/undo_redo/stroke_add_command.dart` — concrete command
24. `lib/features/editor/domain/undo_redo/undo_redo_stack.dart` — StateNotifier with push, undo, redo
25. `lib/features/editor/presentation/widgets/tool_bar.dart` — pen tool, eraser tool, undo button, color picker, size slider
26. `lib/features/editor/data/storage/ink_file_storage.dart` — save/load strokes to .ink binary files in app documents directory
27. Wire ink_file_storage so strokes persist across app restarts

**Deliverable after Phase 1:** User can create a notebook, open it, write with a pressure-sensitive pen, undo strokes, change pen color and size, close and reopen the note with strokes preserved.

---

## Rules for the Agent

1. **Build Phase 1 tasks in the order listed.** Do not reorder them.
2. **Do not implement any feature outside Phase 1** unless explicitly asked.
3. **After writing each file, run `flutter analyze`** and fix any errors before moving on.
4. **Do not use StatefulWidget for state.** Use ConsumerWidget + Riverpod providers.
5. **Do not use GestureDetector on the canvas.** Use Listener only.
6. **Use RepaintBoundary on every canvas layer.** No exceptions.
7. **Do not add any new packages to pubspec.yaml** without confirming with the user first.
8. **After writing the Isar models**, always run `dart run build_runner build` before continuing.
9. **Name every file in snake_case.** One class per file.
10. **Write a brief comment at the top of every file** explaining what it does in one sentence.
