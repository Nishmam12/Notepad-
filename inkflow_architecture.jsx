import { useState } from "react";

/* ═══════════════════════════════════════════════════════════════════
   InkFlow — Architecture Blueprint Dashboard
   Android-First Cross-Platform Note-Taking App
   Reference codebase: saber-notes/saber (GPL-3, study only)
═══════════════════════════════════════════════════════════════════ */

// ── DESIGN TOKENS ──────────────────────────────────────────────────
const C = {
  bg: "#0d1117", surface: "#161b22", surfaceDeep: "#0d1117",
  border: "#21262d", borderHover: "#30363d",
  blue: "#58a6ff", green: "#3fb950", yellow: "#e3b341",
  purple: "#bc8cff", orange: "#db6d28", red: "#f85149", teal: "#39d353",
  text: "#e6edf3", textSub: "#8b949e", textMuted: "#484f58",
};

// ── DATA ────────────────────────────────────────────────────────────
const LAYERS = [
  {
    id: "ui", no: "01", title: "Presentation Layer", color: C.blue, tech: "Flutter Widget Tree",
    modules: ["HomeScreen", "NoteEditor", "ToolBar", "TemplateSelector", "PageNavigator", "BookView", "SettingsScreen"],
    desc: "All visible UI composed from thin Flutter widgets. Screens are data consumers only — zero business logic. State is consumed reactively from Riverpod providers below.",
    points: [
      "HomeScreen: note/notebook grid with search, tags, sort, and swipe-to-delete",
      "NoteEditor: full-screen canvas host — toolbar slides in/out contextually to maximise writing area",
      "BookView: two CanvasPage instances side-by-side inside a Row, sharing one ToolNotifier",
      "TemplateSelector: bottom sheet with live vector-rendered previews (no PNGs needed)",
      "go_router handles all navigation — deep-link-aware for future web/desktop support",
    ],
  },
  {
    id: "canvas", no: "02", title: "Canvas Engine", color: C.green, tech: "Stacked CustomPainter + RepaintBoundary",
    modules: ["BackgroundLayer", "ImportedContentLayer", "StrokeHistoryLayer", "ActiveStrokeLayer", "ShapeLayer", "SelectionLayer", "TileManager"],
    desc: "The heart of the app. Six stacked CustomPainter widgets, each wrapped in a RepaintBoundary. Only the ActiveStrokeLayer repaints during input (~8ms at 120Hz). All others are cached Flutter Pictures.",
    points: [
      "BackgroundLayer: pure math-driven vector grid/lines — never invalidated during drawing sessions",
      "ImportedContentLayer: PDF pages and images as a locked background — repaints only on page load",
      "StrokeHistoryLayer: all completed strokes, stored as a Flutter Picture (GPU-cached bitmap)",
      "ActiveStrokeLayer: the single in-progress stroke only — the hot path, repaints every pointer event",
      "TileManager: pre-renders off-screen regions as Pictures for large notebooks (>20 pages)",
      "ShapeLayer: SVG-based vector shapes with transform handles; above strokes, below selection UI",
    ],
  },
  {
    id: "input", no: "03", title: "Input Pipeline", color: C.red, tech: "Listener → StrokeBuilder → 8ms loop",
    modules: ["RawPointerListener", "StylusProcessor", "PressureMapper", "StrokeBuilder", "PredictiveRenderer"],
    desc: "Raw PointerEvents captured via Listener widget — NOT GestureDetector. On 120Hz devices this fires every ~8ms. A PredictiveRenderer extends the stroke 1–2 points forward to hide OS-level input latency.",
    points: [
      "Listener captures PointerDownEvent, PointerMoveEvent, PointerUpEvent at the device's native rate",
      "StylusProcessor extracts pressure (0.0–1.0), tilt angle, and tool type (stylus vs finger vs palm)",
      "perfect_freehand algorithm maps pressure in real time → stroke width and opacity variation",
      "Catmull-Rom spline interpolation smooths between sparse input points for clean bezier curves",
      "PredictiveRenderer extends the visible stroke 1–2 samples ahead to mask Android OS touch latency",
      "Target: < 16ms perceived latency (one frame at 60fps) — sub-10ms at 120fps with Impeller",
    ],
  },
  {
    id: "state", no: "04", title: "State Management", color: C.yellow, tech: "Riverpod 2.x — compile-safe providers",
    modules: ["NoteListNotifier", "CanvasStateNotifier", "ToolNotifier", "PageNotifier", "UndoRedoStack", "SettingsNotifier"],
    desc: "Riverpod 2.x manages all reactive state. The UndoRedoStack implements the Command pattern — every canvas mutation is a typed, reversible Command object. AutoDispose prevents memory leaks.",
    points: [
      "NoteListNotifier: CRUD for notebooks, lazy-loads metadata from Isar on first access",
      "CanvasStateNotifier: holds live stroke points, selection set, zoom level, pan offset",
      "ToolNotifier: active tool (pen/eraser/shape/select), color, size, opacity, stabilisation level",
      "PageNotifier: current page index, total page count, page size config (A4/letter/infinite)",
      "UndoRedoStack: StrokeAddCommand, StrokeDeleteCommand, TransformCommand — each is reversible",
      "All providers are autoDisposed — navigating away from the editor frees all canvas memory",
    ],
  },
  {
    id: "data", no: "05", title: "Data Layer", color: C.purple, tech: "Isar DB + .ink files (MessagePack)",
    modules: ["IsarDatabase", "StrokeFileStorage", "PDFService", "ImageService", "ExportEngine", "CacheManager"],
    desc: "Isar stores note metadata (title, created, modified, tags, page count). Actual stroke data lives in binary .ink files encoded with MessagePack — compact, fast, and language-agnostic for future iOS.",
    points: [
      "Isar: embedded NoSQL, Dart-native schema, zero config, 5–10x faster than SQLite for queries",
      ".ink format: MessagePack-encoded StrokePage objects, one file per page, lazy-loaded on demand",
      "PDFService: pdfx renders each PDF page to a Flutter Image at 2x display density, cached by hash",
      "ImageService: image_picker for import, image package for in-memory crop/resize/compress",
      "ExportEngine: rasterize canvas → PNG, vector-redraw → SVG, print layout → PDF (printing package)",
      "CacheManager: LRU eviction for rendered PDF thumbnails, bounded by 200MB soft limit",
    ],
  },
  {
    id: "sync", no: "06", title: "Sync Layer", color: C.orange, tech: "Phase 2 — Supabase (pluggable)",
    modules: ["AuthService", "SyncEngine", "ConflictResolver", "CloudStorage", "OfflineQueue", "DeltaEncoder"],
    desc: "(Phase 2 only.) Pluggable sync — Supabase for launch, designed for swap. Sends delta-encoded .ink diffs, not full snapshots. An offline queue persists all changes when connectivity is absent.",
    points: [
      "AuthService: email + Google SSO via Supabase Auth — entirely opt-in, app works without it",
      "SyncEngine: bidirectional sync with three-way merge strategy (base + local + remote)",
      "DeltaEncoder: identifies changed stroke segments and sends only those, not full page files",
      "OfflineQueue: SQLite-backed action log — replays on reconnect with idempotent operations",
      "ConflictResolver: last-write-wins for metadata; stroke-level merge for concurrent annotations",
      "Interface-abstracted sync layer — swapping Supabase for Firebase or self-hosted requires only one class change",
    ],
  },
];

const STACK = [
  { cat: "Framework", tech: "Flutter 3.x + Dart 3", why: "Cross-platform from day one (Android → iOS → Web later). GPU-accelerated Skia/Impeller renderer. 120fps canvas capable. Saber proves this stack works in production for note apps.", p: "critical" },
  { cat: "Stylus Input", tech: "Listener (raw PointerEvents)", why: "Bypasses GestureDetector entirely — captures native-rate events (up to 240Hz on some Android devices). PointerId discrimination enables palm rejection logic.", p: "critical" },
  { cat: "Stroke Rendering", tech: "perfect_freehand ^2.5.1", why: "MIT-licensed. Maps pressure → width in real time. The same algorithm used in Excalidraw and Notability. Saber ships it at v2.5.1 — validated in production.", p: "critical" },
  { cat: "Canvas", tech: "CustomPainter + Flutter Canvas", why: "Full GPU-accelerated 2D drawing control. RepaintBoundary for per-layer caching. No intermediate rendering framework needed between our code and the GPU.", p: "critical" },
  { cat: "GPU Renderer", tech: "Flutter Impeller", why: "Replaces Skia on Android 28+. Eliminates shader compilation jank (the primary cause of first-draw stutters). Enable via AndroidManifest metadata flag.", p: "critical" },
  { cat: "State", tech: "Riverpod 2.x", why: "Compile-safe providers, no BuildContext dependency, excellent DX. AutoDispose prevents memory leaks in a canvas that holds thousands of stroke points.", p: "high" },
  { cat: "Database", tech: "Isar 3.x", why: "Embedded, schema-first, Dart-native, 5–10x faster than Hive. Zero-config. Used by Saber in production — battle-tested path.", p: "high" },
  { cat: "Routing", tech: "go_router", why: "Declarative, deep-link-aware, Flutter official. Required for future web/desktop support without refactoring routing.", p: "high" },
  { cat: "DI", tech: "get_it + injectable", why: "Service locator for clean layer separation. Easy to mock in tests — StrokeRepository gets a fake in unit tests, real Isar in integration tests.", p: "high" },
  { cat: "PDF", tech: "pdfx / pdfrx", why: "Native PDF rendering on Android (PDFium) and iOS. Renders pages as Flutter Image objects. Handles multi-hundred-page files with lazy rendering.", p: "medium" },
  { cat: "Image Import", tech: "image_picker + image package", why: "Cross-platform gallery/camera picking. In-memory crop, resize, and compress pipeline without writing temp files.", p: "medium" },
  { cat: "Stroke Storage", tech: "dart_messagepack", why: "~40% smaller than JSON for stroke arrays. Language-agnostic binary format — future iOS client can read .ink files with the same spec.", p: "medium" },
  { cat: "Shapes", tech: "flutter_svg + custom recognizer", why: "SVG rendering for imported/exported vectors. Custom ML-based shape recognizer converts freehand strokes to clean geometry on pen-up.", p: "medium" },
  { cat: "Export / Share", tech: "printing + share_plus", why: "printing renders Flutter widgets to PDF with full vector fidelity. share_plus opens the system share sheet on all platforms.", p: "medium" },
  { cat: "Cloud Sync", tech: "Supabase", why: "Postgres + object storage + auth + realtime in one SDK. Self-hostable. Swap-friendly abstract interface prevents vendor lock-in.", p: "future" },
  { cat: "AI / OCR", tech: "google_ml_kit (on-device)", why: "Handwriting recognition and smart shape detection run entirely on-device. No API costs. Works offline. Privacy-preserving.", p: "future" },
];

const FEATURES = [
  { id: 1, icon: "📄", title: "Unlimited Paper Templates", phase: 1, complexity: "Low", color: C.green, problem: "Squid and CollaNote gate all custom backgrounds behind paywall", approach: "Vector-generated backgrounds via Canvas math. drawLine/drawArc calls — no PNG assets. Infinite colors via full HSL picker." },
  { id: 2, icon: "∞", title: "Truly Infinite Pages", phase: 1, complexity: "Medium", color: C.blue, problem: "Goodnotes: 3 files max. Nebo: 5 pages. CollaNote: 10 pages.", approach: "Each page is an independent StrokePage object. Lazy-load .ink files only when a page is visible. No artificial ceiling." },
  { id: 3, icon: "📖", title: "2-Page Book View", phase: 3, complexity: "Medium", color: C.purple, problem: "Universally absent from every free tier across all competitors", approach: "Row of two CanvasPage widgets sharing a single ToolNotifier. Custom scroll physics simulate a natural page-turn feel." },
  { id: 4, icon: "📎", title: "PDF & Image Import", phase: 4, complexity: "High", color: C.orange, problem: "Goodnotes: 5MB cap free. Squid: no PDF import at all.", approach: "pdfx renders each PDF page to an image (cached). Images become the ImportedContentLayer. No file size cap. User annotates on top." },
  { id: 5, icon: "⚡", title: "< 16ms Stylus Latency", phase: 1, complexity: "High", color: C.red, problem: "Slow rendering pipeline makes writing feel disconnected from the pen", approach: "Raw Listener at 120Hz. RepaintBoundary isolates ActiveStrokeLayer. Impeller GPU renderer. PredictiveRenderer extends stroke ahead of finger." },
  { id: 6, icon: "⬠", title: "Shapes & Vector Art", phase: 5, complexity: "High", color: C.yellow, problem: "Shape tools absent from every free tier", approach: "Freehand-to-shape recognizer on pen-up (circle, rect, line, arrow, triangle). Converts freehand stroke to clean SVG vector. flutter_svg for import." },
  { id: 7, icon: "🖊️", title: "Pressure-Sensitive Pens", phase: 1, complexity: "Medium", color: C.blue, problem: "Most Android apps completely ignore stylus pressure data", approach: "perfect_freehand maps raw pressure (0.0–1.0) to stroke width and opacity. Multiple pen types (ballpoint, fountain, brush) each have distinct pressure curves." },
  { id: 8, icon: "🎨", title: "Unlimited Colors & Opacity", phase: 1, complexity: "Low", color: C.green, problem: "CollaNote/Squid limit free color palette to ~10 choices", approach: "Full HSL and RGB pickers. Per-stroke color and opacity. Color history swatch row. Zero limits on custom colors." },
  { id: 9, icon: "〰️", title: "Stroke Stabilisation", phase: 2, complexity: "Medium", color: C.purple, problem: "Stabilisation (gyro correction) locked behind premium in all apps", approach: "Three levels: Raw (native), Balanced (Catmull-Rom), Smooth (Catmull-Rom + moving average pre-filter). Set per pen type." },
  { id: 10, icon: "⭕", title: "Lasso Select & Move", phase: 5, complexity: "High", color: C.red, problem: "Advanced selection universally gated behind premium tier", approach: "Freehand lasso → path hit-test against all stroke segments. Selected strokes move into a draggable overlay layer. Move, scale, rotate, delete." },
  { id: 11, icon: "💧", title: "Watermark-Free Export", phase: 2, complexity: "Low", color: C.green, problem: "Goodnotes watermarks all free-tier exports with its logo", approach: "Export to PNG, PDF, and SVG is always free and always clean. share_plus opens system share sheet without any branding." },
  { id: 12, icon: "📵", title: "Fully Offline & No Account", phase: 1, complexity: "Low", color: C.blue, problem: "Notability gates iCloud sync behind $19.99/yr paywall", approach: "100% local-first using Isar + .ink files. Cloud sync is opt-in in Phase 2. The app is complete and useful without ever signing in." },
];

const ROADMAP = [
  {
    phase: 0, title: "Study & Foundation", weeks: "Wk 1–2", color: C.blue,
    deliverable: "Flutter project scaffolded, Saber architecture understood, Isar schemas defined",
    tasks: [
      "Install Flutter SDK, Android Studio, enable developer mode on a physical Android device",
      "Clone saber-notes/saber — read StrokeManager, canvas layer files, data/storage paths",
      "Map Saber's folder structure: identify which patterns to replicate, which to improve",
      "Create fresh Flutter project (NOT a fork — avoids GPL-3 viral copyleft for commercial use)",
      "Add core dependencies: Riverpod, Isar, go_router, perfect_freehand, get_it, injectable",
      "Define Clean Architecture folder structure (feature-first, described in Tech Stack tab)",
      "Author Isar schemas: Notebook, NotePage, and StrokeMetadata models with indexes",
      "Write failing unit tests for Notebook CRUD (TDD from day one)",
    ],
  },
  {
    phase: 1, title: "Core Canvas Engine", weeks: "Wk 3–6", color: C.green,
    deliverable: "Create notes, write with a pressure-sensitive pen, undo/redo, save locally, load across restarts",
    tasks: [
      "HomeScreen: notebook grid backed by Isar, create / rename / delete notebooks",
      "NoteEditor: full-screen CustomPainter canvas shell with proper aspect ratio",
      "Listener-based input pipeline — raw PointerEvents, no GestureDetector",
      "perfect_freehand integration with pressure support from Android MotionEvent",
      "Catmull-Rom spline smoothing between input sample points",
      "RepaintBoundary layer isolation: StrokeHistoryLayer (cached) vs. ActiveStrokeLayer (live)",
      "Command pattern UndoRedoStack: StrokeAddCommand and EraseCommand",
      "Pen + Eraser tools with inline color picker and size slider",
      "Local persistence: write .ink MessagePack files on stroke commit, read on editor open",
    ],
  },
  {
    phase: 2, title: "Templates & Export", weeks: "Wk 7–8", color: C.yellow,
    deliverable: "Any paper color and background template; clean PNG/PDF exports; stabilisation levels",
    tasks: [
      "Vector template engine: blank, ruled, grid, dot grid, isometric, hexagonal, music staff",
      "Background color picker with full HSL spectrum and dark mode canvas support",
      "Ink inversion algorithm: strokes drawn in dark mode invert gracefully on light backgrounds",
      "StabilisationEngine: Raw / Balanced (Catmull-Rom) / Smooth (+ moving average), set per tool",
      "ExportEngine: Canvas.toImage() → PNG; printing package for vector-quality PDF",
      "share_plus integration for one-tap sharing to any Android app",
    ],
  },
  {
    phase: 3, title: "Multi-Page & Book View", weeks: "Wk 9–10", color: C.purple,
    deliverable: "Unlimited pages per notebook; insert/delete/reorder; 2-page book view working",
    tasks: [
      "NotePage schema in Isar — Notebook has a 1:N relationship to NotePage objects",
      "PageNavigator widget: thumbnail strip at the bottom of NoteEditor, swipeable",
      "Lazy-load .ink files per page — only load current page ±1 neighbour into memory",
      "Insert, delete, and drag-to-reorder pages in the thumbnail strip",
      "2-page BookView screen: Row containing two CanvasPage instances",
      "Custom PageTurnScrollPhysics with spring animation for natural feel",
    ],
  },
  {
    phase: 4, title: "PDF & Image Import", weeks: "Wk 11–14", color: C.orange,
    deliverable: "Import any PDF (any size) or image, annotate on top, cache managed automatically",
    tasks: [
      "PDFService: integrate pdfx — open document, get page count, render page N to Image at 2x DPI",
      "Import wizard: PDF → one note page per PDF page, ImportedContentLayer populated",
      "Image import from gallery and camera via image_picker — crop and resize UI",
      "ImportedContentLayer in canvas stack: locked below user strokes, not included in lasso selection",
      "Free-element image placement: tap-to-place, drag corners to resize, two-finger rotate",
      "Progressive loading for large PDFs: render pages on demand, LRU cache with 200MB limit",
      "CacheManager: thumbnail rendering pipeline for the page navigator strip",
    ],
  },
  {
    phase: 5, title: "Shapes & Selection", weeks: "Wk 15–18", color: C.red,
    deliverable: "Full shape toolbox, lasso selection and transform, text boxes, SVG import",
    tasks: [
      "ShapeLayer in canvas stack — sits above StrokeHistoryLayer, below SelectionLayer",
      "Basic shape tools: line, arrow, circle, rectangle, triangle, polygon",
      "Freehand-to-shape recogniser: on pen-up, classify stroke geometry and snap to clean vector",
      "LassoTool: draw freehand path → hit-test all stroke and shape segments → build selection set",
      "SelectionController: move, uniform scale, free rotate, and delete the active selection",
      "TextBox tool: tap on canvas to create, type via keyboard, set font/size/color",
      "SVG import via flutter_svg and file_picker — renders as a shape element with handles",
    ],
  },
  {
    phase: 6, title: "Performance & Launch Prep", weeks: "Wk 19–21", color: C.blue,
    deliverable: "App live on Google Play; 120fps consistent on flagship devices; onboarding complete",
    tasks: [
      "TileManager: pre-render off-screen page regions as Flutter Pictures for large notebooks",
      "Enable Flutter Impeller renderer in AndroidManifest — benchmark on target devices",
      "Memory profiler pass: eliminate leaks in canvas layer stack, PDF cache, stroke storage",
      "UI polish: page-turn animations, toolbar slide transitions, haptic feedback on tool change",
      "Accessibility: semantic labels on all interactive elements, minimum 4.5:1 contrast ratios",
      "App icon, splash screen (no-op, Impeller starts fast), onboarding flow (3 screens max)",
      "Google Play Store listing: screenshots, feature graphic, description, privacy policy",
      "Internal testing track → closed beta with ~20 testers → open production release",
    ],
  },
  {
    phase: 7, title: "Sync & AI (Post-Launch)", weeks: "Wk 22+", color: C.textSub,
    deliverable: "Optional cloud sync live; handwriting OCR; iOS beta available",
    tasks: [
      "Supabase integration: auth (email + Google), Postgres metadata, object storage for .ink files",
      "SyncEngine: bidirectional delta sync with three-way merge and idempotent operations",
      "OfflineQueue: SQLite-backed action log — replays changes reliably on reconnect",
      "Handwriting recognition via ML Kit Digital Ink (on-device, Devanagari + Latin + Arabic)",
      "Smart shape detection: replace rule-based recogniser with ML Kit shape classifier",
      "Audio recording with stroke-timeline timestamps using the record package",
      "iOS port: Flutter makes this less than two weeks of platform-specific plumbing work",
    ],
  },
];

const CANVAS_LAYERS = [
  { n: "Layer 0", label: "BackgroundLayer", hot: false, note: "Vector templates + paper colour — never repaints during drawing sessions" },
  { n: "Layer 1", label: "ImportedContentLayer", hot: false, note: "PDF pages and images — locked, repaints only on page load or scroll" },
  { n: "Layer 2", label: "StrokeHistoryLayer", hot: false, note: "All completed strokes, cached as a Flutter Picture — fast GPU-side repaint" },
  { n: "Layer 3 🔴", label: "ActiveStrokeLayer", hot: true, note: "The live in-progress stroke only — the hot path, repaints every ~8ms at 120Hz" },
  { n: "Layer 4", label: "ShapeLayer", hot: false, note: "Vector shapes and text boxes — repaints only when a shape is modified" },
  { n: "Layer 5", label: "SelectionLayer", hot: false, note: "Selection handles and bounding box — top of stack, UI overlay" },
];

// ── MICRO-COMPONENTS ─────────────────────────────────────────────────
function Badge({ label, color = C.textSub }) {
  return (
    <span style={{ padding: "2px 8px", border: `1px solid ${color}50`, background: `${color}15`, borderRadius: 4, fontSize: 10, fontWeight: 700, color, letterSpacing: "0.08em", textTransform: "uppercase", whiteSpace: "nowrap", fontFamily: "inherit" }}>
      {label}
    </span>
  );
}

function Tag({ text, color = C.textSub }) {
  return (
    <span style={{ padding: "2px 7px", background: `${color}15`, borderRadius: 3, fontSize: 10, color, fontFamily: "'JetBrains Mono', monospace", border: `1px solid ${color}25` }}>
      {text}
    </span>
  );
}

function SectionLabel({ children }) {
  return (
    <div style={{ fontSize: 9, fontWeight: 700, letterSpacing: "0.18em", textTransform: "uppercase", color: C.textMuted, marginBottom: 12, paddingBottom: 8, borderBottom: `1px solid ${C.border}` }}>
      {children}
    </div>
  );
}

const priorityBadge = {
  critical: { label: "Critical", col: C.red },
  high: { label: "High", col: C.blue },
  medium: { label: "Medium", col: C.yellow },
  future: { label: "Future", col: C.textMuted },
};

const complexityColor = { Low: C.green, Medium: C.yellow, High: C.red };

// ── OVERVIEW TAB ─────────────────────────────────────────────────────
function OverviewTab() {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      {/* Hero */}
      <div style={{ background: "linear-gradient(135deg,rgba(88,166,255,.07) 0%,rgba(63,185,80,.04) 100%)", border: `1px solid ${C.borderHover}`, borderRadius: 12, padding: 28, position: "relative", overflow: "hidden" }}>
        <div style={{ position: "absolute", top: -80, right: -80, width: 320, height: 320, background: `radial-gradient(circle, ${C.blue}12 0%, transparent 70%)`, pointerEvents: "none" }} />
        <div style={{ fontSize: 9, letterSpacing: "0.22em", textTransform: "uppercase", color: C.blue, marginBottom: 6, fontWeight: 700 }}>Architecture Blueprint v1.0</div>
        <div style={{ fontSize: 30, fontWeight: 800, fontFamily: "'Syne', sans-serif", color: C.text, marginBottom: 6, lineHeight: 1.1 }}>InkFlow</div>
        <div style={{ fontSize: 13, color: C.textSub, marginBottom: 24, maxWidth: 560, lineHeight: 1.7 }}>
          Android-first cross-platform note-taking with no artificial limitations. Built on Flutter, architecturally informed by the open-source Saber project — written fresh to stay GPL-3-free.
        </div>
        <div style={{ display: "flex", gap: 28, flexWrap: "wrap" }}>
          {[["7", "Build Phases"], ["21+", "Weeks to Launch"], ["12", "Features Free"], ["< 16ms", "Pen Latency Target"], ["∞", "Pages per Note"]].map(([v, l]) => (
            <div key={l}>
              <div style={{ fontSize: 24, fontWeight: 700, color: C.blue, lineHeight: 1 }}>{v}</div>
              <div style={{ fontSize: 10, color: C.textSub, marginTop: 4 }}>{l}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Three pillars */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 10 }}>
        {[
          { color: C.green, icon: "🚫", title: "Zero Artificial Limits", body: "Unlimited pages, templates, colors, PDF imports, and clean exports. Nothing locked behind a paywall that costs the developer negligible server resources." },
          { color: C.blue, icon: "⚡", title: "Performance-First Canvas", body: "Sub-16ms pen latency via a layered RepaintBoundary architecture, 120Hz raw input capture, PredictiveRenderer, and Flutter's Impeller GPU backend." },
          { color: C.purple, icon: "🧱", title: "Modular Clean Architecture", body: "Feature-first folder structure with distinct Presentation, Domain, and Data layers. Each piece is independently testable, replaceable, and understandable." },
        ].map(p => (
          <div key={p.title} style={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 10, padding: 18 }}>
            <div style={{ fontSize: 22, marginBottom: 8 }}>{p.icon}</div>
            <div style={{ fontSize: 12, fontWeight: 700, color: p.color, marginBottom: 6 }}>{p.title}</div>
            <div style={{ fontSize: 11, color: C.textSub, lineHeight: 1.7 }}>{p.body}</div>
          </div>
        ))}
      </div>

      {/* Saber reference box */}
      <div style={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 10, padding: 18 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 10, flexWrap: "wrap" }}>
          <div style={{ fontSize: 12, fontWeight: 700, color: C.text }}>📂 Reference Codebase Confirmed: saber-notes/saber</div>
          <Badge label="GPL-3 Licensed" color={C.yellow} />
          <Badge label="Flutter + Dart" color={C.blue} />
          <Badge label="perfect_freehand v2.5.1" color={C.green} />
        </div>
        <div style={{ fontSize: 12, color: C.textSub, lineHeight: 1.8, marginBottom: 12 }}>
          ChatGPT identified <strong style={{ color: C.text }}>Saber</strong> (github.com/saber-notes/saber) — a production-quality Flutter handwriting app with stroke rendering, multi-page notebooks, PDF import, and Nextcloud sync. Its pubspec confirms it already ships <code style={{ color: C.green, background: `${C.green}15`, padding: "0 4px", borderRadius: 3 }}>perfect_freehand: ^2.5.1</code>, validating the entire rendering stack choice.
        </div>
        <div style={{ padding: 12, background: `${C.yellow}08`, border: `1px solid ${C.yellow}30`, borderRadius: 8 }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: C.yellow, marginBottom: 6 }}>⚠️ License Strategy — Important</div>
          <div style={{ fontSize: 11, color: C.textSub, lineHeight: 1.8 }}>
            Saber is GPL-3: forking it forces your entire app to be GPL-3 (viral copyleft), meaning competitors can fork and redistribute your commercial product. The correct approach is to <strong style={{ color: C.text }}>study Saber's architecture, then build from scratch</strong>. Reading source code for learning is universally legal. Writing your own implementation informed by Saber's patterns — without copying its code — produces a clean commercial product with zero GPL obligations. Every package in our tech stack is MIT or Apache-2 licensed.
          </div>
        </div>
      </div>

      {/* What we unlock */}
      <div style={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 10, padding: 18 }}>
        <SectionLabel>Features Unlocked Free (paywalled in competitors)</SectionLabel>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: 0 }}>
          {[
            ["Unlimited pages per notebook", "Goodnotes: 3 files • Nebo: 5 pages • CollaNote: 10 pages"],
            ["All paper templates & colors", "Squid: all custom backgrounds paywalled"],
            ["PDF import with no size cap", "Goodnotes: 5MB cap • Squid: no PDF at all"],
            ["Watermark-free export", "Goodnotes watermarks all free-tier exports"],
            ["2-page side-by-side book view", "Absent from every free tier in the market"],
            ["Stroke stabilisation", "Premium feature in Notability, CollaNote, and Nebo"],
            ["Lasso selection and transform", "Universally gated behind premium tiers"],
            ["Fully offline — no account needed", "Notability: iCloud sync costs $19.99/yr"],
          ].map(([f, n]) => (
            <div key={f} style={{ display: "flex", gap: 8, padding: "9px 0", borderBottom: `1px solid ${C.border}`, alignItems: "flex-start" }}>
              <span style={{ color: C.green, fontSize: 11, marginTop: 2, flexShrink: 0 }}>✓</span>
              <div>
                <div style={{ fontSize: 12, color: C.text, fontWeight: 500 }}>{f}</div>
                <div style={{ fontSize: 10, color: C.textMuted, marginTop: 1 }}>{n}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ── TECH STACK TAB ────────────────────────────────────────────────────
function StackTab() {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 0 }}>
      <div style={{ display: "grid", gridTemplateColumns: "130px 190px 1fr 74px", gap: 12, padding: "8px 0 12px", borderBottom: `1px solid ${C.border}`, fontSize: 9, fontWeight: 700, letterSpacing: "0.12em", textTransform: "uppercase", color: C.textMuted }}>
        <span>Category</span><span>Technology</span><span>Rationale</span><span>Priority</span>
      </div>
      {STACK.map(s => {
        const pb = priorityBadge[s.p];
        return (
          <div key={s.tech} style={{ display: "grid", gridTemplateColumns: "130px 190px 1fr 74px", gap: 12, padding: "11px 0", borderBottom: `1px solid ${C.border}`, alignItems: "start" }}>
            <span style={{ fontSize: 11, color: C.textSub, fontWeight: 500, paddingTop: 1 }}>{s.cat}</span>
            <span style={{ fontSize: 11, fontWeight: 700, color: C.text, fontFamily: "'JetBrains Mono', monospace" }}>{s.tech}</span>
            <span style={{ fontSize: 11, color: C.textSub, lineHeight: 1.65 }}>{s.why}</span>
            <div><Badge label={pb.label} color={pb.col} /></div>
          </div>
        );
      })}

      {/* Folder structure */}
      <div style={{ marginTop: 24, background: C.surface, border: `1px solid ${C.border}`, borderRadius: 10, padding: 20 }}>
        <SectionLabel>Flutter Project Folder Structure (Clean / Feature-First Architecture)</SectionLabel>
        <pre style={{ fontSize: 10.5, color: C.textSub, lineHeight: 1.85, margin: 0, fontFamily: "'JetBrains Mono', 'Cascadia Code', monospace", overflowX: "auto" }}>{`lib/
├── main.dart                        # Entry: ProviderScope, Isar init, runApp
├── app/
│   ├── app.dart                     # MaterialApp, ThemeData, go_router
│   └── router.dart                  # Route tree: /, /note/:id, /note/:id/book-view
│
├── core/
│   ├── constants/                   # App-wide colours, sizes, durations
│   ├── utils/                       # Dart extensions, date formatters, maths helpers
│   └── theme/                       # ThemeData builder, ColorScheme, TextTheme
│
├── features/
│   ├── home/                        # Notebook grid, search, tags
│   │   ├── presentation/screens/    # HomeScreen.dart
│   │   ├── domain/models/           # Notebook.dart (Isar schema)
│   │   └── data/repositories/       # NoteRepository (Isar CRUD)
│   │
│   ├── editor/                      # The full canvas experience
│   │   ├── presentation/
│   │   │   ├── screens/             # NoteEditorScreen.dart, BookViewScreen.dart
│   │   │   ├── widgets/             # ToolBar, PageNavigator, TemplateSelector
│   │   │   └── canvas/
│   │   │       ├── layers/          # BackgroundLayer, StrokeHistoryLayer, ActiveStrokeLayer...
│   │   │       ├── input/           # RawPointerListener, StylusProcessor, StrokeBuilder
│   │   │       └── shapes/          # ShapeEngine, LassoTool, SelectionController
│   │   ├── domain/
│   │   │   ├── models/              # Stroke.dart, StrokePage.dart, ShapeElement.dart
│   │   │   ├── services/            # TemplateService, StabilisationEngine
│   │   │   └── undo_redo/           # UndoRedoStack, Command<T> interface + implementations
│   │   └── data/
│   │       ├── repositories/        # StrokeRepository, PageRepository
│   │       └── storage/             # InkFileStorage (.ink read/write with MessagePack)
│   │
│   ├── import/                      # PDF + image import pipeline
│   │   ├── pdf_service.dart         # pdfx wrapper: openDoc, renderPage, cacheManager
│   │   └── image_service.dart       # image_picker + crop/compress helpers
│   │
│   ├── export/                      # PNG / PDF / SVG export
│   │   └── export_engine.dart       # Canvas rasterisation + printing package
│   │
│   └── settings/                    # User preferences, theme toggle, about
│
└── shared/
    ├── widgets/                     # Reusable: ColorPicker, ConfirmDialog, LoadingOverlay
    └── isar/                        # Isar instance singleton + schema collection list`}
        </pre>
      </div>
    </div>
  );
}

// ── ARCHITECTURE TAB ──────────────────────────────────────────────────
function ArchitectureTab() {
  const [sel, setSel] = useState("ui");
  const selected = LAYERS.find(l => l.id === sel);

  return (
    <div style={{ display: "grid", gridTemplateColumns: "220px 1fr", gap: 14 }}>
      {/* Layer list */}
      <div style={{ display: "flex", flexDirection: "column", gap: 3 }}>
        <div style={{ fontSize: 9, fontWeight: 700, color: C.textMuted, letterSpacing: "0.14em", textTransform: "uppercase", padding: "0 0 8px" }}>Click a layer</div>
        {LAYERS.map(l => (
          <div key={l.id} onClick={() => setSel(l.id)} style={{ padding: "11px 13px", borderRadius: 8, cursor: "pointer", background: sel === l.id ? `${l.color}12` : "transparent", border: `1px solid ${sel === l.id ? `${l.color}45` : C.border}`, transition: "all 0.12s" }}>
            <div style={{ fontSize: 8, color: l.color, fontWeight: 700, letterSpacing: "0.14em", marginBottom: 2 }}>LAYER {l.no}</div>
            <div style={{ fontSize: 12, fontWeight: 600, color: sel === l.id ? l.color : C.text }}>{l.title}</div>
            <div style={{ fontSize: 9, color: C.textMuted, marginTop: 2 }}>{l.tech.split(" — ")[0]}</div>
          </div>
        ))}
        <div style={{ textAlign: "center", padding: "10px 0", color: C.textMuted, fontSize: 10, letterSpacing: "0.05em" }}>↕ bidirectional data flow</div>
      </div>

      {/* Detail panel */}
      {selected && (
        <div style={{ background: C.surface, border: `1px solid ${selected.color}30`, borderRadius: 12, padding: 22, display: "flex", flexDirection: "column", gap: 16 }}>
          <div>
            <div style={{ fontSize: 9, color: selected.color, fontWeight: 700, letterSpacing: "0.16em", textTransform: "uppercase", marginBottom: 5 }}>Layer {selected.no}</div>
            <div style={{ fontSize: 20, fontWeight: 800, fontFamily: "'Syne', sans-serif", color: C.text, marginBottom: 8 }}>{selected.title}</div>
            <div style={{ display: "inline-block", fontSize: 10, color: selected.color, padding: "3px 10px", background: `${selected.color}10`, borderRadius: 4, border: `1px solid ${selected.color}25`, marginBottom: 12 }}>{selected.tech}</div>
            <p style={{ fontSize: 12, color: C.textSub, lineHeight: 1.8, margin: 0 }}>{selected.desc}</p>
          </div>

          <div>
            <SectionLabel>Modules / Classes</SectionLabel>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
              {selected.modules.map(m => <Tag key={m} text={m} color={selected.color} />)}
            </div>
          </div>

          <div>
            <SectionLabel>Implementation Notes</SectionLabel>
            {selected.points.map(p => (
              <div key={p} style={{ display: "flex", gap: 10, padding: "7px 0", borderBottom: `1px solid ${C.border}`, alignItems: "flex-start" }}>
                <span style={{ color: selected.color, fontSize: 12, marginTop: 1, flexShrink: 0 }}>›</span>
                <span style={{ fontSize: 12, color: C.textSub, lineHeight: 1.65 }}>{p}</span>
              </div>
            ))}
          </div>

          {/* Special sub-diagram for canvas layer */}
          {selected.id === "canvas" && (
            <div>
              <SectionLabel>Canvas Layer Stack (bottom → top)</SectionLabel>
              <div style={{ background: C.bg, borderRadius: 8, border: `1px solid ${C.border}`, overflow: "hidden" }}>
                {CANVAS_LAYERS.map((row, i) => (
                  <div key={row.label} style={{ display: "grid", gridTemplateColumns: "72px 190px 1fr", gap: 10, padding: "8px 12px", background: row.hot ? `${C.red}12` : i % 2 === 0 ? "rgba(255,255,255,0.01)" : "transparent", borderBottom: i < CANVAS_LAYERS.length - 1 ? `1px solid ${C.border}` : "none", alignItems: "center" }}>
                    <span style={{ fontSize: 10, color: C.textMuted }}>{row.n}</span>
                    <span style={{ fontSize: 10, fontFamily: "'JetBrains Mono', monospace", color: row.hot ? C.red : C.green, fontWeight: 600 }}>{row.label}</span>
                    <span style={{ fontSize: 11, color: C.textSub, lineHeight: 1.5 }}>{row.note}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ── FEATURES TAB ──────────────────────────────────────────────────────
function FeaturesTab() {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
      <div style={{ fontSize: 12, color: C.textSub, marginBottom: 4 }}>
        All 12 features are paywalled in competing apps. InkFlow ships them free by design.
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: 10 }}>
        {FEATURES.map(f => (
          <div key={f.id} style={{ background: C.surface, border: `1px solid ${C.border}`, borderRadius: 10, padding: 16, display: "flex", flexDirection: "column", gap: 9 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
              <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
                <span style={{ fontSize: 18, lineHeight: 1 }}>{f.icon}</span>
                <div>
                  <div style={{ fontSize: 12, fontWeight: 700, color: f.color }}>{f.title}</div>
                  <div style={{ fontSize: 9, color: C.textMuted, marginTop: 2 }}>Phase {f.phase}</div>
                </div>
              </div>
              <Badge label={f.complexity} color={complexityColor[f.complexity]} />
            </div>
            <div style={{ fontSize: 11, color: C.textSub, padding: "6px 8px", background: `${C.red}08`, borderRadius: 4, borderLeft: `2px solid ${C.red}40` }}>
              ❌ {f.problem}
            </div>
            <div style={{ fontSize: 11, color: C.textSub, lineHeight: 1.65 }}>
              <strong style={{ color: C.text }}>→ </strong>{f.approach}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── ROADMAP TAB ───────────────────────────────────────────────────────
function RoadmapTab() {
  const [open, setOpen] = useState(0);
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
      {ROADMAP.map(r => (
        <div key={r.phase} style={{ border: `1px solid ${open === r.phase ? `${r.color}40` : C.border}`, borderRadius: 10, overflow: "hidden" }}>
          <div onClick={() => setOpen(open === r.phase ? -1 : r.phase)} style={{ display: "flex", alignItems: "center", gap: 14, padding: "13px 16px", cursor: "pointer", background: open === r.phase ? `${r.color}06` : C.surface, transition: "background 0.12s" }}>
            <div style={{ width: 30, height: 30, borderRadius: 7, background: `${r.color}18`, border: `1px solid ${r.color}35`, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
              <span style={{ fontSize: 11, fontWeight: 700, color: r.color }}>{r.phase}</span>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, fontWeight: 700, color: r.phase === 7 ? C.textSub : C.text }}>{r.title}</div>
              <div style={{ fontSize: 9, color: C.textMuted, marginTop: 1 }}>{r.weeks}</div>
            </div>
            <div style={{ fontSize: 11, color: C.textSub, maxWidth: 280, textAlign: "right", display: "none" }}>{r.deliverable}</div>
            <div style={{ color: C.textMuted, fontSize: 12 }}>{open === r.phase ? "▲" : "▼"}</div>
          </div>
          {open === r.phase && (
            <div style={{ padding: "0 16px 16px", background: `${r.color}03` }}>
              <div style={{ height: 1, background: C.border, marginBottom: 14 }} />
              <div style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: "7px 16px", marginBottom: 14 }}>
                {r.tasks.map((task, i) => (
                  <div key={i} style={{ display: "flex", gap: 8, alignItems: "flex-start" }}>
                    <span style={{ color: r.color, fontSize: 10, marginTop: 3, flexShrink: 0 }}>◈</span>
                    <span style={{ fontSize: 11, color: C.textSub, lineHeight: 1.65 }}>{task}</span>
                  </div>
                ))}
              </div>
              <div style={{ padding: "9px 12px", background: `${r.color}10`, border: `1px solid ${r.color}28`, borderRadius: 6 }}>
                <span style={{ fontSize: 9, fontWeight: 700, color: r.color }}>✓ DELIVERABLE: </span>
                <span style={{ fontSize: 11, color: C.textSub }}>{r.deliverable}</span>
              </div>
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

// ── ROOT APP ──────────────────────────────────────────────────────────
const TABS = [
  { id: "overview", label: "Overview" },
  { id: "stack", label: "Tech Stack" },
  { id: "architecture", label: "Architecture" },
  { id: "features", label: "Features" },
  { id: "roadmap", label: "Roadmap" },
];

export default function App() {
  const [tab, setTab] = useState("overview");

  return (
    <div style={{ fontFamily: "'JetBrains Mono', 'SF Mono', 'Cascadia Code', monospace", background: C.bg, color: C.text, minHeight: "100vh", padding: 20, maxWidth: 1080, margin: "0 auto" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;500;600;700&family=Syne:wght@600;700;800&display=swap');
        * { box-sizing: border-box; }
        ::-webkit-scrollbar { width: 5px; height: 5px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: #30363d; border-radius: 3px; }
      `}</style>

      {/* Header */}
      <div style={{ display: "flex", alignItems: "center", gap: 14, marginBottom: 20 }}>
        <div style={{ fontSize: 8, fontWeight: 700, letterSpacing: "0.24em", color: C.textMuted, textTransform: "uppercase", whiteSpace: "nowrap" }}>
          InkFlow / Architecture
        </div>
        <div style={{ height: 1, flex: 1, background: C.border }} />
        <div style={{ fontSize: 8, color: C.textMuted, whiteSpace: "nowrap" }}>Flutter · Android-First · v0.0.1</div>
      </div>

      {/* Tab nav */}
      <div style={{ display: "flex", gap: 2, marginBottom: 18, background: C.surface, padding: 4, borderRadius: 10, border: `1px solid ${C.border}` }}>
        {TABS.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)} style={{ flex: 1, padding: "8px 10px", borderRadius: 7, border: "none", cursor: "pointer", background: tab === t.id ? C.blue : "transparent", color: tab === t.id ? "#fff" : C.textSub, fontSize: 11, fontWeight: 600, fontFamily: "inherit", transition: "all 0.12s" }}>
            {t.label}
          </button>
        ))}
      </div>

      {/* Content */}
      {tab === "overview" && <OverviewTab />}
      {tab === "stack" && <StackTab />}
      {tab === "architecture" && <ArchitectureTab />}
      {tab === "features" && <FeaturesTab />}
      {tab === "roadmap" && <RoadmapTab />}
    </div>
  );
}
