// Debounced autosave: coalesces rapid edits into one save after a quiet period.
// Editor mutations call [schedule]; [flush] forces a pending save (e.g. on
// page switch / app pause); [dispose] cancels.

import 'dart:async';

class AutosaveController {
  final Duration debounce;
  final Future<void> Function() onSave;
  Timer? _timer;

  AutosaveController({
    required this.onSave,
    this.debounce = const Duration(seconds: 1),
  });

  bool get hasPending => _timer?.isActive ?? false;

  void schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      onSave();
    });
  }

  /// Saves immediately if a save is pending.
  Future<void> flush() async {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _timer = null;
      await onSave();
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
