import '../../domain/models/shape_element.dart';
import '../../presentation/shape_notifier.dart';
import 'command.dart';

class ShapeDeleteCommand extends Command {
  final ShapeNotifier _shapeNotifier;
  final ShapeElement _shape;

  ShapeDeleteCommand({
    required ShapeNotifier shapeNotifier,
    required ShapeElement shape,
  })  : _shapeNotifier = shapeNotifier,
        _shape = shape;

  @override
  void execute() {
    _shapeNotifier.removeShape(_shape.id);
  }

  @override
  void undo() {
    _shapeNotifier.addShape(_shape);
  }
}
