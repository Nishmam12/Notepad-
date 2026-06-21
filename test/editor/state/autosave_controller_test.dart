import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/editor/state/autosave_controller.dart';

void main() {
  test('debounce coalesces rapid edits into one save', () async {
    var saves = 0;
    final a = AutosaveController(
        onSave: () async => saves++,
        debounce: const Duration(milliseconds: 50));

    a.schedule();
    a.schedule();
    a.schedule();
    expect(saves, 0);

    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(saves, 1);
    a.dispose();
  });

  test('flush saves a pending edit immediately', () async {
    var saves = 0;
    final a = AutosaveController(
        onSave: () async => saves++,
        debounce: const Duration(seconds: 10));

    a.schedule();
    expect(a.hasPending, true);
    await a.flush();
    expect(saves, 1);
    expect(a.hasPending, false);
    a.dispose();
  });

  test('flush is a no-op when nothing is pending', () async {
    var saves = 0;
    final a = AutosaveController(onSave: () async => saves++);
    await a.flush();
    expect(saves, 0);
    a.dispose();
  });
}
