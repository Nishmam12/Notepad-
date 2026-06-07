// Abstract command interface for the undo/redo system (Command pattern).

abstract class Command {
  /// Executes the command.
  void execute();

  /// Reverses the command.
  void undo();
}
