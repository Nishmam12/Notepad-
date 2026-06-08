import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../image_service.dart';
import '../../editor/presentation/imported_content_notifier.dart';
import '../../editor/presentation/shape_notifier.dart';
import '../../../core/constants/app_colors.dart';

class ImportBottomSheet extends ConsumerWidget {
  final int notebookId;
  final int pageIndex;

  const ImportBottomSheet({super.key, required this.notebookId, required this.pageIndex});

  static Future<void> show(BuildContext context, int notebookId, int pageIndex) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => ImportBottomSheet(
        notebookId: notebookId,
        pageIndex: pageIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Import PDF'),
            onTap: () {
              Navigator.of(context).pop();
              // Navigate to PDF wizard
              context.push('/import/pdf', extra: {
                'notebookId': notebookId,
                'pageIndex': pageIndex,
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Import Image from Gallery'),
            onTap: () async {
              Navigator.of(context).pop();
              final service = ImageService(ref.read(pdfCacheManagerProvider));
              try {
                final content = await service.pickFromGallery(notebookId.toString());
                if (content != null) {
                  await ref.read(importedContentProvider(pageIndex).notifier)
                      .addContent(notebookId, content);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to import image: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.draw_outlined, color: AppColors.accentPurple),
            title: const Text('Import SVG'),
            subtitle: const Text('Place vector graphic on current page'),
            onTap: () async {
              Navigator.of(context).pop();
              final service = ImageService(ref.read(pdfCacheManagerProvider));
              try {
                final shape = await service.pickSvg(notebookId.toString());
                if (shape != null) {
                  ref.read(shapeProvider(pageIndex).notifier).addShape(shape);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to import SVG: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
