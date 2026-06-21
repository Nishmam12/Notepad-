# InkFlow 2.0 — Regression Checklist

Run before shipping a build that touches the editor or persistence. The
automated suite (`flutter analyze` + `flutter test`) is the first gate; this
covers the device-only behaviour the headless tests can't.

## Automated gate
- [ ] `flutter analyze` → no issues
- [ ] `flutter test` → all green

## Data safety (most important — must never regress)
- [ ] Launch a build that has **existing 1.0.x notebooks**. App opens normally.
- [ ] Legacy editor (`Settings → Canvas 2.0 editor` **off**) opens every existing
      notebook with all strokes/shapes/images intact.
- [ ] On disk: original `.ink` files and `NotePage.shapes`/`importedContents`
      are still present after first launch (migration is non-destructive).
- [ ] Re-launching does not duplicate migrated content (migration is idempotent).

## Classic editor (unchanged baseline)
- [ ] Draw, erase, shapes, lasso, undo/redo, page add/delete, book view.
- [ ] Palm rejection: pen draws, palm ignored, two-finger pan/zoom works.

## Canvas 2.0 (Settings → Canvas 2.0 editor **on**)
- [ ] Open a notebook → edits load; draw a stroke, reopen the page → it persists.
- [ ] Tools: select, pen, shape (all types + styling sheet), text, frame,
      eraser (element + pixel), laser, hand (pan/zoom).
- [ ] Selection: marquee, move, 8-handle resize (shift = aspect, alt = centre),
      rotate, group/ungroup, lock, align/distribute, z-order.
- [ ] Frames: draw a frame over content; move the frame → contents move and stay
      clipped to it.
- [ ] Undo/redo covers every edit above.
- [ ] Element library: save a selection, reopen it on another page.
- [ ] Clipboard: copy here, paste on another page.
- [ ] Export/share PNG, SVG, PDF (selection vs whole page) — images render, not
      placeholders.
- [ ] Paper colour + template match the notebook; Book View shows correct pages
      with the filmstrip and no draw/swipe conflict.

## Performance (device)
- [ ] A ~500-stroke page stays at 60fps while drawing and panning/zooming.
- [ ] Importing/showing several images does not crash on rapid page switches
      (ref-counted image cache).
