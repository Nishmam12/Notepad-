import '../../domain/models/shape_element.dart';
import '../../presentation/shape_notifier.dart';
import 'command.dart';

class ShapeTransformCommand extends Command {
  final ShapeNotifier _shapeNotifier;
  final ShapeElement _before;
  final ShapeElement _after;

  ShapeTransformCommand({
    required ShapeNotifier shapeNotifier,
    required ShapeElement before,
    required ShapeElement after,
  })  : _shapeNotifier = shapeNotifier,
        _before = before,
        _after = after;

  @override
  void execute() {
    _shapeNotifier.updateShape(_after);
  }

  @override
  void undo() {
    _shapeNotifier.updateShape(_before);
  }
}
