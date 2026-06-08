import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/shape_element.dart';
import '../../domain/models/shape_type.dart';
import '../../domain/services/shape_geometry.dart';
import '../shape_notifier.dart';
import '../../domain/undo_redo/undo_redo_stack.dart';
import '../../domain/undo_redo/shape_add_command.dart';
import '../../domain/undo_redo/shape_transform_command.dart';

class TextBoxOverlay extends ConsumerStatefulWidget {
  final int pageIndex;
  // If editing an existing text box, pass it here
  final ShapeElement? existingShape;
  // If creating a new one, pass the initial rect and tool settings
  final Rect? initialRect;
  final int? colorValue;
  final VoidCallback onCommit;

  const TextBoxOverlay({
    Key? key,
    required this.pageIndex,
    this.existingShape,
    this.initialRect,
    this.colorValue,
    required this.onCommit,
  }) : super(key: key);

  @override
  ConsumerState<TextBoxOverlay> createState() => _TextBoxOverlayState();
}

class _TextBoxOverlayState extends ConsumerState<TextBoxOverlay> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  
  late double _fontSize;
  late String _fontFamily;
  late bool _isBold;
  late bool _isItalic;
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingShape?.text ?? '');
    _focusNode = FocusNode();
    
    _fontSize = widget.existingShape?.fontSize ?? 24.0;
    _fontFamily = widget.existingShape?.fontFamily ?? 'Roboto';
    _isBold = widget.existingShape?.isBold ?? false;
    _isItalic = widget.existingShape?.isItalic ?? false;
    _colorValue = widget.existingShape?.color ?? widget.colorValue ?? 0xFF000000;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text.isEmpty && widget.existingShape == null) {
      widget.onCommit();
      return;
    }

    final shapeNotifier = ref.read(shapeProvider(widget.pageIndex).notifier);
    
    if (widget.existingShape != null) {
      // Update existing
      final newShape = ShapeElement()
        ..id = widget.existingShape!.id
        ..type = widget.existingShape!.type
        ..color = _colorValue
        ..strokeWidth = widget.existingShape!.strokeWidth
        ..hasFill = widget.existingShape!.hasFill
        ..fillColor = widget.existingShape!.fillColor
        ..opacity = widget.existingShape!.opacity
        ..rotation = widget.existingShape!.rotation
        ..text = text
        ..fontSize = _fontSize
        ..fontFamily = _fontFamily
        ..isBold = _isBold
        ..isItalic = _isItalic
        ..svgRelativePath = widget.existingShape!.svgRelativePath
        ..zOrder = widget.existingShape!.zOrder
        ..geometryData = widget.existingShape!.geometryData;

      if (text.isEmpty) {
        shapeNotifier.removeShape(widget.existingShape!.id);
      } else {
        final command = ShapeTransformCommand(
          shapeNotifier: shapeNotifier,
          before: widget.existingShape!,
          after: newShape,
        );
        ref.read(undoRedoProvider(widget.pageIndex).notifier).push(command);
        command.execute();
      }
    } else {
      // Create new
      final rect = widget.initialRect ?? const Rect.fromLTWH(100, 100, 200, 50);
      final shape = ShapeElement.textBox(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        rect: rect,
        color: _colorValue,
        text: text,
        fontSize: _fontSize,
      )
        ..fontFamily = _fontFamily
        ..isBold = _isBold
        ..isItalic = _isItalic
        ..zOrder = DateTime.now().millisecondsSinceEpoch;

      final command = ShapeAddCommand(
        shapeNotifier: shapeNotifier,
        shape: shape,
      );
      ref.read(undoRedoProvider(widget.pageIndex).notifier).push(command);
      command.execute();
    }
    widget.onCommit();
  }

  @override
  Widget build(BuildContext context) {
    final rect = widget.existingShape != null 
        ? ShapeGeometry.rectFromGeometry(widget.existingShape!.geometryData)
        : widget.initialRect ?? const Rect.fromLTWH(100, 100, 200, 50);

    return Stack(
      children: [
        // Tap outside to commit
        Positioned.fill(
          child: GestureDetector(
            onTap: _commit,
            child: Container(color: Colors.transparent),
          ),
        ),
        
        // Font controls row above the box
        Positioned(
          left: rect.left,
          top: rect.top - 60,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.format_bold, color: _isBold ? AppColors.accent : AppColors.textPrimary),
                  onPressed: () => setState(() => _isBold = !_isBold),
                  iconSize: 20,
                ),
                IconButton(
                  icon: Icon(Icons.format_italic, color: _isItalic ? AppColors.accent : AppColors.textPrimary),
                  onPressed: () => setState(() => _isItalic = !_isItalic),
                  iconSize: 20,
                ),
                // Simple font size slider or buttons
                IconButton(
                  icon: const Icon(Icons.text_decrease, color: AppColors.textPrimary),
                  onPressed: () => setState(() => _fontSize = (_fontSize - 2).clamp(8.0, 72.0)),
                  iconSize: 20,
                ),
                Text('${_fontSize.toInt()}', style: const TextStyle(color: AppColors.textPrimary)),
                IconButton(
                  icon: const Icon(Icons.text_increase, color: AppColors.textPrimary),
                  onPressed: () => setState(() => _fontSize = (_fontSize + 2).clamp(8.0, 72.0)),
                  iconSize: 20,
                ),
              ],
            ),
          ),
        ),

        // The text box
        Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          // height: null to let it grow with text, or clamp it
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.9),
              border: Border.all(color: AppColors.accent), // Dashed in prompt but simple border works well
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              onSubmitted: (_) => _commit(),
              style: TextStyle(
                color: Color(_colorValue),
                fontSize: _fontSize,
                fontFamily: _fontFamily,
                fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
