# InkFlow — Book View Bug Fix & Redesign Prompt
## For: Google Antigravity IDE (Gemini Agent)

---

## 0. AGENT PERSONA

**Senior Software Engineer:** Diagnose root causes from source code, not symptoms. Every fix
must be traced to the exact file and line causing the problem. No speculative changes.

**QA Engineer:** After each fix, verify both the happy path AND the regression case (does the
fix break anything that was working before). Run `flutter analyze` after every file change.
Zero new warnings permitted.

**UI/UX Professional:** The Book View must feel like a physical book — shadows, spine depth,
paper warmth, page-turn animation. Reference: how Apple Books or Kindle look when reading.
All colours from `AppColors` only. Zero hardcoded hex values in new code.

---

## 1. FULL BUG INVENTORY — READ EVERY ITEM BEFORE WRITING ANY CODE

There are **6 confirmed bugs**. They are diagnosed below with the exact root cause extracted
from the source code. Fix them in the order listed — they have dependencies.

---

### BUG 1 (CRITICAL) — Spread Calculation Off-by-One
**File:** `lib/features/editor/presentation/book_view_notifier.dart`

**Root cause (exact code):**
```dart
List<int> calculateSpreadPages(int spreadIndex) {
  final left = spreadIndex * 2 - 1;   // ← BUG: spread 0 → left = -1 (empty slot)
  final right = spreadIndex * 2;       // ← BUG: spread 0 → right = 0 (Page 1 alone)
  return [left, right];
}
```
The formula implements a "cover page alone" model:
- Spread 0 → [-1, 0] → renders only Page 1 on the right (no left page)
- Spread 1 → [1, 2] → renders Page 2 left, Page 3 right ← **this is what the screenshot shows**

The user wants a straightforward model: Spread 0 = Pages 1 & 2, Spread 1 = Pages 3 & 4.

**Also broken in `nextSpread()`:**
```dart
final maxSpread = state.totalPages ~/ 2;   // ← BUG: 8 pages → maxSpread=4, but only 4 spreads exist (0-3)
```

**Also broken in `jumpToPage()`:**
```dart
final targetSpread = (pageIndex + 1) ~/ 2;  // ← BUG: page 0 → spread 0, page 1 → spread 1
// Should be: pageIndex ~/ 2 → page 0 → spread 0, page 1 → spread 0
```

**Also broken in `BookSpreadNavBar`:**
```dart
Text('Spread ${bookViewState.currentSpread} / $maxSpread')
// Shows "Spread 0 / 3" instead of "Spread 1 / 4" (1-indexed for user display)
```

**The complete fix:**
```dart
// In BookViewNotifier:

List<int> calculateSpreadPages(int spreadIndex) {
  final left = spreadIndex * 2;           // spread 0 → 0, spread 1 → 2
  final right = spreadIndex * 2 + 1;      // spread 0 → 1, spread 1 → 3
  return [left, right];
}

void nextSpread() {
  final maxSpread = (state.totalPages - 1) ~/ 2;   // 8 pages → 3, 7 pages → 3, 1 page → 0
  if (state.currentSpread < maxSpread) {
    state = BookViewState(
      currentSpread: state.currentSpread + 1,
      totalPages: state.totalPages,
    );
  }
}

void previousSpread() {
  if (state.currentSpread > 0) {
    state = BookViewState(
      currentSpread: state.currentSpread - 1,
      totalPages: state.totalPages,
    );
  }
}

void jumpToPage(int pageIndex) {
  if (pageIndex < 0 || pageIndex >= state.totalPages) return;
  final targetSpread = pageIndex ~/ 2;    // page 0,1 → spread 0; page 2,3 → spread 1
  if (targetSpread != state.currentSpread) {
    state = BookViewState(
      currentSpread: targetSpread,
      totalPages: state.totalPages,
    );
  }
}

// In BookSpreadNavBar — display as 1-indexed:
Text('Spread ${bookViewState.currentSpread + 1} / ${(bookViewState.totalPages / 2).ceil()}')
```

**Regression check after this fix:** With 4 pages, spread 0 shows Pages 1&2, spread 1 shows Pages 3&4. Forward button disabled at spread 1. Back button disabled at spread 0.

---

### BUG 2 (CRITICAL) — Paper Color Hardcoded to White
**File 1:** `lib/features/editor/presentation/screens/book_view_screen.dart` — `EditablePagePane`

**Root cause (exact code):**
```dart
// In EditablePagePane.build():
child: Container(
  color: Colors.white,    // ← HARDCODED: ignores all user colour selections
  child: CanvasWidget(
    ...
    templateType: toolState.template,
    // backgroundColor NOT passed — defaults to Colors.white in CanvasWidget
  ),
),
```

**File 2:** `lib/features/home/domain/models/notebook.dart`

**Root cause:** `Notebook` has no `backgroundColor` field. There is nowhere to persist the
paper colour the user selected. `toolProvider` holds `template` but no `backgroundColor`.

**The complete fix — two parts:**

**Part A: Add backgroundColor to Notebook Isar schema.**
In `lib/features/home/domain/models/notebook.dart`, add ONE field:
```dart
int backgroundColor = 0xFFFFFFFF;   // Default: white. ARGB int. 0xFFF5E6C8 = warm paper.
```
After adding: `dart run build_runner build --delete-conflicting-outputs`
Wait for `.g.dart` regeneration before continuing.

**Part B: Thread backgroundColor through the widget chain.**
The chain is: `Notebook.backgroundColor` → `BookViewScreen` → `EditablePagePane` → `CanvasWidget` → `BackgroundLayer`.

In `BookViewScreen.build()`:
```dart
// Read notebook from Isar to get backgroundColor
// Add to _BookViewScreenState: Future<Color> _notebookColor = Future.value(Colors.white);
// In initState, after initialize():
//   final notebook = await IsarService.instance.isar.notebooks.get(widget.notebookId);
//   _notebookColor = notebook?.backgroundColor ?? 0xFFFFFFFF;

// Pass to both EditablePagePane instances:
EditablePagePane(
  pageIndex: leftPage,
  notebookId: widget.notebookId,
  backgroundColor: Color(_resolvedBackgroundColor), // new param
  totalPages: totalPages,
  onAutosaveTriggered: _triggerAutosave,
),
```

In `EditablePagePane`:
```dart
// Add parameter:
final Color backgroundColor;

// Replace hardcoded Container color:
Container(
  color: backgroundColor,   // was: Colors.white
  child: CanvasWidget(
    ...
    backgroundColor: backgroundColor,   // ADD this — was missing
    templateType: toolState.template,
  ),
),
```

**Part C: Ensure ToolNotifier persists backgroundColor to Notebook when user changes it.**
When the user changes the paper colour in the editor (from `NoteEditorScreen`), call
`NotebookRepository.updateBackgroundColor(notebookId, color)` to persist it in Isar.
The `BookViewScreen` then reads it on open.

**Regression check:** Open a notebook where you previously set a cream/dark background.
Open Book View. Both pages must show the correct background colour.

---

### BUG 3 (HIGH) — No Physical Book Aesthetics
**File:** `lib/features/editor/presentation/screens/book_view_screen.dart`

**Root cause (exact code):**
```dart
// Spine — too thin, flat gradient
Container(
  width: 20,                    // ← 20dp is too thin. A real book spine is ~30-40dp
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Colors.black.withValues(alpha: 0.25),
        Colors.black.withValues(alpha: 0.5),  // ← just darkening, not realistic
        Colors.black.withValues(alpha: 0.25),
      ],
    ),
  ),
),

// Outer book — no realistic book cover aesthetic
Container(
  ...
  decoration: BoxDecoration(
    color: const Color(0xFF161B22),   // ← flat dark colour, not a book cover
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, ...),
    ],
  ),
  padding: const EdgeInsets.all(8),  // ← 8dp overhang is too small
  ...
),

// EditablePagePane background — no per-page shadow
Container(
  color: Colors.white,   // ← no shadow, no paper texture, pure white
```

**The complete redesign — keep architecture, replace only styling:**

```dart
// 1. OUTER BOOK CONTAINER — realistic hardcover
decoration: BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color(0xFF2C2C2E),   // dark slate top-left
      const Color(0xFF1C1C1E),   // deeper slate bottom-right
    ],
  ),
  borderRadius: const BorderRadius.only(
    topLeft: Radius.circular(4),      // books have small top-left corner
    bottomLeft: Radius.circular(4),
    topRight: Radius.circular(12),
    bottomRight: Radius.circular(12),
  ),
  boxShadow: [
    BoxShadow(                          // ambient shadow
      color: Colors.black.withValues(alpha: 0.6),
      blurRadius: 40,
      spreadRadius: 4,
      offset: const Offset(0, 16),
    ),
    BoxShadow(                          // tight key shadow
      color: Colors.black.withValues(alpha: 0.4),
      blurRadius: 12,
      offset: const Offset(4, 8),
    ),
  ],
),
padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),  // asymmetric: spine side thicker

// 2. PAGE SHADOW WRAPPER — wrap each EditablePagePane in this:
Container(
  decoration: BoxDecoration(
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: 8,
        offset: Offset(isLeftPage ? -2 : 2, 0),   // shadow faces outward on each page
      ),
    ],
  ),
  child: EditablePagePane(...),
),

// 3. SPINE — wider and multi-layer
Container(
  width: 32,
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Color(0xFF000000),         // deep shadow on left page edge
        Color(0xFF3A3A3C),         // spine surface
        Color(0xFF555557),         // spine highlight centre
        Color(0xFF3A3A3C),         // spine surface
        Color(0xFF000000),         // deep shadow on right page edge
      ],
      stops: [0.0, 0.15, 0.5, 0.85, 1.0],
    ),
  ),
),

// 4. PAPER QUALITY — add subtle paper grain to EditablePagePane
// Overlay a very low-opacity noise texture using a CustomPainter that draws
// random 1px dots at ~3% opacity over the page surface.
// This is purely cosmetic — add it as a non-interactive layer BELOW the CanvasWidget.
```

**Warm paper preset:** When `backgroundColor` is the default white (`0xFFFFFFFF`), automatically
substitute `0xFFFAF7F0` (warm cream) for display in Book View only. Do NOT change the stored
value — this is a Book View rendering preference only.

---

### BUG 4 (HIGH) — No Page-Turn Animation
**File:** `lib/features/editor/presentation/screens/book_view_screen.dart`

**Root cause (exact code):**
```dart
// Spread change happens instantly — no animation
onHorizontalDragEnd: (details) {
  if (details.primaryVelocity! > 300) {
    ref.read(bookViewProvider(widget.notebookId).notifier).previousSpread();  // instant
  } else if (details.primaryVelocity! < -300) {
    ref.read(bookViewProvider(widget.notebookId).notifier).nextSpread();       // instant
  }
},
```

The book content area also has no transition when the spread index changes.

**The fix — AnimatedSwitcher with directional slide:**

Replace the static spread content with:
```dart
// Add to _BookViewScreenState:
int _previousSpread = 0;
bool _swipingForward = true;

// In the ref.listen for BookViewState spread changes:
ref.listen<BookViewState>(bookViewProvider(widget.notebookId), (previous, next) {
  if (previous != null && previous.currentSpread != next.currentSpread) {
    _swipingForward = next.currentSpread > previous.currentSpread;
    // ... existing save/load logic
  }
});

// Wrap the spread content Row (the two EditablePagePanes + spine) in:
AnimatedSwitcher(
  duration: const Duration(milliseconds: 350),
  transitionBuilder: (child, animation) {
    final slideIn = Tween<Offset>(
      begin: Offset(_swipingForward ? 1.0 : -1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    final slideOut = Tween<Offset>(
      begin: Offset(_swipingForward ? -0.3 : 0.3, 0.0),   // partial exit, not full
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return SlideTransition(
      position: child.key == ValueKey(bookViewState.currentSpread) ? slideIn : slideOut,
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  },
  child: KeyedSubtree(
    key: ValueKey(bookViewState.currentSpread),   // triggers AnimatedSwitcher on change
    child: // ... the existing Row with left pane + spine + right pane
  ),
),
```

**Fix the gesture conflict with canvas drawing:**
The existing `GestureDetector` on the outer layout area captures ALL horizontal drags,
including strokes drawn horizontally on the canvas. Fix: move the swipe detection to
**only the top navigation bar area** (BookSpreadNavBar) and the area outside the page bounds.
Remove `GestureDetector` from around the `LayoutBuilder`. Use the nav bar arrows exclusively.

```dart
// REMOVE the outer GestureDetector wrapping the LayoutBuilder entirely.
// Navigation is handled by:
// 1. The left/right arrow buttons in BookSpreadNavBar
// 2. Left/right edge tap zones added as thin Positioned overlays (48dp wide, full height)
//    that sit OUTSIDE the page area.
Positioned(
  left: 0, top: 0, bottom: 0,
  width: 48,
  child: GestureDetector(
    onTap: () => ref.read(bookViewProvider(widget.notebookId).notifier).previousSpread(),
    child: const SizedBox.expand(),  // transparent tap zone
  ),
),
Positioned(
  right: 0, top: 0, bottom: 0,
  width: 48,
  child: GestureDetector(
    onTap: () => ref.read(bookViewProvider(widget.notebookId).notifier).nextSpread(),
    child: const SizedBox.expand(),
  ),
),
```

---

### BUG 5 (HIGH) — BookSpreadNavBar Has No Thumbnails
**File:** `lib/features/editor/presentation/widgets/book_spread_nav_bar.dart`

**Root cause:** The widget is just a label and two arrow buttons. It has no thumbnails.
```dart
Row(
  children: [
    IconButton(back arrow),
    Text('Spread X / Y'),      // ← just text, no visual page preview
    IconButton(forward arrow),
  ],
)
```

The `ThumbnailCacheManager.getThumbnail()` already works and is used in the main
`PageNavigatorWidget`. This needs to be used here too.

**The complete replacement:**

Completely rebuild `BookSpreadNavBar` as a full-width thumbnail filmstrip. Keep the same
widget name and constructor signature so no callers need changing.

**Design spec:**
- Full-width `Container`, height: 90dp, background: `AppColors.surface`, top border 1dp `AppColors.border`
- Inside: a horizontally scrollable `ListView` of spread thumbnails
- Each thumbnail item represents ONE SPREAD (two mini pages side by side)
- Item width: 80dp, height: 56dp (A4 landscape is ~1.41 ratio, two pages = 2.82)
- Active spread: 2dp `AppColors.accent` border + 4dp elevation effect
- Inactive spread: 1dp `AppColors.border` border
- Tapping a thumbnail calls `bookViewProvider.notifier.jumpToPage(spreadIndex * 2)`
- Auto-scrolls to keep the current spread centred when the spread changes

**Implementation:**
```dart
class BookSpreadNavBar extends ConsumerStatefulWidget {
  final int notebookId;
  const BookSpreadNavBar({super.key, required this.notebookId});

  @override
  ConsumerState<BookSpreadNavBar> createState() => _BookSpreadNavBarState();
}

class _BookSpreadNavBarState extends ConsumerState<BookSpreadNavBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSpread(int spreadIndex) {
    const itemWidth = 80.0 + 8.0; // thumbnail width + margin
    final targetOffset = spreadIndex * itemWidth;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Note: ConsumerState already has ref available
    final bookViewState = ref.watch(bookViewProvider(widget.notebookId));
    final pageState = ref.watch(pageProvider(widget.notebookId));
    final totalPages = pageState.pages.length;
    final totalSpreads = (totalPages / 2).ceil();

    // Auto-scroll when spread changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSpread(bookViewState.currentSpread);
    });

    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Left arrow
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              size: 18,
              color: bookViewState.currentSpread > 0
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
            ),
            onPressed: bookViewState.currentSpread > 0
                ? () => ref.read(bookViewProvider(widget.notebookId).notifier).previousSpread()
                : null,
          ),

          // Thumbnail filmstrip
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: totalSpreads,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, spreadIndex) {
                final leftPageIndex = spreadIndex * 2;
                final rightPageIndex = spreadIndex * 2 + 1;
                final isActive = spreadIndex == bookViewState.currentSpread;

                return GestureDetector(
                  onTap: () => ref
                      .read(bookViewProvider(widget.notebookId).notifier)
                      .jumpToPage(leftPageIndex),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isActive ? AppColors.accent : AppColors.border,
                        width: isActive ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isActive
                          ? [BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              blurRadius: 6,
                            )]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Row(
                        children: [
                          // Left page thumbnail
                          Expanded(
                            child: _SpreadThumbnailHalf(
                              notebookId: widget.notebookId,
                              pageIndex: leftPageIndex,
                              totalPages: totalPages,
                            ),
                          ),
                          // Mini spine
                          Container(
                            width: 2,
                            color: AppColors.border,
                          ),
                          // Right page thumbnail
                          Expanded(
                            child: _SpreadThumbnailHalf(
                              notebookId: widget.notebookId,
                              pageIndex: rightPageIndex,
                              totalPages: totalPages,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Right arrow
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: bookViewState.currentSpread < totalSpreads - 1
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
            ),
            onPressed: bookViewState.currentSpread < totalSpreads - 1
                ? () => ref.read(bookViewProvider(widget.notebookId).notifier).nextSpread()
                : null,
          ),
        ],
      ),
    );
  }
}

// Helper widget for one half of a spread thumbnail
class _SpreadThumbnailHalf extends StatelessWidget {
  final int notebookId;
  final int pageIndex;
  final int totalPages;

  const _SpreadThumbnailHalf({
    required this.notebookId,
    required this.pageIndex,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    if (pageIndex >= totalPages) {
      // Empty page slot — show blank
      return Container(color: const Color(0xFFF0EDE8));
    }
    return FutureBuilder<ui.Image?>(
      future: ThumbnailCacheManager.getThumbnail(notebookId, pageIndex),
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          return RawImage(
            image: snapshot.data,
            fit: BoxFit.cover,
          );
        }
        // Thumbnail not yet generated — show warm placeholder
        return Container(
          color: const Color(0xFFFAF7F0),
          child: const Center(
            child: Icon(Icons.article_outlined, size: 14, color: AppColors.textMuted),
          ),
        );
      },
    );
  }
}
```

---

### BUG 6 (MEDIUM) — Swipe Gesture Conflicts with Canvas Drawing
Already addressed in Bug 4 fix (removing outer GestureDetector and using edge tap zones).

**Additional fix:** In `EditablePagePane`, the `RawPointerListener` wraps the entire pane and
uses the `Listener` widget which fires on ALL pointer events. When the user draws a horizontal
stroke that starts near the pane edge, it must NOT trigger page navigation. The fix (edge tap
zones outside the page bounds) already solves this since navigation is no longer triggered by
the canvas's `Listener`.

---

## 2. PREREQUISITES — DO THESE FIRST

**P-1:** Run `flutter analyze`. Fix ALL existing issues before adding new code.

**P-2:** Run `flutter test`. All tests must pass.

**P-3:** Identify and report the exact current line numbers for these methods in
`book_view_notifier.dart`:
- `calculateSpreadPages()`
- `nextSpread()`
- `jumpToPage()`

**P-4:** Confirm `Notebook` Isar schema does NOT currently have a `backgroundColor` field:
```bash
grep "backgroundColor" lib/features/home/domain/models/notebook.dart
```
Expected: no output. If it already exists, skip Part A of Bug 2.

---

## 3. IMPLEMENTATION ORDER

Fix bugs in this exact order. Do not reorder.

```
STEP 1  → Fix Bug 1: calculateSpreadPages, nextSpread, jumpToPage, display label
STEP 2  → VERIFY: hot reload, confirm spread 0 shows Pages 1&2, spread 1 shows Pages 3&4
STEP 3  → Fix Bug 2 Part A: add backgroundColor to Notebook Isar schema
STEP 4  → Run: dart run build_runner build --delete-conflicting-outputs
STEP 5  → Fix Bug 2 Part B: thread backgroundColor through BookViewScreen → EditablePagePane → CanvasWidget
STEP 6  → Fix Bug 2 Part C: persist backgroundColor when user changes paper colour in editor
STEP 7  → VERIFY: change paper colour in editor, open Book View, both pages show correct colour
STEP 8  → Fix Bug 3: book aesthetics redesign (outer container, spine, page shadows, warm paper)
STEP 9  → VERIFY: Book View looks like a physical book (no regression on canvas functionality)
STEP 10 → Fix Bug 4: AnimatedSwitcher page-turn animation + remove outer GestureDetector
STEP 11 → Fix Bug 6: add edge tap zones for navigation
STEP 12 → VERIFY: swiping left/right animates correctly, drawing on canvas no longer triggers spread change
STEP 13 → Fix Bug 5: replace BookSpreadNavBar entirely with thumbnail filmstrip implementation
STEP 14 → VERIFY: thumbnails load, active spread highlighted, tapping thumbnail navigates correctly
STEP 15 → Run full flutter analyze (must be 0 issues)
STEP 16 → Run all QA checks (Section 4)
STEP 17 → Run cleanup protocol (Section 5)
STEP 18 → Run final audit (Section 6)
```

---

## 4. QA CHECKLIST

Run through every item manually on the device/emulator.

### Bug 1 — Spread Logic
- [ ] Open a notebook with 6 pages. Spread 0 shows Pages 1 & 2. Spread 1 shows Pages 3 & 4. Spread 2 shows Pages 5 & 6.
- [ ] Forward button disabled on the last spread. Back button disabled on spread 0.
- [ ] Nav bar displays "Spread 1 / 3" on spread 0, "Spread 2 / 3" on spread 1 (1-indexed).
- [ ] Open a notebook with 1 page. Spread 0 shows Page 1 on left, empty slot on right. No crash.
- [ ] Open a notebook with 7 pages. Last spread shows Page 7 on left, empty slot on right.
- [ ] `jumpToPage(3)` navigates to Spread 1 (pages 3 & 4). `jumpToPage(0)` navigates to Spread 0.

### Bug 2 — Paper Colour
- [ ] Set paper colour to cream (#FAF7F0) in editor. Open Book View. Both pages are cream.
- [ ] Set paper colour to dark (#1C1C1E). Open Book View. Both pages are dark.
- [ ] Close app entirely. Reopen. Open Book View. Colour persists correctly.
- [ ] Draw on a cream-coloured page in Book View. Strokes are visible (not hidden by white background).

### Bug 3 — Book Aesthetics
- [ ] Book View looks like a physical book — dark hardcover surround, visible spine, subtle page shadows.
- [ ] Spine is visible and clearly separates the two pages.
- [ ] Pages have a subtle shadow on their outer edges.
- [ ] White-background notebooks display with warm cream tone in Book View.

### Bug 4 — Page-Turn Animation
- [ ] Tapping the right arrow animates with a left-slide transition (new pages come from the right).
- [ ] Tapping the left arrow animates with a right-slide transition (new pages come from the left).
- [ ] Animation duration is ~350ms — not too slow, not jarring.
- [ ] Drawing a horizontal stroke on the canvas does NOT trigger a spread change.
- [ ] Left and right edge tap zones (outside page bounds) trigger navigation correctly.

### Bug 5 — Thumbnail Filmstrip
- [ ] BookSpreadNavBar shows thumbnail images for all spreads.
- [ ] Active spread has `AppColors.accent` border highlight.
- [ ] Tapping a non-active spread thumbnail navigates to that spread with animation.
- [ ] Filmstrip auto-scrolls to keep active spread visible.
- [ ] For a page with no thumbnail yet: shows warm placeholder, not an error.
- [ ] After drawing on a page in Book View: thumbnail updates when saving (not necessarily live).

### Regression — Existing Functionality
- [ ] Drawing strokes on both pages in a spread works correctly.
- [ ] Undo/redo works on both pages in a spread.
- [ ] Shapes and imported content visible correctly in Book View.
- [ ] Saving and loading strokes between spreads still works (no ghosting bug regression).
- [ ] Page count in `BookViewState.totalPages` stays in sync with actual Isar page count.
- [ ] `flutter analyze` → 0 errors, 0 warnings.

---

## 5. CLEANUP PROTOCOL

After all QA checks pass:

**C-1:** Search for and remove any debug prints added during fixing:
```bash
grep -rn "print(\|debugPrint(" lib/features/editor/presentation/screens/book_view_screen.dart
grep -rn "print(\|debugPrint(" lib/features/editor/presentation/book_view_notifier.dart
grep -rn "print(\|debugPrint(" lib/features/editor/presentation/widgets/book_spread_nav_bar.dart
```

**C-2:** Remove any TODO comments that are now resolved.

**C-3:** Verify the old `GestureDetector` that was wrapping the `LayoutBuilder` is fully removed.
No vestigial drag handler code should remain.

**C-4:** Confirm `EditablePagePane` no longer has `Container(color: Colors.white)` anywhere.
```bash
grep "Colors.white" lib/features/editor/presentation/screens/book_view_screen.dart
```
Expected: zero matches (or only in comments).

**C-5:** Full rebuild:
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --debug
```
APK must build cleanly.

**C-6:** Run all tests:
```bash
flutter test
```
All must pass.

---

## 6. FINAL AUDIT — FLUTTER INSPECTOR & DEVTOOLS

### Step A-1: Launch
```bash
flutter run --debug
```

### Step A-2: Widget Tree Inspection (Flutter Inspector)
Navigate to Book View in the running app. Open Flutter Inspector and verify:
- [ ] `BookViewScreen` → `Scaffold` → `body` → `Stack` → `Column` → contains `BookSpreadNavBar` at top.
- [ ] `BookSpreadNavBar` widget tree contains a `ListView` (the filmstrip) — NOT just a `Row` of two `IconButton`s.
- [ ] The canvas `Stack` inside each `EditablePagePane` has 6 `RepaintBoundary` children (Layers 0–5). This must not have changed.
- [ ] `Container(color: Colors.white)` does NOT appear anywhere inside `EditablePagePane`.
- [ ] `AnimatedSwitcher` wraps the spread content (the Row of panes + spine).
- [ ] The outer `GestureDetector` that previously wrapped `LayoutBuilder` is gone. Two thin `Positioned` `GestureDetector` widgets (edge zones) exist in the `Stack` instead.

### Step A-3: Performance
Enable overlay temporarily:
```dart
showPerformanceOverlay: true
```
- [ ] Drawing strokes in Book View: GPU thread stays below 16ms.
- [ ] Triggering spread change animation: no dropped frames (animation runs on GPU).
- [ ] Scrolling the thumbnail filmstrip: smooth, no jank.

### Step A-4: Memory
In DevTools → Memory:
- [ ] Navigate through all spreads of a 10-page notebook. Memory does not grow unboundedly.
- [ ] Thumbnail filmstrip loads lazily — memory does not spike when BookSpreadNavBar first appears.

### Step A-5: End-to-End Validation
Execute exactly:
1. Open InkFlow. Create a notebook with 6 pages. Set paper colour to cream.
2. Write distinct content on Pages 1–4.
3. Open Book View.
4. **Verify:** Spread 1 (displayed as "1 / 3") shows Pages 1 & 2, both cream coloured.
5. Tap right arrow. **Verify:** Pages 3 & 4 slide in from the right with animation.
6. Draw a horizontal stroke across the full width of Page 3. **Verify:** No accidental spread change.
7. Tap the Page 1&2 thumbnail in the filmstrip. **Verify:** Returns to spread 0 with left-slide animation.
8. Tap the left edge zone (outside the page). **Verify:** Nothing changes (already on first spread).
9. Force-close the app. Reopen. Open Book View for the same notebook.
10. **Verify:** Cream colour persists, strokes on all pages intact, spread starts at 0.

If every step passes: **Book View bugs are resolved.**

### Step A-6: Remove Debug Flags
```dart
showPerformanceOverlay: false,  // or remove the line
```

---

## 7. COMPLETION REPORT

```
BOOK VIEW BUG FIX COMPLETE
===========================
Files modified:
  - lib/features/editor/presentation/book_view_notifier.dart     (Bug 1)
  - lib/features/home/domain/models/notebook.dart                (Bug 2 - schema)
  - lib/features/home/domain/models/notebook.g.dart              (regenerated)
  - lib/features/editor/presentation/screens/book_view_screen.dart (Bugs 2,3,4,6)
  - lib/features/editor/presentation/widgets/book_spread_nav_bar.dart (Bug 5)
  - [any other file modified]

build_runner run: YES
flutter analyze: 0 errors, 0 warnings
flutter test: X passed, 0 failed
All 6 bugs resolved: YES
QA checklist: all items verified
Cleanup: all 6 steps complete
DevTools audit: all 6 steps complete

Known limitations deferred:
  - [anything intentionally left for Phase 6]
```
