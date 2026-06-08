import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/imported_content.dart';
import '../imported_content_notifier.dart';

class FreeImageOverlay extends ConsumerStatefulWidget {
  final int notebookId;
  final int pageIndex;

  const FreeImageOverlay({super.key, required this.notebookId, required this.pageIndex});

  @override
  ConsumerState<FreeImageOverlay> createState() => _FreeImageOverlayState();
}

class _FreeImageOverlayState extends ConsumerState<FreeImageOverlay> {
  String? _activeContentId;
  Offset _initialFocalPoint = Offset.zero;
  double _initialX = 0;
  double _initialY = 0;
  double _initialWidth = 0;
  double _initialHeight = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importedContentProvider(widget.pageIndex));
    final freeImages = state.contents.where((c) => c.type == ImportedContentType.freeImage).toList();

    if (freeImages.isEmpty) {
      return const SizedBox.shrink(); // Nothing to interact with
    }

    return Stack(
      children: freeImages.map((content) {
        return Positioned(
          left: content.x,
          top: content.y,
          width: content.width,
          height: content.height,
          child: GestureDetector(
            onScaleStart: (details) {
              _activeContentId = content.id;
              _initialFocalPoint = details.focalPoint;
              _initialX = content.x;
              _initialY = content.y;
              _initialWidth = content.width;
              _initialHeight = content.height;
            },
            onScaleUpdate: (details) {
              if (_activeContentId == content.id) {
                final dx = details.focalPoint.dx - _initialFocalPoint.dx;
                final dy = details.focalPoint.dy - _initialFocalPoint.dy;

                ref.read(importedContentProvider(widget.pageIndex).notifier).updateTransform(
                  widget.notebookId,
                  id: content.id,
                  x: _initialX + dx,
                  y: _initialY + dy,
                  width: _initialWidth * details.scale,
                  height: _initialHeight * details.scale,
                );
              }
            },
            onScaleEnd: (details) {
              _activeContentId = null;
            },
            onLongPress: () {
              // Delete on long press for now
              ref.read(importedContentProvider(widget.pageIndex).notifier).removeContent(
                widget.notebookId,
                content.id,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.surface.withValues(alpha: 0.9), width: 2),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
