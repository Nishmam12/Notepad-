# InkFlow 2.0 — Ground-Up Rebuild & Excalidraw-Parity Prompt

> **Paste this entire document into Claude (Claude Code / agentic mode) at the root of the InkFlow repo.**
> It is designed to be run **phase by phase**. After each phase, Claude stops at a checkpoint and waits for your "continue". Do not ask for everything in one shot — the checkpoints are what keep a 12K-line rewrite from going off the rails.

---

## 0. AGENT PERSONA

You are operating as four specialists at once. Hold all four hats for every change.

- **Principal Flutter/Dart Engineer** — you design a clean, layered, testable architecture. You port proven algorithms rather than reinventing them. You prize correctness and rendering performance (60fps on a mid-range Android tablet with an active stylus) over cleverness.
- **Rendering/Graphics Engineer** — you understand `CustomPainter`, `Canvas`, `Path`, layer compositing, repaint boundaries, and `dart:ui.Image` lifecycle. You know perfect_freehand and rough.js-style hand-drawn rendering.
- **QA Engineer** — after every phase you verify the happy path AND the regression case. You write widget/unit tests. Nothing is "done" until `flutter analyze` is clean and `flutter test` passes.
- **Product Designer** — the app must *feel* like Excalidraw: fluid, responsive, with the same direct-manipulation editing language (drag to select, handles to transform, snapping, infinite canvas).

---

## 1. MISSION

Rebuild **InkFlow** — a Flutter/Dart infinite-canvas note-taking + whiteboard app — from a clean architectural foundation, reaching **near-full feature parity with Excalidraw's drawing engine** while keeping all of InkFlow's existing note-taking features (notebooks, pages, book view, templates, PDF/image import, export).

This is a **full ground-up rewrite of the application architecture**, in **Dart and Flutter only**. You will not produce a web app, you will not introduce React/TypeScript, and you will not call into the Excalidraw codebase at runtime. Excalidraw (in `./excalidraw-master/`, a React/TypeScript monorepo) is a **reference specification only** — read its algorithms and behavior, then re-implement them idiomatically in Dart.

---

## 2. CONTEXT — CARRY THIS FORWARD (do not rediscover, do not contradict)

This context is authoritative. It was extracted from the current codebase. Trust it over your own assumptions, but verify any line/file before you edit it.

### 2.1 What InkFlow is today (the code you are replacing)
- ~12,000 lines of Dart across ~85 files (`lib/`), currently at app version `1.0.2+6`.
- **Stack:** Flutter (Dart SDK >=3.0 <4.0), `flutter_riverpod` ^2.5 (state), `go_router` ^14 (nav), `get_it` ^7.7 (DI), `isar` ^3.1 (local DB), `perfect_freehand` ^2.5 (stroke geometry — *this is the Dart port of the exact library Excalidraw uses*), `pdfx` (PDF render), `image_picker`/`image` (image import), `flutter_svg` (vector), `printing`/`pdf`/`share_plus`/`file_picker` (export).
- **Architecture today:** feature-first folders (`lib/features/{editor,home,export,import,settings}`) with `domain/`, `data/`, `presentation/` layers. Riverpod `StateNotifier`s drive an editor with multiple `CustomPainter` layers.

### 2.2 Proven systems that already work — PORT these algorithms, do not invent new ones
- **Viewport / infinite canvas** (`viewport_notifier.dart`): `ViewportState{scrollX, scrollY, zoom}`, `toMatrix4()`, `toScene()/toViewport()` coordinate transforms, `zoomAtPoint(newZoom, focalScreen)` focal-anchored zoom, min/max zoom 0.1–5.0. The transform model is: `screenX = scrollX + zoom * sceneX`.
- **Stroke model:** `Stroke{id, color(ARGB int), size, opacity, isEraser, points}` and `StrokePoint{x, y, pressure, simulatePressure}`. `simulatePressure` mirrors Excalidraw's flag — lets perfect_freehand synthesize a thinning curve when hardware gives no real pressure.
- **Shape model:** `ShapeElement` (Isar `@embedded`) with `ShapeType{line, arrow, circle, rectangle, triangle, polygon, textBox, svgImage, diamond}`, flat `geometryData: List<double>` interpreted per type, `rotation`, fill, opacity, `zOrder`, `seed` (stable rough-render seed), `roughness`, and arrow `startBindingId/endBindingId`.
- **Hand-drawn rendering:** `rough_renderer.dart` already produces Excalidraw-style sketchy shapes driven by a stable `seed`.
- **Arrow binding:** `binding_service.dart` re-anchors bound arrow endpoints to a shape's edge when it moves/resizes/rotates.
- **Undo/redo:** command-pattern stack (`undo_redo/`) with per-operation command classes.
- **Eraser:** both stroke-erase and pixel-erase, with point/segment distance hit-testing.
- **Palm rejection** (shipped in 1.0.2): order-independent stylus-vs-palm logic, grace window after each stroke, hover pre-arm. **This was hard-won — preserve its exact behavior.**

### 2.3 Persistence formats that MUST survive the rewrite (data migration is mandatory)
- **Strokes** are NOT in the DB. They live in per-page JSON files: `<appDocs>/notes/<notebookId>/page_<pageId>.ink` via `InkFileStorage`, with `.tmp`/`.bak` atomic-write safety. Schema = `[{id, color, size, opacity, isEraser, points:[{x,y,p,sim}]}]`.
- **Notebooks/pages/shapes/imported content** are in **Isar**: `Notebook{id, title, createdAt, modifiedAt, pageCount, backgroundColor, templateIndex}`, `NotePage{id, notebookId, pageIndex, createdAt, modifiedAt, importedContents:[ImportedContent], shapes:[ShapeElement]}`.
- **Hard requirement:** A user who opens InkFlow 2.0 with notebooks created in 1.0.2 MUST see every notebook, page, stroke, shape, and imported PDF/image intact. If you change a schema, you MUST write a migration. Existing `.ink` files and Isar collections are a fixed contract unless you ship a migrator.

### 2.4 Known pain points the rewrite must eliminate
- **`dart:ui.Image` lifecycle crashes** ("Bad state: Cannot clone a disposed image") from thumbnail/PDF cache disposing handles still being painted. The new architecture must own image lifecycles explicitly (ref-counted clones, no disposal while referenced by the widget tree).
- **Book View defects:** off-by-one spread pagination, hardcoded paper color, gesture conflicts between page-swipe and canvas drawing, missing page-turn animation, thumbnail-less navigation. Rebuild Book View correctly from the start.
- **Tooling/state coupling:** monolithic `note_editor_screen.dart` (571 lines) wires every concern together. The new editor must have a clean separation between input → tool/command → document model → render layers.

---

## 3. HARD CONSTRAINTS (NEVER violate)

1. **Dart & Flutter only.** No web stack, no platform channels to JS, no runtime dependency on Excalidraw.
2. **Excalidraw is a spec, not a source.** Port behavior/algorithms/math. Never copy `.ts`/`.tsx`.
3. **Preserve user data.** Existing `.ink` files and Isar data load correctly, or ship a migration. Never write code that can delete a user's notes without an explicit, reviewed migration path.
4. **Phased delivery with checkpoints.** Implement ONE phase per turn. At each checkpoint: run `flutter analyze` (zero issues) and `flutter test` (all green), output a summary, then STOP and wait for "continue".
5. **No over-engineering.** Build only what each phase specifies. Do not add speculative abstractions, plugins, or features not listed. (You default to over-building — resist it.)
6. **Human-review triggers — STOP and ASK before:** deleting any file outside a phase's declared scope, changing an Isar schema or `.ink` format, adding a new third-party dependency, or removing the palm-rejection logic.
7. **Performance budget:** the canvas holds 60fps with an active stylus while panning/zooming a page of ~500 strokes + 100 shapes on a mid-range Android tablet. Use `RepaintBoundary`, layer separation (static vs active stroke), and avoid rebuilding painters that didn't change.
8. **Every phase ships tests.** New logic (geometry, hit-testing, transforms, snapping, serialization, migration) gets unit tests. Editor flows get widget tests.
9. **After each step, output `✅ <what was completed>`.** Keep me oriented.

---

## 4. TARGET ARCHITECTURE (the clean foundation to build)

Design a single, coherent document model and a strict unidirectional data flow. Suggested structure (adapt names if you justify it):

```
lib/
  core/            theme, colors, constants, DI, result/error types
  data/
    persistence/   IsarService, InkFileStorage (back-compat + migration), file IO
    migration/     1.x → 2.0 migrators (Isar + .ink), versioned
  domain/
    model/         SceneElement hierarchy, Stroke, Notebook, Page, Viewport
    geometry/      bounds, collision, distance, transforms, snapping (PORTED from Excalidraw)
    services/      binding, recognizer, eraser, grouping, z-order, alignment
    commands/      undo/redo command pattern (one command per mutation)
  editor/
    state/         Riverpod notifiers: SceneController, ToolController, SelectionController, ViewportController, HistoryController
    input/         pointer pipeline: raw pointer → palm rejection → tool router → gesture/command
    render/        layered CustomPainters (background/template, static content, active stroke, selection/handles, overlays)
    tools/         pen, eraser, selection, each shape, text, image, laser, hand
    ui/            editor screen, toolbars, panels, color/style pickers
  features/
    home/          notebook grid, create/rename/delete
    bookview/      correct spread pagination + page-turn animation + thumbnail filmstrip
    import/        PDF + image
    export/        PNG / SVG / PDF / clipboard / share
    settings/
```

**Unifying model decision (make it explicit and document it):** Excalidraw treats *everything* — rectangle, arrow, text, image, and freehand — as one `ExcalidrawElement` union with a shared bounding box, transform, z-index, and style. InkFlow today splits `Stroke` (file) from `ShapeElement` (DB). **Decide and document** whether 2.0 unifies these into a single `SceneElement` hierarchy (recommended — it makes multi-select, grouping, alignment, and z-order uniform) while keeping the *on-disk* formats backward-compatible via serialization adapters. Selection, transform, snapping, grouping, and z-order must all operate on the unified type so they work identically across strokes and shapes.

---

## 5. EXCALIDRAW PARITY — FEATURE SPECIFICATION (near-full)

Target this feature set. Each item names the Excalidraw reference module to study in `./excalidraw-master/packages/element/src/`.

### 5.1 Canvas & navigation
- Infinite canvas, focal-anchored pinch-zoom and pan (port existing `viewport_notifier`), zoom-to-fit, zoom-to-selection, reset-view, zoom % indicator. Optional dotted grid background with snap-to-grid.

### 5.2 Drawing tools
- **Freehand pen** via perfect_freehand with pressure + `simulatePressure` (already correct — keep). Expose Excalidraw-equivalent stroke options (thinning, smoothing, streamline, taper).
- **Shapes:** rectangle, diamond, ellipse, line, multi-point line, arrow (incl. **elbow/right-angle arrows** → `elbowArrow.ts`), freedraw. Sharp vs **rounded corners**.
- **Text:** standalone text + **text bound to a container** shape (`textElement.ts`, `textWrapping.ts`, `textMeasurements.ts`), font family/size/align.
- **Image element** as a first-class element (not just imported background): place, move, resize, rotate, z-order (`image.ts`).
- **Eraser** (stroke + pixel — already present) and **laser pointer** (ephemeral fading trail).

### 5.3 Selection & direct manipulation — the core "feel"
- **Single + multi-select**; marquee/rubber-band selection (`selection.ts`).
- **Transform handles:** 8 resize handles + rotation handle, with **aspect-ratio lock** (shift), resize-from-center (alt), and correct multi-element bounding box (`transformHandles.ts`, `resizeElements.ts`, `bounds.ts`, `resizeTest.ts`).
- **Snapping:** snap to other elements' edges/centers and to grid, with alignment guide lines while dragging (`./excalidraw-master/packages/excalidraw/snapping.ts` if present, else derive).
- **Grouping / ungrouping** (`groups.ts`), move/transform as a unit.
- **Z-order:** bring forward/back, to front/to back (`zindex.ts`, `fractionalIndex.ts`).
- **Alignment & distribution:** left/center/right/top/middle/bottom, distribute h/v (`align.ts`, `distribute.ts`).
- **Arrow binding:** endpoints bind to shapes and re-anchor on move/resize (port existing `binding_service` + study `binding.ts`).
- Drag to move, duplicate (alt-drag / Ctrl+D), delete, copy/paste (in-app + system clipboard where possible), lock/unlock elements.

### 5.4 Styling
- Stroke color, background fill color, **fill style** (hachure / cross-hatch / solid — your rough renderer already does hachure-style fills), stroke width (thin/bold/extra), **stroke style** (solid/dashed/dotted), **sloppiness/roughness** (architect/artist/cartoonist), edges (sharp/round), opacity slider, arrowhead types (none/arrow/triangle/dot/bar → `arrowheads.ts`), font family/size. Reusable color palettes and a recent-colors row.

### 5.5 Frames & library
- **Frames** (`frame.ts`): named containers that clip and move their children together.
- **Element library:** save selected elements as reusable items, browse and drag them back onto the canvas (local persistence; no network).

### 5.6 History, persistence, export
- Undo/redo across every mutation (extend the command pattern).
- Autosave (debounced) with the crash-free image lifecycle described in §2.4. Preserve `.ink` + Isar back-compat.
- **Export:** PNG (with scale + background/transparent), SVG, PDF, copy-to-clipboard, share. Export selection-only or whole page.

### 5.7 InkFlow-specific features to retain (do not drop)
- Notebooks → pages, **Book View** (correct spreads, page-turn animation, thumbnail filmstrip), page templates (blank/lined/grid/dotted), PDF import as page background, image import, per-notebook paper/background color, About/version screen, robust palm rejection.

---

## 6. PHASED IMPLEMENTATION PLAN

Run one phase per turn. Each phase ends at a **CHECKPOINT**: `flutter analyze` clean, `flutter test` green, a written summary of what changed and what to manually verify, then **STOP**.

> **PHASE 0 — Audit, plan, and scaffolding (no behavior change yet)**
> 1. Read the current `lib/` and produce a concise **architecture map** + a table of every existing feature and which new file will own it.
> 2. Confirm the §2.3 persistence contracts by reading `InkFileStorage`, the Isar collections, and `ShapeElement`/`Stroke`. Report any discrepancy with §2 before proceeding.
> 3. Propose the final folder structure (§4) and the **unified `SceneElement` model** decision with a written rationale, including the serialization-adapter plan that keeps `.ink` + Isar backward-compatible.
> 4. Write a **migration test plan**: how you will prove 1.0.2 data loads in 2.0.
> 5. Set up the new directory skeleton and DI wiring with NO features moved yet; app still builds and runs the old screens.
> **CHECKPOINT 0.** Output the architecture map + model decision + migration plan. STOP for my approval before writing feature code.

> **PHASE 1 — Document model, persistence, migration**
> Build the unified `SceneElement` model, geometry primitives (bounds/distance/collision ported from Excalidraw), serialization adapters, Isar schema (+migration), `.ink` loader (+migration), and a `SceneController`. Prove old data loads via tests using sample 1.0.2 `.ink`/Isar fixtures.
> **CHECKPOINT 1.** Migration tests green.

> **PHASE 2 — Canvas, viewport, layered rendering, pen**
> Port the viewport; build the layered painter stack with `RepaintBoundary`s (background/template, static content, active stroke, overlay); re-implement the perfect_freehand pen with pressure + simulatePressure; restore palm rejection with its exact 1.0.2 behavior. Hit 60fps with 500 strokes.
> **CHECKPOINT 2.** Draw, pan, zoom, palm-reject all working; perf check reported.

> **PHASE 3 — Shapes + hand-drawn rendering + text + image elements**
> All shape tools (incl. elbow arrows, rounded corners), rough renderer with stable seed, container-bound + standalone text, first-class image elements. Full styling panel (§5.4).
> **CHECKPOINT 3.**

> **PHASE 4 — Selection & direct manipulation (the Excalidraw feel)**
> Marquee multi-select, 8 resize handles + rotate with aspect/center modifiers, snapping + alignment guides, grouping, z-order, alignment/distribution, arrow binding, duplicate/copy/paste/lock. This is the make-or-break phase for parity — port `transformHandles.ts`/`resizeElements.ts`/`bounds.ts`/`selection.ts` carefully and test the geometry.
> **CHECKPOINT 4.**

> **PHASE 5 — Eraser, laser, undo/redo, autosave (crash-free)**
> Stroke+pixel eraser, laser pointer, command-pattern history across all mutations, debounced autosave with the ref-counted image lifecycle that eliminates the disposed-image crash (§2.4).
> **CHECKPOINT 5.**

> **PHASE 6 — Frames, element library, export**
> Frames with child clipping/move, save/browse/drag reusable library items, export PNG/SVG/PDF/clipboard/share (selection or page).
> **CHECKPOINT 6.**

> **PHASE 7 — Home, Book View, templates, import, settings**
> Notebook grid + CRUD; **correct** Book View (off-by-one-free spreads, page-turn animation, thumbnail filmstrip, per-notebook paper color, no swipe/draw gesture conflict); templates; PDF/image import; settings + About.
> **CHECKPOINT 7.**

> **PHASE 8 — Hardening, full regression, performance, polish**
> Full `flutter analyze`/`flutter test`; manual regression script for every feature; performance profiling; remove dead old code ONLY after confirming parity (ask before deleting). Bump version, update CHANGELOG.
> **CHECKPOINT 8 — Definition of Done review.**

---

## 7. DEFINITION OF DONE

- App builds and runs on Android tablet + desktop; `flutter analyze` reports zero issues; `flutter test` all green.
- A notebook authored in InkFlow 1.0.2 opens in 2.0 with every stroke, shape, PDF/image, and setting intact.
- Every §5 feature is usable, and the editing *feel* matches Excalidraw (multi-select, handles, snapping, grouping).
- 60fps stylus drawing on the target tablet with a busy page; no disposed-image crashes after extended draw/navigate sessions.
- Palm rejection behaves exactly as in 1.0.2.
- No feature from §2/§5.7 was lost.

---

## 8. HOW TO BEGIN

Start with **PHASE 0 only**. Read the codebase, produce the architecture map, the unified-model decision with rationale, and the migration test plan. Do not write feature code yet. End at CHECKPOINT 0 and wait for my approval.

After each phase, end your message with: `➡️ Phase N complete. Reply "continue" for Phase N+1.`
