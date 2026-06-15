import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/editor/domain/models/stroke_point.dart';
import 'package:inkflow/features/editor/presentation/canvas/input/raw_pointer_listener.dart';

void main() {
  // Records which pointer kinds reached the drawing callbacks so we can assert
  // that palm (touch) input is rejected regardless of whether it lands before
  // or after the stylus.
  late List<PointerDeviceKind> downs;
  late List<PointerDeviceKind> moves;
  late int cancels;

  Future<void> pumpListener(WidgetTester tester) async {
    downs = [];
    moves = [];
    cancels = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RawPointerListener(
          onStrokeCancel: () => cancels++,
          onPointerDown: (event, StrokePoint _) => downs.add(event.kind),
          onPointerMove: (event, StrokePoint _) => moves.add(event.kind),
          onPointerUp: (event, StrokePoint _) {},
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  group('RawPointerListener palm rejection', () {
    testWidgets('rejects a touch that lands while the stylus is down', (tester) async {
      await pumpListener(tester);

      final pen = await tester.startGesture(const Offset(100, 100),
          kind: PointerDeviceKind.stylus);
      final palm = await tester.startGesture(const Offset(50, 50),
          kind: PointerDeviceKind.touch);

      await palm.moveBy(const Offset(5, 5));
      await pen.moveBy(const Offset(5, 5));
      await pen.up();
      await palm.up();

      // Only the stylus ever drew; the palm was ignored entirely.
      expect(downs, [PointerDeviceKind.stylus]);
      expect(moves, everyElement(PointerDeviceKind.stylus));
      expect(cancels, 0);
    });

    testWidgets('rejects a palm that lands BEFORE the pen (retroactive)', (tester) async {
      await pumpListener(tester);

      // Palm rests first, then the pen starts writing.
      final palm = await tester.startGesture(const Offset(50, 50),
          kind: PointerDeviceKind.touch);
      final pen = await tester.startGesture(const Offset(100, 100),
          kind: PointerDeviceKind.stylus);

      await palm.moveBy(const Offset(5, 5));
      await pen.moveBy(const Offset(5, 5));
      await pen.up();
      await palm.up();

      // The palm's stray stroke was discarded the moment the pen landed, and the
      // pen then drew cleanly. The palm's subsequent move never reached drawing.
      expect(cancels, 1);
      expect(downs, [PointerDeviceKind.touch, PointerDeviceKind.stylus]);
      expect(moves, [PointerDeviceKind.stylus]);
    });

    testWidgets('rejects a touch in the grace window right after the pen lifts',
        (tester) async {
      await pumpListener(tester);

      final pen = await tester.startGesture(const Offset(100, 100),
          kind: PointerDeviceKind.stylus);
      await pen.up();

      // Palm re-taps in the gap between strokes — still rejected.
      final palm = await tester.startGesture(const Offset(50, 50),
          kind: PointerDeviceKind.touch);
      await palm.up();

      expect(downs, [PointerDeviceKind.stylus]);
    });

    testWidgets('a lone finger still draws when no stylus is involved', (tester) async {
      await pumpListener(tester);

      final finger = await tester.startGesture(const Offset(50, 50),
          kind: PointerDeviceKind.touch);
      await finger.moveBy(const Offset(5, 5));
      await finger.up();

      // No stylus ever seen, so finger drawing is unaffected.
      expect(downs, [PointerDeviceKind.touch]);
      expect(moves, [PointerDeviceKind.touch]);
      expect(cancels, 0);
    });
  });
}
