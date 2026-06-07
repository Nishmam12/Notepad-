// Concrete command for adding a stroke — supports undo by removing it.

import '../../domain/models/stroke.dart';
import '../../presentation/canvas_notifier.dart';
import 'command.dart';

class StrokeAddCommand extends Command {
  final CanvasStateNotifier _canvasNotifier;
  final Stroke _stroke;

  StrokeAddCommand({
    required CanvasStateNotifier canvasNotifier,
    required Stroke stroke,
  })  : _canvasNotifier = canvasNotifier,
        _stroke = stroke;

  @override
  void execute() {
    _canvasNotifier.addStroke(_stroke);
  }

  @override
  void undo() {
    _canvasNotifier.removeLastStroke();
  }
}
